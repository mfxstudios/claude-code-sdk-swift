//
//  AgentSDKBackend.swift
//  ClaudeCodeSDK
//
//  Agent SDK backend using Node.js wrapper around @anthropic-ai/claude-agent-sdk
//

import Foundation

/// Agent SDK backend implementation using Node.js wrapper
public final class AgentSDKBackend: ClaudeCodeBackend, @unchecked Sendable {
    public let configuration: ClaudeCodeConfiguration
    public private(set) var lastExecutedCommandInfo: ExecutedCommandInfo?

    private let executor: ProcessExecutor
    private let parser: StreamParser
    private let nodeExecutable: String
    private let wrapperPath: String
    private let globalNodeModulesPath: String?

    /// Creates a new Agent SDK backend
    /// - Parameter configuration: The configuration for this backend
    /// - Throws: ClaudeCodeError if Node.js or the wrapper script cannot be found
    public init(configuration: ClaudeCodeConfiguration) throws {
        self.configuration = configuration
        self.executor = ProcessExecutor()
        self.parser = StreamParser()

        // Resolve Node.js executable
        if let nodePath = configuration.nodeExecutable {
            self.nodeExecutable = nodePath
        } else {
            self.nodeExecutable = try Self.findNodeExecutable(configuration: configuration)
        }

        // Resolve wrapper script path
        if let wrapperPath = configuration.sdkWrapperPath {
            self.wrapperPath = wrapperPath
        } else {
            self.wrapperPath = try Self.findWrapperScript(configuration: configuration)
        }

        // Find global node_modules path for NODE_PATH
        self.globalNodeModulesPath = Self.findGlobalNodeModulesPath(configuration: configuration)
    }

    // MARK: - ClaudeCodeBackend Implementation

    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        let config = buildWrapperConfig(prompt: prompt, options: options)
        return try await executeWrapper(config: config, outputFormat: outputFormat)
    }

    public func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        // For Agent SDK, stdin content is treated as the prompt
        let config = buildWrapperConfig(prompt: stdinContent, options: options)
        return try await executeWrapper(config: config, outputFormat: outputFormat)
    }

    public func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        var opts = options ?? ClaudeCodeOptions()
        opts.continueConversation = true

        let config = buildWrapperConfig(prompt: prompt ?? "", options: opts)
        return try await executeWrapper(config: config, outputFormat: outputFormat)
    }

    public func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        var opts = options ?? ClaudeCodeOptions()
        opts.resume = sessionId

        let config = buildWrapperConfig(prompt: prompt ?? "", options: opts)
        return try await executeWrapper(config: config, outputFormat: outputFormat)
    }

    public func listSessions() async throws -> [SessionInfo] {
        // Agent SDK doesn't directly support listing sessions
        // Fall back to using the CLI command
        let (stdout, stderr, exitCode) = try await executor.execute(
            command: configuration.command,
            arguments: ["sessions", "list", "--output-format=json"],
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
        // Validate Node.js is available
        let (_, _, nodeExitCode) = try await executor.execute(
            command: nodeExecutable,
            arguments: ["--version"],
            workingDirectory: nil,
            environment: buildEnvironmentWithNodePath(),
            stdinData: nil,
            timeout: 10
        )

        guard nodeExitCode == 0 else {
            return false
        }

        // Validate wrapper script exists
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: wrapperPath)
    }

    // MARK: - Private Methods

    private static func findNodeExecutable(configuration: ClaudeCodeConfiguration) throws -> String {
        // First try to find in PATH using 'which' - this respects user's environment
        let process = Process()
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which node"]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "which node"]
        #endif

        process.environment = configuration.buildEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Fall through to hardcoded paths
        }

        // Fall back to common locations
        let possiblePaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]

        let fileManager = FileManager.default

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        throw ClaudeCodeError.invalidConfiguration("Node.js executable not found. Please install Node.js or specify nodeExecutable in configuration.")
    }

    /// Finds the global node_modules path using `npm root -g`
    private static func findGlobalNodeModulesPath(configuration: ClaudeCodeConfiguration) -> String? {
        let process = Process()
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "npm root -g"]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "npm root -g"]
        #endif

        process.environment = configuration.buildEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Ignore errors
        }

        return nil
    }

    /// Builds environment with NODE_PATH set to find global packages
    private func buildEnvironmentWithNodePath() -> [String: String] {
        var env = configuration.buildEnvironment()

        // Set NODE_PATH to include global node_modules so the wrapper can find @anthropic-ai/claude-agent-sdk
        if let globalPath = globalNodeModulesPath {
            if let existingNodePath = env["NODE_PATH"] {
                env["NODE_PATH"] = "\(globalPath):\(existingNodePath)"
            } else {
                env["NODE_PATH"] = globalPath
            }
        }

        return env
    }

    private static func findWrapperScript(configuration: ClaudeCodeConfiguration) throws -> String {
        // Try to find bundled resource
        #if SWIFT_PACKAGE
        // In Swift Package, check the bundle
        if let bundlePath = Bundle.module.path(forResource: "sdk-wrapper", ofType: "mjs") {
            return bundlePath
        }
        #endif

        // Check relative to working directory
        if let workingDir = configuration.workingDirectory {
            let wrapperPath = (workingDir as NSString).appendingPathComponent("sdk-wrapper.mjs")
            if FileManager.default.fileExists(atPath: wrapperPath) {
                return wrapperPath
            }
        }

        // Check in common locations
        let possiblePaths = [
            "./sdk-wrapper.mjs",
            "./Resources/sdk-wrapper.mjs",
            "../Resources/sdk-wrapper.mjs",
        ]

        for path in possiblePaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }

        throw ClaudeCodeError.invalidConfiguration("sdk-wrapper.mjs not found. Please provide sdkWrapperPath in configuration.")
    }

    /// Configuration structure for the wrapper script
    private struct WrapperConfig: Encodable {
        let prompt: String
        let options: WrapperOptions
    }

    private struct WrapperOptions: Encodable {
        var model: String?
        var maxTurns: Int?
        var maxThinkingTokens: Int?
        var systemPrompt: String?
        var appendSystemPrompt: String?
        var allowedTools: [String]?
        var disallowedTools: [String]?
        var permissionMode: String?
        var continueSession: Bool?
        var resumeSession: String?
        var mcpServers: [String: McpServerConfiguration]?
        var thinking: ThinkingConfiguration?
        var speed: String?
        var betaFeatures: [String]?
        var outputConfig: OutputConfig?

        enum CodingKeys: String, CodingKey {
            case model
            case maxTurns = "max_turns"
            case maxThinkingTokens = "max_thinking_tokens"
            case systemPrompt = "system_prompt"
            case appendSystemPrompt = "append_system_prompt"
            case allowedTools = "allowed_tools"
            case disallowedTools = "disallowed_tools"
            case permissionMode = "permission_mode"
            case continueSession = "continue"
            case resumeSession = "resume"
            case mcpServers = "mcp_servers"
            case thinking
            case speed
            case betaFeatures = "beta_features"
            case outputConfig = "output_config"
        }
    }

    private func buildWrapperConfig(prompt: String, options: ClaudeCodeOptions?) -> WrapperConfig {
        var wrapperOptions = WrapperOptions()

        if let opts = options {
            wrapperOptions.model = opts.model?.rawValue
            wrapperOptions.maxTurns = opts.maxTurns
            wrapperOptions.maxThinkingTokens = opts._maxThinkingTokens
            // System prompt handling:
            // - appendSystemPrompt uses claude_code preset with append (recommended)
            // - systemPrompt replaces the default system prompt entirely
            wrapperOptions.systemPrompt = opts.systemPrompt
            wrapperOptions.appendSystemPrompt = opts.appendSystemPrompt
            wrapperOptions.allowedTools = opts.allowedTools
            wrapperOptions.disallowedTools = opts.disallowedTools ?? configuration.disallowedTools
            wrapperOptions.permissionMode = opts.permissionMode?.rawValue
            wrapperOptions.continueSession = opts.continueConversation
            wrapperOptions.resumeSession = opts.resume
            wrapperOptions.mcpServers = opts.mcpServers
            wrapperOptions.thinking = opts.thinking
            wrapperOptions.speed = opts.speed?.rawValue
            if let betas = opts.betaFeatures, !betas.isEmpty {
                wrapperOptions.betaFeatures = betas.map(\.rawValue)
            }
            wrapperOptions.outputConfig = opts.outputConfig
        } else {
            wrapperOptions.disallowedTools = configuration.disallowedTools
        }

        return WrapperConfig(prompt: prompt, options: wrapperOptions)
    }

    private func executeWrapper(
        config: WrapperConfig,
        outputFormat: ClaudeCodeOutputFormat
    ) async throws -> ClaudeCodeResult {
        let startTime = Date()

        // Encode config to JSON
        let encoder = JSONEncoder()
        let configData = try encoder.encode(config)
        guard let configJson = String(data: configData, encoding: .utf8) else {
            throw ClaudeCodeError.invalidConfiguration("Failed to encode wrapper configuration")
        }

        // Build command: node <wrapper-path> '<json-config>'
        let arguments = [wrapperPath, configJson]

        // Store command info for debugging
        let commandInfo = ExecutedCommandInfo(
            command: nodeExecutable,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: configuration.buildEnvironment(),
            startTime: startTime
        )

        lastExecutedCommandInfo = commandInfo

        if configuration.enableDebugLogging {
            print("[AgentSDKBackend] Executing: \(nodeExecutable) \(wrapperPath) '<config>'")
            print("[AgentSDKBackend] Prompt length: \(config.prompt.count)")
        }

        switch outputFormat {
        case .streamJson:
            return try await executeStreamingWrapper(arguments: arguments)

        case .text, .json:
            return try await executeNonStreamingWrapper(arguments: arguments, outputFormat: outputFormat)
        }
    }

    private func executeNonStreamingWrapper(
        arguments: [String],
        outputFormat: ClaudeCodeOutputFormat
    ) async throws -> ClaudeCodeResult {
        let (stdout, stderr, exitCode) = try await executor.execute(
            command: nodeExecutable,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: buildEnvironmentWithNodePath(),
            stdinData: nil,
            timeout: nil
        )

        guard exitCode == 0 else {
            let errorMessage = String(data: stderr, encoding: .utf8) ?? "Unknown error"
            throw ClaudeCodeError.executionFailed(errorMessage)
        }

        // Parse the JSONL output - get the last result message
        let outputString = String(data: stdout, encoding: .utf8) ?? ""
        let lines = outputString.components(separatedBy: .newlines)

        var lastResult: ResultMessage?
        var allText = ""

        let decoder = JSONDecoder()
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8) else {
                continue
            }

            // Try to parse as a typed message
            struct TypeWrapper: Decodable {
                let type: String
            }

            guard let typeWrapper = try? decoder.decode(TypeWrapper.self, from: lineData) else {
                continue
            }

            switch typeWrapper.type {
            case "result":
                lastResult = try? decoder.decode(ResultMessage.self, from: lineData)
            case "assistant":
                if let msg = try? decoder.decode(AssistantMessage.self, from: lineData) {
                    for content in msg.message.content {
                        if case .text(let textContent) = content {
                            allText += textContent.text
                        }
                    }
                }
            default:
                break
            }
        }

        switch outputFormat {
        case .text:
            if let result = lastResult?.result {
                return .text(result)
            }
            return .text(allText)

        case .json:
            if let result = lastResult {
                return .json(result)
            }
            throw ClaudeCodeError.invalidOutput("No result message in output")

        case .streamJson:
            throw ClaudeCodeError.invalidConfiguration("Stream JSON should use streaming execution")
        }
    }

    private func executeStreamingWrapper(
        arguments: [String]
    ) async throws -> ClaudeCodeResult {
        let dataStream = executor.executeStreaming(
            command: nodeExecutable,
            arguments: arguments,
            workingDirectory: configuration.workingDirectory,
            environment: buildEnvironmentWithNodePath(),
            stdinData: nil
        )

        let chunkStream = parser.parseStream(dataStream)

        let stream = ClaudeCodeStream {
            chunkStream
        }

        return .stream(stream)
    }
}
