//
//  ClaudeCodeSDK.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//  Supports macOS and Linux with async/await and AsyncSequence streaming
//

@_exported import Foundation

// Namespace for SDK types
public enum ClaudeCode {
    public typealias Client = ClaudeCodeClient
    public typealias Configuration = ClaudeCodeConfiguration
    public typealias Options = ClaudeCodeOptions
    public typealias OutputFormat = ClaudeCodeOutputFormat
    public typealias Result = ClaudeCodeResult
    public typealias SDKError = ClaudeCodeError
    public typealias Stream = ClaudeCodeStream
    public typealias Chunk = ResponseChunk
}
