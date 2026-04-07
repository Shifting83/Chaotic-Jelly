import SwiftUI

struct ScanView: View {
    @State var viewModel: ScanViewModel
    let onReview: (Job) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanning || viewModel.isAnalyzing || viewModel.isProcessing {
                progressView
            } else if let job = viewModel.currentJob, job.jobStatus == .reviewing {
                // Analysis complete — prompt review
                analysisCompleteView(job: job)
            } else {
                configurationView
            }
        }
        .padding()
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configurationView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Folder selection
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                if let url = viewModel.selectedFolderURL {
                    VStack(spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.title3)
                            .fontWeight(.medium)

                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Select a folder to scan")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button("Choose Folder...") {
                    viewModel.selectFolder()
                }
                .controlSize(.large)
            }

            Divider()
                .padding(.horizontal, 40)

            // Processing mode
            VStack(alignment: .leading, spacing: 12) {
                Text("Processing Mode")
                    .font(.headline)

                Picker("Mode", selection: $viewModel.processingMode) {
                    ForEach(ProcessingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .frame(maxWidth: 400)

            // Options
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Skip review (scan & process immediately)", isOn: $viewModel.skipReview)
                Toggle("Dry run (preview only, no changes)", isOn: $viewModel.isDryRun)
                    .disabled(viewModel.skipReview)
            }
            .frame(maxWidth: 400)

            // Error display
            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding()
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Start button
            Button(action: {
                Task {
                    await viewModel.startScanAndAnalysis()
                }
            }) {
                Label(viewModel.skipReview ? "Scan & Process" : "Start Scan", systemImage: "play.fill")
                    .frame(minWidth: 120)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedFolderURL == nil)

            Spacer()
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressView: some View {
        VStack(spacing: 20) {
            Spacer()

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.large)

                Text("Scanning for video files...")
                    .font(.title3)

                if let progress = viewModel.scanProgress {
                    VStack(spacing: 4) {
                        Text("\(progress.videoFilesFound) video files found")
                            .fontWeight(.medium)

                        Text("\(progress.filesExamined) files examined in \(progress.directoriesScanned) directories")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(progress.currentPath)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            } else if viewModel.isAnalyzing || viewModel.isProcessing {
                if let progress = viewModel.analysisProgress {
                    VStack(spacing: 8) {
                        ProgressView(
                            value: Double(progress.current),
                            total: Double(progress.total)
                        )
                        .frame(maxWidth: 300)

                        Text(viewModel.isProcessing ? "Scanning & processing..." : "Analyzing media files...")
                            .font(.title3)

                        Text("\(progress.current) of \(progress.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let fileName = viewModel.processingFileName {
                            Text(fileName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                    Text(viewModel.isProcessing ? "Starting..." : "Analyzing...")
                        .font(.title3)
                }
            }

            Spacer()
        }
    }

    // MARK: - Analysis Complete

    @ViewBuilder
    private func analysisCompleteView(job: Job) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Analysis Complete")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 4) {
                Text("\(job.files.count) files scanned")
                let toProcess = job.files.filter { $0.fileStatus == .analyzed }.count
                let skipped = job.files.filter { $0.fileStatus == .skipped }.count
                Text("\(toProcess) files need processing, \(skipped) already optimized")
                    .foregroundStyle(.secondary)

                if job.errorCount > 0 {
                    Text("\(job.errorCount) files had errors")
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 12) {
                Button("Review Results") {
                    onReview(job)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("New Scan") {
                    viewModel.reset()
                }
                .controlSize(.large)
            }

            Spacer()
        }
    }
}
