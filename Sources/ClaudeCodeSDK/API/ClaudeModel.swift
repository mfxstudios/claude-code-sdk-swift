//
//  ClaudeModel.swift
//  ClaudeCodeSDK
//
//  Model identifiers for Claude API
//

import Foundation

/// A Claude model identifier. Uses a struct with static constants so users
/// can also pass arbitrary model strings via `ExpressibleByStringLiteral`.
public struct ClaudeModel: RawRepresentable, Sendable, Equatable, Hashable, Codable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    // MARK: - Opus Family

    /// Claude Opus 4.6
    public static let opus4_6 = ClaudeModel(rawValue: "claude-opus-4-6-20260205")

    /// Claude Opus 4.5
    public static let opus4_5 = ClaudeModel(rawValue: "claude-opus-4-5-20251124")

    /// Claude Opus 4.1
    public static let opus4_1 = ClaudeModel(rawValue: "claude-opus-4-1-20250805")

    /// Claude Opus 4
    public static let opus4 = ClaudeModel(rawValue: "claude-opus-4-20250522")

    // MARK: - Sonnet Family

    /// Claude Sonnet 4.6
    public static let sonnet4_6 = ClaudeModel(rawValue: "claude-sonnet-4-6-20260217")

    /// Claude Sonnet 4.5
    public static let sonnet4_5 = ClaudeModel(rawValue: "claude-sonnet-4-5-20250514")

    /// Claude Sonnet 4
    public static let sonnet4 = ClaudeModel(rawValue: "claude-sonnet-4-20250514")

    // MARK: - Haiku Family

    /// Claude Haiku 4.5
    public static let haiku4_5 = ClaudeModel(rawValue: "claude-haiku-4-5-20251001")

    // MARK: - Aliases (latest in each tier)

    /// Latest Opus model
    public static let latestOpus = opus4_6

    /// Latest Sonnet model
    public static let latestSonnet = sonnet4_6

    /// Latest Haiku model
    public static let latestHaiku = haiku4_5

    // MARK: - Deprecation

    /// Set of known deprecated model identifiers
    public static let deprecated: Set<ClaudeModel> = [
        ClaudeModel(rawValue: "claude-3-opus-20240229"),
        ClaudeModel(rawValue: "claude-3-sonnet-20240229"),
        ClaudeModel(rawValue: "claude-3-haiku-20240307"),
        ClaudeModel(rawValue: "claude-3-5-sonnet-20240620"),
        ClaudeModel(rawValue: "claude-3-5-sonnet-20241022"),
        ClaudeModel(rawValue: "claude-3-5-haiku-20241022"),
    ]

    /// Whether this model has been deprecated by Anthropic
    public var isDeprecated: Bool {
        Self.deprecated.contains(self)
    }
}
