import Foundation

// MARK: - MKVToolNixService

/// Wraps MKVToolNix (mkvmerge) for MKV-specific operations.
/// Preferred over ffmpeg for stream removal from MKV files as it's safer
/// and handles MKV quirks better.
actor MKVToolNixService {
    private let processRunner: ProcessRunner
    private let toolLocator: ToolLocator
    private let logger: LoggingService

    init(processRunner: ProcessRunner, toolLocator: ToolLocator, logger: LoggingService) {
        self.processRunner = processRunner
        self.toolLocator = toolLocator
        self.logger = logger
    }

    /// Check if mkvmerge is available.
    var isAvailable: Bool {
        get async {
            await toolLocator.isAvailable(.mkvmerge)
        }
    }

    /// Remove specified tracks from an MKV file using mkvmerge.
    /// This is safer than ffmpeg for MKV stream removal as it preserves
    /// all MKV-specific metadata, chapters, and attachments.
    func removeStreams(
        inputPath: URL,
        outputPath: URL,
        audioIndicesToRemove: [Int],
        subtitleIndicesToRemove: [Int]
    ) async throws -> ProcessResult {
        let mkvmergePath = try await toolLocator.path(for: .mkvmerge)

        var args: [String] = [
            "-o", outputPath.path
        ]

        // mkvmerge uses track IDs (TIDs), not ffmpeg stream indices.
        // We need to build --audio-tracks and --subtitle-tracks flags
        // with the tracks to KEEP (mkvmerge uses inclusive, not exclusive).

        if !audioIndicesToRemove.isEmpty {
            // Tell mkvmerge which audio tracks to remove
            let removeList = audioIndicesToRemove.map(String.init).joined(separator: ",")
            args += ["--audio-tracks", "!\(removeList)"]
        }

        if !subtitleIndicesToRemove.isEmpty {
            let removeList = subtitleIndicesToRemove.map(String.init).joined(separator: ",")
            args += ["--subtitle-tracks", "!\(removeList)"]
        }

        args.append(inputPath.path)

        let commandString = "mkvmerge " + args.joined(separator: " ")
        await logger.logDiagnostic("Running: \(commandString)")

        // mkvmerge exit codes: 0 = success, 1 = warnings, 2 = error
        let result = try await processRunner.run(
            executablePath: mkvmergePath,
            arguments: args,
            timeout: 3600
        )

        if result.exitCode == 0 || result.exitCode == 1 {
            if result.exitCode == 1 {
                await logger.logWarning("mkvmerge completed with warnings: \(result.stdout)")
            }
            await logger.logDiagnostic("mkvmerge completed in \(String(format: "%.1f", result.duration))s")
            return result
        } else {
            await logger.logError("mkvmerge failed (exit \(result.exitCode)): \(result.stdout)")
            throw ProcessError.executionFailed(
                command: commandString,
                exitCode: result.exitCode,
                stderr: result.stdout  // mkvmerge outputs errors to stdout
            )
        }
    }

    /// Get MKV info (alternative to ffprobe for MKV files).
    func identify(filePath: URL) async throws -> ProcessResult {
        let mkvmergePath = try await toolLocator.path(for: .mkvmerge)
        let args = ["-i", "-F", "json", filePath.path]
        return try await processRunner.runOrThrow(
            executablePath: mkvmergePath,
            arguments: args,
            timeout: 60
        )
    }
}
