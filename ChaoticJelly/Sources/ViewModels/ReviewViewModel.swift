import Foundation
import SwiftUI

@MainActor @Observable
final class ReviewViewModel {
    private let container: ServiceContainer

    var job: Job?
    var searchText = ""
    var filterStatus: FileStatus?
    var sortOrder: SortOrder = .path

    enum SortOrder: String, CaseIterable {
        case path = "Path"
        case size = "Size"
        case savings = "Est. Savings"
        case status = "Status"
    }

    init(container: ServiceContainer) {
        self.container = container
    }

    var filteredFiles: [FileEntry] {
        guard let job else { return [] }
        var files = job.files

        // Filter by status
        if let filterStatus {
            files = files.filter { $0.fileStatus == filterStatus }
        }

        // Filter by search
        if !searchText.isEmpty {
            files = files.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.relativePath.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .path:
            files.sort { $0.relativePath < $1.relativePath }
        case .size:
            files.sort { $0.originalSize > $1.originalSize }
        case .savings:
            files.sort {
                ($0.analysisResult?.estimatedSavingsBytes ?? 0) > ($1.analysisResult?.estimatedSavingsBytes ?? 0)
            }
        case .status:
            files.sort { $0.status < $1.status }
        }

        return files
    }

    var summary: ReviewSummary {
        guard let job else { return .empty }
        let files = job.files

        let toProcess = files.filter { $0.fileStatus == .analyzed }
        let skipped = files.filter { $0.fileStatus == .skipped }
        let failed = files.filter { $0.fileStatus == .failed }

        let totalRemoveStreams = toProcess.compactMap { $0.analysisResult?.removedStreamCount }.reduce(0, +)
        let estimatedSavings = toProcess.compactMap { $0.analysisResult?.estimatedSavingsBytes }.reduce(0, +)
        let warnings = toProcess.flatMap { $0.warnings }

        let isDryRun = job.settingsSnapshot
            .flatMap { try? JSONDecoder().decode(JobSettings.self, from: $0) }?.dryRun ?? false

        return ReviewSummary(
            totalFiles: files.count,
            filesToProcess: toProcess.count,
            filesToSkip: skipped.count,
            filesFailed: failed.count,
            totalStreamsToRemove: totalRemoveStreams,
            estimatedSavingsBytes: estimatedSavings,
            warningCount: warnings.count,
            isDryRun: isDryRun
        )
    }

    func startProcessing() async {
        guard let job else { return }
        await container.jobManager.processJob(job: job)
    }
}

struct ReviewSummary {
    let totalFiles: Int
    let filesToProcess: Int
    let filesToSkip: Int
    let filesFailed: Int
    let totalStreamsToRemove: Int
    let estimatedSavingsBytes: Int64
    let warningCount: Int
    let isDryRun: Bool

    static let empty = ReviewSummary(
        totalFiles: 0, filesToProcess: 0, filesToSkip: 0, filesFailed: 0,
        totalStreamsToRemove: 0, estimatedSavingsBytes: 0, warningCount: 0, isDryRun: false
    )
}
