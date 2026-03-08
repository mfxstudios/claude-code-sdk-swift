//
//  Messages.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

// MARK: - Usage Statistics

/// Token usage statistics
public struct Usage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let serverToolUse: ServerToolUse?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case serverToolUse = "server_tool_use"
    }
}

/// Server tool use statistics
public struct ServerToolUse: Codable, Sendable, Equatable {
    public let webSearchRequests: Int?

    enum CodingKeys: String, CodingKey {
        case webSearchRequests = "web_search_requests"
    }
}

// MARK: - MCP Server

/// MCP Server information
public struct MCPServer: Codable, Sendable, Equatable {
    public let name: String
    public let status: String
}

// MARK: - System Message Subtypes

/// Subtypes for system messages
public enum SystemSubtype: String, Codable, Sendable {
    case `init`
    case success
    case errorMaxTurns = "error_max_turns"
}

// MARK: - Init System Message

/// Initial system message sent at the start of a conversation
public struct InitSystemMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let sessionId: String
    public let tools: [String]
    public let mcpServers: [MCPServer]

    enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case sessionId = "session_id"
        case tools
        case mcpServers = "mcp_servers"
    }
}

// MARK: - Content Blocks

/// Text content in a message
public struct TextContent: Codable, Sendable, Equatable {
    public let type: String
    public let text: String
}

/// Tool use content in a message
public struct ToolUseContent: Codable, Sendable, Equatable {
    public let type: String
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case input
    }
}

/// Tool result content value - can be a string or an array of content blocks
public enum ToolResultContentValue: Codable, Sendable, Equatable {
    case text(String)
    case blocks([ToolResultBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as string first
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }

        // Try to decode as array of content blocks
        if let blocks = try? container.decode([ToolResultBlock].self) {
            self = .blocks(blocks)
            return
        }

        throw DecodingError.typeMismatch(
            ToolResultContentValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected String or Array of content blocks for tool_result content"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }

    /// Returns the content as a string, joining blocks if necessary
    public var stringValue: String {
        switch self {
        case .text(let text):
            return text
        case .blocks(let blocks):
            return blocks.compactMap { block in
                switch block {
                case .text(let textBlock):
                    return textBlock.text
                case .image:
                    return "[image]"
                case .unknown:
                    return nil
                }
            }.joined(separator: "\n")
        }
    }
}

/// A content block within a tool result
public enum ToolResultBlock: Codable, Sendable, Equatable {
    case text(ToolResultTextBlock)
    case image(ToolResultImageBlock)
    case unknown([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        guard let typeKey = DynamicCodingKeys(stringValue: "type"),
              let type = try? container.decode(String.self, forKey: typeKey) else {
            let dict = try [String: AnyCodable](from: decoder)
            self = .unknown(dict)
            return
        }

        switch type {
        case "text":
            let content = try ToolResultTextBlock(from: decoder)
            self = .text(content)
        case "image":
            let content = try ToolResultImageBlock(from: decoder)
            self = .image(content)
        default:
            let dict = try [String: AnyCodable](from: decoder)
            self = .unknown(dict)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .image(let content):
            try content.encode(to: encoder)
        case .unknown(let dict):
            try dict.encode(to: encoder)
        }
    }
}

/// Text block in a tool result
public struct ToolResultTextBlock: Codable, Sendable, Equatable {
    public let type: String
    public let text: String
}

/// Image block in a tool result
public struct ToolResultImageBlock: Codable, Sendable, Equatable {
    public let type: String
    public let source: ImageSource

    public struct ImageSource: Codable, Sendable, Equatable {
        public let type: String
        public let mediaType: String
        public let data: String

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }
}

/// Thinking content in a message (extended thinking)
public struct ThinkingContent: Codable, Sendable, Equatable {
    public let type: String
    public let thinking: String

    public init(type: String = "thinking", thinking: String) {
        self.type = type
        self.thinking = thinking
    }
}

/// Citation content in a message (source attribution)
public struct CitationContent: Codable, Sendable, Equatable {
    public let type: String
    public let citedText: String
    public let documentTitle: String?
    public let documentIndex: Int?
    public let startCharIndex: Int?
    public let endCharIndex: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case citedText = "cited_text"
        case documentTitle = "document_title"
        case documentIndex = "document_index"
        case startCharIndex = "start_char_index"
        case endCharIndex = "end_char_index"
    }

    public init(
        type: String = "citation",
        citedText: String,
        documentTitle: String? = nil,
        documentIndex: Int? = nil,
        startCharIndex: Int? = nil,
        endCharIndex: Int? = nil
    ) {
        self.type = type
        self.citedText = citedText
        self.documentTitle = documentTitle
        self.documentIndex = documentIndex
        self.startCharIndex = startCharIndex
        self.endCharIndex = endCharIndex
    }
}

/// Tool result content in a message
public struct ToolResultContent: Codable, Sendable, Equatable {
    public let type: String
    public let toolUseId: String
    public let content: ToolResultContentValue?
    public let isError: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    /// Returns the content as a string for convenience
    public var contentString: String? {
        content?.stringValue
    }
}

/// Content block that can be text, tool use, tool result, thinking, or citation
public enum ContentBlock: Codable, Sendable, Equatable {
    case text(TextContent)
    case toolUse(ToolUseContent)
    case toolResult(ToolResultContent)
    case thinking(ThinkingContent)
    case citation(CitationContent)
    case unknown([String: AnyCodable])

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        guard let typeKey = DynamicCodingKeys(stringValue: "type"),
              let type = try? container.decode(String.self, forKey: typeKey) else {
            let dict = try [String: AnyCodable](from: decoder)
            self = .unknown(dict)
            return
        }

        switch type {
        case "text":
            let content = try TextContent(from: decoder)
            self = .text(content)
        case "tool_use":
            let content = try ToolUseContent(from: decoder)
            self = .toolUse(content)
        case "tool_result":
            let content = try ToolResultContent(from: decoder)
            self = .toolResult(content)
        case "thinking":
            let content = try ThinkingContent(from: decoder)
            self = .thinking(content)
        case "citation":
            let content = try CitationContent(from: decoder)
            self = .citation(content)
        default:
            let dict = try [String: AnyCodable](from: decoder)
            self = .unknown(dict)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .toolUse(let content):
            try content.encode(to: encoder)
        case .toolResult(let content):
            try content.encode(to: encoder)
        case .thinking(let content):
            try content.encode(to: encoder)
        case .citation(let content):
            try content.encode(to: encoder)
        case .unknown(let dict):
            try dict.encode(to: encoder)
        }
    }
}

// MARK: - Dynamic Coding Keys

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Message Response

/// The response message from Claude
public struct MessageResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [ContentBlock]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

// MARK: - User Message

/// User message in a conversation
public struct UserMessage: Codable, Sendable {
    public let type: String
    public let sessionId: String
    public let message: UserMessageContent

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case message
    }

    public struct UserMessageContent: Codable, Sendable {
        public let role: String
        public let content: [ContentBlock]
    }
}

// MARK: - Assistant Message

/// Assistant message in a conversation
public struct AssistantMessage: Codable, Sendable {
    public let type: String
    public let sessionId: String
    public let message: MessageResponse

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case message
    }
}

// MARK: - Result Message

/// Final result message from Claude Code
public struct ResultMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let totalCostUsd: Double
    public let durationMs: Int
    public let durationApiMs: Int
    public let isError: Bool
    public let numTurns: Int
    public let result: String?
    public let sessionId: String
    public let usage: Usage?

    enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case totalCostUsd = "total_cost_usd"
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case isError = "is_error"
        case numTurns = "num_turns"
        case result
        case sessionId = "session_id"
        case usage
    }

    /// Returns a formatted description of the result message
    public func description() -> String {
        let resultText = result ?? "No result available"
        let durationSeconds = Double(durationMs) / 1000.0
        let durationApiSeconds = Double(durationApiMs) / 1000.0

        return """
        Result: \(resultText)

        Subtype: \(subtype)
        Cost: $\(String(format: "%.6f", totalCostUsd))
        Duration: \(String(format: "%.2f", durationSeconds))s
        API Duration: \(String(format: "%.2f", durationApiSeconds))s
        Error: \(isError ? "Yes" : "No")
        Number of Turns: \(numTurns)
        """
    }
}

// MARK: - Session Info

/// Information about a Claude Code session
public struct SessionInfo: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let createdAt: Date?
    public let lastActiveAt: Date?
    public let summary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case summary
    }
}

// MARK: - Executed Command Info

/// Debug information about executed commands
public struct ExecutedCommandInfo: Sendable {
    public let command: String
    public let arguments: [String]
    public let workingDirectory: String?
    public let environment: [String: String]
    public let exitCode: Int32?
    public let startTime: Date
    public let endTime: Date?

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    public init(
        command: String,
        arguments: [String],
        workingDirectory: String?,
        environment: [String: String],
        exitCode: Int32? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.exitCode = exitCode
        self.startTime = startTime
        self.endTime = endTime
    }
}
