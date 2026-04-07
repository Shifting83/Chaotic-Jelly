import XCTest
@testable import ChaoticJelly

final class AnalysisEngineTests: XCTestCase {
    let engine = AnalysisEngine()

    // MARK: - Default Settings (remove subs, keep audio)

    func testRemoveNonEnglishSubtitles() {
        let settings = makeSettings(removeSubtitles: true, removeAudio: false)
        let mediaInfo = makeMediaInfo(
            subtitles: [
                makeSub(index: 3, lang: "eng"),
                makeSub(index: 4, lang: "spa"),
                makeSub(index: 5, lang: "ger")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        // Video should be kept
        let videoActions = result.actions.filter { $0.id.hasPrefix("keep-0") }
        XCTAssertEqual(videoActions.count, 1)

        // English sub kept, Spanish and German removed
        let keepSubs = result.actions.filter { if case .keepStream(3, _) = $0 { return true }; return false }
        XCTAssertEqual(keepSubs.count, 1)

        let removeSubs = result.actions.filter {
            if case .removeStream(let idx, _) = $0 { return idx == 4 || idx == 5 }
            return false
        }
        XCTAssertEqual(removeSubs.count, 2)

        XCTAssertTrue(result.requiresProcessing)
    }

    func testKeepAllAudioWhenRemovalDisabled() {
        let settings = makeSettings(removeSubtitles: false, removeAudio: false)
        let mediaInfo = makeMediaInfo(
            audio: [
                makeAudio(index: 1, lang: "eng"),
                makeAudio(index: 2, lang: "fre")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        let audioKeeps = result.actions.filter {
            if case .keepStream(let idx, _) = $0 { return idx == 1 || idx == 2 }
            return false
        }
        XCTAssertEqual(audioKeeps.count, 2)
        XCTAssertFalse(result.requiresProcessing)
    }

    // MARK: - Audio Removal

    func testRemoveNonEnglishAudio() {
        let settings = makeSettings(removeSubtitles: false, removeAudio: true)
        let mediaInfo = makeMediaInfo(
            audio: [
                makeAudio(index: 1, lang: "eng"),
                makeAudio(index: 2, lang: "fre"),
                makeAudio(index: 3, lang: "ger")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        let keeps = result.actions.filter { if case .keepStream(1, _) = $0 { return true }; return false }
        XCTAssertEqual(keeps.count, 1)

        let removes = result.actions.filter {
            if case .removeStream(let idx, _) = $0 { return idx == 2 || idx == 3 }
            return false
        }
        XCTAssertEqual(removes.count, 2)
    }

    func testNeverRemoveAllAudioTracks() {
        let settings = makeSettings(removeSubtitles: false, removeAudio: true)
        let mediaInfo = makeMediaInfo(
            audio: [
                makeAudio(index: 1, lang: "fre"),
                makeAudio(index: 2, lang: "ger")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        // Should keep all audio since no English track exists
        let removes = result.actions.filter { if case .removeStream = $0 { return true }; return false }
        XCTAssertEqual(removes.count, 0, "Should not remove all audio tracks")

        XCTAssertFalse(result.warnings.isEmpty, "Should generate a warning")
    }

    // MARK: - Conservative Mode

    func testConservativeModeKeepsAmbiguousStreams() {
        let settings = makeSettings(removeSubtitles: true, removeAudio: true, conservative: true)
        let mediaInfo = makeMediaInfo(
            audio: [
                makeAudio(index: 1, lang: "eng"),
                makeAudio(index: 2, lang: nil)  // no language tag
            ],
            subtitles: [
                makeSub(index: 3, lang: nil)  // no language tag
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        // Ambiguous streams should be kept in conservative mode
        let keeps = result.actions.filter {
            if case .keepStream(let idx, _) = $0 { return idx == 2 || idx == 3 }
            return false
        }
        XCTAssertEqual(keeps.count, 2)
    }

    func testNonConservativeModeRemovesUnknownLanguage() {
        let settings = makeSettings(removeSubtitles: true, removeAudio: false, conservative: false)
        let mediaInfo = makeMediaInfo(
            subtitles: [
                makeSub(index: 3, lang: "eng"),
                makeSub(index: 4, lang: nil)  // unknown
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        let removes = result.actions.filter { if case .removeStream(4, _) = $0 { return true }; return false }
        XCTAssertEqual(removes.count, 1, "Non-conservative should remove unknown language subtitles")
    }

    // MARK: - Forced Subtitles

    func testPreservesForcedEnglishSubtitles() {
        let settings = makeSettings(removeSubtitles: true, preserveForced: true)
        let mediaInfo = makeMediaInfo(
            subtitles: [
                makeSub(index: 3, lang: "eng", forced: true),
                makeSub(index: 4, lang: "spa")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        let forcedKeep = result.actions.filter { if case .keepStream(3, _) = $0 { return true }; return false }
        XCTAssertEqual(forcedKeep.count, 1)

        let spaRemove = result.actions.filter { if case .removeStream(4, _) = $0 { return true }; return false }
        XCTAssertEqual(spaRemove.count, 1)
    }

    // MARK: - Commentary

    func testPreservesCommentaryWhenEnabled() {
        let settings = makeSettings(removeSubtitles: false, removeAudio: true, preserveCommentary: true)
        let mediaInfo = makeMediaInfo(
            audio: [
                makeAudio(index: 1, lang: "eng"),
                makeAudio(index: 2, lang: "eng", title: "Director's Commentary")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        let keeps = result.actions.filter {
            if case .keepStream(let idx, _) = $0 { return idx == 1 || idx == 2 }
            return false
        }
        XCTAssertEqual(keeps.count, 2)
    }

    // MARK: - Skip Processing

    func testSkipsAlreadyOptimizedFile() {
        let settings = makeSettings(removeSubtitles: true, removeAudio: false)
        let mediaInfo = makeMediaInfo(
            audio: [makeAudio(index: 1, lang: "eng")],
            subtitles: [makeSub(index: 2, lang: "eng")]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)
        XCTAssertFalse(result.requiresProcessing, "File with only English tracks should not need processing")
    }

    // MARK: - Multiple Keep Languages

    func testMultipleKeepLanguages() {
        let settings = JobSettings(
            keepLanguages: ["eng", "spa"],
            removeSubtitles: true,
            removeAudio: false,
            conservativeMode: true,
            preserveForced: true,
            preserveSDH: false,
            preserveCommentary: false,
            optimizeForJellyfin: false,
            jellyfinProfile: .broad,
            createBackup: true,
            dryRun: false
        )

        let mediaInfo = makeMediaInfo(
            subtitles: [
                makeSub(index: 3, lang: "eng"),
                makeSub(index: 4, lang: "spa"),
                makeSub(index: 5, lang: "ger")
            ]
        )

        let result = engine.analyze(mediaInfo: mediaInfo, settings: settings)

        // English and Spanish kept, German removed
        let keeps = result.actions.filter {
            if case .keepStream(let idx, _) = $0 { return idx == 3 || idx == 4 }
            return false
        }
        XCTAssertEqual(keeps.count, 2)

        let removes = result.actions.filter { if case .removeStream(5, _) = $0 { return true }; return false }
        XCTAssertEqual(removes.count, 1)
    }

    // MARK: - Helpers

    private func makeSettings(
        removeSubtitles: Bool = true,
        removeAudio: Bool = false,
        conservative: Bool = true,
        preserveForced: Bool = true,
        preserveCommentary: Bool = false
    ) -> JobSettings {
        JobSettings(
            keepLanguages: ["eng"],
            removeSubtitles: removeSubtitles,
            removeAudio: removeAudio,
            conservativeMode: conservative,
            preserveForced: preserveForced,
            preserveSDH: false,
            preserveCommentary: preserveCommentary,
            optimizeForJellyfin: false,
            jellyfinProfile: .broad,
            createBackup: true,
            dryRun: false
        )
    }

    private func makeMediaInfo(
        audio: [AudioStreamInfo] = [makeAudio(index: 1, lang: "eng")],
        subtitles: [SubtitleStreamInfo] = []
    ) -> MediaInfo {
        MediaInfo(
            container: "matroska",
            duration: 7200,
            bitRate: 5_000_000,
            fileSize: 5_368_709_120,
            videoStreams: [
                VideoStreamInfo(
                    index: 0, codec: "h264", codecLongName: nil, profile: "High",
                    width: 1920, height: 1080, frameRate: 23.976, bitRate: 4_000_000,
                    pixelFormat: "yuv420p", isDefault: true, title: nil,
                    language: "eng", languageConfidence: .high
                )
            ],
            audioStreams: audio,
            subtitleStreams: subtitles
        )
    }

    private static func makeAudio(index: Int, lang: String?, title: String? = nil) -> AudioStreamInfo {
        AudioStreamInfo(
            index: index, codec: "aac", codecLongName: nil,
            sampleRate: 48000, channels: 2, channelLayout: "stereo",
            bitRate: 128000, isDefault: index == 1, isForced: false,
            title: title, language: lang,
            languageConfidence: lang != nil ? .high : .unknown
        )
    }

    private func makeAudio(index: Int, lang: String?, title: String? = nil) -> AudioStreamInfo {
        Self.makeAudio(index: index, lang: lang, title: title)
    }

    private static func makeSub(index: Int, lang: String?, forced: Bool = false) -> SubtitleStreamInfo {
        SubtitleStreamInfo(
            index: index, codec: "subrip", codecLongName: nil,
            isDefault: false, isForced: forced, title: nil,
            language: lang,
            languageConfidence: lang != nil ? .high : .unknown
        )
    }

    private func makeSub(index: Int, lang: String?, forced: Bool = false) -> SubtitleStreamInfo {
        Self.makeSub(index: index, lang: lang, forced: forced)
    }
}
