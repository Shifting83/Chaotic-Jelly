import XCTest
@testable import ChaoticJelly

final class FFprobeParsingTests: XCTestCase {

    // MARK: - Test Fixtures

    static let sampleProbeJSON = """
    {
        "streams": [
            {
                "index": 0,
                "codec_name": "h264",
                "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
                "codec_type": "video",
                "profile": "High",
                "width": 1920,
                "height": 1080,
                "r_frame_rate": "24000/1001",
                "pix_fmt": "yuv420p",
                "disposition": { "default": 1, "forced": 0 },
                "tags": { "language": "eng", "title": "Main Video" }
            },
            {
                "index": 1,
                "codec_name": "aac",
                "codec_long_name": "AAC (Advanced Audio Coding)",
                "codec_type": "audio",
                "channels": 6,
                "channel_layout": "5.1",
                "sample_rate": "48000",
                "bit_rate": "384000",
                "disposition": { "default": 1, "forced": 0 },
                "tags": { "language": "eng", "title": "English 5.1" }
            },
            {
                "index": 2,
                "codec_name": "aac",
                "codec_long_name": "AAC (Advanced Audio Coding)",
                "codec_type": "audio",
                "channels": 2,
                "channel_layout": "stereo",
                "sample_rate": "48000",
                "bit_rate": "128000",
                "disposition": { "default": 0, "forced": 0 },
                "tags": { "language": "fre", "title": "French Stereo" }
            },
            {
                "index": 3,
                "codec_name": "subrip",
                "codec_long_name": "SubRip subtitle",
                "codec_type": "subtitle",
                "disposition": { "default": 0, "forced": 0 },
                "tags": { "language": "eng", "title": "English" }
            },
            {
                "index": 4,
                "codec_name": "subrip",
                "codec_long_name": "SubRip subtitle",
                "codec_type": "subtitle",
                "disposition": { "default": 0, "forced": 1 },
                "tags": { "language": "eng", "title": "English (Forced)" }
            },
            {
                "index": 5,
                "codec_name": "subrip",
                "codec_long_name": "SubRip subtitle",
                "codec_type": "subtitle",
                "disposition": { "default": 0, "forced": 0 },
                "tags": { "language": "spa", "title": "Spanish" }
            },
            {
                "index": 6,
                "codec_name": "subrip",
                "codec_long_name": "SubRip subtitle",
                "codec_type": "subtitle",
                "disposition": { "default": 0, "forced": 0 },
                "tags": { "language": "ger", "title": "German" }
            }
        ],
        "format": {
            "filename": "/path/to/movie.mkv",
            "format_name": "matroska,webm",
            "format_long_name": "Matroska / WebM",
            "duration": "7200.000000",
            "size": "5368709120",
            "bit_rate": "5965232"
        }
    }
    """

    // MARK: - Tests

    func testParseBasicMediaInfo() throws {
        let logger = LoggingService()
        let processRunner = ProcessRunner()
        let settings = AppSettings()
        let toolLocator = ToolLocator(settings: settings)
        let service = FFprobeService(processRunner: processRunner, toolLocator: toolLocator, logger: logger)

        // We need to test parseProbeOutput which is on the actor — call from async context
        let expectation = expectation(description: "parse")
        Task {
            do {
                let info = try await service.parseProbeOutput(json: Self.sampleProbeJSON, filePath: "/path/to/movie.mkv")

                XCTAssertEqual(info.container, "matroska,webm")
                XCTAssertEqual(info.duration, 7200.0)
                XCTAssertEqual(info.fileSize, 5368709120)

                XCTAssertEqual(info.videoStreams.count, 1)
                XCTAssertEqual(info.audioStreams.count, 2)
                XCTAssertEqual(info.subtitleStreams.count, 4)

                expectation.fulfill()
            } catch {
                XCTFail("Parse failed: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
    }

    func testParseVideoStream() throws {
        let expectation = expectation(description: "parse")
        Task {
            let info = try await parseFixture()

            let video = info.videoStreams[0]
            XCTAssertEqual(video.index, 0)
            XCTAssertEqual(video.codec, "h264")
            XCTAssertEqual(video.width, 1920)
            XCTAssertEqual(video.height, 1080)
            XCTAssertEqual(video.resolution, "1920x1080")
            XCTAssertEqual(video.language, "eng")
            XCTAssertEqual(video.languageConfidence, .high)
            XCTAssertTrue(video.isDefault)

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testParseAudioStreams() throws {
        let expectation = expectation(description: "parse")
        Task {
            let info = try await parseFixture()

            let engAudio = info.audioStreams[0]
            XCTAssertEqual(engAudio.language, "eng")
            XCTAssertEqual(engAudio.channels, 6)
            XCTAssertEqual(engAudio.channelDescription, "5.1")
            XCTAssertEqual(engAudio.languageConfidence, .high)

            let freAudio = info.audioStreams[1]
            XCTAssertEqual(freAudio.language, "fre")
            XCTAssertEqual(freAudio.channels, 2)
            XCTAssertEqual(freAudio.languageConfidence, .high)
            XCTAssertFalse(freAudio.isDefault)

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testParseSubtitleStreams() throws {
        let expectation = expectation(description: "parse")
        Task {
            let info = try await parseFixture()

            // English subtitle
            let engSub = info.subtitleStreams[0]
            XCTAssertEqual(engSub.language, "eng")
            XCTAssertFalse(engSub.isForced)

            // Forced English subtitle
            let forcedSub = info.subtitleStreams[1]
            XCTAssertEqual(forcedSub.language, "eng")
            XCTAssertTrue(forcedSub.isForced)

            // Spanish subtitle
            let spaSub = info.subtitleStreams[2]
            XCTAssertEqual(spaSub.language, "spa")

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testParseEmptyJSON() throws {
        let expectation = expectation(description: "parse")
        Task {
            let service = makeService()
            do {
                _ = try await service.parseProbeOutput(json: "{}", filePath: "/test")
                XCTFail("Should have thrown")
            } catch {
                // Expected — missing format key
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testParseInvalidJSON() throws {
        let expectation = expectation(description: "parse")
        Task {
            let service = makeService()
            do {
                _ = try await service.parseProbeOutput(json: "not json", filePath: "/test")
                XCTFail("Should have thrown")
            } catch {
                // Expected
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - Helpers

    private func makeService() -> FFprobeService {
        let logger = LoggingService()
        let processRunner = ProcessRunner()
        let settings = AppSettings()
        let toolLocator = ToolLocator(settings: settings)
        return FFprobeService(processRunner: processRunner, toolLocator: toolLocator, logger: logger)
    }

    private func parseFixture() async throws -> MediaInfo {
        let service = makeService()
        return try await service.parseProbeOutput(json: Self.sampleProbeJSON, filePath: "/path/to/movie.mkv")
    }
}
