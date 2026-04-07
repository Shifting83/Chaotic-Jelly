import SwiftUI

// MARK: - Navigation

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case scan = "New Scan"
    case review = "Review"
    case queue = "Queue"
    case history = "History"
    case logs = "Logs"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .scan: return "doc.text.magnifyingglass"
        case .review: return "checklist"
        case .queue: return "list.bullet.rectangle"
        case .history: return "clock.arrow.circlepath"
        case .logs: return "doc.plaintext"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    let container: ServiceContainer
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var scanVM: ScanViewModel?
    @State private var reviewVM: ReviewViewModel?

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
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
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(viewModel: DashboardViewModel(container: container))
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
                    selectedItem = .queue
                })
            }
        case .queue:
            QueueView(viewModel: QueueViewModel(container: container))
        case .history:
            HistoryView(viewModel: HistoryViewModel(container: container))
        case .logs:
            LogsView(viewModel: LogsViewModel(container: container))
        }
    }
}
