//
//  ClaudeCodeClient.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// The main client for interacting with Claude Code CLI
public final class ClaudeCodeClient: ClaudeCodeProtocol, @unchecked Sendable {
    /// The configuration for this client
    public private(set) var configuration: ClaudeCodeConfiguration

    /// The resolved backend type (after auto-detection if applicable)
    public private(set) var resolvedBackendType: BackendType

    /// Detection result (only populated when auto detection was used)
    public private(set) var detectionResult: BackendDetector.DetectionResult?

    /// Debug information about the last executed command
    public var lastExecutedCommandInfo: ExecutedCommandInfo? {
        backend.lastExecutedCommandInfo
    }

    /// The backend used for execution
    private var backend: any ClaudeCodeBackend

    /// Creates a new Claude Code client
    /// - Parameter configuration: The configuration to use
    /// - Throws: ClaudeCodeError if backend creation fails
    public init(configuration: ClaudeCodeConfiguration = .default) throws {
        self.configuration = configuration
        let result = try BackendFactory.createBackendWithResult(for: configuration)
        self.backend = result.backend
        self.resolvedBackendType = result.resolvedType
        self.detectionResult = result.detectionResult
    }

    /// Creates a new Claude Code client with default configuration (non-throwing)
    /// Uses auto-detection to find the best available backend
    public convenience init() {
        // Use auto detection by default
        try! self.init(configuration: .default)
    }

    /// Convenience initializer with working directory and debug flag
    /// - Parameters:
    ///   - workingDirectory: The working directory for command execution
    ///   - debug: Whether to enable debug logging
    ///   - backend: The backend type to use (default: auto)
    /// - Throws: ClaudeCodeError if backend creation fails
    public convenience init(
        workingDirectory: String? = nil,
        debug: Bool = false,
        backend: BackendType = .auto
    ) throws {
        var config = ClaudeCodeConfiguration.default
        config.workingDirectory = workingDirectory
        config.enableDebugLogging = debug
        config.backend = backend
        try self.init(configuration: config)
    }

    /// Updates the configuration and recreates the backend if needed
    /// - Parameter newConfiguration: The new configuration to use
    /// - Throws: ClaudeCodeError if backend creation fails
    public func updateConfiguration(_ newConfiguration: ClaudeCodeConfiguration) throws {
        let needsNewBackend = configuration.backend != newConfiguration.backend ||
                              configuration.workingDirectory != newConfiguration.workingDirectory ||
                              configuration.nodeExecutable != newConfiguration.nodeExecutable ||
                              configuration.sdkWrapperPath != newConfiguration.sdkWrapperPath

        self.configuration = newConfiguration

        if needsNewBackend {
            let result = try BackendFactory.createBackendWithResult(for: newConfiguration)
            self.backend = result.backend
            self.resolvedBackendType = result.resolvedType
            self.detectionResult = result.detectionResult
        }
    }

    // MARK: - Protocol Implementation

    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        try await backend.runSinglePrompt(prompt: prompt, outputFormat: outputFormat, options: options)
    }

    public func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        try await backend.runWithStdin(stdinContent: stdinContent, outputFormat: outputFormat, options: options)
    }

    public func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        try await backend.continueConversation(prompt: prompt, outputFormat: outputFormat, options: options)
    }

    public func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        try await backend.resumeConversation(sessionId: sessionId, prompt: prompt, outputFormat: outputFormat, options: options)
    }

    public func listSessions() async throws -> [SessionInfo] {
        try await backend.listSessions()
    }

    public func cancel() {
        backend.cancel()
    }

    public func validateCommand(_ command: String) async throws -> Bool {
        try await backend.validateSetup()
    }
}

// MARK: - Convenience Extensions

extension ClaudeCodeClient {
    /// Logs a warning to stderr if the specified model is deprecated
    private func warnIfDeprecatedModel(_ options: ClaudeCodeOptions?) {
        guard configuration.enableDebugLogging,
              let model = options?.model,
              model.isDeprecated else { return }
        fputs("[ClaudeCodeSDK WARNING] Model '\(model.rawValue)' is deprecated. Consider using a current model.\n", stderr)
    }

    /// Runs a prompt and waits for the complete result
    /// - Parameters:
    ///   - prompt: The prompt to send
    ///   - options: Optional execution options
    /// - Returns: The result message
    public func ask(_ prompt: String, options: ClaudeCodeOptions? = nil) async throws -> ResultMessage {
        warnIfDeprecatedModel(options)
        let result = try await runSinglePrompt(prompt: prompt, outputFormat: .json, options: options)

        switch result {
        case .json(let message):
            return message
        case .text(let text):
            throw ClaudeCodeError.invalidOutput("Expected JSON result, got text: \(text)")
        case .stream:
            throw ClaudeCodeError.invalidOutput("Expected JSON result, got stream")
        }
    }

    /// Runs a prompt with streaming and processes each chunk
    /// - Parameters:
    ///   - prompt: The prompt to send
    ///   - options: Optional execution options
    ///   - onChunk: Callback for each response chunk
    /// - Returns: The final result message
    @discardableResult
    public func stream(
        _ prompt: String,
        options: ClaudeCodeOptions? = nil,
        onChunk: @escaping (ResponseChunk) async -> Void
    ) async throws -> ResultMessage? {
        warnIfDeprecatedModel(options)
        let result = try await runSinglePrompt(prompt: prompt, outputFormat: .streamJson, options: options)

        guard case .stream(let stream) = result else {
            throw ClaudeCodeError.invalidOutput("Expected stream result")
        }

        var finalResult: ResultMessage?

        for try await chunk in stream {
            await onChunk(chunk)

            if case .result(let msg) = chunk {
                finalResult = msg
            }
        }

        return finalResult
    }

    /// The configured backend type (may be .auto)
    public var backendType: BackendType {
        configuration.backend
    }

    /// Detects available backends on the current system
    /// - Returns: Detection result with available backends
    public static func detectAvailableBackends() -> BackendDetector.DetectionResult {
        BackendFactory.detectAvailableBackends()
    }

    /// Detects available backends asynchronously with validation
    /// - Returns: Detection result with available backends
    public static func detectAvailableBackendsAsync() async -> BackendDetector.DetectionResult {
        await BackendFactory.detectAvailableBackendsAsync()
    }

    /// Validates that the current backend is properly set up
    /// - Returns: Whether the backend is ready to use
    public func validateBackend() async throws -> Bool {
        try await backend.validateSetup()
    }
}

// MARK: - Session Storage Extensions

extension ClaudeCodeClient {
    /// Gets the native session storage for accessing Claude CLI sessions
    /// - Parameter basePath: Optional custom base path (defaults to ~/.claude/projects)
    /// - Returns: Native session storage instance
    public static func nativeSessionStorage(basePath: String? = nil) -> ClaudeNativeSessionStorage {
        ClaudeNativeSessionStorage(basePath: basePath)
    }

    /// Gets stored sessions for the current working directory
    /// - Returns: Array of stored sessions, most recent first
    public func getStoredSessions() async throws -> [ClaudeStoredSession] {
        let storage = ClaudeNativeSessionStorage()
        let projectPath = configuration.workingDirectory ?? FileManager.default.currentDirectoryPath
        return try await storage.getSessions(for: projectPath)
    }

    /// Gets a specific stored session by ID
    /// - Parameter sessionId: The session UUID
    /// - Returns: The stored session if found
    public func getStoredSession(id sessionId: String) async throws -> ClaudeStoredSession? {
        let storage = ClaudeNativeSessionStorage()
        let projectPath = configuration.workingDirectory ?? FileManager.default.currentDirectoryPath
        return try await storage.getSession(id: sessionId, projectPath: projectPath)
    }

    /// Gets the most recent stored session for the current project
    /// - Returns: The most recent session if any exist
    public func getMostRecentStoredSession() async throws -> ClaudeStoredSession? {
        let storage = ClaudeNativeSessionStorage()
        let projectPath = configuration.workingDirectory ?? FileManager.default.currentDirectoryPath
        return try await storage.getMostRecentSession(for: projectPath)
    }

    /// Searches stored sessions for matching content
    /// - Parameter query: The search query
    /// - Returns: Sessions containing the query in messages
    public func searchStoredSessions(query: String) async throws -> [ClaudeStoredSession] {
        let storage = ClaudeNativeSessionStorage()
        let projectPath = configuration.workingDirectory ?? FileManager.default.currentDirectoryPath
        return try await storage.searchSessions(query: query, projectPath: projectPath)
    }

    /// Gets stored sessions for a specific git branch
    /// - Parameter branch: The git branch name
    /// - Returns: Sessions associated with the branch
    public func getStoredSessions(forBranch branch: String) async throws -> [ClaudeStoredSession] {
        let storage = ClaudeNativeSessionStorage()
        let projectPath = configuration.workingDirectory ?? FileManager.default.currentDirectoryPath
        return try await storage.getSessions(forBranch: branch, projectPath: projectPath)
    }

    /// Lists all projects that have Claude sessions
    /// - Returns: Array of projects with session information
    public func listStoredProjects() async throws -> [ClaudeProject] {
        let storage = ClaudeNativeSessionStorage()
        return try await storage.listProjects()
    }
}

// MARK: - Interactive Session Extensions

extension ClaudeCodeClient {
    /// Creates a new interactive session for multi-turn conversations
    /// - Parameter configuration: Optional session configuration
    /// - Returns: A new interactive session
    ///
    /// Example usage:
    /// ```swift
    /// let session = try client.createInteractiveSession()
    ///
    /// // Stream responses
    /// for try await event in session.send("Hello!") {
    ///     switch event {
    ///     case .text(let chunk):
    ///         print(chunk, terminator: "")
    ///     case .completed(let result):
    ///         print("\nDone! Cost: $\(result.totalCostUsd)")
    ///     default:
    ///         break
    ///     }
    /// }
    ///
    /// // Continue the conversation
    /// let response = try await session.sendAndWait("What did I just say?")
    /// print(response.text)
    ///
    /// await session.end()
    /// ```
    public func createInteractiveSession(
        configuration: InteractiveSessionConfiguration = .default
    ) throws -> ClaudeInteractiveSession {
        ClaudeInteractiveSession(
            backend: backend,
            clientConfiguration: self.configuration,
            configuration: configuration
        )
    }

    /// Creates a new interactive session with a system prompt
    /// - Parameter systemPrompt: The system prompt to use
    /// - Returns: A new interactive session
    public func createInteractiveSession(
        systemPrompt: String
    ) throws -> ClaudeInteractiveSession {
        var config = InteractiveSessionConfiguration.default
        config.systemPrompt = systemPrompt
        return try createInteractiveSession(configuration: config)
    }

    /// Creates a new interactive session with common options
    /// - Parameters:
    ///   - systemPrompt: Optional system prompt
    ///   - maxTurns: Maximum turns per message (0 for unlimited)
    ///   - allowedTools: Tools to allow (nil for all). Supports permission rule patterns.
    /// - Returns: A new interactive session
    public func createInteractiveSession(
        systemPrompt: String? = nil,
        maxTurns: Int = 0,
        allowedTools: [ToolPermissionRule]? = nil
    ) throws -> ClaudeInteractiveSession {
        let config = InteractiveSessionConfiguration(
            systemPrompt: systemPrompt,
            maxTurns: maxTurns,
            allowedTools: allowedTools
        )
        return try createInteractiveSession(configuration: config)
    }

    /// Creates a new interactive session with question handling support
    ///
    /// When Claude asks clarifying questions during execution (via AskUserQuestion),
    /// the `onUserQuestion` handler is called. Your app can present the questions
    /// to the user and return their answers.
    ///
    /// ```swift
    /// let session = try client.createInteractiveSession(
    ///     onUserQuestion: { questions in
    ///         var answers: [String: String] = [:]
    ///         for q in questions {
    ///             // Show question UI, collect answer
    ///             answers[q.question] = selectedLabel
    ///         }
    ///         return answers
    ///     }
    /// )
    /// let result = try await session.sendAndWait("Help me set up my project")
    /// ```
    ///
    /// - Parameters:
    ///   - systemPrompt: Optional system prompt
    ///   - onUserQuestion: Handler called when Claude asks clarifying questions
    ///   - onToolPermission: Handler called when Claude requests tool permission
    /// - Returns: A new interactive session with question support
    public func createInteractiveSession(
        systemPrompt: String? = nil,
        onUserQuestion: UserQuestionHandler? = nil,
        onToolPermission: ToolPermissionHandler? = nil
    ) throws -> ClaudeInteractiveSession {
        let config = InteractiveSessionConfiguration(
            systemPrompt: systemPrompt,
            userQuestionHandler: onUserQuestion,
            toolPermissionHandler: onToolPermission
        )
        return try createInteractiveSession(configuration: config)
    }
}
