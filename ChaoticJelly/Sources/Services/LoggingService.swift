import Foundation
import OSLog

// MARK: - LoggingService

/// Centralized logging with both OSLog (system) and file-based (exportable) logging.
actor LoggingService {
    private let osLog = Logger(subsystem: "com.chaoticjelly.app", category: "general")
    private let diagnosticLog = Logger(subsystem: "com.chaoticjelly.app", category: "diagnostic")

    private var logEntries: [LogEntry] = []
    private let maxEntries = 10_000
    private let logFileURL: URL

    init() {
        let logsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChaoticJelly/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        logFileURL = logsDir.appendingPathComponent("chaotic-jelly-\(dateString).log")
    }

    // MARK: - Public Logging Methods

    func logInfo(_ message: String) {
        let entry = LogEntry(level: .info, message: message)
        append(entry)
        osLog.info("\(message)")
    }

    func logWarning(_ message: String) {
        let entry = LogEntry(level: .warning, message: message)
        append(entry)
        osLog.warning("\(message)")
    }

    func logError(_ message: String) {
        let entry = LogEntry(level: .error, message: message)
        append(entry)
        osLog.error("\(message)")
    }

    func logDiagnostic(_ message: String) {
        let entry = LogEntry(level: .diagnostic, message: message)
        append(entry)
        diagnosticLog.debug("\(message)")
    }

    // MARK: - Query

    /// Get all log entries, optionally filtered.
    func entries(level: LogLevel? = nil, limit: Int = 500) -> [LogEntry] {
        if let level {
            return Array(logEntries.filter { $0.level == level }.suffix(limit))
        }
        return Array(logEntries.suffix(limit))
    }

    /// Get user-facing log entries (info, warning, error — no diagnostic).
    func userEntries(limit: Int = 200) -> [LogEntry] {
        Array(logEntries.filter { $0.level != .diagnostic }.suffix(limit))
    }

    /// Get diagnostic log entries.
    func diagnosticEntries(limit: Int = 500) -> [LogEntry] {
        Array(logEntries.filter { $0.level == .diagnostic }.suffix(limit))
    }

    // MARK: - Export

    /// Export all logs as a single text bundle.
    func exportLogBundle() -> String {
        let header = """
        Chaotic Jelly Log Export
        Date: \(ISO8601DateFormatter().string(from: Date()))
        Entries: \(logEntries.count)
        ========================================

        """

        let body = logEntries.map { entry in
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.level.rawValue.uppercased())] \(entry.message)"
        }.joined(separator: "\n")

        return header + body
    }

    /// Export logs to a file and return the URL.
    func exportToFile() throws -> URL {
        let content = exportLogBundle()
        let exportDir = FileManager.default.temporaryDirectory
        let exportURL = exportDir.appendingPathComponent("chaotic-jelly-logs-\(Int(Date().timeIntervalSince1970)).txt")
        try content.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }

    /// Clear all in-memory log entries.
    func clear() {
        logEntries.removeAll()
    }

    // MARK: - Private

    private func append(_ entry: LogEntry) {
        logEntries.append(entry)

        // Trim if over limit
        if logEntries.count > maxEntries {
            logEntries.removeFirst(logEntries.count - maxEntries)
        }

        // Append to file (best-effort)
        appendToFile(entry)
    }

    private func appendToFile(_ entry: LogEntry) {
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let line = "[\(timestamp)] [\(entry.level.rawValue)] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }
}

// MARK: - Log Types

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    init(level: LogLevel, message: String) {
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

enum LogLevel: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
    case diagnostic

    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .diagnostic: return "wrench"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
