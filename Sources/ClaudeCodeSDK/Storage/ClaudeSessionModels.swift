//
//  ClaudeSessionModels.swift
//  ClaudeCodeSDK
//
//  Data models for Claude session storage
//

import Foundation

/// Represents a stored Claude session
public struct ClaudeStoredSession: Sendable, Identifiable, Codable {
    /// Unique session identifier (UUID)
    public let id: String

    /// The project path this session belongs to (decoded from folder name)
    public let projectPath: String

    /// Git branch active during the session (if any)
    public let gitBranch: String?

    /// When the session was created
    public let createdAt: Date

    /// When the session was last accessed
    public let lastAccessedAt: Date

    /// The messages in this session
    public let messages: [ClaudeStoredMessage]

    /// Session summary (if available)
    public let summary: String?

    /// Claude Code version used
    public let version: String?

    /// Working directory for the session
    public let cwd: String?

    public init(
        id: String,
        projectPath: String,
        gitBranch: String? = nil,
        createdAt: Date,
        lastAccessedAt: Date,
        messages: [ClaudeStoredMessage],
        summary: String? = nil,
        version: String? = nil,
        cwd: String? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.gitBranch = gitBranch
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.messages = messages
        self.summary = summary
        self.version = version
        self.cwd = cwd
    }
}

/// Represents a message within a stored session
public struct ClaudeStoredMessage: Sendable, Identifiable, Codable {
    /// Unique message identifier (UUID)
    public let id: String

    /// Parent message UUID (for threading)
    public let parentId: String?

    /// Message role (user, assistant, system)
    public let role: ClaudeMessageRole

    /// Message content
    public let content: String

    /// When the message was created
    public let timestamp: Date

    /// Whether this is a sidechain message
    public let isSidechain: Bool

    /// The model used (for assistant messages)
    public let model: String?

    /// Token usage information
    public let usage: ClaudeTokenUsage?

    public init(
        id: String,
        parentId: String? = nil,
        role: ClaudeMessageRole,
        content: String,
        timestamp: Date,
        isSidechain: Bool = false,
        model: String? = nil,
        usage: ClaudeTokenUsage? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isSidechain = isSidechain
        self.model = model
        self.usage = usage
    }
}

/// Message role enumeration
public enum ClaudeMessageRole: String, Sendable, Codable {
    case user
    case assistant
    case system
}

/// Token usage information
public struct ClaudeTokenUsage: Sendable, Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

/// Represents a Claude project (directory with sessions)
public struct ClaudeProject: Sendable, Identifiable, Codable {
    /// The encoded folder name
    public let id: String

    /// The decoded project path
    public let path: String

    /// Number of sessions in this project
    public let sessionCount: Int

    /// Last activity time across all sessions
    public let lastActivityAt: Date?

    public init(id: String, path: String, sessionCount: Int, lastActivityAt: Date? = nil) {
        self.id = id
        self.path = path
        self.sessionCount = sessionCount
        self.lastActivityAt = lastActivityAt
    }
}

// MARK: - Internal Parsing Models

/// Raw JSONL entry types for parsing session files
internal enum SessionEntryType: String, Codable {
    case user
    case assistant
    case system
    case summary
    case queueOperation = "queue-operation"
}

/// Raw session entry from JSONL file
internal struct RawSessionEntry: Codable {
    let type: String
    let uuid: String?
    let parentUuid: String?
    let sessionId: String?
    let timestamp: String?
    let isSidechain: Bool?
    let version: String?
    let gitBranch: String?
    let cwd: String?
    let message: RawMessage?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case type, uuid, sessionId, timestamp, isSidechain, version, gitBranch, cwd, message, summary
        case parentUuid = "parentUuid"
    }
}

/// Raw message content from JSONL
internal struct RawMessage: Codable {
    let role: String?
    let content: RawMessageContent?
    let model: String?
    let usage: RawUsage?

    enum CodingKeys: String, CodingKey {
        case role, content, model, usage
    }
}

/// Raw message content - can be string or array
internal enum RawMessageContent: Codable {
    case string(String)
    case array([RawContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([RawContentBlock].self) {
            self = .array(arrayValue)
            return
        }

        throw DecodingError.typeMismatch(
            RawMessageContent.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Array")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }

    /// Extract text content from the message
    var textContent: String {
        switch self {
        case .string(let text):
            return text
        case .array(let blocks):
            return blocks.compactMap { block -> String? in
                if case .text(let text) = block.type {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }
}

/// Content block type
internal struct RawContentBlock: Codable {
    let type: ContentBlockType

    enum ContentBlockType: Codable {
        case text(String)
        case toolUse(id: String, name: String)
        case toolResult(toolUseId: String)
        case other

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "tool_use":
                let id = try container.decode(String.self, forKey: .id)
                let name = try container.decode(String.self, forKey: .name)
                self = .toolUse(id: id, name: name)
            case "tool_result":
                let toolUseId = try container.decode(String.self, forKey: .toolUseId)
                self = .toolResult(toolUseId: toolUseId)
            default:
                self = .other
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .toolUse(let id, let name):
                try container.encode("tool_use", forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
            case .toolResult(let toolUseId):
                try container.encode("tool_result", forKey: .type)
                try container.encode(toolUseId, forKey: .toolUseId)
            case .other:
                try container.encode("other", forKey: .type)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type, text, id, name
            case toolUseId = "tool_use_id"
        }
    }
}

/// Raw usage data
internal struct RawUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}
