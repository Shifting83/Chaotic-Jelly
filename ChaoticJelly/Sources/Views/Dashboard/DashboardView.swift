import SwiftUI

struct DashboardView: View {
    @State var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Cards
                HStack(spacing: 16) {
                    StatCard(
                        title: "Space Saved",
                        value: viewModel.totalSpaceSaved.formattedFileSize,
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )

                    StatCard(
                        title: "Files Processed",
                        value: "\(viewModel.totalFilesProcessed)",
                        icon: "doc.circle.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Cache Usage",
                        value: viewModel.cacheUsage.formattedFileSize,
                        icon: "externaldrive.fill",
                        color: .orange
                    )
                }

                // Tool Status
                GroupBox("Tool Status") {
                    if viewModel.isLoadingTools {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.toolStatuses) { status in
                                HStack {
                                    Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(status.isAvailable ? .green : .red)

                                    Text(status.tool.displayName)
                                        .fontWeight(.medium)

                                    Spacer()

                                    if let path = status.resolvedPath {
                                        Text(path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    } else {
                                        Text("Not found")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(8)
                    }
                }

                // Recent Jobs
                GroupBox("Recent Jobs") {
                    if viewModel.recentJobs.isEmpty {
                        Text("No jobs yet. Start a scan to begin.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        VStack(spacing: 4) {
                            ForEach(viewModel.recentJobs) { job in
                                JobRowView(job: job)
                                if job.id != viewModel.recentJobs.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.refresh()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Job Row

struct JobRowView: View {
    let job: Job

    var body: some View {
        HStack {
            Image(systemName: job.jobStatus.systemImage)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(job.fileCount) files \(job.createdAt.relativeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if job.bytesSaved > 0 {
                Text("-\(job.bytesSaved.formattedFileSize)")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }

            Text(job.jobStatus.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch job.jobStatus {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .processing, .scanning, .analyzing: return .blue
        default: return .secondary
        }
    }
}
