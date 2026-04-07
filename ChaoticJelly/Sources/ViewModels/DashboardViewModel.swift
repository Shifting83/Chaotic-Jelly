import Foundation
import SwiftUI

@Observable
final class DashboardViewModel {
    private let container: ServiceContainer

    var recentJobs: [Job] = []
    var totalSpaceSaved: Int64 = 0
    var totalFilesProcessed: Int = 0
    var toolStatuses: [ToolStatus] = []
    var cacheUsage: Int64 = 0
    var isLoadingTools = false

    init(container: ServiceContainer) {
        self.container = container
    }

    @MainActor
    func refresh() async {
        let jobs = container.jobManager.fetchJobs()
        recentJobs = Array(jobs.prefix(5))
        totalSpaceSaved = container.jobManager.totalSpaceSaved()
        totalFilesProcessed = jobs
            .flatMap(\.files)
            .filter { $0.fileStatus == .completed }
            .count

        cacheUsage = await container.cacheManager.currentCacheUsage()
        await refreshToolStatuses()
    }

    private func refreshToolStatuses() async {
        isLoadingTools = true
        var statuses: [ToolStatus] = []

        for tool in ToolType.allCases {
            let available = await container.toolLocator.isAvailable(tool)
            let path = try? await container.toolLocator.path(for: tool)
            statuses.append(ToolStatus(
                tool: tool,
                isAvailable: available,
                resolvedPath: path,
                version: nil
            ))
        }

        toolStatuses = statuses
        isLoadingTools = false
    }
}
