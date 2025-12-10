//
//  ClaudeCodeOutputFormat.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Output format for Claude Code responses
public enum ClaudeCodeOutputFormat: String, Sendable {
    /// Plain text output
    case text

    /// JSON structured output
    case json

    /// Streaming JSON output (for real-time responses)
    case streamJson = "stream-json"

    /// Returns the CLI flag for this output format
    public var cliFlag: String {
        switch self {
        case .text:
            return "--output-format=text"
        case .json:
            return "--output-format=json"
        case .streamJson:
            return "--output-format=stream-json"
        }
    }
}
