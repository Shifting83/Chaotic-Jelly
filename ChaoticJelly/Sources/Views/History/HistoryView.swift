import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var showDeleteConfirmation = false
    @State private var jobToDelete: Job?

    var body: some View {
        VStack(spacing: 0) {
            // Summary stats
            HStack(spacing: 12) {
                miniStat(value: "\(viewModel.jobs.count)", label: "Total Jobs")
                miniStat(value: viewModel.totalSpaceSaved.formattedFileSize, label: "Total Saved", color: .cjSuccess)
                miniStat(value: "\(viewModel.jobs.flatMap(\.files).filter { $0.fileStatus == .completed }.count)", label: "Files Processed")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Filter toolbar
            HStack(spacing: 10) {
                SearchField(text: $viewModel.searchText, placeholder: "Search jobs...")

                HStack(spacing: 4) {
                    FilterPill(label: "All", value: nil as JobStatus?, selection: $viewModel.filterStatus)
                    FilterPill(label: "Completed", value: .completed, selection: $viewModel.filterStatus)
                    FilterPill(label: "Failed", value: .failed, selection: $viewModel.filterStatus, labelColor: .cjError)
                    FilterPill(label: "Cancelled", value: .cancelled, selection: $viewModel.filterStatus)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Job list
            if viewModel.filteredJobs.isEmpty {
                CJEmptyStateView(
                    icon: "📋",
                    title: viewModel.jobs.isEmpty ? "No history yet" : "No matching jobs",
                    message: viewModel.jobs.isEmpty ? "Completed jobs will appear here" : "Try adjusting your filters"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredJobs.enumerated()), id: \.element.id) { index, job in
                            ExpandableRow {
                                historyRowHeader(job: job)
                            } detail: {
                                historyRowDetail(job: job)
                            }
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

                            if index < viewModel.filteredJobs.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .cjCard()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.cjBackground)
        .task { viewModel.refresh() }
        .confirmationDialog(
            "Delete Job",
            isPresented: $showDeleteConfirmation,
            presenting: jobToDelete
        ) { job in
            Button("Delete", role: .destructive) {
                viewModel.deleteJob(job)
            }
        } message: { _ in
            Text("Delete this job and all its history? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func miniStat(value: String, label: String, color: Color = .cjTextPrimary) -> some View {
        HStack(spacing: 12) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cjCard()
    }

    @ViewBuilder
    private func historyRowHeader(job: Job) -> some View {
        HStack(spacing: 10) {
            StatusDot.forJobStatus(job.jobStatus)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text("\(job.fileCount) files · \(job.processingMode.displayName) · \(job.duration?.formattedDuration ?? "—")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Spacer()

            if job.bytesSaved > 0 {
                Text("-\(job.bytesSaved.formattedFileSize)")
                    .font(.cjSecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cjSuccess)
            } else if job.failedFileCount > 0 {
                Text("\(job.failedFileCount) failed")
                    .font(.cjSecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjError)
            }

            Text(job.createdAt.relativeString)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
        }
    }

    @ViewBuilder
    private func historyRowDetail(job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Text("✓ \(job.files.filter { $0.fileStatus == .completed }.count) completed")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
                if job.failedFileCount > 0 {
                    Text("✕ \(job.failedFileCount) failed")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjError)
                }
            }

            ForEach(Array(job.files.prefix(5).enumerated()), id: \.element.id) { _, file in
                HStack {
                    Text(file.fileName)
                        .font(.cjSecondary)
                        .foregroundStyle(file.fileStatus == .failed ? Color.cjError : Color.cjTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    if file.fileStatus == .completed && file.bytesSaved > 0 {
                        Text("-\(file.bytesSaved.formattedFileSize)")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjSuccess)
                    } else if file.fileStatus == .failed {
                        Text(file.errorMessage ?? "Error")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cjError)
                            .lineLimit(1)
                    }
                }
            }

            if job.files.count > 5 {
                Text("Show all \(job.files.count) files →")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjPrimary)
            }
        }
    }
}
