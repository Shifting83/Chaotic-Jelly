import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, CaseIterable {
    case home
    case workflow
    case reference
}

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case scan = "New Scan"
    case review = "Review"
    case processing = "Processing"
    case history = "History"
    case logs = "Logs"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .scan: return "doc.text.magnifyingglass"
        case .review: return "checklist"
        case .processing: return "bolt.fill"
        case .history: return "clock.arrow.circlepath"
        case .logs: return "doc.plaintext"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: return .home
        case .scan, .review, .processing: return .workflow
        case .history, .logs: return .reference
        }
    }

    static var workflowItems: [NavigationItem] { [.scan, .review, .processing] }
    static var referenceItems: [NavigationItem] { [.history, .logs] }
}

// MARK: - ContentView

struct ContentView: View {
    let container: ServiceContainer
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var scanVM: ScanViewModel?
    @State private var reviewVM: ReviewViewModel?
    @State private var queueVM: QueueViewModel?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                // Dashboard (ungrouped)
                Label(NavigationItem.dashboard.rawValue, systemImage: NavigationItem.dashboard.systemImage)
                    .tag(NavigationItem.dashboard)

                // Workflow section
                Section("Workflow") {
                    ForEach(NavigationItem.workflowItems) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                            .badge(badgeFor(item))
                    }
                }

                // Reference section
                Section("Reference") {
                    ForEach(NavigationItem.referenceItems) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(selectedItem.rawValue)
        .onAppear {
            scanVM = ScanViewModel(container: container)
            reviewVM = ReviewViewModel(container: container)
            queueVM = QueueViewModel(container: container)
        }
    }

    private func badgeFor(_ item: NavigationItem) -> Text? {
        switch item {
        case .review:
            let count = reviewVM?.job?.files.filter({ $0.fileStatus == .analyzed }).count ?? 0
            return count > 0 ? Text("\(count)") : nil
        case .processing:
            guard let job = container.jobManager.activeJob else { return nil }
            return Text("\(job.completedFileCount)/\(job.fileCount)")
        default:
            return nil
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(viewModel: DashboardViewModel(container: container), onNewScan: {
                selectedItem = .scan
            })
        case .scan:
            if let scanVM {
                ScanView(viewModel: scanVM, settings: container.settings, onReview: { job in
                    if let reviewVM {
                        reviewVM.job = job
                    }
                    selectedItem = .review
                })
            }
        case .review:
            if let reviewVM {
                ReviewView(viewModel: reviewVM, onStartProcessing: {
                    selectedItem = .processing
                })
            }
        case .processing:
            if let queueVM {
                QueueView(viewModel: queueVM)
            }
        case .history:
            HistoryView(viewModel: HistoryViewModel(container: container))
        case .logs:
            LogsView(viewModel: LogsViewModel(container: container))
        }
    }
}
