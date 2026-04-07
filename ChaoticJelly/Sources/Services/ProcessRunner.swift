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

enum ProcessError: LocalizedError {
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

/// Thread-safe wrapper around Foundation.Process for executing external tools.
actor ProcessRunner {
    private var runningProcesses: [UUID: Process] = [:]

    /// Run a command and return the result.
    func run(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 3600
    ) async throws -> ProcessResult {
        let processID = UUID()
        let commandString = ([executablePath] + arguments).joined(separator: " ")

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

        let startTime = Date()

        // Store for cancellation
        runningProcesses[processID] = process

        defer {
            runningProcesses[processID] = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Timeout task
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { [weak self] proc in
                timeoutTask.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let duration = Date().timeIntervalSince(startTime)

                let result = ProcessResult(
                    exitCode: proc.terminationStatus,
                    stdout: stdout,
                    stderr: stderr,
                    command: commandString,
                    duration: duration
                )

                Task { await self?.removeProcess(processID) }
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                Task { await self.removeProcess(processID) }
                continuation.resume(throwing: ProcessError.toolNotFound(executablePath))
            }
        }
    }

    /// Cancel a specific running process.
    func cancel(processID: UUID) {
        if let process = runningProcesses[processID], process.isRunning {
            process.terminate()
        }
    }

    /// Cancel all running processes.
    func cancelAll() {
        for (_, process) in runningProcesses where process.isRunning {
            process.terminate()
        }
        runningProcesses.removeAll()
    }

    private func removeProcess(_ id: UUID) {
        runningProcesses[id] = nil
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
