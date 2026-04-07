import Foundation

// MARK: - ProcessResult

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let command: String
    let duration: TimeInterval

    var succeeded: Bool { exitCode == 0 }
}

// MARK: - ProcessError

enum ProcessError: LocalizedError, Sendable {
    case toolNotFound(String)
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    case timeout(command: String, seconds: TimeInterval)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "Tool not found: \(tool)"
        case .executionFailed(let cmd, let code, let stderr):
            return "Command failed (exit \(code)): \(cmd)\n\(stderr)"
        case .timeout(let cmd, let seconds):
            return "Command timed out after \(Int(seconds))s: \(cmd)"
        case .cancelled:
            return "Process was cancelled"
        }
    }
}

// MARK: - ProcessRunner

/// Runs external processes (ffmpeg, ffprobe, mkvmerge).
/// Uses nonisolated methods for Process execution to avoid Sendable issues.
final class ProcessRunner: Sendable {

    /// Run a command and return the result.
    func run(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 3600
    ) async throws -> ProcessResult {
        let commandString = ([executablePath] + arguments).joined(separator: " ")
        let startTime = Date()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            if let environment {
                var env = ProcessInfo.processInfo.environment
                env.merge(environment) { _, new in new }
                process.environment = env
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Use a flag to prevent double-resume
            let resumed = ManagedAtomic(false)

            // Timeout via DispatchQueue (avoids actor isolation issues)
            let timeoutItem = DispatchWorkItem { [weak process] in
                process?.terminate()
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout,
                execute: timeoutItem
            )

            process.terminationHandler = { _ in
                timeoutItem.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let duration = Date().timeIntervalSince(startTime)

                let result = ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr,
                    command: commandString,
                    duration: duration
                )

                if resumed.exchange(true) == false {
                    continuation.resume(returning: result)
                }
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                process.terminationHandler = nil
                if resumed.exchange(true) == false {
                    continuation.resume(throwing: ProcessError.toolNotFound(executablePath))
                }
            }
        }
    }
}

// MARK: - ProcessRunner + Convenience

extension ProcessRunner {
    /// Run and throw on non-zero exit code.
    func runOrThrow(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 3600
    ) async throws -> ProcessResult {
        let result = try await run(
            executablePath: executablePath,
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
        guard result.succeeded else {
            throw ProcessError.executionFailed(
                command: result.command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result
    }
}

// MARK: - Simple Atomic Bool (lock-based, no external deps)

private final class ManagedAtomic<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func exchange(_ newValue: T) -> T {
        lock.lock()
        defer { lock.unlock() }
        let old = value
        value = newValue
        return old
    }
}
