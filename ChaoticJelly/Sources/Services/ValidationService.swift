import Foundation

// MARK: - ValidationService

/// Validates processed video files to ensure integrity before replacing originals.
actor ValidationService {
    private let ffprobeService: FFprobeService
    private let logger: LoggingService

    /// Maximum allowed duration difference (in seconds) between original and processed file.
    private let maxDurationDifferenceSeconds: Double = 2.0

    init(ffprobeService: FFprobeService, logger: LoggingService) {
        self.ffprobeService = ffprobeService
        self.logger = logger
    }

    /// Validate a processed file against its original media info and planned actions.
    func validate(
        processedFileURL: URL,
        originalMediaInfo: MediaInfo,
        actions: [PlannedAction]
    ) async throws -> ValidationResult {
        var issues: [ValidationIssue] = []

        // 1. File exists and is non-empty
        guard FileManager.default.fileExists(atPath: processedFileURL.path) else {
            return .failure([.fileNotFound])
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: processedFileURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0
        if fileSize == 0 {
            return .failure([.emptyFile])
        }

        // 2. Probe the output
        let outputInfo: MediaInfo
        do {
            outputInfo = try await ffprobeService.probe(fileURL: processedFileURL)
        } catch {
            return .failure([.cannotProbe(error.localizedDescription)])
        }

        // 3. Duration check
        let durationDiff = abs(outputInfo.duration - originalMediaInfo.duration)
        if durationDiff > maxDurationDifferenceSeconds {
            issues.append(.durationMismatch(
                original: originalMediaInfo.duration,
                processed: outputInfo.duration,
                difference: durationDiff
            ))
        }

        // 4. Video stream check — must have at least the same number of video streams
        if outputInfo.videoStreams.count < originalMediaInfo.videoStreams.count {
            issues.append(.missingVideoStreams(
                expected: originalMediaInfo.videoStreams.count,
                found: outputInfo.videoStreams.count
            ))
        }

        // 5. Check removed streams are actually absent
        let removedIndices = Set(actions.compactMap { action -> Int? in
            if case .removeStream(let idx, _) = action { return idx }
            return nil
        })

        let expectedAudioCount = originalMediaInfo.audioStreams.filter {
            !removedIndices.contains($0.index)
        }.count

        let expectedSubCount = originalMediaInfo.subtitleStreams.filter {
            !removedIndices.contains($0.index)
        }.count

        // Audio count check
        if outputInfo.audioStreams.count != expectedAudioCount {
            issues.append(.unexpectedAudioStreamCount(
                expected: expectedAudioCount,
                found: outputInfo.audioStreams.count
            ))
        }

        // Subtitle count check (lenient — some codecs get dropped during remux)
        if outputInfo.subtitleStreams.count > expectedSubCount {
            issues.append(.unexpectedSubtitleStreamCount(
                expected: expectedSubCount,
                found: outputInfo.subtitleStreams.count
            ))
        }

        // 6. Must have at least one audio stream (safety)
        if outputInfo.audioStreams.isEmpty && !originalMediaInfo.audioStreams.isEmpty {
            issues.append(.noAudioStreams)
        }

        // 7. Classify issues
        let criticalIssues = issues.filter(\.isCritical)
        if !criticalIssues.isEmpty {
            await logger.logError("Validation FAILED for \(processedFileURL.lastPathComponent): \(criticalIssues.map(\.description).joined(separator: "; "))")
            return .failure(issues)
        }

        if !issues.isEmpty {
            await logger.logWarning("Validation passed with warnings for \(processedFileURL.lastPathComponent): \(issues.map(\.description).joined(separator: "; "))")
            return .passedWithWarnings(issues, outputInfo: outputInfo)
        }

        await logger.logDiagnostic("Validation passed for \(processedFileURL.lastPathComponent)")
        return .passed(outputInfo: outputInfo)
    }
}

// MARK: - Validation Types

enum ValidationResult {
    case passed(outputInfo: MediaInfo)
    case passedWithWarnings([ValidationIssue], outputInfo: MediaInfo)
    case failure([ValidationIssue])

    var isAcceptable: Bool {
        switch self {
        case .passed, .passedWithWarnings: return true
        case .failure: return false
        }
    }

    var outputInfo: MediaInfo? {
        switch self {
        case .passed(let info), .passedWithWarnings(_, let info): return info
        case .failure: return nil
        }
    }
}

enum ValidationIssue: CustomStringConvertible {
    case fileNotFound
    case emptyFile
    case cannotProbe(String)
    case durationMismatch(original: Double, processed: Double, difference: Double)
    case missingVideoStreams(expected: Int, found: Int)
    case unexpectedAudioStreamCount(expected: Int, found: Int)
    case unexpectedSubtitleStreamCount(expected: Int, found: Int)
    case noAudioStreams

    var isCritical: Bool {
        switch self {
        case .fileNotFound, .emptyFile, .cannotProbe, .missingVideoStreams, .noAudioStreams:
            return true
        case .durationMismatch(_, _, let diff):
            return diff > 5.0
        case .unexpectedAudioStreamCount, .unexpectedSubtitleStreamCount:
            return false
        }
    }

    var description: String {
        switch self {
        case .fileNotFound:
            return "Output file not found"
        case .emptyFile:
            return "Output file is empty"
        case .cannotProbe(let err):
            return "Cannot probe output: \(err)"
        case .durationMismatch(let orig, let proc, let diff):
            return String(format: "Duration mismatch: original=%.1fs, output=%.1fs (diff=%.1fs)", orig, proc, diff)
        case .missingVideoStreams(let expected, let found):
            return "Missing video streams: expected \(expected), found \(found)"
        case .unexpectedAudioStreamCount(let expected, let found):
            return "Audio stream count: expected \(expected), found \(found)"
        case .unexpectedSubtitleStreamCount(let expected, let found):
            return "Subtitle stream count: expected \(expected), found \(found)"
        case .noAudioStreams:
            return "No audio streams in output"
        }
    }
}
