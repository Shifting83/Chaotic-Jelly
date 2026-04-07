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
    private(set) var isInstalling = false
    private(set) var installProgress: String?
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

    // MARK: - In-Place Upgrade

    /// Download the DMG, mount it, replace the running app, and relaunch.
    func installUpdate() async {
        guard let release = latestRelease,
              let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
        else {
            lastError = "No DMG found in release"
            return
        }

        isInstalling = true
        installProgress = "Downloading update..."
        lastError = nil

        do {
            // 1. Download DMG via GitHub API (handles private repos correctly)
            //    The browserDownloadURL redirects through GitHub → S3 and strips
            //    the auth header on redirect. Use the API asset URL instead.
            let dmgPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("ChaoticJelly-update.dmg")

            try? FileManager.default.removeItem(at: dmgPath)

            // Use the API asset URL for private repo downloads
            let apiURL = "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/assets/\(dmgAsset.id)"
            guard let downloadURL = URL(string: apiURL) else {
                throw UpdateError.downloadFailed
            }

            var request = URLRequest(url: downloadURL)
            // Accept: application/octet-stream tells the GitHub API to return
            // the binary content directly instead of JSON metadata
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.setValue("Chaotic-Jelly/\(Constants.appVersion)", forHTTPHeaderField: "User-Agent")
            if let token = try? KeychainService.load(key: .githubPAT) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (tempURL, response) = try await URLSession.shared.download(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw UpdateError.downloadFailed
            }

            // GitHub API returns 200 for direct download, or 302 redirect to S3
            // URLSession follows redirects automatically
            guard (200...299).contains(http.statusCode) else {
                await logger.logError("Download failed with HTTP \(http.statusCode)")
                throw UpdateError.downloadFailed
            }

            try FileManager.default.moveItem(at: tempURL, to: dmgPath)
            await logger.logInfo("Downloaded update to \(dmgPath.path)")

            // 2. Mount DMG
            installProgress = "Mounting disk image..."
            let mountPoint = try await mountDMG(at: dmgPath)

            // 3. Find the .app inside the mounted volume
            let contents = try FileManager.default.contentsOfDirectory(
                at: mountPoint,
                includingPropertiesForKeys: nil
            )
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                try? await unmountDMG(at: mountPoint)
                throw UpdateError.appNotFoundInDMG
            }

            // 4. Replace the running app
            installProgress = "Installing update..."
            let currentApp = Bundle.main.bundleURL

            // Sanity check: make sure we're replacing an .app
            guard currentApp.pathExtension == "app" else {
                try? await unmountDMG(at: mountPoint)
                throw UpdateError.installFailed("Cannot determine current app location")
            }

            let backupURL = currentApp.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)

            // Move current app to backup, copy new app in
            try FileManager.default.moveItem(at: currentApp, to: backupURL)
            do {
                try FileManager.default.copyItem(at: newApp, to: currentApp)
            } catch {
                // Restore backup on failure
                try? FileManager.default.moveItem(at: backupURL, to: currentApp)
                try? await unmountDMG(at: mountPoint)
                throw UpdateError.installFailed(error.localizedDescription)
            }

            // Clean up backup and unmount
            try? FileManager.default.removeItem(at: backupURL)
            try? await unmountDMG(at: mountPoint)
            try? FileManager.default.removeItem(at: dmgPath)

            await logger.logInfo("Update installed, relaunching...")
            installProgress = "Relaunching..."

            // 5. Relaunch
            relaunch()

        } catch {
            isInstalling = false
            installProgress = nil
            lastError = error.localizedDescription
            await logger.logError("Update install failed: \(error.localizedDescription)")
        }
    }

    private func mountDMG(at url: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-nobrowse", "-readonly", "-plist"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.installFailed("Failed to mount DMG")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        // Parse plist output to find mount point
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            throw UpdateError.installFailed("Could not determine mount point")
        }

        return URL(fileURLWithPath: mountPoint)
    }

    private func unmountDMG(at mountPoint: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
    }

    private func relaunch() {
        let appURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true

        // Launch the new version, then exit the current one
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
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
    let id: Int
    let name: String
    let url: String
    let browserDownloadURL: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
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
    case downloadFailed
    case appNotFoundInDMG
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid GitHub API URL"
        case .networkError: return "Network request failed"
        case .authenticationFailed: return "GitHub token is invalid or expired"
        case .rateLimited: return "GitHub API rate limit exceeded — add a token in Settings"
        case .noReleasesFound: return "No releases found"
        case .httpError(let code): return "GitHub API error (HTTP \(code))"
        case .downloadFailed: return "Failed to download update"
        case .appNotFoundInDMG: return "No app found in downloaded disk image"
        case .installFailed(let reason): return "Install failed: \(reason)"
        }
    }
}
