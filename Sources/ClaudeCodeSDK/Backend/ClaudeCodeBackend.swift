//
//  ClaudeCodeBackend.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Protocol defining the backend interface for Claude Code execution
public protocol ClaudeCodeBackend: Sendable {
    /// The configuration for this backend
    var configuration: ClaudeCodeConfiguration { get }

    /// Debug information about the last executed command
    var lastExecutedCommandInfo: ExecutedCommandInfo? { get }

    /// Runs a single prompt and returns the result
    func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Runs with stdin content (for piping data)
    func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Continues the most recent conversation
    func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Resumes a specific conversation by session ID
    func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Lists available sessions
    func listSessions() async throws -> [SessionInfo]

    /// Cancels any ongoing operation
    func cancel()

    /// Validates that the backend is properly set up
    func validateSetup() async throws -> Bool
}

/// Factory for creating backends based on configuration
public enum BackendFactory {
    /// Result of backend creation including the resolved backend type
    public struct CreationResult {
        /// The created backend
        public let backend: any ClaudeCodeBackend

        /// The resolved backend type (useful when auto was specified)
        public let resolvedType: BackendType

        /// Detection result (only populated when auto detection was used)
        public let detectionResult: BackendDetector.DetectionResult?
    }

    /// Creates a backend based on the configuration
    /// - Parameter configuration: The configuration specifying which backend to use
    /// - Returns: A configured backend instance
    /// - Throws: ClaudeCodeError if the backend cannot be created
    public static func createBackend(for configuration: ClaudeCodeConfiguration) throws -> any ClaudeCodeBackend {
        try createBackendWithResult(for: configuration).backend
    }

    /// Creates a backend and returns additional information about the creation
    /// - Parameter configuration: The configuration specifying which backend to use
    /// - Returns: CreationResult containing the backend and metadata
    /// - Throws: ClaudeCodeError if the backend cannot be created
    public static func createBackendWithResult(for configuration: ClaudeCodeConfiguration) throws -> CreationResult {
        switch configuration.backend {
        case .auto:
            return try createAutoDetectedBackend(for: configuration)

        case .headless:
            // When explicitly requesting headless, detect CLI path if using default command
            var config = configuration
            if configuration.command == "claude" {
                let detector = BackendDetector(configuration: configuration)
                let detection = detector.detect()
                if let claudePath = detection.claudeCliPath {
                    config.command = claudePath
                }
            }
            return CreationResult(
                backend: HeadlessBackend(configuration: config),
                resolvedType: .headless,
                detectionResult: nil
            )

        case .agentSDK:
            return CreationResult(
                backend: try AgentSDKBackend(configuration: configuration),
                resolvedType: .agentSDK,
                detectionResult: nil
            )
        }
    }

    /// Creates a backend using auto-detection
    private static func createAutoDetectedBackend(for configuration: ClaudeCodeConfiguration) throws -> CreationResult {
        let detector = BackendDetector(configuration: configuration)
        let detection = detector.detect()

        if configuration.enableDebugLogging {
            print("[BackendFactory] Auto-detecting backend...")
            print("[BackendFactory] \(detection.description)")
        }

        // Try to create the recommended backend
        let recommendedType = detection.recommendedBackend

        switch recommendedType {
        case .headless:
            // Create headless backend with detected path if available
            // Only override command if the user hasn't explicitly set a custom command
            var config = configuration
            if let claudePath = detection.claudeCliPath, configuration.command == "claude" {
                config.command = claudePath
            }

            return CreationResult(
                backend: HeadlessBackend(configuration: config),
                resolvedType: .headless,
                detectionResult: detection
            )

        case .agentSDK:
            // Create Agent SDK backend with detected node path
            var config = configuration
            if let nodePath = detection.nodePath {
                config.nodeExecutable = nodePath
            }

            do {
                return CreationResult(
                    backend: try AgentSDKBackend(configuration: config),
                    resolvedType: .agentSDK,
                    detectionResult: detection
                )
            } catch {
                // If Agent SDK fails, fall back to headless
                if configuration.enableDebugLogging {
                    print("[BackendFactory] Agent SDK backend creation failed, falling back to headless")
                }

                return CreationResult(
                    backend: HeadlessBackend(configuration: configuration),
                    resolvedType: .headless,
                    detectionResult: detection
                )
            }

        case .auto:
            // This shouldn't happen, but default to headless
            return CreationResult(
                backend: HeadlessBackend(configuration: configuration),
                resolvedType: .headless,
                detectionResult: detection
            )
        }
    }

    /// Detects available backends without creating one
    /// - Parameter configuration: The configuration to use for detection
    /// - Returns: Detection result with available backends
    public static func detectAvailableBackends(configuration: ClaudeCodeConfiguration = .default) -> BackendDetector.DetectionResult {
        BackendDetector(configuration: configuration).detect()
    }

    /// Detects available backends asynchronously with validation
    /// - Parameter configuration: The configuration to use for detection
    /// - Returns: Detection result with available backends
    public static func detectAvailableBackendsAsync(configuration: ClaudeCodeConfiguration = .default) async -> BackendDetector.DetectionResult {
        await BackendDetector(configuration: configuration).detectAsync()
    }
}
