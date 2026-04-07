import Foundation
import SwiftUI

@Observable
final class QueueViewModel {
    private let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
    }

    var activeJob: Job? {
        container.jobManager.activeJob
    }

    var isProcessing: Bool {
        container.jobManager.isProcessing
    }

    var currentProgress: FileProcessingProgress? {
        container.jobManager.currentFileProgress
    }

    var activeFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { !$0.fileStatus.isTerminal }
    }

    var completedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .completed }
    }

    var failedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .failed }
    }

    @MainActor
    func cancelJob() async {
        await container.jobManager.cancelActiveJob()
    }
}
