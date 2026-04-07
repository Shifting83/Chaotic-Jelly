import Foundation
import SwiftUI
import AppKit

@Observable
final class ScanViewModel {
    private let container: ServiceContainer

    // State
    var selectedFolderURL: URL?
    var processingMode: ProcessingMode = .removeBoth
    var isDryRun = false
    var skipReview = false
    var selectedArrInstanceIds: Set<UUID> = []
    var isScanning = false
    var isAnalyzing = false
    var isProcessing = false
    var scanProgress: ScanProgress?
    var analysisProgress: (current: Int, total: Int)?
    var processingFileName: String?
    var currentJob: Job?
    var error: String?

    init(container: ServiceContainer) {
        self.container = container
    }

    // MARK: - Folder Selection

    @MainActor
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan for video files"
        panel.prompt = "Scan"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolderURL = url
            BookmarkStore.shared.saveBookmark(for: url)
        }
    }

    // MARK: - Scan + Analyze

    @MainActor
    func startScanAndAnalysis() async {
        guard let folderURL = selectedFolderURL else { return }

        error = nil
        isScanning = true

        // Create job
        let job = container.jobManager.createJob(
            folderURL: folderURL,
            processingMode: processingMode,
            dryRun: isDryRun
        )
        currentJob = job

        // Scan
        do {
            try await container.jobManager.startScan(
                job: job,
                folderURL: folderURL,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.scanProgress = progress
                    }
                }
            )
        } catch {
            self.error = error.localizedDescription
            isScanning = false
            return
        }

        isScanning = false

        if skipReview {
            // Pipeline mode: analyze and process simultaneously
            isProcessing = true
            await container.jobManager.analyzeAndProcess(
                job: job,
                selectedArrInstanceIds: selectedArrInstanceIds,
                onProgress: { [weak self] current, total, fileName in
                    Task { @MainActor in
                        self?.analysisProgress = (current, total)
                        self?.processingFileName = fileName
                    }
                }
            )
            isProcessing = false
        } else {
            // Review mode: analyze all first, then let user review
            isAnalyzing = true
            do {
                try await container.jobManager.analyzeJob(
                    job: job,
                    selectedArrInstanceIds: selectedArrInstanceIds,
                    onProgress: { [weak self] current, total in
                        Task { @MainActor in
                            self?.analysisProgress = (current, total)
                        }
                    }
                )
            } catch {
                self.error = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    func reset() {
        selectedFolderURL = nil
        currentJob = nil
        scanProgress = nil
        analysisProgress = nil
        processingFileName = nil
        error = nil
        isScanning = false
        isAnalyzing = false
        isProcessing = false
    }
}
