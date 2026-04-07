import Foundation
import SwiftUI

@Observable
final class LogsViewModel {
    private let container: ServiceContainer

    var entries: [LogEntry] = []
    var filterLevel: LogLevel?
    var searchText = ""
    var showDiagnostic = false

    init(container: ServiceContainer) {
        self.container = container
    }

    var filteredEntries: [LogEntry] {
        var result = entries

        if let filterLevel {
            result = result.filter { $0.level == filterLevel }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    func refresh() async {
        if showDiagnostic {
            entries = await container.logger.entries(limit: 1000)
        } else {
            entries = await container.logger.userEntries(limit: 500)
        }
    }

    func exportLogs() async -> URL? {
        try? await container.logger.exportToFile()
    }

    func clearLogs() async {
        await container.logger.clear()
        entries = []
    }
}
