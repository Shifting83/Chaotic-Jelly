import Foundation

// MARK: - MediaInfo

/// Parsed result of an ffprobe analysis of a media file.
struct MediaInfo: Codable, Equatable, Sendable {
    let container: String
    let duration: Double
    let bitRate: Int64?
    let fileSize: Int64
    let videoStreams: [VideoStreamInfo]
    let audioStreams: [AudioStreamInfo]
    let subtitleStreams: [SubtitleStreamInfo]

    var totalStreamCount: Int {
        videoStreams.count + audioStreams.count + subtitleStreams.count
    }
}

// MARK: - Stream Info Types

struct VideoStreamInfo: Codable, Equatable, Sendable, Identifiable {
    let index: Int
    let codec: String
    let codecLongName: String?
    let profile: String?
    let width: Int
    let height: Int
    let frameRate: Double?
    let bitRate: Int64?
    let pixelFormat: String?
    let isDefault: Bool
    let title: String?
    let language: String?
    let languageConfidence: LanguageConfidence

    var id: Int { index }

    var resolution: String {
        "\(width)x\(height)"
    }

    var codecDisplay: String {
        if let profile {
            return "\(codec.uppercased()) (\(profile))"
        }
        return codec.uppercased()
    }
}

struct AudioStreamInfo: Codable, Equatable, Sendable, Identifiable {
    let index: Int
    let codec: String
    let codecLongName: String?
    let sampleRate: Int?
    let channels: Int
    let channelLayout: String?
    let bitRate: Int64?
    let isDefault: Bool
    let isForced: Bool
    let title: String?
    let language: String?
    let languageConfidence: LanguageConfidence

    var id: Int { index }

    var channelDescription: String {
        if let layout = channelLayout {
            return layout
        }
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }

    var isCommentary: Bool {
        guard let title = title?.lowercased() else { return false }
        return title.contains("commentary") || title.contains("comment")
    }
}

struct SubtitleStreamInfo: Codable, Equatable, Sendable, Identifiable {
    let index: Int
    let codec: String
    let codecLongName: String?
    let isDefault: Bool
    let isForced: Bool
    let title: String?
    let language: String?
    let languageConfidence: LanguageConfidence

    var id: Int { index }

    var isImageBased: Bool {
        let imageCodecs: Set<String> = ["hdmv_pgs_subtitle", "dvd_subtitle", "dvb_subtitle", "pgssub", "vobsub"]
        return imageCodecs.contains(codec.lowercased())
    }

    var isSDH: Bool {
        guard let title = title?.lowercased() else { return false }
        return title.contains("sdh") ||
               title.contains("hearing impaired") ||
               title.contains("hard of hearing")
    }

    var isCommentary: Bool {
        guard let title = title?.lowercased() else { return false }
        return title.contains("commentary") || title.contains("comment")
    }
}

// MARK: - Planned Action

/// An action the processing pipeline will take on a specific stream or file.
enum PlannedAction: Codable, Equatable, Sendable, Identifiable {
    case keepStream(index: Int, reason: String)
    case removeStream(index: Int, reason: String)
    case remuxContainer(from: String, to: String)
    case copyStream(index: Int)
    case transcodeVideo(index: Int, codec: String, preset: String, crf: Int)
    case transcodeAudio(index: Int, codec: String, channels: Int, bitrate: Int)

    var id: String {
        switch self {
        case .keepStream(let idx, _): return "keep-\(idx)"
        case .removeStream(let idx, _): return "remove-\(idx)"
        case .remuxContainer(let from, let to): return "remux-\(from)-\(to)"
        case .copyStream(let idx): return "copy-\(idx)"
        case .transcodeVideo(let idx, _, _, _): return "transcode-v-\(idx)"
        case .transcodeAudio(let idx, _, _, _): return "transcode-a-\(idx)"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .removeStream: return true
        case .transcodeVideo, .transcodeAudio: return true
        default: return false
        }
    }

    var displayDescription: String {
        switch self {
        case .keepStream(let idx, let reason):
            return "Keep stream \(idx): \(reason)"
        case .removeStream(let idx, let reason):
            return "Remove stream \(idx): \(reason)"
        case .remuxContainer(let from, let to):
            return "Remux container: \(from) → \(to)"
        case .copyStream(let idx):
            return "Copy stream \(idx)"
        case .transcodeVideo(let idx, let codec, let preset, let crf):
            return "Transcode video stream \(idx): \(codec), preset=\(preset), crf=\(crf)"
        case .transcodeAudio(let idx, let codec, let channels, let bitrate):
            return "Transcode audio stream \(idx): \(codec), \(channels)ch, \(bitrate)kbps"
        }
    }
}

// MARK: - File Analysis Result

/// Complete analysis result for a single file, combining probe data and planned actions.
struct FileAnalysisResult: Codable, Equatable, Sendable {
    let mediaInfo: MediaInfo
    let actions: [PlannedAction]
    let estimatedSavingsBytes: Int64?
    let requiresProcessing: Bool
    let warnings: [String]

    var removedStreamCount: Int {
        actions.filter { if case .removeStream = $0 { return true }; return false }.count
    }

    var keptStreamCount: Int {
        actions.filter { if case .keepStream = $0 { return true }; return false }.count
    }
}
