import Foundation

// MARK: - CacheManager

/// Manages the local working cache for network-safe file processing.
actor CacheManager {
    private let settings: AppSettings
    private let logger: LoggingService
    private let fileManager = FileManager.default

    init(settings: AppSettings, logger: LoggingService) {
        self.settings = settings
        self.logger = logger
    }

    // MARK: - Directory Management

    /// Ensure the cache directory exists.
    func ensureCacheDirectory() throws -> URL {
        let cacheDir = settings.cachePath
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }

    /// Create a working directory for a specific job.
    func createJobDirectory(jobID: UUID) throws -> URL {
        let cacheDir = try ensureCacheDirectory()
        let jobDir = cacheDir.appendingPathComponent(jobID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: jobDir.path) {
            try fileManager.createDirectory(at: jobDir, withIntermediateDirectories: true)
        }
        return jobDir
    }

    /// Create a working directory for a specific file within a job.
    func createFileDirectory(jobID: UUID, fileID: UUID) throws -> URL {
        let jobDir = try createJobDirectory(jobID: jobID)
        let fileDir = jobDir.appendingPathComponent(fileID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: fileDir.path) {
            try fileManager.createDirectory(at: fileDir, withIntermediateDirectories: true)
        }
        return fileDir
    }

    // MARK: - File Operations

    /// Copy a source file to the local cache for processing.
    func cacheFile(
        source: URL,
        jobID: UUID,
        fileID: UUID,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let fileDir = try createFileDirectory(jobID: jobID, fileID: fileID)
        let destURL = fileDir.appendingPathComponent(source.lastPathComponent)

        // Check available space
        try await checkAvailableSpace(requiredBytes: fileSize(at: source) * 2)

        await logger.logDiagnostic("Caching \(source.lastPathComponent) to \(destURL.path)")

        // Use FileManager copy (no progress for local copy, but works for network shares)
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }

        try fileManager.copyItem(at: source, to: destURL)

        await logger.logDiagnostic("Cached successfully: \(destURL.lastPathComponent)")

        return destURL
    }

    /// Get the output file path for a processed file.
    func outputPath(
        for cachedFile: URL,
        outputExtension: String? = nil
    ) -> URL {
        let dir = cachedFile.deletingLastPathComponent()
        let name = cachedFile.deletingPathExtension().lastPathComponent
        let ext = outputExtension ?? cachedFile.pathExtension
        return dir.appendingPathComponent("\(name).processed.\(ext)")
    }

    // MARK: - Cleanup

    /// Clean up a specific file's working directory.
    func cleanFileCache(jobID: UUID, fileID: UUID) async {
        let cacheDir = settings.cachePath
        let fileDir = cacheDir
            .appendingPathComponent(jobID.uuidString)
            .appendingPathComponent(fileID.uuidString)

        do {
            if fileManager.fileExists(atPath: fileDir.path) {
                try fileManager.removeItem(at: fileDir)
                await logger.logDiagnostic("Cleaned cache for file \(fileID)")
            }
        } catch {
            await logger.logWarning("Failed to clean cache for file \(fileID): \(error.localizedDescription)")
        }
    }

    /// Clean up an entire job's working directory.
    func cleanJobCache(jobID: UUID) async {
        let cacheDir = settings.cachePath
        let jobDir = cacheDir.appendingPathComponent(jobID.uuidString)

        do {
            if fileManager.fileExists(atPath: jobDir.path) {
                try fileManager.removeItem(at: jobDir)
                await logger.logDiagnostic("Cleaned cache for job \(jobID)")
            }
        } catch {
            await logger.logWarning("Failed to clean cache for job \(jobID): \(error.localizedDescription)")
        }
    }

    /// Clean up orphaned cache directories from crashed or incomplete jobs.
    func cleanOrphanedCaches(activeJobIDs: Set<UUID>) async {
        let cacheDir = settings.cachePath
        guard fileManager.fileExists(atPath: cacheDir.path) else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            for item in contents {
                guard let uuid = UUID(uuidString: item.lastPathComponent),
                      !activeJobIDs.contains(uuid) else { continue }

                try fileManager.removeItem(at: item)
                await logger.logInfo("Cleaned orphaned cache: \(item.lastPathComponent)")
            }
        } catch {
            await logger.logWarning("Failed to scan cache for orphans: \(error.localizedDescription)")
        }
    }

    // MARK: - Space Management

    /// Check available disk space against required bytes.
    func checkAvailableSpace(requiredBytes: Int64) async throws {
        let cacheDir = try ensureCacheDirectory()

        let values = try cacheDir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0

        if available < requiredBytes {
            throw CacheError.insufficientSpace(
                required: requiredBytes,
                available: available
            )
        }
    }

    /// Get current cache usage in bytes.
    func currentCacheUsage() -> Int64 {
        let cacheDir = settings.cachePath
        guard fileManager.fileExists(atPath: cacheDir.path) else { return 0 }
        return directorySize(at: cacheDir)
    }

    /// Check if cache usage exceeds the configured limit.
    func isCacheOverLimit() -> Bool {
        currentCacheUsage() > settings.maxCacheSizeBytes
    }

    // MARK: - Helpers

    private func fileSize(at url: URL) -> Int64 {
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int64) ?? 0
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            totalSize += Int64(size)
        }
        return totalSize
    }
}

// MARK: - Cache Errors

enum CacheError: LocalizedError {
    case insufficientSpace(required: Int64, available: Int64)
    case cacheLimitExceeded(usage: Int64, limit: Int64)
    case directoryCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let req, let avail):
            return "Insufficient disk space: need \(ByteCountFormatter.string(fromByteCount: req, countStyle: .file)), available \(ByteCountFormatter.string(fromByteCount: avail, countStyle: .file))"
        case .cacheLimitExceeded(let usage, let limit):
            return "Cache limit exceeded: using \(ByteCountFormatter.string(fromByteCount: usage, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: limit, countStyle: .file))"
        case .directoryCreationFailed(let path):
            return "Cannot create cache directory: \(path)"
        }
    }
}
