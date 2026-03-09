//
//  ToolPermission.swift
//  ClaudeCodeSDK
//
//  Types for bidirectional IPC: user questions and tool permission requests
//

import Foundation

// MARK: - Input Request (Node.js → Swift)

/// A request from the SDK wrapper for user input (question or tool permission)
public struct InputRequest: Codable, Sendable {
    public let type: String
    public let requestId: String
    public let inputType: String
    public let payload: InputRequestPayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case inputType = "input_type"
        case payload
    }
}

/// Payload for an input request — either a user question or a tool permission request
public enum InputRequestPayload: Codable, Sendable {
    case userQuestion(UserQuestionRequest)
    case toolPermission(ToolPermissionRequest)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try user question first
        if let uq = try? container.decode(UserQuestionRequest.self) {
            self = .userQuestion(uq)
            return
        }
        // Try tool permission
        if let tp = try? container.decode(ToolPermissionRequest.self) {
            self = .toolPermission(tp)
            return
        }
        throw DecodingError.typeMismatch(
            InputRequestPayload.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Cannot decode InputRequestPayload"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .userQuestion(let uq):
            try container.encode(uq)
        case .toolPermission(let tp):
            try container.encode(tp)
        }
    }
}

// MARK: - User Question Types

/// Claude is asking the user clarifying questions via AskUserQuestion tool
public struct UserQuestionRequest: Codable, Sendable, Equatable {
    public let questions: [UserQuestion]

    public init(questions: [UserQuestion]) {
        self.questions = questions
    }
}

/// A single question from Claude to the user
public struct UserQuestion: Codable, Sendable, Equatable {
    public let question: String
    public let options: [UserQuestionOption]
    public let multiSelect: Bool

    enum CodingKeys: String, CodingKey {
        case question
        case options
        case multiSelect = "multi_select"
    }

    public init(question: String, options: [UserQuestionOption], multiSelect: Bool = false) {
        self.question = question
        self.options = options
        self.multiSelect = multiSelect
    }
}

/// An option for a user question
public struct UserQuestionOption: Codable, Sendable, Equatable {
    public let label: String
    public let description: String

    public init(label: String, description: String) {
        self.label = label
        self.description = description
    }
}

// MARK: - Input Response (Swift → Node.js)

/// Response to a user question, sent back via stdin
public struct UserQuestionResponse: Codable, Sendable {
    public let requestId: String
    public let type: String
    public let answers: [String: String]

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case type
        case answers
    }

    public init(requestId: String, answers: [String: String]) {
        self.requestId = requestId
        self.type = "input_response"
        self.answers = answers
    }
}

// MARK: - Tool Permission Types

/// Claude is requesting permission to use a tool
public struct ToolPermissionRequest: Codable, Sendable, Equatable {
    public let toolName: String
    public let input: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input
    }

    public init(toolName: String, input: [String: AnyCodable]) {
        self.toolName = toolName
        self.input = input
    }
}

/// Decision for a tool permission request
public enum ToolPermissionDecision: String, Codable, Sendable {
    case allow
    case deny
}

/// Response to a tool permission request, sent back via stdin
public struct ToolPermissionResponse: Codable, Sendable {
    public let requestId: String
    public let type: String
    public let decision: ToolPermissionDecision
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case type
        case decision
        case reason
    }

    public init(requestId: String, decision: ToolPermissionDecision, reason: String? = nil) {
        self.requestId = requestId
        self.type = "input_response"
        self.decision = decision
        self.reason = reason
    }
}

// MARK: - Handler Type Aliases

/// Handler called when Claude asks the user clarifying questions.
///
/// The handler receives an array of questions and should return a dictionary
/// mapping question text to the selected answer label.
///
/// ```swift
/// let handler: UserQuestionHandler = { questions in
///     var answers: [String: String] = [:]
///     for q in questions {
///         // Present to user and collect answer
///         answers[q.question] = selectedOptionLabel
///     }
///     return answers
/// }
/// ```
public typealias UserQuestionHandler = @Sendable ([UserQuestion]) async -> [String: String]

/// Handler called when Claude requests permission to use a tool.
///
/// The handler receives the tool permission request and should return
/// a tuple of (decision, optional reason).
///
/// ```swift
/// let handler: ToolPermissionHandler = { request in
///     if request.toolName == "Bash" {
///         return (.deny, "Bash not allowed")
///     }
///     return (.allow, nil)
/// }
/// ```
public typealias ToolPermissionHandler = @Sendable (ToolPermissionRequest) async -> (ToolPermissionDecision, String?)
