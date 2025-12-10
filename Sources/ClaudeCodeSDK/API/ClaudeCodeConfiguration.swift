//
//  ClaudeCodeConfiguration.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// The backend type for Claude Code execution
public enum BackendType: String, Sendable, Equatable {
    /// Automatically detect the best available backend
    case auto

    /// Headless backend using `claude -p` CLI subprocess
    case headless

    /// Agent SDK backend using Node.js wrapper around @anthropic-ai/claude-agent-sdk
    case agentSDK
}

/// Configuration for the Claude Code client
public struct ClaudeCodeConfiguration: Sendable, Equatable {
    /// The backend type to use for execution
    public var backend: BackendType

    /// The command to execute (default: "claude") - used for headless backend
    public var command: String

    /// Path to Node.js executable (optional, auto-detected if not provided) - used for agentSDK backend
    public var nodeExecutable: String?

    /// Path to sdk-wrapper.mjs script (optional, uses bundled resource if not provided) - used for agentSDK backend
    public var sdkWrapperPath: String?

    /// The working directory for command execution
    public var workingDirectory: String?

    /// Additional environment variables to set
    public var environment: [String: String]

    /// Enable debug logging
    public var enableDebugLogging: Bool

    /// Additional paths to add to PATH environment variable
    public var additionalPaths: [String]

    /// Optional suffix to append after the command (e.g., "--" for argument delimiter)
    public var commandSuffix: String?

    /// List of tools that should be disallowed for Claude to use
    public var disallowedTools: [String]?

    /// Creates a new configuration with the specified parameters
    public init(
        backend: BackendType = .auto,
        command: String = "claude",
        nodeExecutable: String? = nil,
        sdkWrapperPath: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        enableDebugLogging: Bool = false,
        additionalPaths: [String] = ClaudeCodeConfiguration.defaultPaths,
        commandSuffix: String? = nil,
        disallowedTools: [String]? = nil
    ) {
        self.backend = backend
        self.command = command
        self.nodeExecutable = nodeExecutable
        self.sdkWrapperPath = sdkWrapperPath
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.enableDebugLogging = enableDebugLogging
        self.additionalPaths = additionalPaths
        self.commandSuffix = commandSuffix
        self.disallowedTools = disallowedTools
    }

    /// Default configuration
    public static let `default` = ClaudeCodeConfiguration()

    /// Default paths to search for executables
    public static var defaultPaths: [String] {
        #if os(macOS)
        return [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        #elseif os(Linux)
        return [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/snap/bin"
        ]
        #else
        return [
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        #endif
    }
}

extension ClaudeCodeConfiguration {
    /// Builds the complete environment dictionary for process execution
    public func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        // Add additional paths to PATH
        if !additionalPaths.isEmpty {
            let additionalPathString = additionalPaths.joined(separator: ":")
            if let currentPath = env["PATH"] {
                env["PATH"] = "\(additionalPathString):\(currentPath)"
            } else {
                env["PATH"] = additionalPathString
            }
        }

        // Apply custom environment variables
        for (key, value) in environment {
            env[key] = value
        }

        return env
    }
}
