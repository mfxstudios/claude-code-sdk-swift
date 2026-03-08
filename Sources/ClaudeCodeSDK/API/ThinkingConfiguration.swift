//
//  ThinkingConfiguration.swift
//  ClaudeCodeSDK
//
//  Extended thinking configuration for Claude API
//

import Foundation

/// Configuration for Claude's extended thinking capability.
///
/// Extended thinking gives Claude a dedicated space for step-by-step reasoning
/// before producing a final response.
public enum ThinkingConfiguration: Sendable, Equatable {
    /// Thinking is disabled
    case disabled

    /// Thinking is enabled with a specific token budget
    case enabled(budgetTokens: Int)

    /// Adaptive thinking — Claude decides dynamically when and how much to think
    case adaptive
}

// MARK: - Codable

extension ThinkingConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "disabled":
            self = .disabled
        case "enabled":
            let budget = try container.decode(Int.self, forKey: .budgetTokens)
            self = .enabled(budgetTokens: budget)
        case "adaptive":
            self = .adaptive
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown thinking type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .disabled:
            try container.encode("disabled", forKey: .type)
        case .enabled(let budgetTokens):
            try container.encode("enabled", forKey: .type)
            try container.encode(budgetTokens, forKey: .budgetTokens)
        case .adaptive:
            try container.encode("adaptive", forKey: .type)
        }
    }
}
