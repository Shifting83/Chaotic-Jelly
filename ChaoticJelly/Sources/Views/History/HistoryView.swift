import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var selectedJob: Job?
    @State private var showDeleteConfirmation = false
    @State private var jobToDelete: Job?

    var body: some View {
        VStack(spacing: 0) {
            // Header stats
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Jobs",
                    value: "\(viewModel.jobs.count)",
                    icon: "number",
                    color: .blue
                )
                StatCard(
                    title: "Total Space Saved",
                    value: viewModel.totalSpaceSaved.formattedFileSize,
                    icon: "arrow.down.circle.fill",
                    color: .green
                )

                Spacer()

                // Search and filter
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 200)

                    Picker("Status", selection: Binding(
                        get: { viewModel.filterStatus },
                        set: { viewModel.filterStatus = $0 }
                    )) {
                        Text("All").tag(nil as JobStatus?)
                        ForEach(JobStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status as JobStatus?)
                        }
                    }
                    .frame(width: 130)
                }
            }
            .padding()

            Divider()

            // Job list
            if viewModel.filteredJobs.isEmpty {
                ContentUnavailableView(
                    "No Jobs",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(viewModel.jobs.isEmpty ? "Run your first scan to start building history." : "No jobs match your filters.")
                )
            } else {
                List(viewModel.filteredJobs, selection: $selectedJob) { job in
                    HistoryJobRow(job: job)
                        .contextMenu {
                            if job.failedFileCount > 0 {
                                Button("Retry Failed Files") {
                                    Task { await viewModel.retryJob(job) }
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                jobToDelete = job
                                showDeleteConfirmation = true
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .task { viewModel.refresh() }
        .confirmationDialog(
            "Delete Job",
            isPresented: $showDeleteConfirmation,
            presenting: jobToDelete
        ) { job in
            Button("Delete", role: .destructive) {
                viewModel.deleteJob(job)
            }
        } message: { job in
            Text("Delete this job and all its history? This cannot be undone.")
        }
    }
}

struct HistoryJobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: job.jobStatus.systemImage)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label("\(job.fileCount) files", systemImage: "doc")
                    Label(job.processingMode.displayName, systemImage: "gearshape")

                    if let duration = job.duration {
                        Label(duration.formattedDuration, systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if job.bytesSaved > 0 {
                    Text("-\(job.bytesSaved.formattedFileSize)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }

                Text(job.createdAt.shortString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(job.jobStatus.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
                .frame(width: 80)
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
