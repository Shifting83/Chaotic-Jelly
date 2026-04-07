import SwiftUI

struct QueueView: View {
    @State var viewModel: QueueViewModel

    var body: some View {
        if let job = viewModel.activeJob {
            VStack(spacing: 0) {
                // Job header
                jobHeader(job: job)

                Divider()

                // File list with progress
                List {
                    // Currently processing
                    if let currentFile = job.files.first(where: { $0.fileStatus == .processing }) {
                        Section("Processing") {
                            ActiveFileRow(file: currentFile, progress: viewModel.currentProgress)
                        }
                    }

                    // Queued
                    let queued = job.files.filter { $0.fileStatus == .queued }
                    if !queued.isEmpty {
                        Section("Queued (\(queued.count))") {
                            ForEach(queued) { file in
                                QueuedFileRow(file: file)
                            }
                        }
                    }

                    // Completed
                    if !viewModel.completedFiles.isEmpty {
                        Section("Completed (\(viewModel.completedFiles.count))") {
                            ForEach(viewModel.completedFiles) { file in
                                CompletedFileRow(file: file)
                            }
                        }
                    }

                    // Failed
                    if !viewModel.failedFiles.isEmpty {
                        Section("Failed (\(viewModel.failedFiles.count))") {
                            ForEach(viewModel.failedFiles) { file in
                                FailedFileRow(file: file)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        } else {
            ContentUnavailableView(
                "No Active Jobs",
                systemImage: "list.bullet.rectangle",
                description: Text("Start processing from the Review tab to see progress here.")
            )
        }
    }

    @ViewBuilder
    private func jobHeader(job: Job) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing: \(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)")
                        .font(.headline)

                    Text(job.sourceFolderPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(role: .destructive) {
                    Task { await viewModel.cancelJob() }
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .controlSize(.large)
            }

            // Overall progress
            ProgressView(value: job.progressFraction) {
                HStack {
                    Text("\(job.completedFileCount) of \(job.fileCount) files")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(job.progressFraction * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Stats
            HStack(spacing: 20) {
                if job.bytesSaved > 0 {
                    Label("Saved: \(job.bytesSaved.formattedFileSize)", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if job.errorCount > 0 {
                    Label("\(job.errorCount) errors", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let duration = job.duration {
                    Label("Elapsed: \(duration.formattedDuration)", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(.background.secondary)
    }
}

// MARK: - File Row Views

struct ActiveFileRow: View {
    let file: FileEntry
    let progress: FileProcessingProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressView()
                    .controlSize(.small)

                Text(file.fileName)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Text(file.originalSize.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress {
                ProgressView(value: progress.progress) {
                    Text(progress.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct QueuedFileRow: View {
    let file: FileEntry

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)

            Text(file.fileName)
                .lineLimit(1)

            Spacer()

            Text(file.originalSize.formattedFileSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CompletedFileRow: View {
    let file: FileEntry

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(file.fileName)
                .lineLimit(1)

            Spacer()

            if file.bytesSaved > 0 {
                Text("-\(file.bytesSaved.formattedFileSize)")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }

            Text(file.originalSize.formattedFileSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FailedFileRow: View {
    let file: FileEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)

                Text(file.fileName)
                    .lineLimit(1)

                Spacer()
            }

            if let error = file.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }
}
