import Foundation

// MARK: - AnalysisEngine

/// Analyzes media files and produces planned actions based on settings.
/// This is the decision engine that determines what to do with each stream.
struct AnalysisEngine: Sendable {

    /// Analyze a single file's media info and produce planned actions.
    func analyze(mediaInfo: MediaInfo, settings: JobSettings) -> FileAnalysisResult {
        var actions: [PlannedAction] = []
        var warnings: [String] = []

        // Process video streams — always keep
        for stream in mediaInfo.videoStreams {
            actions.append(.keepStream(index: stream.index, reason: "Video stream"))
        }

        // Process audio streams
        if settings.removeAudio {
            let audioActions = analyzeAudioStreams(
                streams: mediaInfo.audioStreams,
                settings: settings,
                warnings: &warnings
            )
            actions.append(contentsOf: audioActions)
        } else {
            for stream in mediaInfo.audioStreams {
                actions.append(.keepStream(index: stream.index, reason: "Audio removal disabled"))
            }
        }

        // Process subtitle streams
        if settings.removeSubtitles {
            let subActions = analyzeSubtitleStreams(
                streams: mediaInfo.subtitleStreams,
                settings: settings,
                warnings: &warnings
            )
            actions.append(contentsOf: subActions)
        } else {
            for stream in mediaInfo.subtitleStreams {
                actions.append(.keepStream(index: stream.index, reason: "Subtitle removal disabled"))
            }
        }

        let requiresProcessing = actions.contains { $0.isDestructive }
        let removedCount = actions.filter {
            if case .removeStream = $0 { return true }
            return false
        }.count

        // Estimate savings (rough: proportional to stream count removed)
        let estimatedSavings: Int64? = removedCount > 0 ? estimateSavings(
            mediaInfo: mediaInfo,
            actions: actions
        ) : nil

        return FileAnalysisResult(
            mediaInfo: mediaInfo,
            actions: actions,
            estimatedSavingsBytes: estimatedSavings,
            requiresProcessing: requiresProcessing,
            warnings: warnings
        )
    }

    // MARK: - Audio Analysis

    private func analyzeAudioStreams(
        streams: [AudioStreamInfo],
        settings: JobSettings,
        warnings: inout [String]
    ) -> [PlannedAction] {
        var actions: [PlannedAction] = []
        let englishStreams = streams.filter { isKeptLanguage($0.language, settings: settings) }

        // Safety: never remove ALL audio tracks
        if englishStreams.isEmpty && !streams.isEmpty {
            warnings.append("No English audio tracks found — keeping all audio to avoid silent output")
            return streams.map { .keepStream(index: $0.index, reason: "No English audio found, keeping all") }
        }

        for stream in streams {
            if isKeptLanguage(stream.language, settings: settings) {
                actions.append(.keepStream(index: stream.index, reason: "Language matches keep list"))
            } else if stream.languageConfidence < .high && settings.conservativeMode {
                warnings.append("Audio stream \(stream.index): ambiguous language '\(stream.language ?? "unknown")' — keeping (conservative mode)")
                actions.append(.keepStream(index: stream.index, reason: "Ambiguous language (conservative mode)"))
            } else if settings.preserveCommentary && stream.isCommentary {
                actions.append(.keepStream(index: stream.index, reason: "Commentary track preserved"))
            } else if stream.languageConfidence == .unknown && settings.conservativeMode {
                warnings.append("Audio stream \(stream.index): no language tag — keeping (conservative mode)")
                actions.append(.keepStream(index: stream.index, reason: "No language tag (conservative mode)"))
            } else {
                actions.append(.removeStream(
                    index: stream.index,
                    reason: "Non-English audio (\(stream.language ?? "unknown"), confidence: \(stream.languageConfidence.rawValue))"
                ))
            }
        }

        return actions
    }

    // MARK: - Subtitle Analysis

    private func analyzeSubtitleStreams(
        streams: [SubtitleStreamInfo],
        settings: JobSettings,
        warnings: inout [String]
    ) -> [PlannedAction] {
        var actions: [PlannedAction] = []

        for stream in streams {
            // Always preserve forced English subtitles
            if settings.preserveForced && stream.isForced && isKeptLanguage(stream.language, settings: settings) {
                actions.append(.keepStream(index: stream.index, reason: "Forced English subtitle"))
                continue
            }

            // Preserve SDH if requested
            if settings.preserveSDH && stream.isSDH && isKeptLanguage(stream.language, settings: settings) {
                actions.append(.keepStream(index: stream.index, reason: "SDH subtitle preserved"))
                continue
            }

            // Preserve commentary if requested
            if settings.preserveCommentary && stream.isCommentary {
                actions.append(.keepStream(index: stream.index, reason: "Commentary subtitle preserved"))
                continue
            }

            // Keep if language matches
            if isKeptLanguage(stream.language, settings: settings) {
                actions.append(.keepStream(index: stream.index, reason: "Language matches keep list"))
                continue
            }

            // Conservative mode: keep ambiguous
            if settings.conservativeMode && stream.languageConfidence < .high {
                let reason: String
                if stream.languageConfidence == .unknown {
                    reason = "No language tag (conservative mode)"
                } else {
                    reason = "Ambiguous language (conservative mode)"
                }
                warnings.append("Subtitle stream \(stream.index): \(reason)")
                actions.append(.keepStream(index: stream.index, reason: reason))
                continue
            }

            // Remove
            actions.append(.removeStream(
                index: stream.index,
                reason: "Non-English subtitle (\(stream.language ?? "unknown"), confidence: \(stream.languageConfidence.rawValue))"
            ))
        }

        return actions
    }

    // MARK: - Language Matching

    private func isKeptLanguage(_ language: String?, settings: JobSettings) -> Bool {
        guard let lang = language?.lowercased() else { return false }

        for keepLang in settings.keepLanguages {
            let keep = keepLang.lowercased()
            // Match various English codes: eng, en, english
            if lang == keep { return true }
            if lang.hasPrefix(keep) { return true }
            if keep == "eng" && (lang == "en" || lang == "english") { return true }
            if keep == "en" && (lang == "eng" || lang == "english") { return true }
        }
        return false
    }

    // MARK: - Savings Estimation

    private func estimateSavings(mediaInfo: MediaInfo, actions: [PlannedAction]) -> Int64 {
        var estimatedBytes: Int64 = 0
        let totalStreams = mediaInfo.totalStreamCount

        guard totalStreams > 0 else { return 0 }

        for action in actions {
            if case .removeStream(let index, _) = action {
                // Check audio streams for bitrate info
                if let audioStream = mediaInfo.audioStreams.first(where: { $0.index == index }),
                   let bitRate = audioStream.bitRate,
                   mediaInfo.duration > 0 {
                    estimatedBytes += Int64(Double(bitRate) * mediaInfo.duration / 8)
                }
                // For subtitles, estimate small savings
                else if mediaInfo.subtitleStreams.contains(where: { $0.index == index }) {
                    // Subtitle tracks are typically small (1-10MB) unless image-based
                    let sub = mediaInfo.subtitleStreams.first { $0.index == index }
                    estimatedBytes += sub?.isImageBased == true ? 50_000_000 : 500_000
                }
                // Fallback: proportional estimate
                else {
                    estimatedBytes += mediaInfo.fileSize / Int64(totalStreams)
                }
            }
        }

        return estimatedBytes
    }
}
