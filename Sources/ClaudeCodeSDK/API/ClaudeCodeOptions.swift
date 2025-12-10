//
//  ClaudeCodeOptions.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Permission mode for Claude Code execution
public enum PermissionMode: String, Sendable, Codable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
}

/// Configuration for MCP (Model Context Protocol) servers
public struct McpServerConfiguration: Sendable, Codable, Equatable {
    public let command: String
    public let args: [String]?
    public let env: [String: String]?

    public init(command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}

/// Options for Claude Code execution
public struct ClaudeCodeOptions: Sendable {
    /// List of tools that Claude is allowed to use
    public var allowedTools: [String]?

    /// System prompt to append to the default system prompt
    public var appendSystemPrompt: String?

    /// Custom system prompt to replace the default
    public var systemPrompt: String?

    /// List of tools that should be disallowed
    public var disallowedTools: [String]?

    /// Maximum number of thinking tokens for extended reasoning
    public var maxThinkingTokens: Int?

    /// Maximum number of conversation turns
    public var maxTurns: Int?

    /// MCP servers to use
    public var mcpServers: [String: McpServerConfiguration]?

    /// Permission mode for the execution
    public var permissionMode: PermissionMode?

    /// Name of the permission prompt tool
    public var permissionPromptToolName: String?

    /// Whether to continue the most recent conversation
    public var continueConversation: Bool?

    /// Session ID to resume
    public var resume: String?

    /// Model to use for the request
    public var model: String?

    /// Timeout for the operation in seconds
    public var timeout: TimeInterval?

    /// Path to MCP configuration file
    public var mcpConfigPath: String?

    /// Whether to enable verbose output
    public var verbose: Bool

    /// Creates new options with the specified parameters
    public init(
        allowedTools: [String]? = nil,
        appendSystemPrompt: String? = nil,
        systemPrompt: String? = nil,
        disallowedTools: [String]? = nil,
        maxThinkingTokens: Int? = nil,
        maxTurns: Int? = nil,
        mcpServers: [String: McpServerConfiguration]? = nil,
        permissionMode: PermissionMode? = nil,
        permissionPromptToolName: String? = nil,
        continueConversation: Bool? = nil,
        resume: String? = nil,
        model: String? = nil,
        timeout: TimeInterval? = nil,
        mcpConfigPath: String? = nil,
        verbose: Bool = false
    ) {
        self.allowedTools = allowedTools
        self.appendSystemPrompt = appendSystemPrompt
        self.systemPrompt = systemPrompt
        self.disallowedTools = disallowedTools
        self.maxThinkingTokens = maxThinkingTokens
        self.maxTurns = maxTurns
        self.mcpServers = mcpServers
        self.permissionMode = permissionMode
        self.permissionPromptToolName = permissionPromptToolName
        self.continueConversation = continueConversation
        self.resume = resume
        self.model = model
        self.timeout = timeout
        self.mcpConfigPath = mcpConfigPath
        self.verbose = verbose
    }

    /// Escapes a string for safe shell usage
    internal static func shellEscape(_ string: String) -> String {
        // Use single quotes and escape any single quotes within
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    /// Converts options to command-line arguments
    public func toCommandArgs() -> [String] {
        var args: [String] = []

        if let allowedTools = allowedTools, !allowedTools.isEmpty {
            for tool in allowedTools {
                args.append("--allowedTools")
                args.append(tool)
            }
        }

        if let disallowedTools = disallowedTools, !disallowedTools.isEmpty {
            for tool in disallowedTools {
                args.append("--disallowedTools")
                args.append(tool)
            }
        }

        if let systemPrompt = systemPrompt {
            args.append("--system-prompt")
            args.append(systemPrompt)
        }

        if let appendSystemPrompt = appendSystemPrompt {
            args.append("--append-system-prompt")
            args.append(appendSystemPrompt)
        }

        if let maxThinkingTokens = maxThinkingTokens {
            args.append("--max-thinking-tokens")
            args.append(String(maxThinkingTokens))
        }

        if let maxTurns = maxTurns {
            args.append("--max-turns")
            args.append(String(maxTurns))
        }

        if let permissionMode = permissionMode {
            args.append("--permission-mode")
            args.append(permissionMode.rawValue)
        }

        if let model = model {
            args.append("--model")
            args.append(model)
        }

        if let mcpConfigPath = mcpConfigPath {
            args.append("--mcp-config")
            args.append(mcpConfigPath)
        }

        if continueConversation == true {
            args.append("--continue")
        }

        if let resume = resume {
            args.append("--resume")
            args.append(resume)
        }

        if verbose {
            args.append("--verbose")
        }

        return args
    }
}
