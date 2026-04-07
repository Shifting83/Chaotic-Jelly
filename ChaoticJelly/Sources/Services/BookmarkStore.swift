import Foundation

/// Persists security-scoped bookmarks so the app retains access to
/// user-selected folders across processing and between launches.
final class BookmarkStore {
    static let shared = BookmarkStore()

    private let key = "com.chaoticjelly.securityBookmarks"
    private let lock = NSLock()

    private init() {}

    // MARK: - Save

    func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            lock.lock()
            var bookmarks = loadAllBookmarks()
            bookmarks[url.path] = data
            UserDefaults.standard.set(bookmarks, forKey: key)
            lock.unlock()
        } catch {
            // Non-fatal: processing may still work if access is still live
        }
    }

    // MARK: - Resolve & Access

    /// Resolves a bookmark for the given path (or any parent) and starts
    /// accessing the security-scoped resource. Returns the resolved URL
    /// on success — caller must call `stopAccessing` when done.
    func startAccessing(path: String) -> URL? {
        lock.lock()
        let bookmarks = loadAllBookmarks()
        lock.unlock()

        // Try exact match first, then walk up parent directories
        var candidate = URL(fileURLWithPath: path)
        while true {
            if let data = bookmarks[candidate.path] {
                var isStale = false
                if let resolved = try? URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    if isStale {
                        // Re-save a fresh bookmark
                        saveBookmark(for: resolved)
                    }
                    if resolved.startAccessingSecurityScopedResource() {
                        return resolved
                    }
                }
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }
        return nil
    }

    /// Stops accessing a previously resolved security-scoped resource.
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Helpers

    private func loadAllBookmarks() -> [String: Data] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Data]) ?? [:]
    }
}
