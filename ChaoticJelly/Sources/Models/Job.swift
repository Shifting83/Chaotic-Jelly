import Foundation
import SwiftData

// MARK: - Job

@Model
final class Job {
    @Attribute(.unique) var id: UUID
    var status: String  // JobStatus raw value (SwiftData limitation)
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var sourceFolderPath: String
    var sourceFolderBookmark: Data?
    var processingModeRaw: String  // ProcessingMode raw value
    var settingsSnapshot: Data?    // JSON-encoded JobSettings
    @Relationship(deleteRule: .cascade, inverse: \FileEntry.job)
    var files: [FileEntry]
    var totalBytesBefore: Int64
    var totalBytesAfter: Int64
    var errorCount: Int
    var warningCount: Int
    var progressFraction: Double
    var statusMessage: String?

    // MARK: Computed Properties

    var jobStatus: JobStatus {
        get { JobStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var processingMode: ProcessingMode {
        get { ProcessingMode(rawValue: processingModeRaw) ?? .removeBoth }
        set { processingModeRaw = newValue.rawValue }
    }

    var bytesSaved: Int64 {
        guard totalBytesAfter > 0 else { return 0 }
        return totalBytesBefore - totalBytesAfter
    }

    var fileCount: Int {
        files.count
    }

    var completedFileCount: Int {
        files.filter { $0.fileStatus.isTerminal }.count
    }

    var failedFileCount: Int {
        files.filter { $0.fileStatus == .failed }.count
    }

    var pendingFiles: [FileEntry] {
        files.filter { !$0.fileStatus.isTerminal }
    }

    var failedFiles: [FileEntry] {
        files.filter { $0.fileStatus == .failed }
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    // MARK: Init

    init(
        sourceFolderPath: String,
        processingMode: ProcessingMode,
        sourceFolderBookmark: Data? = nil
    ) {
        self.id = UUID()
        self.status = JobStatus.pending.rawValue
        self.createdAt = Date()
        self.sourceFolderPath = sourceFolderPath
        self.sourceFolderBookmark = sourceFolderBookmark
        self.processingModeRaw = processingMode.rawValue
        self.files = []
        self.totalBytesBefore = 0
        self.totalBytesAfter = 0
        self.errorCount = 0
        self.warningCount = 0
        self.progressFraction = 0
    }

    // MARK: State Transitions

    func canTransition(to newStatus: JobStatus) -> Bool {
        switch (jobStatus, newStatus) {
        case (.pending, .scanning),
             (.scanning, .analyzing),
             (.analyzing, .reviewing),
             (.reviewing, .processing),
             (.processing, .completed),
             (.processing, .paused),
             (.paused, .processing),
             (_, .failed),
             (_, .cancelled):
            return true
        default:
            return false
        }
    }

    @discardableResult
    func transition(to newStatus: JobStatus) -> Bool {
        guard canTransition(to: newStatus) else { return false }
        jobStatus = newStatus
        if newStatus == .scanning && startedAt == nil {
            startedAt = Date()
        }
        if newStatus.isTerminal {
            completedAt = Date()
        }
        return true
    }
}

// MARK: - Job Settings (snapshot at creation time)

struct JobSettings: Codable, Sendable {
    let keepLanguages: [String]
    let removeSubtitles: Bool
    let removeAudio: Bool
    let conservativeMode: Bool
    let preserveForced: Bool
    let preserveSDH: Bool
    let preserveCommentary: Bool
    let optimizeForJellyfin: Bool
    let jellyfinProfile: JellyfinProfile
    let createBackup: Bool
    let dryRun: Bool
}
