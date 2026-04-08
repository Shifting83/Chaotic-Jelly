import SwiftUI

struct DashboardView: View {
    @State var viewModel: DashboardViewModel
    var onNewScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top row: New Scan CTA + Stat cards
                topRow

                // Active job panel (only when processing)
                if let job = viewModel.activeJob, viewModel.isProcessing {
                    activeJobPanel(job: job)
                }

                // Recent jobs
                recentJobsPanel
            }
            .padding(24)
        }
        .background(Color.cjBackground)
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Top Row

    @ViewBuilder
    private var topRow: some View {
        HStack(spacing: 16) {
            // New Scan CTA
            Button(action: onNewScan) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cjPrimary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Scan")
                            .font(.cjPageTitle)
                            .foregroundStyle(Color.cjTextPrimary)
                        Text("Scan a folder for video files")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjTextSecondary)
                    }

                    Spacer()
                }
                .padding(20)
                .cjCard()
            }
            .buttonStyle(.plain)

            // Space Saved
            VStack(spacing: 4) {
                Text("Space Saved")
                    .cjSectionLabel()
                Text(viewModel.totalSpaceSaved.formattedFileSize)
                    .font(.cjHeroCounter)
                    .foregroundStyle(Color.cjTextPrimary)
                    .monospacedDigit()
                if viewModel.weeklySpaceSaved > 0 {
                    Text("↑ \(viewModel.weeklySpaceSaved.formattedFileSize) this week")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cjSuccess)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .cjCard()

            // Files Processed
            VStack(spacing: 4) {
                Text("Files Processed")
                    .cjSectionLabel()
                Text("\(viewModel.totalFilesProcessed)")
                    .font(.cjHeroCounter)
                    .foregroundStyle(Color.cjTextPrimary)
                    .monospacedDigit()
                Text("across \(viewModel.totalJobCount) jobs")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .cjCard()
        }
    }

    // MARK: - Active Job Panel

    @ViewBuilder
    private func activeJobPanel(job: Job) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    StatusDot(color: .cjPrimary, pulsing: true)
                    Text("Processing — \(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)")
                        .font(.cjPageTitle)
                        .foregroundStyle(Color.cjTextPrimary)
                }
                Spacer()
                if let duration = job.duration {
                    Text(duration.formattedDuration)
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                }
            }

            // Progress bar
            ProgressView(value: job.progressFraction)
                .tint(Color.cjPrimary)

            // Stats row
            HStack {
                HStack(spacing: 20) {
                    Text("Progress: **\(job.completedFileCount) / \(job.fileCount) files**")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)

                    if let currentFile = job.files.first(where: { $0.fileStatus == .processing }) {
                        Text("Current: **\(currentFile.fileName)**")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if job.bytesSaved > 0 {
                    Text("↓ \(job.bytesSaved.formattedFileSize) saved")
                        .font(.cjSecondary)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.cjSuccess)
                }
            }
        }
        .padding(20)
        .cjCard()
    }

    // MARK: - Recent Jobs

    @ViewBuilder
    private var recentJobsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Jobs")
                .font(.cjSectionHeader)
                .foregroundStyle(Color.cjTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if viewModel.recentJobs.isEmpty {
                CJEmptyStateView(
                    icon: "📁",
                    title: "No scans yet",
                    message: "Scan a folder to find video files to clean up",
                    actionTitle: "New Scan",
                    action: onNewScan
                )
                .frame(height: 200)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentJobs.enumerated()), id: \.element.id) { index, job in
                        DashboardJobRow(job: job)
                        if index < viewModel.recentJobs.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .cjCard()
    }
}

// MARK: - Dashboard Job Row

struct DashboardJobRow: View {
    let job: Job

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text("\(job.fileCount) files · \(job.bytesSaved.formattedFileSize) saved · \(job.duration?.formattedDuration ?? "—")")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Spacer()

            Text(job.createdAt.relativeString)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)

            JobStatusBadge(status: job.jobStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct JobStatusBadge: View {
    let status: JobStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .foregroundStyle(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var badgeColor: Color {
        switch status {
        case .completed: return .cjSuccess
        case .failed: return .cjError
        case .cancelled: return .cjWarning
        default: return .cjTextSecondary
        }
    }

    private var badgeBackground: Color {
        switch status {
        case .completed: return Color.cjSuccess.opacity(0.12)
        case .failed: return Color.cjError.opacity(0.12)
        case .cancelled: return Color.cjWarning.opacity(0.12)
        default: return Color.cjTextSecondary.opacity(0.12)
        }
    }
}
