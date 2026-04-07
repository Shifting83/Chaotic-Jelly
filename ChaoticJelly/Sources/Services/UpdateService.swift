import Foundation
import AppKit

// MARK: - UpdateService

/// Checks GitHub Releases for new versions and opens the download page.
@MainActor @Observable
final class UpdateService {
    private let settings: AppSettings
    private let logger: LoggingService

    private(set) var latestRelease: GitHubRelease?
    private(set) var isChecking = false
    private(set) var lastCheckDate: Date?
    private(set) var lastError: String?

    private static let owner = "Shifting83"
    private static let repo = "Chaotic-Jelly"
    private static let lastCheckKey = "update.lastCheckDate"

    var updateAvailable: Bool {
        guard let release = latestRelease else { return false }
        return isNewer(release.tagName, than: Constants.appVersion)
    }

    init(settings: AppSettings, logger: LoggingService) {
        self.settings = settings
        self.logger = logger
        self.lastCheckDate = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    // MARK: - Public

    /// Check for updates if auto-check is enabled and enough time has passed.
    func checkIfNeeded() async {
        guard settings.checkForUpdates else { return }

        // Skip if checked within the last 4 hours
        if let last = lastCheckDate, Date().timeIntervalSince(last) < 4 * 3600 {
            return
        }

        await check()
    }

    /// Manually check for a new release.
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil

        defer {
            isChecking = false
            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: Self.lastCheckKey)
        }

        do {
            latestRelease = try await fetchLatestRelease()
            if updateAvailable, let tag = latestRelease?.tagName {
                await logger.logInfo("Update available: \(tag)")
            }
        } catch {
            lastError = error.localizedDescription
            await logger.logError("Update check failed: \(error.localizedDescription)")
        }
    }

    /// Open the release page in the default browser so the user can download.
    func openReleasePage() {
        guard let release = latestRelease else { return }
        if let url = URL(string: release.htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open a direct DMG download if one is attached to the release.
    func downloadDMG() {
        guard let release = latestRelease,
              let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
        else {
            openReleasePage()
            return
        }

        if let url = URL(string: dmgAsset.browserDownloadURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - GitHub API

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Chaotic-Jelly/\(Constants.appVersion)", forHTTPHeaderField: "User-Agent")

        // Use PAT for private repo access
        if let token = try? KeychainService.load(key: .githubPAT) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.networkError
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        case 401:
            throw UpdateError.authenticationFailed
        case 403:
            throw UpdateError.rateLimited
        case 404:
            throw UpdateError.noReleasesFound
        default:
            throw UpdateError.httpError(http.statusCode)
        }
    }

    // MARK: - Version Comparison

    /// Returns true if `remote` (e.g. "v0.4.0") is newer than `local` (e.g. "0.3.7").
    private func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = parseVersion(remote)
        let localParts = parseVersion(local)

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    private func parseVersion(_ version: String) -> [Int] {
        let stripped = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return stripped.split(separator: ".").compactMap { Int($0) }
    }
}

// MARK: - Models

struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let body: String?
    let prerelease: Bool
    let publishedAt: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case body
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable, Sendable {
    let name: String
    let browserDownloadURL: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case networkError
    case authenticationFailed
    case rateLimited
    case noReleasesFound
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid GitHub API URL"
        case .networkError: return "Network request failed"
        case .authenticationFailed: return "GitHub token is invalid or expired"
        case .rateLimited: return "GitHub API rate limit exceeded — add a token in Settings"
        case .noReleasesFound: return "No releases found"
        case .httpError(let code): return "GitHub API error (HTTP \(code))"
        }
    }
}
