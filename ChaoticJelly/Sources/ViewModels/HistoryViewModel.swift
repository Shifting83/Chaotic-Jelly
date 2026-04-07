import Foundation
import SwiftUI

@Observable
final class HistoryViewModel {
    private let container: ServiceContainer

    var jobs: [Job] = []
    var searchText = ""
    var filterStatus: JobStatus?

    init(container: ServiceContainer) {
        self.container = container
    }

    var filteredJobs: [Job] {
        var result = jobs

        if let filterStatus {
            result = result.filter { $0.jobStatus == filterStatus }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.sourceFolderPath.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var totalSpaceSaved: Int64 {
        jobs.filter { $0.jobStatus == .completed }.reduce(0) { $0 + $1.bytesSaved }
    }

    @MainActor
    func refresh() {
        jobs = container.jobManager.fetchJobs()
    }

    @MainActor
    func deleteJob(_ job: Job) {
        container.jobManager.deleteJob(job)
        refresh()
    }

    @MainActor
    func retryJob(_ job: Job) async {
        await container.jobManager.retryFailedFiles(job: job)
        refresh()
    }
}
