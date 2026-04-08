import Foundation
import SwiftUI

@MainActor @Observable
final class DashboardViewModel {
    private let container: ServiceContainer

    var recentJobs: [Job] = []
    var totalSpaceSaved: Int64 = 0
    var totalFilesProcessed: Int = 0
    var totalJobCount: Int = 0
    var weeklySpaceSaved: Int64 = 0
    var cacheUsage: Int64 = 0

    init(container: ServiceContainer) {
        self.container = container
    }

    var activeJob: Job? {
        container.jobManager.activeJob
    }

    var isProcessing: Bool {
        container.jobManager.isProcessing
    }

    var currentFileProgress: FileProcessingProgress? {
        container.jobManager.currentFileProgress
    }

    func refresh() async {
        let jobs = container.jobManager.fetchJobs()
        recentJobs = Array(jobs.prefix(5))
        totalSpaceSaved = container.jobManager.totalSpaceSaved()
        totalJobCount = jobs.count
        totalFilesProcessed = jobs
            .flatMap(\.files)
            .filter { $0.fileStatus == .completed }
            .count

        // Weekly savings
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklySpaceSaved = jobs
            .filter { ($0.completedAt ?? $0.createdAt) >= oneWeekAgo }
            .reduce(0) { $0 + $1.bytesSaved }

        cacheUsage = await container.cacheManager.currentCacheUsage()
    }
}
