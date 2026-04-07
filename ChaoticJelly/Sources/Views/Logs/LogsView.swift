import SwiftUI

struct LogsView: View {
    @State var viewModel: LogsViewModel
    @State private var showExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search logs...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 250)

                // Level filter
                Picker("Level", selection: Binding(
                    get: { viewModel.filterLevel },
                    set: { viewModel.filterLevel = $0 }
                )) {
                    Text("All Levels").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Label(level.displayName, systemImage: level.systemImage)
                            .tag(level as LogLevel?)
                    }
                }
                .frame(width: 130)

                Toggle("Show Diagnostic", isOn: $viewModel.showDiagnostic)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()

                Button {
                    Task {
                        if let url = await viewModel.exportLogs() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    Task { await viewModel.clearLogs() }
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Log entries
            if viewModel.filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "doc.plaintext",
                    description: Text("Log entries will appear here as the app runs.")
                )
            } else {
                List(viewModel.filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .font(.system(.caption, design: .monospaced))
            }
        }
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.showDiagnostic) {
            Task { await viewModel.refresh() }
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.level.systemImage)
                .foregroundStyle(levelColor)
                .frame(width: 16)

            Text(entry.timestamp, style: .time)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(entry.level.rawValue.uppercased())
                .foregroundStyle(levelColor)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .diagnostic: return .secondary
        }
    }
}
