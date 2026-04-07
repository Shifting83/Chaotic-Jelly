import SwiftUI

struct ReviewView: View {
    @State var viewModel: ReviewViewModel
    let onStartProcessing: () -> Void
    @State private var showConfirmation = false
    @State private var selectedFile: FileEntry?

    var body: some View {
        if viewModel.job == nil {
            ContentUnavailableView(
                "No Scan Results",
                systemImage: "checklist",
                description: Text("Run a scan first to review results here.")
            )
        } else {
            VStack(spacing: 0) {
                // Summary bar
                summaryBar

                Divider()

                // Toolbar
                toolbar

                // File list
                fileList
            }
            .sheet(item: $selectedFile) { file in
                FileDetailSheet(file: file)
            }
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
            SummaryPill(label: "Total", value: "\(viewModel.summary.totalFiles)", color: .primary)
            SummaryPill(label: "To Process", value: "\(viewModel.summary.filesToProcess)", color: .blue)
            SummaryPill(label: "Skipped", value: "\(viewModel.summary.filesToSkip)", color: .secondary)
            SummaryPill(label: "Failed", value: "\(viewModel.summary.filesFailed)", color: .red)
            SummaryPill(label: "Streams to Remove", value: "\(viewModel.summary.totalStreamsToRemove)", color: .orange)
            SummaryPill(label: "Est. Savings", value: viewModel.summary.estimatedSavingsBytes.formattedFileSize, color: .green)

            Spacer()

            if viewModel.summary.filesToProcess > 0 {
                Button(action: { showConfirmation = true }) {
                    Label("Start Processing", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(.background.secondary)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 250)

            // Filter
            Picker("Status", selection: Binding(
                get: { viewModel.filterStatus },
                set: { viewModel.filterStatus = $0 }
            )) {
                Text("All").tag(nil as FileStatus?)
                ForEach(FileStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status as FileStatus?)
                }
            }
            .frame(width: 120)

            // Sort
            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(ReviewViewModel.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .frame(width: 120)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - File List

    @ViewBuilder
    private var fileList: some View {
        List(viewModel.filteredFiles) { file in
            FileReviewRow(file: file)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFile = file
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Summary Pill

struct SummaryPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - File Review Row

struct FileReviewRow: View {
    let file: FileEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.fileStatus.systemImage)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(file.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Stream summary
            if let analysis = file.analysisResult {
                HStack(spacing: 8) {
                    if analysis.removedStreamCount > 0 {
                        Label("\(analysis.removedStreamCount) remove", systemImage: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let savings = analysis.estimatedSavingsBytes, savings > 0 {
                        Text("-\(savings.formattedFileSize)")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    }
                }
            }

            // Size
            Text(file.originalSize.formattedFileSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch file.fileStatus {
        case .analyzed: return .blue
        case .skipped: return .secondary
        case .failed: return .red
        case .completed: return .green
        default: return .secondary
        }
    }
}

// MARK: - File Detail Sheet

struct FileDetailSheet: View {
    let file: FileEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (pinned, not scrollable)
            HStack {
                Text(file.fileName)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // File info
                    GroupBox("File Info") {
                        VStack(alignment: .leading, spacing: 6) {
                            InfoRow(label: "Path", value: file.fullPath)
                            InfoRow(label: "Size", value: file.originalSize.formattedFileSize)
                            InfoRow(label: "Container", value: file.fileExtension.uppercased())
                            InfoRow(label: "Status", value: file.fileStatus.displayName)
                        }
                        .padding(4)
                    }

            // Streams
            if let info = file.mediaInfo {
                GroupBox("Streams") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(info.videoStreams) { stream in
                            StreamRow(
                                icon: "video",
                                label: "Video",
                                detail: "\(stream.codecDisplay) \(stream.resolution)"
                            )
                        }
                        ForEach(info.audioStreams) { stream in
                            StreamRow(
                                icon: "speaker.wave.2",
                                label: "Audio",
                                detail: "\(stream.codec.uppercased()) \(stream.channelDescription) [\(stream.language ?? "?")]"
                            )
                        }
                        ForEach(info.subtitleStreams) { stream in
                            StreamRow(
                                icon: "captions.bubble",
                                label: "Subtitle",
                                detail: "\(stream.codec) [\(stream.language ?? "?")]\(stream.isForced ? " FORCED" : "")"
                            )
                        }
                    }
                    .padding(4)
                }
            }

            // Planned actions
            if let analysis = file.analysisResult {
                GroupBox("Planned Actions") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(analysis.actions) { action in
                            HStack(spacing: 6) {
                                Image(systemName: action.isDestructive ? "minus.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(action.isDestructive ? .red : .green)
                                    .font(.caption)
                                Text(action.displayDescription)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(4)
                }

                // Warnings
                if !analysis.warnings.isEmpty {
                    GroupBox("Warnings") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(analysis.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(4)
                    }
                }
            }

                    // Error
                    if let error = file.errorMessage {
                        GroupBox("Error") {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(4)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

struct StreamRow: View {
    let icon: String
    let label: String
    let detail: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(label)
                .fontWeight(.medium)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
