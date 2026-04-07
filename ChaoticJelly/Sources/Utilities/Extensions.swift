import Foundation

// MARK: - Int64 Formatting

extension Int64 {
    /// Format as a human-readable file size string.
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// Format as "Xh Ym Zs" or "Ym Zs" or "Zs".
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Date Formatting

extension Date {
    /// Relative time string like "2 hours ago".
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Short date/time string.
    var shortString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - URL

extension URL {
    /// Check if this URL points to a network share (SMB, NFS, AFP).
    var isNetworkPath: Bool {
        let path = self.path
        return path.hasPrefix("/Volumes/") || path.hasPrefix("/mnt/") || path.hasPrefix("/net/")
    }
}

// MARK: - Array

extension Array where Element == PlannedAction {
    var removeCount: Int {
        filter { if case .removeStream = $0 { return true }; return false }.count
    }

    var keepCount: Int {
        filter { if case .keepStream = $0 { return true }; return false }.count
    }

    var hasDestructiveActions: Bool {
        contains { $0.isDestructive }
    }
}
