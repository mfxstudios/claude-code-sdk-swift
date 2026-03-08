//
//  SpeedMode.swift
//  ClaudeCodeSDK
//
//  Speed/fast mode configuration for Claude API
//

import Foundation

/// Speed mode for Claude API requests.
///
/// Fast mode delivers up to 2.5x faster output for supported models (e.g. Opus 4.6)
/// at premium pricing.
public enum SpeedMode: String, Sendable, Codable {
    /// Normal speed (default)
    case normal = "normal"

    /// Fast mode — 2.5x faster output
    case fast = "fast"
}
