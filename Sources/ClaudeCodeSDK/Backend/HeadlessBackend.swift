//
//  HeadlessBackend.swift
//  ClaudeCodeSDK
//
//  Headless backend using `claude -p` CLI subprocess
//

import Foundation

/// Headless backend implementation using Claude CLI subprocess
public final class HeadlessBackend: ClaudeCodeBackend, @unchecked Sendable {
    public let configuration: ClaudeCodeConfiguration
    public private(set) var lastExecutedCommandInfo: ExecutedCommandInfo?

    private let executor: ProcessExecutor
    private let parser: StreamParser

    public init(configuration: ClaudeCodeConfiguration) {
        self.configuration = configuration
        self.executor = ProcessExecutor()
        self.parser = StreamParser()
    }

    // MARK: - ClaudeCodeBackend Implementation

    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        let arguments = buildArguments(
            prompt: prompt,
            outputFormat: outputFormat,
            options: options,
            useStdin: false
        )

        return try await executeCommand(arguments: arguments, outputFormat: outputFormat, stdinData: nil, options: options)
    }

    public func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        var arguments = buildArguments(
            prompt: nil,
            outputFormat: outputFormat,
            options: options,
            useStdin: true
        )

        // Add the pipe flag
        arguments.insert("-p", at: 0)

        let stdinData = stdinContent.data(using: .utf8)
        return try await executeCommand(arguments: arguments, outputFormat: outputFormat, stdinData: stdinData, options: options)
    }

    public func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        var opts = options ?? ClaudeCodeOptions()
        opts.continueConversation = true

        let arguments = buildArguments(
            prompt: prompt,
            outputFormat: outputFormat,
            options: opts,
            useStdin: false
        )

        return try await executeCommand(arguments: arguments, outputFormat: outputFormat, stdinData: nil, options: opts)
    }

    public func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        var opts = options ?? ClaudeCodeOptions()
        opts.resume = sessionId

        let arguments = buildArguments(
            prompt: prompt,
            outputFormat: outputFormat,
            options: opts,
            useStdin: false
        )

        return try await executeCommand(arguments: arguments, outputFormat: outputFormat, stdinData: nil, options: opts)
    }

    public func listSessions() async throws -> [SessionInfo] {
        let arguments = ["sessions", "list", "--output-format=json"]

        let (stdout, stderr, exitCode) = try await executor.execute(
            command: configuration.command,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: configuration.buildEnvironment(),
            stdinData: nil,
            timeout: 30
        )

        guard exitCode == 0 else {
            let errorMessage = String(data: stderr, encoding: .utf8) ?? "Unknown error"
            throw ClaudeCodeError.executionFailed(errorMessage)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([SessionInfo].self, from: stdout)
    }

    public func cancel() {
        Task {
            await executor.cancel()
        }
    }

    public func validateSetup() async throws -> Bool {
        #if os(macOS)
        let whichCommand = "which"
        #else
        let whichCommand = "command -v"
        #endif

        let (_, _, exitCode) = try await executor.execute(
            command: whichCommand,
            arguments: [configuration.command],
            workingDirectory: nil,
            environment: configuration.buildEnvironment(),
            stdinData: nil,
            timeout: 10
        )

        return exitCode == 0
    }

    // MARK: - Private Methods

    /// Builds environment with beta feature headers if specified
    private func buildEnvironmentWithBetas(options: ClaudeCodeOptions?) -> [String: String] {
        var env = configuration.buildEnvironment()
        if let betas = options?.betaFeatures, !betas.isEmpty {
            let betaHeader = betas.map(\.rawValue).joined(separator: ",")
            env["ANTHROPIC_BETA"] = betaHeader
        }
        return env
    }

    private func buildArguments(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?,
        useStdin: Bool
    ) -> [String] {
        var args: [String] = []

        // Add output format flag
        args.append(outputFormat.cliFlag)

        // Add print mode flag for non-interactive
        args.append("--print")

        // Streaming JSON requires --verbose when using --print
        if outputFormat == .streamJson {
            args.append("--verbose")
        }

        // Add options
        if let options = options {
            args.append(contentsOf: options.toCommandArgs())
        }

        // Add disallowed tools from configuration
        if let disallowedTools = configuration.disallowedTools {
            for tool in disallowedTools {
                args.append("--disallowedTools")
                args.append(tool)
            }
        }

        // Add command suffix if specified
        if let suffix = configuration.commandSuffix {
            args.append(suffix)
        }

        // Add prompt if provided
        if let prompt = prompt {
            args.append(prompt)
        }

        return args
    }

    private func executeCommand(
        arguments: [String],
        outputFormat: ClaudeCodeOutputFormat,
        stdinData: Data?,
        options: ClaudeCodeOptions? = nil
    ) async throws -> ClaudeCodeResult {
        let startTime = Date()
        let environment = buildEnvironmentWithBetas(options: options)

        // Store command info for debugging
        let commandInfo = ExecutedCommandInfo(
            command: configuration.command,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: environment,
            startTime: startTime
        )

        lastExecutedCommandInfo = commandInfo

        if configuration.enableDebugLogging {
            print("[HeadlessBackend] Executing: \(configuration.command) \(arguments.joined(separator: " "))")
        }

        switch outputFormat {
        case .streamJson:
            return try await executeStreamingCommand(arguments: arguments, stdinData: stdinData, environment: environment)

        case .text, .json:
            return try await executeNonStreamingCommand(
                arguments: arguments,
                outputFormat: outputFormat,
                stdinData: stdinData,
                environment: environment
            )
        }
    }

    private func executeNonStreamingCommand(
        arguments: [String],
        outputFormat: ClaudeCodeOutputFormat,
        stdinData: Data?,
        environment: [String: String]
    ) async throws -> ClaudeCodeResult {
        let (stdout, stderr, exitCode) = try await executor.execute(
            command: configuration.command,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: environment,
            stdinData: stdinData,
            timeout: nil
        )

        // Check exit code
        guard exitCode == 0 else {
            let errorMessage = String(data: stderr, encoding: .utf8) ?? "Unknown error"

            switch exitCode {
            case 127:
                throw ClaudeCodeError.notInstalled
            case 126:
                throw ClaudeCodeError.permissionDenied(errorMessage)
            case -1:
                throw ClaudeCodeError.signalTerminated(exitCode)
            default:
                throw ClaudeCodeError.executionFailed(errorMessage)
            }
        }

        let outputString = String(data: stdout, encoding: .utf8) ?? ""

        switch outputFormat {
        case .text:
            return .text(outputString)

        case .json:
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(ResultMessage.self, from: stdout)
                return .json(result)
            } catch {
                throw ClaudeCodeError.jsonParsingError(error.localizedDescription)
            }

        case .streamJson:
            throw ClaudeCodeError.invalidConfiguration("Stream JSON should use streaming execution")
        }
    }

    private func executeStreamingCommand(
        arguments: [String],
        stdinData: Data?,
        environment: [String: String]
    ) async throws -> ClaudeCodeResult {
        let dataStream = executor.executeStreaming(
            command: configuration.command,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: environment,
            stdinData: stdinData
        )

        let chunkStream = parser.parseStream(dataStream)

        let stream = ClaudeCodeStream {
            chunkStream
        }

        return .stream(stream)
    }
}
