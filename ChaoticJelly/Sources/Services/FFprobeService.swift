import Foundation

// MARK: - FFprobeService

/// Wraps ffprobe to analyze media files and parse their metadata.
actor FFprobeService {
    private let processRunner: ProcessRunner
    private let toolLocator: ToolLocator
    private let logger: LoggingService

    init(processRunner: ProcessRunner, toolLocator: ToolLocator, logger: LoggingService) {
        self.processRunner = processRunner
        self.toolLocator = toolLocator
        self.logger = logger
    }

    /// Probe a media file and return parsed MediaInfo.
    /// Retries on transient failures (network shares, locked files).
    /// For MP4 files on network shares, scales timeout with file size
    /// since the moov atom may be at the end of the file.
    func probe(fileURL: URL) async throws -> MediaInfo {
        let ffprobePath = try await toolLocator.path(for: .ffprobe)
        let filePath = fileURL.path
        let isNetworkPath = filePath.hasPrefix("/Volumes/") || filePath.hasPrefix("/mnt/")
        let ext = fileURL.pathExtension.lowercased()
        let isMp4Like = ["mp4", "m4v", "mov"].contains(ext)

        // Verify file is accessible before probing
        guard FileManager.default.isReadableFile(atPath: filePath) else {
            throw FFprobeError.fileNotFound(filePath)
        }

        // Get file size to scale timeout for large files on network shares
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int64) ?? 0
        let fileSizeGB = Double(fileSize) / 1_073_741_824

        let maxAttempts = isNetworkPath ? 3 : 2

        // Scale base timeout: 60s for local, 90s for network, +30s per GB for MP4 on network
        let baseTimeout: TimeInterval
        if isNetworkPath && isMp4Like {
            baseTimeout = max(120, 60 + fileSizeGB * 30)
        } else if isNetworkPath {
            baseTimeout = 90
        } else {
            baseTimeout = 60
        }

        var lastError: Error?

        for attempt in 1...maxAttempts {
            // Use progressively larger probe settings on retry
            let analyzeDuration = attempt == 1 ? "2000000" : "10000000"
            let probeSize = attempt == 1 ? "2000000" : "10000000"

            let arguments = [
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                "-analyzeduration", analyzeDuration,
                "-probesize", probeSize,
                filePath
            ]

            do {
                let result = try await processRunner.runOrThrow(
                    executablePath: ffprobePath,
                    arguments: arguments,
                    timeout: baseTimeout * Double(attempt)
                )

                await logger.logDiagnostic("ffprobe completed in \(String(format: "%.1f", result.duration))s for \(fileURL.lastPathComponent)")
                return try parseProbeOutput(json: result.stdout, filePath: filePath)
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = Double(attempt) * 2.0
                    await logger.logWarning("ffprobe attempt \(attempt)/\(maxAttempts) failed for \(fileURL.lastPathComponent), retrying in \(Int(delay))s...")
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }

        await logger.logError("ffprobe failed after \(maxAttempts) attempts for \(fileURL.lastPathComponent): \(lastError?.localizedDescription ?? "unknown")")
        throw lastError!
    }

    // MARK: - Parsing

    /// Parse ffprobe JSON output into MediaInfo.
    /// This is a static-like method for testability.
    func parseProbeOutput(json: String, filePath: String) throws -> MediaInfo {
        guard let data = json.data(using: .utf8) else {
            throw FFprobeError.invalidOutput("Empty or non-UTF8 output")
        }

        let probeResult: FFprobeJSON
        do {
            probeResult = try JSONDecoder().decode(FFprobeJSON.self, from: data)
        } catch {
            throw FFprobeError.parseError("Failed to decode ffprobe JSON: \(error.localizedDescription)")
        }

        let format = probeResult.format
        let streams = probeResult.streams ?? []

        let videoStreams = streams
            .filter { $0.codecType == "video" }
            .map { parseVideoStream($0) }

        let audioStreams = streams
            .filter { $0.codecType == "audio" }
            .map { parseAudioStream($0) }

        let subtitleStreams = streams
            .filter { $0.codecType == "subtitle" }
            .map { parseSubtitleStream($0) }

        let container = format.formatName ?? URL(fileURLWithPath: filePath).pathExtension
        let duration = Double(format.duration ?? "0") ?? 0
        let bitRate = format.bitRate.flatMap { Int64($0) }
        let fileSize = Int64(format.size ?? "0") ?? 0

        return MediaInfo(
            container: container,
            duration: duration,
            bitRate: bitRate,
            fileSize: fileSize,
            videoStreams: videoStreams,
            audioStreams: audioStreams,
            subtitleStreams: subtitleStreams
        )
    }

    // MARK: - Stream Parsing

    private func parseVideoStream(_ stream: FFprobeStream) -> VideoStreamInfo {
        let lang = stream.tags?.language
        let confidence = classifyLanguageConfidence(language: lang, title: stream.tags?.title)

        return VideoStreamInfo(
            index: stream.index,
            codec: stream.codecName ?? "unknown",
            codecLongName: stream.codecLongName,
            profile: stream.profile,
            width: stream.width ?? 0,
            height: stream.height ?? 0,
            frameRate: parseFrameRate(stream.rFrameRate),
            bitRate: stream.bitRate.flatMap { Int64($0) },
            pixelFormat: stream.pixFmt,
            isDefault: stream.disposition?.isDefault == 1,
            title: stream.tags?.title,
            language: lang,
            languageConfidence: confidence
        )
    }

    private func parseAudioStream(_ stream: FFprobeStream) -> AudioStreamInfo {
        let lang = stream.tags?.language
        let confidence = classifyLanguageConfidence(language: lang, title: stream.tags?.title)

        return AudioStreamInfo(
            index: stream.index,
            codec: stream.codecName ?? "unknown",
            codecLongName: stream.codecLongName,
            sampleRate: stream.sampleRate.flatMap { Int($0) },
            channels: stream.channels ?? 0,
            channelLayout: stream.channelLayout,
            bitRate: stream.bitRate.flatMap { Int64($0) },
            isDefault: stream.disposition?.isDefault == 1,
            isForced: stream.disposition?.forced == 1,
            title: stream.tags?.title,
            language: lang,
            languageConfidence: confidence
        )
    }

    private func parseSubtitleStream(_ stream: FFprobeStream) -> SubtitleStreamInfo {
        let lang = stream.tags?.language
        let confidence = classifyLanguageConfidence(language: lang, title: stream.tags?.title)

        return SubtitleStreamInfo(
            index: stream.index,
            codec: stream.codecName ?? "unknown",
            codecLongName: stream.codecLongName,
            isDefault: stream.disposition?.isDefault == 1,
            isForced: stream.disposition?.forced == 1,
            title: stream.tags?.title,
            language: lang,
            languageConfidence: confidence
        )
    }

    // MARK: - Language Classification

    private func classifyLanguageConfidence(language: String?, title: String?) -> LanguageConfidence {
        // High: recognized ISO 639 tag present
        if let lang = language, !lang.isEmpty, lang != "und", lang != "unk" {
            if LanguageUtils.isRecognizedCode(lang) {
                return .high
            }
            return .low
        }

        // Medium: title contains a language name
        if let title = title, !title.isEmpty {
            if LanguageUtils.titleContainsLanguageName(title) {
                return .medium
            }
        }

        return .unknown
    }

    // MARK: - Helpers

    private func parseFrameRate(_ rateString: String?) -> Double? {
        guard let rateString else { return nil }
        let parts = rateString.split(separator: "/")
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]),
              den > 0 else {
            return Double(rateString)
        }
        return num / den
    }
}

// MARK: - FFprobe JSON Models

struct FFprobeJSON: Codable {
    let format: FFprobeFormat
    let streams: [FFprobeStream]?
}

struct FFprobeFormat: Codable {
    let filename: String?
    let formatName: String?
    let formatLongName: String?
    let duration: String?
    let size: String?
    let bitRate: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case formatName = "format_name"
        case formatLongName = "format_long_name"
        case duration
        case size
        case bitRate = "bit_rate"
    }
}

struct FFprobeStream: Codable {
    let index: Int
    let codecName: String?
    let codecLongName: String?
    let codecType: String?
    let profile: String?
    let width: Int?
    let height: Int?
    let channels: Int?
    let channelLayout: String?
    let sampleRate: String?
    let bitRate: String?
    let rFrameRate: String?
    let pixFmt: String?
    let disposition: FFprobeDisposition?
    let tags: FFprobeTags?

    enum CodingKeys: String, CodingKey {
        case index
        case codecName = "codec_name"
        case codecLongName = "codec_long_name"
        case codecType = "codec_type"
        case profile
        case width
        case height
        case channels
        case channelLayout = "channel_layout"
        case sampleRate = "sample_rate"
        case bitRate = "bit_rate"
        case rFrameRate = "r_frame_rate"
        case pixFmt = "pix_fmt"
        case disposition
        case tags
    }
}

struct FFprobeDisposition: Codable {
    let isDefault: Int?
    let forced: Int?
    let hearingImpaired: Int?
    let visualImpaired: Int?
    let comment: Int?

    enum CodingKeys: String, CodingKey {
        case isDefault = "default"
        case forced
        case hearingImpaired = "hearing_impaired"
        case visualImpaired = "visual_impaired"
        case comment
    }
}

struct FFprobeTags: Codable {
    let language: String?
    let title: String?
    let handler_name: String?

    enum CodingKeys: String, CodingKey {
        case language
        case title
        case handler_name
    }
}

// MARK: - FFprobe Errors

enum FFprobeError: LocalizedError {
    case invalidOutput(String)
    case parseError(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput(let msg): return "Invalid ffprobe output: \(msg)"
        case .parseError(let msg): return "FFprobe parse error: \(msg)"
        case .fileNotFound(let path): return "File not found: \(path)"
        }
    }
}
