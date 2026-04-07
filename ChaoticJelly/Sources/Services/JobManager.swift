import Foundation
import SwiftData

// MARK: - JobManager

/// Manages job lifecycle: creation, execution, persistence, and recovery.
@MainActor @Observable
final class JobManager {
    private let modelContext: ModelContext
    private let scanService: ScanService
    private let ffprobeService: FFprobeService
    private let analysisEngine: AnalysisEngine
    private let pipeline: ProcessingPipeline
    private let cacheManager: CacheManager
    private let logger: LoggingService
    private let settings: AppSettings

    // Observable state
    private(set) var activeJob: Job?
    private(set) var currentFileProgress: FileProcessingProgress?
    private(set) var isProcessing = false

    private var processingTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        scanService: ScanService,
        ffprobeService: FFprobeService,
        analysisEngine: AnalysisEngine,
        pipeline: ProcessingPipeline,
        cacheManager: CacheManager,
        logger: LoggingService,
        settings: AppSettings
    ) {
        self.modelContext = modelContext
        self.scanService = scanService
        self.ffprobeService = ffprobeService
        self.analysisEngine = analysisEngine
        self.pipeline = pipeline
        self.cacheManager = cacheManager
        self.logger = logger
        self.settings = settings
    }

    // MARK: - Job Creation

    /// Create a new job for a folder scan.
    func createJob(
        folderURL: URL,
        processingMode: ProcessingMode,
        dryRun: Bool = false
    ) -> Job {
        let job = Job(
            sourceFolderPath: folderURL.path,
            processingMode: processingMode
        )

        let jobSettings = settings.makeJobSettings(processingMode: processingMode, dryRun: dryRun)
        job.settingsSnapshot = try? JSONEncoder().encode(jobSettings)

        modelContext.insert(job)
        try? modelContext.save()

        return job
    }

    // MARK: - Scanning

    /// Scan a folder and populate the job with discovered files.
    func startScan(
        job: Job,
        folderURL: URL,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws {
        job.transition(to: .scanning)
        try? modelContext.save()

        let scannedFiles = try await scanService.scan(folderURL: folderURL, onProgress: onProgress)

        for file in scannedFiles {
            let entry = FileEntry(
                relativePath: file.relativePath,
                fileName: file.fileName,
                fileExtension: file.fileExtension,
                originalSize: file.fileSize
            )
            entry.job = job
            modelContext.insert(entry)
        }

        job.totalBytesBefore = scannedFiles.reduce(0) { $0 + $1.fileSize }
        try? modelContext.save()
    }

    // MARK: - Analysis

    /// Analyze all files in a job using ffprobe.
    func analyzeJob(
        job: Job,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws {
        job.transition(to: .analyzing)
        try? modelContext.save()

        let jobSettings = decodeJobSettings(job)
        let files = job.files.filter { $0.fileStatus == .pending }
        // Analysis is read-only (ffprobe), so we can run more concurrently
        // than the processing step which does heavy I/O.
        let concurrency = max(settings.maxConcurrentFiles * 4, 8)
        var completed = 0

        // Process files in concurrent batches
        var index = 0
        while index < files.count {
            let batchEnd = min(index + concurrency, files.count)
            let batch = Array(files[index..<batchEnd])

            // Mark batch as analyzing
            for file in batch {
                file.transition(to: .analyzing)
            }

            // Run ffprobe concurrently for the batch
            let results = await withTaskGroup(of: (Int, Result<(MediaInfo, FileAnalysisResult), Error>).self) { group in
                for (offset, file) in batch.enumerated() {
                    let fileURL = URL(fileURLWithPath: file.fullPath)
                    group.addTask { [ffprobeService, analysisEngine] in
                        do {
                            let mediaInfo = try await ffprobeService.probe(fileURL: fileURL)
                            let analysis = analysisEngine.analyze(mediaInfo: mediaInfo, settings: jobSettings)
                            return (offset, .success((mediaInfo, analysis)))
                        } catch {
                            return (offset, .failure(error))
                        }
                    }
                }

                var collected = [(Int, Result<(MediaInfo, FileAnalysisResult), Error>)]()
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            // Apply results back to file entries on the main actor
            for (offset, result) in results {
                let file = batch[offset]
                switch result {
                case .success(let (mediaInfo, analysis)):
                    file.mediaInfo = mediaInfo
                    file.analysisResult = analysis
                    file.warnings = analysis.warnings
                    if analysis.requiresProcessing {
                        file.transition(to: .analyzed)
                    } else {
                        file.transition(to: .skipped)
                    }
                case .failure(let error):
                    file.transition(to: .failed)
                    file.errorMessage = error.localizedDescription
                    job.errorCount += 1
                    await logger.logError("Analysis failed for \(file.fileName): \(error.localizedDescription)")
                }
                completed += 1
                onProgress?(completed, files.count)
            }

            try? modelContext.save()
            index = batchEnd
        }

        job.transition(to: .reviewing)
        try? modelContext.save()
    }

    // MARK: - Pipelined Analyze & Process

    /// Analyze and process files in a streaming pipeline — files are processed
    /// as soon as they're analyzed, no separate review step needed.
    func analyzeAndProcess(
        job: Job,
        onProgress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async {
        // Transition through required states to reach processing
        job.transition(to: .analyzing)
        job.transition(to: .reviewing)
        job.transition(to: .processing)
        isProcessing = true
        activeJob = job
        try? modelContext.save()

        await pipeline.reset()

        let jobSettings = decodeJobSettings(job)
        let files = job.files.filter { $0.fileStatus == .pending }
        let analyzeConcurrency = max(settings.maxConcurrentFiles * 4, 8)
        var totalAnalyzed = 0
        var totalProcessed = 0

        // Process files in batches: analyze a batch, then immediately process
        // any files that need it before moving to the next batch.
        var index = 0
        while index < files.count {
            guard job.jobStatus == .processing else { break }

            let batchEnd = min(index + analyzeConcurrency, files.count)
            let batch = Array(files[index..<batchEnd])

            // Mark batch as analyzing
            for file in batch {
                file.transition(to: .analyzing)
            }

            // Analyze batch concurrently
            let results = await withTaskGroup(of: (Int, Result<(MediaInfo, FileAnalysisResult), Error>).self) { group in
                for (offset, file) in batch.enumerated() {
                    let fileURL = URL(fileURLWithPath: file.fullPath)
                    group.addTask { [ffprobeService, analysisEngine] in
                        do {
                            let mediaInfo = try await ffprobeService.probe(fileURL: fileURL)
                            let analysis = analysisEngine.analyze(mediaInfo: mediaInfo, settings: jobSettings)
                            return (offset, .success((mediaInfo, analysis)))
                        } catch {
                            return (offset, .failure(error))
                        }
                    }
                }

                var collected = [(Int, Result<(MediaInfo, FileAnalysisResult), Error>)]()
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            // Apply analysis results
            var filesToProcess: [(FileEntry, FileAnalysisResult)] = []
            for (offset, result) in results {
                let file = batch[offset]
                switch result {
                case .success(let (mediaInfo, analysis)):
                    file.mediaInfo = mediaInfo
                    file.analysisResult = analysis
                    file.warnings = analysis.warnings
                    if analysis.requiresProcessing {
                        file.transition(to: .analyzed)
                        filesToProcess.append((file, analysis))
                    } else {
                        file.transition(to: .skipped)
                    }
                case .failure(let error):
                    file.transition(to: .failed)
                    file.errorMessage = error.localizedDescription
                    job.errorCount += 1
                    await logger.logError("Analysis failed for \(file.fileName): \(error.localizedDescription)")
                }
                totalAnalyzed += 1
            }
            try? modelContext.save()

            // Process analyzed files from this batch immediately
            for (file, analysis) in filesToProcess {
                guard job.jobStatus == .processing else { break }

                file.transition(to: .processing)
                try? modelContext.save()

                onProgress?(totalProcessed, files.count, file.fileName)

                do {
                    let sourceURL = URL(fileURLWithPath: file.fullPath)
                    let result = try await pipeline.processFile(
                        sourceURL: sourceURL,
                        jobID: job.id,
                        fileID: file.id,
                        analysisResult: analysis,
                        jobSettings: jobSettings,
                        onProgress: { [weak self] progress in
                            Task { @MainActor in
                                self?.currentFileProgress = progress
                            }
                        }
                    )
                    file.processedSize = result.processedSize
                    file.commandLog = result.commandLog
                    file.transition(to: .completed)
                    job.totalBytesAfter += result.processedSize
                } catch {
                    file.transition(to: .failed)
                    file.errorMessage = error.localizedDescription
                    job.errorCount += 1
                    await logger.logError("Processing failed for \(file.fileName): \(error.localizedDescription)")
                }

                totalProcessed += 1
                let terminalCount = job.files.filter { $0.fileStatus.isTerminal }.count
                job.progressFraction = Double(terminalCount) / Double(job.files.count)
                try? modelContext.save()
            }

            index = batchEnd
        }

        // Complete the job
        if job.jobStatus == .processing {
            let processedFiles = job.files.filter { $0.fileStatus == .completed || $0.fileStatus == .failed }
            let allFailed = !processedFiles.isEmpty && processedFiles.allSatisfy { $0.fileStatus == .failed }
            job.transition(to: allFailed ? .failed : .completed)
        }

        isProcessing = false
        activeJob = nil
        currentFileProgress = nil
        try? modelContext.save()
        await cacheManager.cleanJobCache(jobID: job.id)
    }

    // MARK: - Processing

    /// Process all analyzed files in a job.
    func processJob(job: Job) async {
        guard job.transition(to: .processing) else { return }
        isProcessing = true
        activeJob = job
        try? modelContext.save()

        await pipeline.reset()

        let jobSettings = decodeJobSettings(job)
        let filesToProcess = job.files.filter { $0.fileStatus == .analyzed }

        // Queue all files
        for file in filesToProcess {
            file.transition(to: .queued)
        }
        try? modelContext.save()

        for file in filesToProcess {
            guard job.jobStatus == .processing else { break }

            file.transition(to: .processing)
            try? modelContext.save()

            guard let analysis = file.analysisResult else {
                file.transition(to: .failed)
                file.errorMessage = "Missing analysis result"
                job.errorCount += 1
                continue
            }

            do {
                let sourceURL = URL(fileURLWithPath: file.fullPath)

                let result = try await pipeline.processFile(
                    sourceURL: sourceURL,
                    jobID: job.id,
                    fileID: file.id,
                    analysisResult: analysis,
                    jobSettings: jobSettings,
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.currentFileProgress = progress
                        }
                    }
                )

                file.processedSize = result.processedSize
                file.commandLog = result.commandLog
                file.transition(to: .completed)

                // Update job totals
                job.totalBytesAfter += result.processedSize
            } catch {
                file.transition(to: .failed)
                file.errorMessage = error.localizedDescription
                job.errorCount += 1
                await logger.logError("Processing failed for \(file.fileName): \(error.localizedDescription)")
            }

            // Update progress
            let completed = job.files.filter { $0.fileStatus.isTerminal }.count
            job.progressFraction = Double(completed) / Double(job.files.count)
            try? modelContext.save()
        }

        // Complete the job
        if job.jobStatus == .processing {
            job.transition(to: job.failedFileCount > 0 && job.failedFileCount == filesToProcess.count ? .failed : .completed)
        }

        isProcessing = false
        activeJob = nil
        currentFileProgress = nil
        try? modelContext.save()

        // Clean job cache
        await cacheManager.cleanJobCache(jobID: job.id)
    }

    // MARK: - Control

    /// Cancel the active job.
    func cancelActiveJob() async {
        guard let job = activeJob else { return }
        await pipeline.cancel()
        job.transition(to: .cancelled)
        isProcessing = false
        activeJob = nil
        try? modelContext.save()
        await cacheManager.cleanJobCache(jobID: job.id)
    }

    /// Retry failed files in a job.
    func retryFailedFiles(job: Job) async {
        let failedFiles = job.failedFiles
        guard !failedFiles.isEmpty else { return }

        // Reset failed files to analyzed state
        for file in failedFiles {
            file.status = FileStatus.analyzed.rawValue
            file.errorMessage = nil
            file.processedSize = nil
            file.startedAt = nil
            file.completedAt = nil
        }

        job.errorCount = 0
        job.status = JobStatus.reviewing.rawValue
        try? modelContext.save()
    }

    // MARK: - History

    /// Fetch all jobs, most recent first.
    func fetchJobs() -> [Job] {
        let descriptor = FetchDescriptor<Job>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch total space saved across all completed jobs.
    func totalSpaceSaved() -> Int64 {
        let jobs = fetchJobs().filter { $0.jobStatus == .completed }
        return jobs.reduce(0) { $0 + $1.bytesSaved }
    }

    /// Delete a job and its file entries.
    func deleteJob(_ job: Job) {
        modelContext.delete(job)
        try? modelContext.save()
    }

    // MARK: - Recovery

    /// Recover jobs that were in progress when the app crashed.
    func recoverInterruptedJobs() async {
        let jobs = fetchJobs().filter { $0.jobStatus.isActive }
        for job in jobs {
            await logger.logWarning("Recovering interrupted job \(job.id)")
            job.transition(to: .failed)
            job.statusMessage = "Interrupted — app was closed during processing"

            // Reset in-progress files
            for file in job.files where file.fileStatus == .processing || file.fileStatus == .validating {
                file.transition(to: .failed)
                file.errorMessage = "Interrupted by app shutdown"
            }
        }
        try? modelContext.save()

        // Clean orphaned caches
        let activeIDs = Set(fetchJobs().filter { $0.jobStatus.isActive }.map(\.id))
        await cacheManager.cleanOrphanedCaches(activeJobIDs: activeIDs)
    }

    // MARK: - Helpers

    private func decodeJobSettings(_ job: Job) -> JobSettings {
        guard let data = job.settingsSnapshot,
              let settings = try? JSONDecoder().decode(JobSettings.self, from: data) else {
            // Fallback to current settings
            return self.settings.makeJobSettings(processingMode: job.processingMode, dryRun: false)
        }
        return settings
    }
}
