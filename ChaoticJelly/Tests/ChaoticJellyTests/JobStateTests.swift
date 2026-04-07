import XCTest
@testable import ChaoticJelly

final class JobStateTests: XCTestCase {

    // MARK: - Job State Transitions

    func testValidJobTransitions() {
        let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)

        XCTAssertTrue(job.canTransition(to: .scanning))
        XCTAssertTrue(job.transition(to: .scanning))
        XCTAssertEqual(job.jobStatus, .scanning)
        XCTAssertNotNil(job.startedAt)

        XCTAssertTrue(job.canTransition(to: .analyzing))
        XCTAssertTrue(job.transition(to: .analyzing))
        XCTAssertEqual(job.jobStatus, .analyzing)

        XCTAssertTrue(job.canTransition(to: .reviewing))
        XCTAssertTrue(job.transition(to: .reviewing))

        XCTAssertTrue(job.canTransition(to: .processing))
        XCTAssertTrue(job.transition(to: .processing))

        XCTAssertTrue(job.canTransition(to: .completed))
        XCTAssertTrue(job.transition(to: .completed))
        XCTAssertEqual(job.jobStatus, .completed)
        XCTAssertNotNil(job.completedAt)
    }

    func testInvalidJobTransitions() {
        let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)

        // Can't go directly to processing from pending
        XCTAssertFalse(job.canTransition(to: .processing))
        XCTAssertFalse(job.transition(to: .processing))
        XCTAssertEqual(job.jobStatus, .pending)

        // Can't go directly to completed from pending
        XCTAssertFalse(job.canTransition(to: .completed))

        // Can't go directly to reviewing from pending
        XCTAssertFalse(job.canTransition(to: .reviewing))
    }

    func testCancellationFromAnyState() {
        let states: [JobStatus] = [.pending, .scanning, .analyzing, .reviewing, .processing]

        for state in states {
            let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)
            job.status = state.rawValue

            XCTAssertTrue(job.canTransition(to: .cancelled), "Should be able to cancel from \(state)")
            XCTAssertTrue(job.transition(to: .cancelled))
            XCTAssertEqual(job.jobStatus, .cancelled)
        }
    }

    func testFailureFromAnyState() {
        let states: [JobStatus] = [.pending, .scanning, .analyzing, .processing]

        for state in states {
            let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)
            job.status = state.rawValue

            XCTAssertTrue(job.canTransition(to: .failed), "Should be able to fail from \(state)")
        }
    }

    func testPauseAndResume() {
        let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)
        job.status = JobStatus.processing.rawValue

        XCTAssertTrue(job.canTransition(to: .paused))
        XCTAssertTrue(job.transition(to: .paused))

        XCTAssertTrue(job.canTransition(to: .processing))
        XCTAssertTrue(job.transition(to: .processing))
    }

    func testTerminalStates() {
        XCTAssertTrue(JobStatus.completed.isTerminal)
        XCTAssertTrue(JobStatus.failed.isTerminal)
        XCTAssertTrue(JobStatus.cancelled.isTerminal)
        XCTAssertFalse(JobStatus.pending.isTerminal)
        XCTAssertFalse(JobStatus.processing.isTerminal)
    }

    // MARK: - FileEntry State Transitions

    func testValidFileTransitions() {
        let file = FileEntry(relativePath: "test.mkv", fileName: "test.mkv", fileExtension: "mkv", originalSize: 1000)

        XCTAssertTrue(file.canTransition(to: .analyzing))
        XCTAssertTrue(file.transition(to: .analyzing))

        XCTAssertTrue(file.canTransition(to: .analyzed))
        XCTAssertTrue(file.transition(to: .analyzed))

        XCTAssertTrue(file.canTransition(to: .queued))
        XCTAssertTrue(file.transition(to: .queued))

        XCTAssertTrue(file.canTransition(to: .processing))
        XCTAssertTrue(file.transition(to: .processing))
        XCTAssertNotNil(file.startedAt)

        XCTAssertTrue(file.canTransition(to: .validating))
        XCTAssertTrue(file.transition(to: .validating))

        XCTAssertTrue(file.canTransition(to: .completed))
        XCTAssertTrue(file.transition(to: .completed))
        XCTAssertNotNil(file.completedAt)
    }

    func testFileSkipFromAnyState() {
        let file = FileEntry(relativePath: "test.mkv", fileName: "test.mkv", fileExtension: "mkv", originalSize: 1000)
        XCTAssertTrue(file.canTransition(to: .skipped))
        XCTAssertTrue(file.transition(to: .skipped))
    }

    func testFileFailFromAnyState() {
        let file = FileEntry(relativePath: "test.mkv", fileName: "test.mkv", fileExtension: "mkv", originalSize: 1000)
        XCTAssertTrue(file.canTransition(to: .failed))
    }

    // MARK: - Job Computed Properties

    func testBytesSaved() {
        let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)
        job.totalBytesBefore = 10_000_000
        job.totalBytesAfter = 7_000_000

        XCTAssertEqual(job.bytesSaved, 3_000_000)
    }

    func testBytesSavedZeroWhenNoAfter() {
        let job = Job(sourceFolderPath: "/test", processingMode: .removeBoth)
        job.totalBytesBefore = 10_000_000
        job.totalBytesAfter = 0

        XCTAssertEqual(job.bytesSaved, 0)
    }

    func testFileSavingsPercent() {
        let file = FileEntry(relativePath: "test.mkv", fileName: "test.mkv", fileExtension: "mkv", originalSize: 1000)
        file.processedSize = 800

        XCTAssertEqual(file.savingsPercent, 20.0, accuracy: 0.01)
    }
}
