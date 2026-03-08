//
//  BetaFeature.swift
//  ClaudeCodeSDK
//
//  Beta feature flags for Claude API
//

import Foundation

/// Beta features that can be enabled via API headers.
///
/// Beta features require the `anthropic-beta` header to be set with the
/// appropriate feature identifier string.
public enum BetaFeature: String, Sendable, Equatable, Hashable, Codable {
    /// Context compaction for long conversations
    case compaction = "compact-2026-01-12"

    /// 1M token extended context window
    case extendedContext1M = "context-1m-2025-08-07"

    /// Interleaved thinking between tool calls
    case interleavedThinking = "interleaved-thinking-2025-05-14"

    /// Computer use tool support
    case computerUse = "computer-use-2025-01-24"

    /// Search results citations
    case searchResultsCitations = "search-results-2025-06-09"

    /// Skills API
    case skills = "skills-2025-10-02"
}
