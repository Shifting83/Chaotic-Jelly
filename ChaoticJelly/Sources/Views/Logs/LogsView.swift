import SwiftUI
import AppKit

struct LogsView: View {
    @State var viewModel: LogsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 10) {
                SearchField(text: $viewModel.searchText, placeholder: "Filter logs...")

                HStack(spacing: 4) {
                    FilterPill(label: "All", value: nil as LogLevel?, selection: $viewModel.filterLevel)
                    FilterPill(label: "Info", value: .info, selection: $viewModel.filterLevel)
                    FilterPill(label: "Warning", value: .warning, selection: $viewModel.filterLevel, labelColor: .cjWarning)
                    FilterPill(label: "Error", value: .error, selection: $viewModel.filterLevel, labelColor: .cjError)
                }

                Spacer()

                Toggle("Diagnostics", isOn: $viewModel.showDiagnostic)
                    .toggleStyle(.checkbox)
                    .font(.cjSecondary)

                Button {
                    Task {
                        if let url = await viewModel.exportLogs() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } label: {
                    Text("Export")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    Task { await viewModel.clearLogs() }
                } label: {
                    Text("Clear")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            // Log panel (dark terminal)
            if viewModel.filteredEntries.isEmpty {
                CJEmptyStateView(
                    icon: "📝",
                    title: "No logs yet",
                    message: "Logs will appear when you start processing"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(viewModel.filteredEntries) { entry in
                                logEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(12)
                    }
                    .background(Color.cjLogTerminal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cjLogBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .onChange(of: viewModel.filteredEntries.count) {
                        if let last = viewModel.filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.cjBackground)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.showDiagnostic) {
            Task { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func logEntryRow(entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .foregroundStyle(Color(white: 0.4))
                .frame(width: 72, alignment: .leading)

            Text(entry.level.rawValue.uppercased())
                .fontWeight(.medium)
                .foregroundStyle(logLevelColor(entry.level))
                .frame(width: 52, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(logMessageColor(entry.level))
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .font(.cjLogText)
        .padding(.vertical, 1)
    }

    private func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .cjLogInfo
        case .warning: return .cjLogWarn
        case .error: return .cjLogError
        case .diagnostic: return Color(white: 0.5)
        }
    }

    private func logMessageColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return Color(white: 0.83)
        case .warning: return .cjLogWarn
        case .error: return .cjLogError
        case .diagnostic: return Color(white: 0.5)
        }
    }
}
