//
//  ClaudeInteractiveSession.swift
//  ClaudeCodeSDK
//
//  Concrete implementation of InteractiveSession using ClaudeCodeBackend
//

import Foundation
import Synchronization

/// Concrete implementation of an interactive Claude session
public final class ClaudeInteractiveSession: InteractiveSessionProtocol, @unchecked Sendable {
    /// The current session ID
    public private(set) var sessionId: String?

    /// Whether the session is active
    public var isActive: Bool {
        _hasEnded.withLock { !$0 }
    }

    /// The session configuration
    public let configuration: InteractiveSessionConfiguration

    // MARK: - Private Properties

    private let backend: any ClaudeCodeBackend
    private let clientConfiguration: ClaudeCodeConfiguration
    private let _hasEnded = Mutex(false)

    // MARK: - Initialization

    /// Creates a new interactive session
    /// - Parameters:
    ///   - backend: The backend to use for execution
    ///   - clientConfiguration: The client configuration
    ///   - configuration: The session configuration
    internal init(
        backend: any ClaudeCodeBackend,
        clientConfiguration: ClaudeCodeConfiguration,
        configuration: InteractiveSessionConfiguration = .default
    ) {
        self.backend = backend
        self.clientConfiguration = clientConfiguration
        self.configuration = configuration
    }

    // MARK: - InteractiveSessionProtocol

    public func send(_ message: String) -> InteractiveResponseStream {
        let stream = AsyncThrowingStream<InteractiveEvent, any Swift.Error> { continuation in
            Task {
                do {
                    try await self.performSend(message: message, continuation: continuation)
                } catch {
                    continuation.yield(.error(.sendFailed(error.localizedDescription)))
                    continuation.finish(throwing: error)
                }
            }
        }
        return InteractiveResponseStream(stream)
    }

    public func sendAndWait(_ message: String) async throws -> InteractiveResult {
        try await send(message).waitForCompletion()
    }

    public func cancel() {
        backend.cancel()
    }

    public func end() async {
        _hasEnded.withLock { $0 = true }
        cancel()
    }

    // MARK: - Private Methods

    private func performSend(
        message: String,
        continuation: AsyncThrowingStream<InteractiveEvent, any Swift.Error>.Continuation
    ) async throws {
        // Check if session has ended
        let hasEnded = _hasEnded.withLock { $0 }
        guard !hasEnded else {
            continuation.yield(.error(.sessionEnded))
            continuation.finish()
            return
        }

        // Build options
        var options = ClaudeCodeOptions()

        // Use appendSystemPrompt to add to the existing Claude Code system prompt
        // rather than replacing it entirely
        if let systemPrompt = configuration.systemPrompt {
            options.appendSystemPrompt = systemPrompt
        }

        if configuration.maxTurns > 0 {
            options.maxTurns = configuration.maxTurns
        }

        if let allowedTools = configuration.allowedTools {
            options.allowedTools = allowedTools
        }

        if let disallowedTools = configuration.disallowedTools {
            options.disallowedTools = disallowedTools
        }

        // Set permission prompt tool name
        switch configuration.permissionPromptTool {
        case .auto:
            break
        case .deny:
            options.permissionPromptToolName = "deny-all"
        case .allow:
            options.permissionPromptToolName = "allow-all"
        }

        // Resume existing session if we have one
        if let currentSessionId = sessionId {
            options.resume = currentSessionId
        }

        // Execute the request with streaming
        let result: ClaudeCodeResult

        if let currentSessionId = sessionId {
            result = try await backend.resumeConversation(
                sessionId: currentSessionId,
                prompt: message,
                outputFormat: .streamJson,
                options: options
            )
        } else {
            result = try await backend.runSinglePrompt(
                prompt: message,
                outputFormat: .streamJson,
                options: options
            )
        }

        // Process the stream
        guard case .stream(let stream) = result else {
            throw InteractiveError.sendFailed("Expected streaming response")
        }

        var accumulatedText = ""

        for try await chunk in stream {
            switch chunk {
            case .initSystem(let initMsg):
                // Update session ID
                self.sessionId = initMsg.sessionId
                continuation.yield(.sessionStarted(SessionStartInfo(
                    sessionId: initMsg.sessionId,
                    tools: initMsg.tools,
                    mcpServers: initMsg.mcpServers
                )))

            case .assistant(let assistantMsg):
                // Process content blocks
                for content in assistantMsg.message.content {
                    switch content {
                    case .text(let textContent):
                        let text = textContent.text
                        accumulatedText += text
                        continuation.yield(.text(text))

                    case .toolUse(let toolUse):
                        continuation.yield(.toolUse(ToolUseInfo(
                            id: toolUse.id,
                            name: toolUse.name,
                            input: toolUse.input
                        )))

                    case .toolResult(let toolResult):
                        continuation.yield(.toolResult(ToolResultInfo(
                            toolUseId: toolResult.toolUseId,
                            content: toolResult.content
                        )))

                    case .unknown:
                        break
                    }
                }

                // Update session ID if needed
                if self.sessionId == nil {
                    self.sessionId = assistantMsg.sessionId
                }

            case .user:
                // User messages in stream are echoes, skip them
                break

            case .result(let resultMsg):
                // Update session ID
                self.sessionId = resultMsg.sessionId

                // Emit completion
                continuation.yield(.completed(InteractiveResult(from: resultMsg)))
            }
        }

        continuation.finish()
    }
}

// MARK: - Factory Extension

extension ClaudeInteractiveSession {
    /// Creates an interactive session from a ClaudeCodeClient
    /// - Parameters:
    ///   - client: The Claude Code client
    ///   - configuration: The session configuration
    /// - Returns: A new interactive session
    public static func create(
        from client: ClaudeCodeClient,
        configuration: InteractiveSessionConfiguration = .default
    ) throws -> ClaudeInteractiveSession {
        // Access the backend through the client's configuration
        let backendResult = try BackendFactory.createBackendWithResult(for: client.configuration)

        return ClaudeInteractiveSession(
            backend: backendResult.backend,
            clientConfiguration: client.configuration,
            configuration: configuration
        )
    }
}
