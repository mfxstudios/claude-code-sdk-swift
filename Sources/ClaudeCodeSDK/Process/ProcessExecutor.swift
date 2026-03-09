//
//  ProcessExecutor.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Cross-platform process executor
public actor ProcessExecutor {
    private var currentProcess: Process?
    private var isCancelled = false

    public init() {}

    /// Executes a command and returns the output
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Arguments for the command
    ///   - workingDirectory: The working directory
    ///   - environment: Environment variables
    ///   - stdinData: Optional data to send to stdin
    ///   - timeout: Optional timeout in seconds
    /// - Returns: Tuple of (stdout, stderr, exit code)
    public func execute(
        command: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String],
        stdinData: Data? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> (stdout: Data, stderr: Data, exitCode: Int32) {
        isCancelled = false

        let process = Process()
        currentProcess = process

        // Configure the shell based on platform
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", buildCommandString(command: command, arguments: arguments)]
        #elseif os(Linux)
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", buildCommandString(command: command, arguments: arguments)]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", buildCommandString(command: command, arguments: arguments)]
        #endif

        // Set working directory
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        // Set environment
        process.environment = environment

        // Set up pipes
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        // Launch the process
        do {
            try process.run()
        } catch {
            currentProcess = nil
            throw ClaudeCodeError.processLaunchFailed(error.localizedDescription)
        }

        // Write stdin if provided
        if let stdinData = stdinData {
            stdinPipe.fileHandleForWriting.write(stdinData)
        }
        try? stdinPipe.fileHandleForWriting.close()

        // Set up timeout if specified
        let timeoutTask: Task<Void, Never>?
        if let timeout = timeout {
            timeoutTask = Task { [weak process] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !Task.isCancelled, let p = process, p.isRunning {
                    p.terminate()
                }
            }
        } else {
            timeoutTask = nil
        }

        // Read output in parallel with process execution to avoid pipe buffer deadlock
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Use async tasks to read stdout and stderr concurrently
        async let stdoutData = Task.detached {
            stdoutHandle.readDataToEndOfFile()
        }.value

        async let stderrData = Task.detached {
            stderrHandle.readDataToEndOfFile()
        }.value

        // Wait for process to exit
        process.waitUntilExit()
        timeoutTask?.cancel()

        // Get the output data
        let stdout = await stdoutData
        let stderr = await stderrData

        currentProcess = nil
        return (stdout, stderr, process.terminationStatus)
    }

    /// Executes a command with streaming output
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Arguments for the command
    ///   - workingDirectory: The working directory
    ///   - environment: Environment variables
    ///   - stdinData: Optional data to send to stdin
    /// - Returns: An async stream of output data
    public nonisolated func executeStreaming(
        command: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String],
        stdinData: Data? = nil
    ) -> AsyncThrowingStream<Data, any Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let process = Process()
                    await self.setCurrentProcess(process)

                    // Configure the shell based on platform
                    #if os(macOS)
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = ["-l", "-c", self.buildCommandString(command: command, arguments: arguments)]
                    #elseif os(Linux)
                    process.executableURL = URL(fileURLWithPath: "/bin/bash")
                    process.arguments = ["-l", "-c", self.buildCommandString(command: command, arguments: arguments)]
                    #else
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = ["-c", self.buildCommandString(command: command, arguments: arguments)]
                    #endif

                    // Set working directory
                    if let workingDirectory = workingDirectory {
                        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                    }

                    // Set environment
                    process.environment = environment

                    // Set up pipes
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    let stdinPipe = Pipe()

                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe
                    process.standardInput = stdinPipe

                    // Set up stdout handler for streaming
                    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            continuation.yield(data)
                        }
                    }

                    // Set up termination handler
                    process.terminationHandler = { [weak self] proc in
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil

                        // Read any remaining data
                        let remainingData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        if !remainingData.isEmpty {
                            continuation.yield(remainingData)
                        }

                        Task { [weak self] in
                            await self?.clearCurrentProcess()
                        }

                        if proc.terminationStatus == 0 {
                            continuation.finish()
                        } else {
                            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            let stderrString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                            continuation.finish(throwing: ClaudeCodeError.executionFailed(stderrString))
                        }
                    }

                    // Launch the process
                    try process.run()

                    // Write stdin if provided
                    if let stdinData = stdinData {
                        stdinPipe.fileHandleForWriting.write(stdinData)
                    }
                    try? stdinPipe.fileHandleForWriting.close()

                } catch {
                    await self.clearCurrentProcess()
                    continuation.finish(throwing: ClaudeCodeError.processLaunchFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Executes a command with streaming output and keeps stdin open for bidirectional IPC.
    ///
    /// Unlike `executeStreaming`, this method does NOT close stdin after launch,
    /// allowing the caller to write responses back to the child process.
    ///
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Arguments for the command
    ///   - workingDirectory: The working directory
    ///   - environment: Environment variables
    ///   - stdinData: Optional initial data to send to stdin
    /// - Returns: A tuple of (stdout data stream, stdin writer handle)
    public nonisolated func executeBidirectionalStreaming(
        command: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String],
        stdinData: Data? = nil
    ) -> (stream: AsyncThrowingStream<Data, any Swift.Error>, stdinWriter: ProcessStdinWriter) {
        let stdinWriter = ProcessStdinWriter()

        let stream = AsyncThrowingStream<Data, any Swift.Error> { continuation in
            Task {
                do {
                    let process = Process()
                    await self.setCurrentProcess(process)

                    // Configure the shell based on platform
                    #if os(macOS)
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = ["-l", "-c", self.buildCommandString(command: command, arguments: arguments)]
                    #elseif os(Linux)
                    process.executableURL = URL(fileURLWithPath: "/bin/bash")
                    process.arguments = ["-l", "-c", self.buildCommandString(command: command, arguments: arguments)]
                    #else
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = ["-c", self.buildCommandString(command: command, arguments: arguments)]
                    #endif

                    // Set working directory
                    if let workingDirectory = workingDirectory {
                        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                    }

                    // Set environment
                    process.environment = environment

                    // Set up pipes
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    let stdinPipe = Pipe()

                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe
                    process.standardInput = stdinPipe

                    // Set up stdout handler for streaming
                    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty {
                            continuation.yield(data)
                        }
                    }

                    // Set up termination handler
                    process.terminationHandler = { [weak self] proc in
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil

                        // Read any remaining data
                        let remainingData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        if !remainingData.isEmpty {
                            continuation.yield(remainingData)
                        }

                        // Close the stdin writer
                        stdinWriter.close()

                        Task { [weak self] in
                            await self?.clearCurrentProcess()
                        }

                        if proc.terminationStatus == 0 {
                            continuation.finish()
                        } else {
                            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            let stderrString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                            continuation.finish(throwing: ClaudeCodeError.executionFailed(stderrString))
                        }
                    }

                    // Launch the process
                    try process.run()

                    // Give the stdin writer a handle to the pipe
                    stdinWriter.setFileHandle(stdinPipe.fileHandleForWriting)

                    // Write initial stdin data if provided (but do NOT close stdin)
                    if let stdinData = stdinData {
                        stdinPipe.fileHandleForWriting.write(stdinData)
                    }

                } catch {
                    await self.clearCurrentProcess()
                    stdinWriter.close()
                    continuation.finish(throwing: ClaudeCodeError.processLaunchFailed(error.localizedDescription))
                }
            }
        }

        return (stream, stdinWriter)
    }

    /// Cancels the current process
    public func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    /// Whether an operation is currently cancelled
    public var cancelled: Bool {
        isCancelled
    }

    // MARK: - Private Methods

    private func setCurrentProcess(_ process: Process) {
        currentProcess = process
    }

    private func clearCurrentProcess() {
        currentProcess = nil
    }

    private nonisolated func buildCommandString(command: String, arguments: [String]) -> String {
        var parts = [command]
        parts.append(contentsOf: arguments.map { arg in
            // If the argument contains spaces or special characters, quote it
            if arg.contains(" ") || arg.contains("\"") || arg.contains("'") || arg.contains("\\") {
                // Escape any existing double quotes and wrap in double quotes
                let escaped = arg.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }
            return arg
        })
        return parts.joined(separator: " ")
    }
}

// MARK: - Process Stdin Writer

/// Handle for writing to a running process's stdin.
///
/// Used for bidirectional IPC — allows sending responses back to the child process
/// while it's still running and streaming output.
public final class ProcessStdinWriter: @unchecked Sendable {
    private var fileHandle: FileHandle?
    private let lock = NSLock()

    internal init() {}

    /// Sets the file handle (called after process launch)
    internal func setFileHandle(_ handle: FileHandle) {
        lock.lock()
        defer { lock.unlock() }
        self.fileHandle = handle
    }

    /// Writes raw data to the process's stdin
    public func write(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        fileHandle?.write(data)
    }

    /// Writes a string as a complete line (with newline) to the process's stdin
    public func writeLine(_ string: String) {
        guard let data = (string + "\n").data(using: .utf8) else { return }
        write(data)
    }

    /// Closes the stdin pipe
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        try? fileHandle?.close()
        fileHandle = nil
    }
}

// MARK: - Process Result

/// Result from a process execution
public struct ProcessResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public var isSuccess: Bool {
        exitCode == 0
    }
}
