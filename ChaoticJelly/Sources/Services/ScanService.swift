import Foundation

// MARK: - ScanService

/// Recursively scans directories for video files.
actor ScanService {
    private let logger: LoggingService

    init(logger: LoggingService) {
        self.logger = logger
    }

    /// Scan a folder recursively for video files.
    /// Returns file URLs sorted by path.
    func scan(
        folderURL: URL,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws -> [ScannedFile] {
        await logger.logInfo("Starting scan of \(folderURL.path)")

        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            throw ScanError.folderNotFound(folderURL.path)
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw ScanError.notADirectory(folderURL.path)
        }

        let supportedExtensions = VideoExtension.allExtensionStrings
        var results: [ScannedFile] = []
        var directoriesScanned = 0
        var filesExamined = 0

        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        guard let enumerator else {
            throw ScanError.cannotEnumerate(folderURL.path)
        }

        for case let fileURL as URL in enumerator {
            // Check cancellation
            try Task.checkCancellation()

            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])

            if resourceValues?.isDirectory == true {
                directoriesScanned += 1
                onProgress?(.init(
                    directoriesScanned: directoriesScanned,
                    filesExamined: filesExamined,
                    videoFilesFound: results.count,
                    currentPath: fileURL.path
                ))
                continue
            }

            guard resourceValues?.isRegularFile == true else { continue }

            filesExamined += 1

            let ext = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }

            // Skip temp/partial files from other tools or previous runs
            let fileName = fileURL.lastPathComponent
            if fileName.contains(".tmp.") ||
               fileName.hasSuffix(".tmp") ||
               fileName.hasSuffix(".part") ||
               fileName.hasSuffix(".chaotic-backup") ||
               fileName.hasSuffix(".chaotic-tmp") ||
               fileName.hasPrefix(".") {
                continue
            }

            let fileSize = Int64(resourceValues?.fileSize ?? 0)

            // Build relative path by removing the base folder prefix
            // Use standardized paths to avoid trailing slash / encoding issues
            let basePath = folderURL.standardizedFileURL.path
            let filePath = fileURL.standardizedFileURL.path
            let relativePath: String
            if filePath.hasPrefix(basePath) {
                var rel = String(filePath.dropFirst(basePath.count))
                if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                relativePath = rel
            } else {
                relativePath = fileURL.lastPathComponent
            }

            results.append(ScannedFile(
                url: fileURL,
                relativePath: relativePath,
                fileName: fileURL.lastPathComponent,
                fileExtension: ext,
                fileSize: fileSize
            ))

            onProgress?(.init(
                directoriesScanned: directoriesScanned,
                filesExamined: filesExamined,
                videoFilesFound: results.count,
                currentPath: fileURL.path
            ))
        }

        // Sort by path for consistent ordering
        results.sort { $0.relativePath < $1.relativePath }

        await logger.logInfo("Scan complete: \(results.count) video files found in \(directoriesScanned) directories")

        return results
    }
}

// MARK: - Scan Types

struct ScannedFile: Sendable {
    let url: URL
    let relativePath: String
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
}

struct ScanProgress: Sendable {
    let directoriesScanned: Int
    let filesExamined: Int
    let videoFilesFound: Int
    let currentPath: String
}

enum ScanError: LocalizedError {
    case folderNotFound(String)
    case notADirectory(String)
    case cannotEnumerate(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .folderNotFound(let path): return "Folder not found: \(path)"
        case .notADirectory(let path): return "Not a directory: \(path)"
        case .cannotEnumerate(let path): return "Cannot read directory: \(path)"
        case .permissionDenied(let path): return "Permission denied: \(path)"
        }
    }
}
