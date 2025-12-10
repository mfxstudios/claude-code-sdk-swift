//
//  ClaudeCodeProtocol.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Protocol defining the Claude Code interface
public protocol ClaudeCodeProtocol: Sendable {
    /// The configuration for this client
    var configuration: ClaudeCodeConfiguration { get }

    /// Debug information about the last executed command
    var lastExecutedCommandInfo: ExecutedCommandInfo? { get }

    /// Runs a single prompt and returns the result
    /// - Parameters:
    ///   - prompt: The prompt to send to Claude
    ///   - outputFormat: The desired output format
    ///   - options: Additional options for the request
    /// - Returns: The result from Claude Code
    func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Runs with stdin content (for piping data)
    /// - Parameters:
    ///   - stdinContent: The content to send via stdin
    ///   - outputFormat: The desired output format
    ///   - options: Additional options for the request
    /// - Returns: The result from Claude Code
    func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Continues the most recent conversation
    /// - Parameters:
    ///   - prompt: Optional additional prompt
    ///   - outputFormat: The desired output format
    ///   - options: Additional options for the request
    /// - Returns: The result from Claude Code
    func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Resumes a specific conversation by session ID
    /// - Parameters:
    ///   - sessionId: The session ID to resume
    ///   - prompt: Optional additional prompt
    ///   - outputFormat: The desired output format
    ///   - options: Additional options for the request
    /// - Returns: The result from Claude Code
    func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult

    /// Lists available sessions
    /// - Returns: Array of session information
    func listSessions() async throws -> [SessionInfo]

    /// Cancels any ongoing operation
    func cancel()

    /// Validates that the Claude Code command is available
    /// - Parameter command: The command to validate
    /// - Returns: Whether the command is available
    func validateCommand(_ command: String) async throws -> Bool
}

// MARK: - Default Implementations

extension ClaudeCodeProtocol {
    /// Runs a single prompt with default options
    public func run(_ prompt: String) async throws -> ClaudeCodeResult {
        try await runSinglePrompt(prompt: prompt, outputFormat: .json, options: nil)
    }

    /// Runs a single prompt and returns the text result
    public func runText(_ prompt: String) async throws -> String {
        let result = try await runSinglePrompt(prompt: prompt, outputFormat: .text, options: nil)
        guard case .text(let text) = result else {
            throw ClaudeCodeError.invalidOutput("Expected text result")
        }
        return text
    }

    /// Runs a single prompt and returns a streaming response
    public func runStream(_ prompt: String, options: ClaudeCodeOptions? = nil) async throws -> ClaudeCodeStream {
        let result = try await runSinglePrompt(prompt: prompt, outputFormat: .streamJson, options: options)
        guard case .stream(let stream) = result else {
            throw ClaudeCodeError.invalidOutput("Expected stream result")
        }
        return stream
    }
}
