import Foundation

// MARK: - Job Status

enum JobStatus: String, Codable, CaseIterable {
    case pending
    case scanning
    case analyzing
    case reviewing
    case processing
    case completed
    case failed
    case cancelled
    case paused

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }

    var isActive: Bool {
        switch self {
        case .scanning, .analyzing, .processing:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .scanning: return "magnifyingglass"
        case .analyzing: return "waveform"
        case .reviewing: return "eye"
        case .processing: return "gearshape.2"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}

// MARK: - File Status

enum FileStatus: String, Codable, CaseIterable {
    case pending
    case analyzing
    case analyzed
    case queued
    case processing
    case validating
    case completed
    case failed
    case skipped

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .analyzing: return "magnifyingglass"
        case .analyzed: return "checkmark.diamond"
        case .queued: return "tray.full"
        case .processing: return "gearshape"
        case .validating: return "checkmark.shield"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }
}

// MARK: - Language Confidence

enum LanguageConfidence: String, Codable, CaseIterable, Comparable {
    case high       // BCP-47 or ISO 639 tag present and recognized
    case medium     // title contains a language name
    case low        // tag present but unrecognized or suspicious
    case unknown    // no tag, no title, no info

    private var sortOrder: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .unknown: return 0
        }
    }

    static func < (lhs: LanguageConfidence, rhs: LanguageConfidence) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Stream Type

enum StreamType: String, Codable {
    case video
    case audio
    case subtitle
    case attachment
    case data
}

// MARK: - Overwrite Behavior

enum OverwriteBehavior: String, Codable, CaseIterable {
    case confirmEach
    case confirmOnce
    case alwaysOverwrite
    case neverOverwrite

    var displayName: String {
        switch self {
        case .confirmEach: return "Confirm each file"
        case .confirmOnce: return "Confirm once per job"
        case .alwaysOverwrite: return "Always overwrite"
        case .neverOverwrite: return "Never overwrite (save alongside)"
        }
    }
}

// MARK: - Jellyfin Profile

enum JellyfinProfile: String, Codable, CaseIterable {
    case broad          // Maximum compatibility (H.264 + AAC)
    case modern         // Modern devices (H.265 + AAC/EAC3)
    case remuxOnly      // Only remux container, never transcode

    var displayName: String {
        switch self {
        case .broad: return "Broad Compatibility (H.264 + AAC)"
        case .modern: return "Modern Devices (H.265 + AAC/EAC3)"
        case .remuxOnly: return "Remux Only (no transcoding)"
        }
    }

    var targetVideoCodecs: [String] {
        switch self {
        case .broad: return ["h264"]
        case .modern: return ["h264", "hevc"]
        case .remuxOnly: return [] // accept anything
        }
    }

    var targetAudioCodecs: [String] {
        switch self {
        case .broad: return ["aac", "ac3"]
        case .modern: return ["aac", "ac3", "eac3"]
        case .remuxOnly: return [] // accept anything
        }
    }

    var targetContainers: [String] {
        switch self {
        case .broad: return ["mp4", "mkv"]
        case .modern: return ["mp4", "mkv"]
        case .remuxOnly: return ["mkv"]
        }
    }
}

// MARK: - Processing Mode

enum ProcessingMode: String, Codable, CaseIterable {
    case removeSubtitlesOnly
    case removeAudioOnly
    case removeBoth
    case jellyfinOptimize

    var displayName: String {
        switch self {
        case .removeSubtitlesOnly: return "Remove non-English subtitles only"
        case .removeAudioOnly: return "Remove non-English audio only"
        case .removeBoth: return "Remove non-English subtitles and audio"
        case .jellyfinOptimize: return "Optimize for Jellyfin direct play"
        }
    }

    var removesSubtitles: Bool {
        switch self {
        case .removeSubtitlesOnly, .removeBoth, .jellyfinOptimize: return true
        case .removeAudioOnly: return false
        }
    }

    var removesAudio: Bool {
        switch self {
        case .removeAudioOnly, .removeBoth, .jellyfinOptimize: return true
        case .removeSubtitlesOnly: return false
        }
    }
}

// MARK: - Tool Type

enum ToolType: String, Codable, CaseIterable {
    case ffmpeg
    case ffprobe
    case mkvmerge

    var binaryName: String { rawValue }

    var displayName: String {
        switch self {
        case .ffmpeg: return "FFmpeg"
        case .ffprobe: return "FFprobe"
        case .mkvmerge: return "MKVmerge"
        }
    }
}

// MARK: - Supported Video Extensions

enum VideoExtension: String, CaseIterable {
    case mkv
    case mp4
    case m4v
    case avi
    case mov
    case ts
    case m2ts

    static var allExtensionStrings: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}
