import Foundation

// MARK: - ProcessingPipeline

/// Orchestrates the full file processing flow:
/// cache → process → validate → replace original.
actor ProcessingPipeline {
    private let ffmpegService: FFmpegService
    private let mkvService: MKVToolNixService
    private let validationService: ValidationService
    private let cacheManager: CacheManager
    private let logger: LoggingService
    private let settings: AppSettings

    private var isCancelled = false

    init(
        ffmpegService: FFmpegService,
        mkvService: MKVToolNixService,
        validationService: ValidationService,
        cacheManager: CacheManager,
        logger: LoggingService,
        settings: AppSettings
    ) {
        self.ffmpegService = ffmpegService
        self.mkvService = mkvService
        self.validationService = validationService
        self.cacheManager = cacheManager
        self.logger = logger
        self.settings = settings
    }

    /// Process a single file through the full pipeline.
    func processFile(
        sourceURL: URL,
        jobID: UUID,
        fileID: UUID,
        analysisResult: FileAnalysisResult,
        jobSettings: JobSettings,
        onProgress: (@Sendable (FileProcessingProgress) -> Void)? = nil
    ) async throws -> FileProcessingResult {
        guard !isCancelled else { throw PipelineError.cancelled }

        // Ensure we have security-scoped access to the source folder
        let scopedURL = BookmarkStore.shared.startAccessing(path: sourceURL.path)
        defer {
            if let scopedURL { BookmarkStore.shared.stopAccessing(scopedURL) }
        }

        let startTime = Date()

        await logger.logInfo("Processing: \(sourceURL.lastPathComponent)")
        onProgress?(.init(stage: .caching, progress: 0, message: "Copying to local cache..."))

        // 1. Cache the source file locally
        let cachedFile: URL
        do {
            cachedFile = try await cacheManager.cacheFile(
                source: sourceURL,
                jobID: jobID,
                fileID: fileID
            )
        } catch {
            await logger.logError("Cache failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            throw PipelineError.cacheFailed(error)
        }

        guard !isCancelled else {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            throw PipelineError.cancelled
        }

        onProgress?(.init(stage: .processing, progress: 0.3, message: "Processing streams..."))

        // 2. Process the file
        // If there's a remux action, use the target container as the output extension
        let targetExtension: String? = analysisResult.actions.compactMap { action in
            if case .remuxContainer(_, let to) = action { return to }
            return nil
        }.first
        let outputFile = await cacheManager.outputPath(for: cachedFile, outputExtension: targetExtension)
        let processResult: ProcessResult
        do {
            processResult = try await executeProcessing(
                inputPath: cachedFile,
                outputPath: outputFile,
                analysisResult: analysisResult
            )
        } catch {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            await logger.logError("Processing failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            throw PipelineError.processingFailed(error)
        }

        guard !isCancelled else {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            throw PipelineError.cancelled
        }

        onProgress?(.init(stage: .validating, progress: 0.7, message: "Validating output..."))

        // 3. Validate the output
        let validationResult = try await validationService.validate(
            processedFileURL: outputFile,
            originalMediaInfo: analysisResult.mediaInfo,
            actions: analysisResult.actions
        )

        guard validationResult.isAcceptable else {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            await logger.logError("Validation failed for \(sourceURL.lastPathComponent)")
            throw PipelineError.validationFailed
        }

        guard !isCancelled else {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            throw PipelineError.cancelled
        }

        // 4. Dry run: skip replacement
        if jobSettings.dryRun {
            let outputSize = fileSize(at: outputFile)
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            return FileProcessingResult(
                originalSize: analysisResult.mediaInfo.fileSize,
                processedSize: outputSize,
                commandLog: processResult.command,
                duration: Date().timeIntervalSince(startTime),
                wasDryRun: true
            )
        }

        onProgress?(.init(stage: .replacing, progress: 0.85, message: "Replacing original..."))

        // 5. Replace the original
        let outputSize = fileSize(at: outputFile)
        do {
            try await replaceOriginal(
                source: outputFile,
                destination: sourceURL,
                createBackup: jobSettings.createBackup
            )
        } catch {
            await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)
            await logger.logError("Replace failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            throw PipelineError.replaceFailed(error)
        }

        onProgress?(.init(stage: .cleanup, progress: 0.95, message: "Cleaning up..."))

        // 6. Clean up cache and backup files
        await cacheManager.cleanFileCache(jobID: jobID, fileID: fileID)

        // Remove backup file after successful processing — the output
        // has already been validated, so the backup is no longer needed.
        if jobSettings.createBackup {
            let backupURL = sourceURL.appendingPathExtension("chaotic-backup")
            try? FileManager.default.removeItem(at: backupURL)
        }

        let result = FileProcessingResult(
            originalSize: analysisResult.mediaInfo.fileSize,
            processedSize: outputSize,
            commandLog: processResult.command,
            duration: Date().timeIntervalSince(startTime),
            wasDryRun: false
        )

        await logger.logInfo("Completed \(sourceURL.lastPathComponent): saved \(ByteCountFormatter.string(fromByteCount: result.bytesSaved, countStyle: .file))")

        onProgress?(.init(stage: .done, progress: 1.0, message: "Done"))

        return result
    }

    func cancel() {
        isCancelled = true
    }

    func reset() {
        isCancelled = false
    }

    // MARK: - Processing Execution

    private func executeProcessing(
        inputPath: URL,
        outputPath: URL,
        analysisResult: FileAnalysisResult
    ) async throws -> ProcessResult {
        let isMKV = inputPath.pathExtension.lowercased() == "mkv"
        let mkvAvailable = await mkvService.isAvailable
        let useMkvmerge = isMKV && mkvAvailable && isStreamRemovalOnly(analysisResult.actions)

        if useMkvmerge {
            // Use mkvmerge for pure stream removal from MKV files
            let audioToRemove = analysisResult.actions.compactMap { action -> Int? in
                if case .removeStream(let idx, _) = action,
                   analysisResult.mediaInfo.audioStreams.contains(where: { $0.index == idx }) {
                    return idx
                }
                return nil
            }

            let subsToRemove = analysisResult.actions.compactMap { action -> Int? in
                if case .removeStream(let idx, _) = action,
                   analysisResult.mediaInfo.subtitleStreams.contains(where: { $0.index == idx }) {
                    return idx
                }
                return nil
            }

            return try await mkvService.removeStreams(
                inputPath: inputPath,
                outputPath: outputPath,
                audioIndicesToRemove: audioToRemove,
                subtitleIndicesToRemove: subsToRemove
            )
        } else {
            // Use ffmpeg for everything else
            return try await ffmpegService.process(
                inputPath: inputPath,
                outputPath: outputPath,
                actions: analysisResult.actions,
                mediaInfo: analysisResult.mediaInfo
            )
        }
    }

    private func isStreamRemovalOnly(_ actions: [PlannedAction]) -> Bool {
        for action in actions {
            switch action {
            case .keepStream, .removeStream, .copyStream:
                continue
            case .remuxContainer, .transcodeVideo, .transcodeAudio:
                return false
            }
        }
        return true
    }

    // MARK: - File Replacement

    private func replaceOriginal(source: URL, destination: URL, createBackup: Bool) async throws {
        // Resolve security-scoped bookmark to regain access to the destination folder
        let scopedURL = BookmarkStore.shared.startAccessing(path: destination.path)
        defer {
            if let scopedURL { BookmarkStore.shared.stopAccessing(scopedURL) }
        }

        let fm = FileManager.default

        // Create backup if requested
        if createBackup {
            let backupURL = destination.appendingPathExtension("chaotic-backup")
            if fm.fileExists(atPath: backupURL.path) {
                try fm.removeItem(at: backupURL)
            }
            try fm.copyItem(at: destination, to: backupURL)
            await logger.logDiagnostic("Created backup: \(backupURL.lastPathComponent)")
        }

        // Strategy 1: replaceItemAt — atomic, handles cross-volume
        do {
            _ = try fm.replaceItemAt(destination, withItemAt: source)
            await logger.logDiagnostic("Replaced original (atomic): \(destination.lastPathComponent)")
            return
        } catch {
            await logger.logDiagnostic("replaceItemAt failed: \(error.localizedDescription)")
        }

        // Strategy 2: Direct remove + copy (no temp file in destination dir)
        // This avoids needing write permission to create new files in the
        // destination directory — we only need permission to overwrite the
        // existing file.
        do {
            try fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
            await logger.logDiagnostic("Replaced original (remove+copy): \(destination.lastPathComponent)")
            return
        } catch {
            await logger.logDiagnostic("remove+copy failed: \(error.localizedDescription)")
        }

        // Strategy 3: Copy via shell cp command as last resort
        // This can sometimes succeed where FileManager fails due to
        // different permission handling
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/cp")
            process.arguments = ["-f", source.path, destination.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                await logger.logDiagnostic("Replaced original (cp): \(destination.lastPathComponent)")
                return
            }
            let stderr = (process.standardError as? Pipe).flatMap {
                String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            } ?? ""
            throw NSError(domain: "ProcessingPipeline", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "cp failed: \(stderr)"])
        } catch {
            await logger.logError("All replacement strategies failed for \(destination.lastPathComponent): \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helpers

    private func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int64) ?? 0
    }
}

// MARK: - Pipeline Types

struct FileProcessingProgress: Sendable {
    enum Stage: String, Sendable {
        case caching = "Caching"
        case processing = "Processing"
        case validating = "Validating"
        case replacing = "Replacing"
        case cleanup = "Cleanup"
        case done = "Done"
    }

    let stage: Stage
    let progress: Double  // 0.0 - 1.0
    let message: String
}

struct FileProcessingResult: Sendable {
    let originalSize: Int64
    let processedSize: Int64
    let commandLog: String
    let duration: TimeInterval
    let wasDryRun: Bool

    var bytesSaved: Int64 {
        originalSize - processedSize
    }

    var savingsPercent: Double {
        guard originalSize > 0 else { return 0 }
        return Double(bytesSaved) / Double(originalSize) * 100
    }
}

enum PipelineError: LocalizedError {
    case cancelled
    case cacheFailed(Error)
    case processingFailed(Error)
    case validationFailed
    case replaceFailed(Error)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Processing was cancelled"
        case .cacheFailed(let e): return "Failed to cache file: \(e.localizedDescription)"
        case .processingFailed(let e): return "Processing failed: \(e.localizedDescription)"
        case .validationFailed: return "Output validation failed — original file was not modified"
        case .replaceFailed(let e): return "Failed to replace original: \(e.localizedDescription)"
        case .fileNotFound(let path): return "File not found: \(path)"
        }
    }
}
