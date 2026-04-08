import Foundation
import SwiftData

// MARK: - FileEntry

@Model
final class FileEntry {
    @Attribute(.unique) var id: UUID
    var job: Job?
    var relativePath: String
    var fileName: String
    var fileExtension: String
    var status: String              // FileStatus raw value
    var originalSize: Int64
    var processedSize: Int64?
    var mediaInfoData: Data?        // JSON-encoded MediaInfo
    var analysisResultData: Data?   // JSON-encoded FileAnalysisResult
    var errorMessage: String?
    var warningMessages: Data?      // JSON-encoded [String]
    var startedAt: Date?
    var completedAt: Date?
    var commandLog: String?         // ffmpeg/ffprobe commands executed

    // MARK: Computed Properties

    var fileStatus: FileStatus {
        get { FileStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var fullPath: String {
        guard let job else { return relativePath }
        let base = job.sourceFolderPath
        // Use URL-based path joining to handle edge cases correctly
        let baseURL = URL(fileURLWithPath: base, isDirectory: true)
        let fullURL = baseURL.appendingPathComponent(relativePath)
        return fullURL.path
    }

    var mediaInfo: MediaInfo? {
        get {
            guard let data = mediaInfoData else { return nil }
            return try? JSONDecoder().decode(MediaInfo.self, from: data)
        }
        set {
            mediaInfoData = try? JSONEncoder().encode(newValue)
        }
    }

    var analysisResult: FileAnalysisResult? {
        get {
            guard let data = analysisResultData else { return nil }
            return try? JSONDecoder().decode(FileAnalysisResult.self, from: data)
        }
        set {
            analysisResultData = try? JSONEncoder().encode(newValue)
        }
    }

    var warnings: [String] {
        get {
            guard let data = warningMessages else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            warningMessages = try? JSONEncoder().encode(newValue)
        }
    }

    var bytesSaved: Int64 {
        guard let processed = processedSize, processed > 0 else { return 0 }
        return originalSize - processed
    }

    var savingsPercent: Double {
        guard originalSize > 0, let processed = processedSize else { return 0 }
        return Double(originalSize - processed) / Double(originalSize) * 100
    }

    // MARK: Init

    init(
        relativePath: String,
        fileName: String,
        fileExtension: String,
        originalSize: Int64
    ) {
        self.id = UUID()
        self.status = FileStatus.pending.rawValue
        self.relativePath = relativePath
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.originalSize = originalSize
    }

    // MARK: State Transitions

    func canTransition(to newStatus: FileStatus) -> Bool {
        switch (fileStatus, newStatus) {
        case (.pending, .analyzing),
             (.analyzing, .analyzed),
             (.analyzed, .queued),
             (.analyzed, .processing),
             (.queued, .processing),
             (.processing, .validating),
             (.processing, .completed),
             (.validating, .completed),
             (_, .failed),
             (_, .skipped):
            return true
        default:
            return false
        }
    }

    @discardableResult
    func transition(to newStatus: FileStatus) -> Bool {
        guard canTransition(to: newStatus) else { return false }
        fileStatus = newStatus
        if newStatus == .processing && startedAt == nil {
            startedAt = Date()
        }
        if newStatus.isTerminal {
            completedAt = Date()
        }
        return true
    }
}
