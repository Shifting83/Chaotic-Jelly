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

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                // Dashboard (ungrouped)
                Label(NavigationItem.dashboard.rawValue, systemImage: NavigationItem.dashboard.systemImage)
                    .tag(NavigationItem.dashboard)

                // Workflow section
                Section("Workflow") {
                    ForEach(NavigationItem.workflowItems) { item in
                        sidebarRow(item: item)
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
        }
    }

    @ViewBuilder
    private func sidebarRow(item: NavigationItem) -> some View {
        switch item {
        case .review:
            let count = reviewVM?.job?.files.filter({ $0.fileStatus == .analyzed }).count ?? 0
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
                .badge(count > 0 ? count : 0)
        case .processing:
            let vm = QueueViewModel(container: container)
            if let job = vm.activeJob {
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
                    .badge("\(job.completedFileCount)/\(job.fileCount)")
            } else {
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
        default:
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
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
                    reviewVM?.job = job
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
            QueueView(viewModel: QueueViewModel(container: container))
        case .history:
            HistoryView(viewModel: HistoryViewModel(container: container))
        case .logs:
            LogsView(viewModel: LogsViewModel(container: container))
        }
    }
}
