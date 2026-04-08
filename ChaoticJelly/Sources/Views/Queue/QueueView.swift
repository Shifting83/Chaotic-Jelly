import SwiftUI

struct QueueView: View {
    @State var viewModel: QueueViewModel

    var body: some View {
        if let job = viewModel.activeJob, viewModel.isProcessing {
            ScrollView {
                VStack(spacing: 16) {
                    // Workflow stepper
                    WorkflowStepper(
                        currentStep: .processing,
                        scanSummary: "\(job.fileCount) files",
                        reviewSummary: "\(job.fileCount) files",
                        processingSummary: "\(job.completedFileCount) / \(job.fileCount)"
                    )

                    // Hero stats panel
                    heroPanel(job: job)

                    // Current file
                    if let file = viewModel.currentFile {
                        currentFileCard(file: file)
                    }

                    // File feed
                    fileFeed(job: job)
                }
                .padding(24)
            }
            .background(Color.cjBackground)
            .onAppear { viewModel.startTimer() }
            .onDisappear { viewModel.stopTimer() }
        } else {
            CJEmptyStateView(
                icon: "⚡",
                title: "No active jobs",
                message: "Start processing from the Review screen"
            )
        }
    }

    // MARK: - Hero Stats Panel

    @ViewBuilder
    private func heroPanel(job: Job) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    StatusDot(color: .cjPrimary, pulsing: true)
                    Text("Processing \(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)")
                        .font(.cjPageTitle)
                        .foregroundStyle(Color.cjTextPrimary)
                }
                Spacer()
                Button(role: .destructive) {
                    Task { await viewModel.cancelJob() }
                } label: {
                    Text("Cancel")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .tint(Color.cjError)
                .controlSize(.small)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cjBorder)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cjPrimary, Color(red: 90/255, green: 200/255, blue: 250/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * job.progressFraction)
                        .animation(.easeInOut(duration: 0.3), value: job.progressFraction)
                }
            }
            .frame(height: 12)

            // Counter grid
            HStack(spacing: 0) {
                counterCell(label: "Progress", value: "\(job.completedFileCount) / \(job.fileCount)")
                counterCell(label: "Space Saved", value: viewModel.runningSavings.formattedFileSize, color: .cjSuccess)
                counterCell(label: "Elapsed", value: viewModel.elapsedFormatted)
                counterCell(label: "Remaining", value: viewModel.remainingFormatted ?? "—")
            }
        }
        .padding(24)
        .cjCard()
    }

    @ViewBuilder
    private func counterCell(label: String, value: String, color: Color = .cjTextPrimary) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .cjSectionLabel()
            Text(value)
                .font(.cjHeroCounter)
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Current File Card

    @ViewBuilder
    private func currentFileCard(file: FileEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(file.fileName)
                        .font(.cjBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cjTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Text(file.originalSize.formattedFileSize)
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            if let progress = viewModel.currentProgress {
                ProgressView(value: progress.progress)
                    .tint(Color.cjPrimary)

                Text(progress.message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }
        }
        .padding(16)
        .cjCard()
    }

    // MARK: - File Feed

    @ViewBuilder
    private func fileFeed(job: Job) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("File Feed")
                    .font(.cjSectionHeader)
                    .foregroundStyle(Color.cjTextPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Text("✓ \(viewModel.completedFiles.count) done")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjSuccess)
                    Text("○ \(viewModel.queuedFiles.count) queued")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                    if !viewModel.failedFiles.isEmpty {
                        Text("✕ \(viewModel.failedFiles.count) error")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjError)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            // Completed files (most recent first)
            ForEach(viewModel.completedFiles) { file in
                completedFeedRow(file: file)
                Divider().padding(.horizontal, 16)
            }

            // Failed files
            ForEach(viewModel.failedFiles) { file in
                failedFeedRow(file: file)
                Divider().padding(.horizontal, 16)
            }

            // Queued files
            ForEach(viewModel.queuedFiles) { file in
                queuedFeedRow(file: file)
                if file.id != viewModel.queuedFiles.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .cjCard()
    }

    @ViewBuilder
    private func completedFeedRow(file: FileEntry) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text("✓").foregroundStyle(Color.cjSuccess)
                Text(file.fileName)
                    .font(.cjBody)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)
            }
            Spacer()
            if file.bytesSaved > 0 {
                Text("-\(file.bytesSaved.formattedFileSize)")
                    .font(.cjSecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjSuccess)
            }
            if let start = file.startedAt, let end = file.completedAt {
                let seconds = Int(end.timeIntervalSince(start))
                Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func failedFeedRow(file: FileEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("✕").foregroundStyle(Color.cjError)
                Text(file.fileName)
                    .font(.cjBody)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text("Error")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjError)
            }
            if let error = file.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjError)
                    .padding(.leading, 22)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cjErrorBackground)
    }

    @ViewBuilder
    private func queuedFeedRow(file: FileEntry) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text("○").foregroundStyle(Color.cjTextSecondary)
                Text(file.fileName)
                    .font(.cjBody)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Text(file.originalSize.formattedFileSize)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(0.4)
    }
}
