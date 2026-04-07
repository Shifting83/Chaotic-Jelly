import Foundation

// MARK: - ToolLocator

/// Locates external tool binaries with a resolution order:
/// 1. User-configured path (Settings)
/// 2. Bundled in app bundle (Contents/MacOS/Tools/)
/// 3. Common Homebrew paths
/// 4. System PATH
actor ToolLocator {
    private var resolvedPaths: [ToolType: String] = [:]
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Resolve the path for a tool. Caches result.
    func path(for tool: ToolType) async throws -> String {
        if let cached = resolvedPaths[tool] {
            return cached
        }

        let resolved = try resolveToolPath(for: tool)
        resolvedPaths[tool] = resolved
        return resolved
    }

    /// Force re-resolution (e.g., after settings change).
    func invalidateCache() {
        resolvedPaths.removeAll()
    }

    /// Check if a tool is available.
    func isAvailable(_ tool: ToolType) async -> Bool {
        return (try? await path(for: tool)) != nil
    }

    /// Check all required tools and return missing ones.
    func checkRequiredTools() async -> [ToolType] {
        var missing: [ToolType] = []
        for tool in [ToolType.ffmpeg, .ffprobe] {
            if await !isAvailable(tool) {
                missing.append(tool)
            }
        }
        return missing
    }

    // MARK: - Resolution

    private func resolveToolPath(for tool: ToolType) throws -> String {
        // 1. User-configured path
        let userPath = userConfiguredPath(for: tool)
        if !userPath.isEmpty, FileManager.default.isExecutableFile(atPath: userPath) {
            return userPath
        }

        // 2. Bundled binary
        if let bundledPath = bundledPath(for: tool),
           FileManager.default.isExecutableFile(atPath: bundledPath) {
            return bundledPath
        }

        // 3. Common paths
        for commonPath in commonPaths(for: tool) {
            if FileManager.default.isExecutableFile(atPath: commonPath) {
                return commonPath
            }
        }

        // 4. Search PATH
        if let pathResult = searchPATH(for: tool.binaryName) {
            return pathResult
        }

        throw ProcessError.toolNotFound(tool.displayName)
    }

    private func userConfiguredPath(for tool: ToolType) -> String {
        switch tool {
        case .ffmpeg: return settings.ffmpegPath
        case .ffprobe: return settings.ffprobePath
        case .mkvmerge: return settings.mkvmergePath
        }
    }

    private func bundledPath(for tool: ToolType) -> String? {
        guard let bundlePath = Bundle.main.executableURL?.deletingLastPathComponent() else {
            return nil
        }
        let toolPath = bundlePath.appendingPathComponent("Tools/\(tool.binaryName)")
        return toolPath.path
    }

    private func commonPaths(for tool: ToolType) -> [String] {
        [
            "/opt/homebrew/bin/\(tool.binaryName)",
            "/usr/local/bin/\(tool.binaryName)",
            "/usr/bin/\(tool.binaryName)"
        ]
    }

    private func searchPATH(for binary: String) -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        let paths = pathEnv.split(separator: ":").map(String.init)
        for dir in paths {
            let fullPath = (dir as NSString).appendingPathComponent(binary)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
}

// MARK: - Tool Status

struct ToolStatus: Identifiable {
    let tool: ToolType
    let isAvailable: Bool
    let resolvedPath: String?
    let version: String?

    var id: ToolType { tool }
}
