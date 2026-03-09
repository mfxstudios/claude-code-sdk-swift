//
//  ClaudeCodeOptions.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Permission mode for Claude Code execution
///
/// Controls how Claude handles permission prompts for tool use:
/// - `default`: Standard permission prompting behavior
/// - `acceptEdits`: Auto-approve file edits, prompt for other tools
/// - `plan`: Plan mode — Claude plans but doesn't execute changes
/// - `bypassPermissions`: Bypass all permission checks entirely
public enum PermissionMode: String, Sendable, Codable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case plan = "plan"
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
    /// List of tools that Claude is allowed to use.
    ///
    /// Supports per-tool permission rules with patterns:
    /// ```swift
    /// options.allowedTools = [
    ///     .tool("Read"),                         // Allow Read tool
    ///     .tool("Bash", argument: "git *"),       // Allow Bash for git commands only
    ///     .tool("Write", argument: "/src/*"),     // Allow Write scoped to /src/
    ///     .bashGit,                               // Shorthand for Bash(git *)
    ///     "Grep",                                 // String literals work too
    /// ]
    /// ```
    public var allowedTools: [ToolPermissionRule]?

    /// System prompt to append to the default system prompt
    public var appendSystemPrompt: String?

    /// Custom system prompt to replace the default
    public var systemPrompt: String?

    /// List of tools that should be disallowed.
    ///
    /// Supports per-tool permission rules with patterns:
    /// ```swift
    /// options.disallowedTools = [
    ///     .tool("Bash"),                          // Deny all Bash usage
    ///     .tool("Write", argument: "/etc/*"),      // Deny writes to /etc/
    /// ]
    /// ```
    public var disallowedTools: [ToolPermissionRule]?

    /// Maximum number of thinking tokens for extended reasoning
    @available(*, deprecated, message: "Use 'thinking' property with ThinkingConfiguration instead")
    public var maxThinkingTokens: Int? {
        get { _maxThinkingTokens }
        set { _maxThinkingTokens = newValue }
    }

    // Backing storage to avoid deprecation warnings internally
    internal var _maxThinkingTokens: Int?

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
    public var model: ClaudeModel?

    /// Timeout for the operation in seconds
    public var timeout: TimeInterval?

    /// Path to MCP configuration file
    public var mcpConfigPath: String?

    /// Whether to enable verbose output
    public var verbose: Bool

    /// Extended thinking configuration
    public var thinking: ThinkingConfiguration?

    /// Speed mode (normal or fast) for supported models
    public var speed: SpeedMode?

    /// Beta features to enable via API headers
    public var betaFeatures: Set<BetaFeature>?

    /// Structured output configuration
    public var outputConfig: OutputConfig?

    /// Whether interactive mode is enabled (bidirectional IPC for user questions and tool permissions).
    /// Automatically set to `true` when `userQuestionHandler` or `toolPermissionHandler` is provided.
    public var interactive: Bool

    /// Handler called when Claude asks the user clarifying questions via AskUserQuestion.
    /// Only used with the Agent SDK backend.
    public var userQuestionHandler: UserQuestionHandler?

    /// Handler called when Claude requests permission to use a tool.
    /// Only used with the Agent SDK backend.
    public var toolPermissionHandler: ToolPermissionHandler?

    /// Creates new options with the specified parameters
    public init(
        allowedTools: [ToolPermissionRule]? = nil,
        appendSystemPrompt: String? = nil,
        systemPrompt: String? = nil,
        disallowedTools: [ToolPermissionRule]? = nil,
        maxTurns: Int? = nil,
        mcpServers: [String: McpServerConfiguration]? = nil,
        permissionMode: PermissionMode? = nil,
        permissionPromptToolName: String? = nil,
        continueConversation: Bool? = nil,
        resume: String? = nil,
        model: ClaudeModel? = nil,
        timeout: TimeInterval? = nil,
        mcpConfigPath: String? = nil,
        verbose: Bool = false,
        thinking: ThinkingConfiguration? = nil,
        speed: SpeedMode? = nil,
        betaFeatures: Set<BetaFeature>? = nil,
        outputConfig: OutputConfig? = nil,
        interactive: Bool = false,
        userQuestionHandler: UserQuestionHandler? = nil,
        toolPermissionHandler: ToolPermissionHandler? = nil
    ) {
        self.allowedTools = allowedTools
        self.appendSystemPrompt = appendSystemPrompt
        self.systemPrompt = systemPrompt
        self.disallowedTools = disallowedTools
        self._maxThinkingTokens = nil
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
        self.thinking = thinking
        self.speed = speed
        self.betaFeatures = betaFeatures
        self.outputConfig = outputConfig
        self.interactive = interactive
        self.userQuestionHandler = userQuestionHandler
        self.toolPermissionHandler = toolPermissionHandler
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
                args.append(tool.rule)
            }
        }

        if let disallowedTools = disallowedTools, !disallowedTools.isEmpty {
            for tool in disallowedTools {
                args.append("--disallowedTools")
                args.append(tool.rule)
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

        // Thinking configuration takes precedence over legacy maxThinkingTokens
        if let thinking = thinking {
            switch thinking {
            case .enabled(let budgetTokens):
                args.append("--max-thinking-tokens")
                args.append(String(budgetTokens))
            case .adaptive:
                args.append("--thinking-mode")
                args.append("adaptive")
            case .disabled:
                break
            }
        } else if let maxThinkingTokens = _maxThinkingTokens {
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

        if let permissionPromptToolName = permissionPromptToolName {
            args.append("--permission-prompt-tool")
            args.append(permissionPromptToolName)
        }

        if let model = model {
            args.append("--model")
            args.append(model.rawValue)
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

        if let speed = speed, speed == .fast {
            args.append("--fast")
        }

        if verbose {
            args.append("--verbose")
        }

        return args
    }
}
