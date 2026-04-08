import Foundation
import SwiftUI

@MainActor @Observable
final class QueueViewModel {
    private let container: ServiceContainer
    var elapsedSeconds: Int = 0
    private var timer: Timer?

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

    var completedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .completed }.reversed()
    }

    var failedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .failed }
    }

    var queuedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .queued || $0.fileStatus == .analyzed }
    }

    var currentFile: FileEntry? {
        activeJob?.files.first(where: { $0.fileStatus == .processing || $0.fileStatus == .validating })
    }

    var runningSavings: Int64 {
        completedFiles.reduce(0) { $0 + $1.bytesSaved }
    }

    var estimatedRemainingSeconds: Int? {
        guard let job = activeJob, job.completedFileCount > 0 else { return nil }
        let avgPerFile = elapsedSeconds / job.completedFileCount
        let remaining = job.fileCount - job.completedFileCount
        return avgPerFile * remaining
    }

    func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func cancelJob() async {
        await container.jobManager.cancelActiveJob()
        stopTimer()
    }

    var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingFormatted: String? {
        guard let remaining = estimatedRemainingSeconds else { return nil }
        let minutes = remaining / 60
        return "~\(minutes) min"
    }
}
