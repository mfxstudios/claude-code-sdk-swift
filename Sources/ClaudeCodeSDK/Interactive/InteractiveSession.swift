//
//  InteractiveSession.swift
//  ClaudeCodeSDK
//
//  Interactive session API for multi-turn conversations
//

import Foundation

// MARK: - Interactive Event

/// Events emitted during an interactive session response
public enum InteractiveEvent: Sendable {
    /// Text chunk from the assistant's response
    case text(String)

    /// Assistant is using a tool
    case toolUse(ToolUseInfo)

    /// Tool execution completed
    case toolResult(ToolResultInfo)

    /// Session initialization info
    case sessionStarted(SessionStartInfo)

    /// Response completed with final result
    case completed(InteractiveResult)

    /// Error occurred during response
    case error(InteractiveError)

    /// Thinking content from extended thinking
    case thinking(String)
}

/// Information about a tool being used
public struct ToolUseInfo: Sendable {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]

    public init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// Information about a tool result
public struct ToolResultInfo: Sendable {
    public let toolUseId: String
    public let content: String?

    public init(toolUseId: String, content: String?) {
        self.toolUseId = toolUseId
        self.content = content
    }
}

/// Information about session start
public struct SessionStartInfo: Sendable {
    public let sessionId: String
    public let tools: [String]
    public let mcpServers: [MCPServer]

    public init(sessionId: String, tools: [String], mcpServers: [MCPServer]) {
        self.sessionId = sessionId
        self.tools = tools
        self.mcpServers = mcpServers
    }
}

/// Final result of an interactive response
public struct InteractiveResult: Sendable {
    public let sessionId: String
    public let text: String
    public let isError: Bool
    public let numTurns: Int
    public let totalCostUsd: Double
    public let durationMs: Int
    public let usage: Usage?

    public init(
        sessionId: String,
        text: String,
        isError: Bool,
        numTurns: Int,
        totalCostUsd: Double,
        durationMs: Int,
        usage: Usage?
    ) {
        self.sessionId = sessionId
        self.text = text
        self.isError = isError
        self.numTurns = numTurns
        self.totalCostUsd = totalCostUsd
        self.durationMs = durationMs
        self.usage = usage
    }

    internal init(from resultMessage: ResultMessage) {
        self.sessionId = resultMessage.sessionId
        self.text = resultMessage.result ?? ""
        self.isError = resultMessage.isError
        self.numTurns = resultMessage.numTurns
        self.totalCostUsd = resultMessage.totalCostUsd
        self.durationMs = resultMessage.durationMs
        self.usage = resultMessage.usage
    }
}

/// Errors specific to interactive sessions
public enum InteractiveError: Error, Sendable, Equatable {
    case sessionNotStarted
    case sessionEnded
    case sendFailed(String)
    case streamError(String)
    case cancelled
}

// MARK: - Interactive Response Stream

/// A stream of events from an interactive response
public struct InteractiveResponseStream: AsyncSequence, Sendable {
    public typealias Element = InteractiveEvent

    private let stream: AsyncThrowingStream<InteractiveEvent, any Swift.Error>

    internal init(_ stream: AsyncThrowingStream<InteractiveEvent, any Swift.Error>) {
        self.stream = stream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: stream.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<InteractiveEvent, any Swift.Error>.AsyncIterator

        init(iterator: AsyncThrowingStream<InteractiveEvent, any Swift.Error>.AsyncIterator) {
            self.iterator = iterator
        }

        public mutating func next() async throws -> InteractiveEvent? {
            try await iterator.next()
        }
    }
}

// MARK: - Convenience Extensions

extension InteractiveResponseStream {
    /// Collects all text from the response
    public func collectText() async throws -> String {
        var text = ""
        for try await event in self {
            if case .text(let chunk) = event {
                text += chunk
            }
        }
        return text
    }

    /// Waits for the completion event and returns the result
    public func waitForCompletion() async throws -> InteractiveResult {
        for try await event in self {
            if case .completed(let result) = event {
                return result
            }
            if case .error(let error) = event {
                throw error
            }
        }
        throw InteractiveError.streamError("Stream ended without completion")
    }

    /// Collects all events into an array
    public func collect() async throws -> [InteractiveEvent] {
        var events: [InteractiveEvent] = []
        for try await event in self {
            events.append(event)
        }
        return events
    }
}

// MARK: - Interactive Session Protocol

/// Protocol for interactive Claude sessions
public protocol InteractiveSessionProtocol: AnyObject, Sendable {
    /// The current session ID (nil if not started)
    var sessionId: String? { get }

    /// Whether the session is currently active
    var isActive: Bool { get }

    /// Sends a message and returns a stream of events
    /// - Parameter message: The message to send
    /// - Returns: A stream of interactive events
    func send(_ message: String) -> InteractiveResponseStream

    /// Sends a message and waits for the complete response
    /// - Parameter message: The message to send
    /// - Returns: The complete result
    func sendAndWait(_ message: String) async throws -> InteractiveResult

    /// Cancels any ongoing request
    func cancel()

    /// Ends the session
    func end() async
}

// MARK: - Interactive Session Configuration

/// Configuration for an interactive session
public struct InteractiveSessionConfiguration: Sendable {
    /// System prompt for the session
    public var systemPrompt: String?

    /// Maximum turns per message (0 for unlimited)
    public var maxTurns: Int

    /// Tools to allow during the session
    public var allowedTools: [String]?

    /// Tools to disallow during the session
    public var disallowedTools: [String]?

    /// MCP permission prompt behavior
    public var permissionPromptTool: PermissionPromptTool

    /// Working directory for the session
    public var workingDirectory: String?

    /// Extended thinking configuration
    public var thinking: ThinkingConfiguration?

    /// Speed mode (normal or fast)
    public var speed: SpeedMode?

    /// Model to use for this session
    public var model: ClaudeModel?

    /// Creates a new interactive session configuration
    public init(
        systemPrompt: String? = nil,
        maxTurns: Int = 0,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil,
        permissionPromptTool: PermissionPromptTool = .auto,
        workingDirectory: String? = nil,
        thinking: ThinkingConfiguration? = nil,
        speed: SpeedMode? = nil,
        model: ClaudeModel? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.maxTurns = maxTurns
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.permissionPromptTool = permissionPromptTool
        self.workingDirectory = workingDirectory
        self.thinking = thinking
        self.speed = speed
        self.model = model
    }

    /// Default configuration
    public static let `default` = InteractiveSessionConfiguration()
}

/// Permission prompt tool behavior
public enum PermissionPromptTool: String, Sendable {
    case auto
    case deny = "deny-all"
    case allow = "allow-all"
}
