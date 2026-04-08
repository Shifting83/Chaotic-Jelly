import SwiftUI

struct ReviewView: View {
    @State var viewModel: ReviewViewModel
    let onStartProcessing: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        if viewModel.job == nil {
            CJEmptyStateView(
                icon: "🔍",
                title: "Nothing to review",
                message: "Run a scan to analyze files before processing"
            )
        } else {
            VStack(spacing: 0) {
                // Workflow stepper
                WorkflowStepper(
                    currentStep: .review,
                    scanSummary: "\(viewModel.summary.totalFiles) files found",
                    reviewSummary: "\(viewModel.summary.filesToProcess) to process"
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Summary bar
                summaryBar

                // Filter toolbar
                filterToolbar

                // File list
                fileList
            }
            .background(Color.cjBackground)
            .confirmationDialog(
                "Start Processing",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Process \(viewModel.summary.filesToProcess) Files", role: .destructive) {
                    Task {
                        await viewModel.startProcessing()
                        onStartProcessing()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will modify \(viewModel.summary.filesToProcess) files. \(viewModel.summary.totalStreamsToRemove) streams will be removed. Estimated savings: \(viewModel.summary.estimatedSavingsBytes.formattedFileSize).")
            }
        }
    }

    // MARK: - Summary Bar

    @ViewBuilder
    private var summaryBar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 16) {
                Text("**\(viewModel.summary.totalFiles)** total")
                    .font(.cjSecondary)
                Text("**\(viewModel.summary.filesToProcess)** to process")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjPrimary)
                Text("**\(viewModel.summary.filesToSkip)** skipped")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
                if viewModel.summary.warningCount > 0 {
                    Text("**\(viewModel.summary.warningCount)** warnings")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjWarning)
                }
            }

            Spacer()

            Text("Est. savings: \(viewModel.summary.estimatedSavingsBytes.formattedFileSize)")
                .font(.cjSecondary)
                .fontWeight(.semibold)
                .foregroundStyle(Color.cjSuccess)

            if viewModel.summary.filesToProcess > 0 {
                Button("Start Processing") {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .cjCard()
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Toolbar

    @ViewBuilder
    private var filterToolbar: some View {
        HStack(spacing: 10) {
            SearchField(text: $viewModel.searchText, placeholder: "Search files...")

            HStack(spacing: 4) {
                FilterPill(label: "All", value: nil as FileStatus?, selection: $viewModel.filterStatus)
                FilterPill(label: "To Process", value: .analyzed, selection: $viewModel.filterStatus)
                FilterPill(label: "Skipped", value: .skipped, selection: $viewModel.filterStatus)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - File List

    @ViewBuilder
    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                    ExpandableRow {
                        fileRowHeader(file: file)
                    } detail: {
                        fileRowDetail(file: file)
                    }
                    .opacity(file.fileStatus == .skipped ? 0.5 : 1)

                    if index < viewModel.filteredFiles.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .cjCard()
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func fileRowHeader(file: FileEntry) -> some View {
        HStack(spacing: 10) {
            statusIcon(for: file)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text(actionSummary(for: file))
                    .font(.system(size: 11))
                    .foregroundStyle(file.warnings.isEmpty ? Color.cjTextSecondary : Color.cjWarning)
                    .lineLimit(1)
            }

            Spacer()

            if let savings = file.analysisResult?.estimatedSavingsBytes, savings > 0 {
                Text("-\(savings.formattedFileSize)")
                    .font(.cjSecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjSuccess)
            } else {
                Text("—")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Text(file.originalSize.formattedFileSize)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
                .frame(width: 70, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func fileRowDetail(file: FileEntry) -> some View {
        if let analysis = file.analysisResult {
            HStack(alignment: .top, spacing: 16) {
                // Removing column
                VStack(alignment: .leading, spacing: 8) {
                    Text("Removing")
                        .cjSectionLabel()

                    ForEach(analysis.actions.filter { if case .removeStream = $0 { return true }; return false }) { action in
                        HStack(spacing: 6) {
                            Text("✕")
                                .foregroundStyle(Color.cjError)
                            Text(action.displayDescription)
                                .font(.cjSecondary)
                                .foregroundStyle(Color.cjError)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Keeping column
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keeping")
                        .cjSectionLabel()

                    ForEach(analysis.actions.filter { if case .keepStream = $0 { return true }; return false }) { action in
                        HStack(spacing: 6) {
                            Text("✓")
                                .foregroundStyle(Color.cjSuccess)
                            Text(action.displayDescription)
                                .font(.cjSecondary)
                                .foregroundStyle(Color.cjSuccess)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusIcon(for file: FileEntry) -> some View {
        switch file.fileStatus {
        case .analyzed:
            if !file.warnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.cjWarning)
            } else {
                StatusDot(color: .cjPrimary)
            }
        case .skipped:
            StatusDot(color: .cjTextSecondary)
        case .failed:
            StatusDot(color: .cjError)
        default:
            StatusDot(color: .cjTextSecondary)
        }
    }

    private func actionSummary(for file: FileEntry) -> String {
        if !file.warnings.isEmpty {
            return file.warnings.first ?? "Warning"
        }
        guard let analysis = file.analysisResult else {
            return file.fileStatus == .skipped ? "English only — nothing to remove" : "Pending analysis"
        }
        let removeCount = analysis.removedStreamCount
        if removeCount == 0 { return "Nothing to remove" }
        return "Remove \(removeCount) track\(removeCount == 1 ? "" : "s")"
    }
}
