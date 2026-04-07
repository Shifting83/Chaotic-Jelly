import Foundation

// MARK: - FFmpegService

/// Wraps ffmpeg to process video files — stream removal, remuxing, transcoding.
actor FFmpegService {
    private let processRunner: ProcessRunner
    private let toolLocator: ToolLocator
    private let logger: LoggingService
    private var videoToolboxAvailable: Bool?

    init(processRunner: ProcessRunner, toolLocator: ToolLocator, logger: LoggingService) {
        self.processRunner = processRunner
        self.toolLocator = toolLocator
        self.logger = logger
    }

    /// Check if VideoToolbox hardware encoding is available.
    private func checkVideoToolbox() async -> Bool {
        if let cached = videoToolboxAvailable { return cached }
        do {
            let ffmpegPath = try await toolLocator.path(for: .ffmpeg)
            let result = try await processRunner.run(
                executablePath: ffmpegPath,
                arguments: ["-hide_banner", "-encoders"],
                timeout: 10
            )
            let available = result.stdout.contains("h264_videotoolbox")
            videoToolboxAvailable = available
            if available {
                await logger.logInfo("VideoToolbox hardware encoding available")
            } else {
                await logger.logInfo("VideoToolbox not available, using CPU encoding")
            }
            return available
        } catch {
            videoToolboxAvailable = false
            return false
        }
    }

    /// Build and execute an ffmpeg command based on planned actions.
    func process(
        inputPath: URL,
        outputPath: URL,
        actions: [PlannedAction],
        mediaInfo: MediaInfo,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ProcessResult {
        let ffmpegPath = try await toolLocator.path(for: .ffmpeg)
        let useHW = await checkVideoToolbox()
        let arguments = buildArguments(
            inputPath: inputPath,
            outputPath: outputPath,
            actions: actions,
            mediaInfo: mediaInfo,
            useVideoToolbox: useHW
        )

        let commandString = "ffmpeg " + arguments.joined(separator: " ")
        await logger.logDiagnostic("Running: \(commandString)")

        let result = try await processRunner.run(
            executablePath: ffmpegPath,
            arguments: arguments,
            timeout: 7200  // 2 hours max for large files
        )

        if result.succeeded {
            await logger.logDiagnostic("ffmpeg completed successfully in \(String(format: "%.1f", result.duration))s")
        } else {
            await logger.logError("ffmpeg failed (exit \(result.exitCode)): \(result.stderr)")
        }

        return result
    }

    // MARK: - Argument Building

    func buildArguments(
        inputPath: URL,
        outputPath: URL,
        actions: [PlannedAction],
        mediaInfo: MediaInfo,
        useVideoToolbox: Bool = false
    ) -> [String] {
        var args: [String] = [
            "-hide_banner",
            "-y",  // overwrite output (we control output path)
            "-i", inputPath.path
        ]

        // Determine which streams to copy vs remove vs transcode
        var mapArgs: [String] = []
        var codecArgs: [String] = []

        let allStreamIndices = Set(
            mediaInfo.videoStreams.map(\.index) +
            mediaInfo.audioStreams.map(\.index) +
            mediaInfo.subtitleStreams.map(\.index)
        )

        var removedIndices = Set<Int>()
        var transcodeVideoActions: [PlannedAction] = []
        var transcodeAudioActions: [PlannedAction] = []

        for action in actions {
            switch action {
            case .removeStream(let index, _):
                removedIndices.insert(index)
            case .transcodeVideo:
                transcodeVideoActions.append(action)
            case .transcodeAudio:
                transcodeAudioActions.append(action)
            case .keepStream, .copyStream, .remuxContainer:
                break
            }
        }

        // Map all non-removed streams
        let keptIndices = allStreamIndices.subtracting(removedIndices).sorted()
        for index in keptIndices {
            mapArgs += ["-map", "0:\(index)"]
        }

        // If no streams explicitly mapped, map everything except removed
        if mapArgs.isEmpty && removedIndices.isEmpty {
            mapArgs += ["-map", "0"]
        }

        args += mapArgs

        // Handle transcoding
        for action in transcodeVideoActions {
            if case .transcodeVideo(_, let codec, let preset, let crf) = action {
                if useVideoToolbox {
                    // macOS VideoToolbox hardware encoder
                    let encoder = codec == "hevc" ? "hevc_videotoolbox" : "h264_videotoolbox"
                    // Map CRF roughly to VT quality (lower CRF = higher quality)
                    let quality = max(1, min(100, 100 - crf * 3))
                    codecArgs += ["-c:v", encoder, "-q:v", String(quality)]
                    if codec == "hevc" {
                        codecArgs += ["-tag:v", "hvc1"]
                    }
                } else {
                    // CPU software encoder fallback
                    let encoder = codec == "hevc" ? "libx265" : "libx264"
                    codecArgs += ["-c:v", encoder, "-preset", preset, "-crf", String(crf)]
                }
            }
        }

        for action in transcodeAudioActions {
            if case .transcodeAudio(let index, let codec, let channels, let bitrate) = action {
                // Find the output stream index for this input stream
                let outputIdx = keptIndices.firstIndex(of: index) ?? 0
                codecArgs += [
                    "-c:a:\(outputIdx)", codec == "aac" ? "aac" : "ac3",
                    "-ac:\(outputIdx)", String(channels),
                    "-b:a:\(outputIdx)", "\(bitrate)k"
                ]
            }
        }

        // Default: copy all non-transcoded streams
        if transcodeVideoActions.isEmpty {
            codecArgs += ["-c:v", "copy"]
        }
        if transcodeAudioActions.isEmpty {
            codecArgs += ["-c:a", "copy"]
        }

        // Subtitles: copy if container supports, otherwise drop
        let outputExt = outputPath.pathExtension.lowercased()
        if outputExt == "mp4" {
            // MP4 only supports mov_text subtitles
            codecArgs += ["-c:s", "mov_text"]
        } else {
            codecArgs += ["-c:s", "copy"]
        }

        args += codecArgs

        // Metadata
        args += [
            "-map_metadata", "0",
            "-map_chapters", "0"
        ]

        // Output path
        args.append(outputPath.path)

        return args
    }

    /// Quick remux only — copy all streams, just change container.
    func remux(
        inputPath: URL,
        outputPath: URL
    ) async throws -> ProcessResult {
        let ffmpegPath = try await toolLocator.path(for: .ffmpeg)
        let args = [
            "-hide_banner",
            "-y",
            "-i", inputPath.path,
            "-map", "0",
            "-c", "copy",
            "-map_metadata", "0",
            "-map_chapters", "0",
            outputPath.path
        ]

        await logger.logDiagnostic("Running remux: ffmpeg \(args.joined(separator: " "))")
        return try await processRunner.runOrThrow(executablePath: ffmpegPath, arguments: args)
    }
}
