//
//  BackendDetector.swift
//  ClaudeCodeSDK
//
//  Automatic backend detection for Claude Code SDK
//

import Foundation

/// Utility for detecting available backends
public struct BackendDetector: Sendable {
    private let configuration: ClaudeCodeConfiguration

    /// Detection result containing available backends and recommendation
    public struct DetectionResult: Sendable {
        /// Whether the headless backend (Claude CLI) is available
        public let headlessAvailable: Bool

        /// Whether the Agent SDK backend is available (Node.js + @anthropic-ai/claude-agent-sdk npm package)
        public let agentSDKAvailable: Bool

        /// Path to the Claude CLI command (if found)
        public let claudeCliPath: String?

        /// Path to Node.js executable (if found)
        public let nodePath: String?

        /// Whether the @anthropic-ai/claude-agent-sdk npm package is installed
        public let claudeCodePackageInstalled: Bool

        /// The recommended backend based on availability
        public var recommendedBackend: BackendType {
            if agentSDKAvailable {
                return .agentSDK
            } else if headlessAvailable {
                return .headless
            } else {
                // Default to headless even if not detected
                // (user might have it in a non-standard location)
                return .headless
            }
        }

        /// Whether any backend is available
        public var anyBackendAvailable: Bool {
            headlessAvailable || agentSDKAvailable
        }

        /// Human-readable description of detection results
        public var description: String {
            var lines: [String] = []

            if headlessAvailable {
                lines.append("✓ Headless backend available" + (claudeCliPath.map { " (\($0))" } ?? ""))
            } else {
                lines.append("✗ Headless backend not found (install: curl -fsSL https://claude.ai/install.sh | bash)")
            }

            if agentSDKAvailable {
                lines.append("✓ Agent SDK backend available" + (nodePath.map { " (node: \($0))" } ?? ""))
            } else if nodePath != nil && !claudeCodePackageInstalled {
                lines.append("✗ Agent SDK backend not available (Node.js found but @anthropic-ai/claude-agent-sdk not installed)")
            } else {
                lines.append("✗ Agent SDK backend not found (requires Node.js and @anthropic-ai/claude-agent-sdk)")
            }

            lines.append("→ Recommended: \(recommendedBackend.rawValue)")

            return lines.joined(separator: "\n")
        }
    }

    /// Creates a new backend detector
    /// - Parameter configuration: Configuration to use for detection
    public init(configuration: ClaudeCodeConfiguration = .default) {
        self.configuration = configuration
    }

    /// Detects available backends synchronously
    /// - Returns: Detection result with available backends
    public func detect() -> DetectionResult {
        let claudePath = findClaudeCli()
        let nodePath = findNode()
        let packageInstalled = nodePath != nil ? checkClaudeCodePackage(nodePath: nodePath) : false

        return DetectionResult(
            headlessAvailable: claudePath != nil,
            agentSDKAvailable: nodePath != nil && packageInstalled,
            claudeCliPath: claudePath,
            nodePath: nodePath,
            claudeCodePackageInstalled: packageInstalled
        )
    }

    /// Detects available backends asynchronously with validation
    /// - Returns: Detection result with available backends
    public func detectAsync() async -> DetectionResult {
        async let claudeCheck = validateClaudeCli()
        async let nodeCheck = validateNodeAndPackage()

        let (claudeResult, nodeResult) = await (claudeCheck, nodeCheck)

        return DetectionResult(
            headlessAvailable: claudeResult.available,
            agentSDKAvailable: nodeResult.available && nodeResult.packageInstalled,
            claudeCliPath: claudeResult.path,
            nodePath: nodeResult.path,
            claudeCodePackageInstalled: nodeResult.packageInstalled
        )
    }

    // MARK: - Private Detection Methods

    private func findClaudeCli() -> String? {
        // Check if custom command is specified and exists
        if configuration.command != "claude" {
            if let path = findExecutable(configuration.command) {
                return path
            }
        }

        // Get home directory for user-local paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Check common locations for claude
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude",
            "\(homeDir)/.local/bin/claude"  // User-local installation
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find in PATH
        return findExecutable("claude")
    }

    private func findNode() -> String? {
        // Check if custom node executable is specified
        if let customNode = configuration.nodeExecutable,
           FileManager.default.fileExists(atPath: customNode) {
            return customNode
        }

        // First try to find in PATH - this respects user's environment setup
        if let pathNode = findExecutable("node") {
            return pathNode
        }

        // Fall back to common locations for node
        let possiblePaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func findExecutable(_ name: String) -> String? {
        let process = Process()
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(name)"]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "which \(name)"]
        #endif

        process.environment = configuration.buildEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Ignore errors, return nil
        }

        return nil
    }

    /// Checks if @anthropic-ai/claude-agent-sdk npm package is installed globally
    private func checkClaudeCodePackage(nodePath: String?) -> Bool {
        guard nodePath != nil else { return false }

        // Use npm list -g to check for globally installed package
        // This is more reliable than require() which may fail with newer Node.js versions
        let process = Process()
        #if os(macOS)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "npm list -g @anthropic-ai/claude-agent-sdk --depth=0"]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "npm list -g @anthropic-ai/claude-agent-sdk --depth=0"]
        #endif
        process.environment = configuration.buildEnvironment()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private struct ValidationResult {
        let available: Bool
        let path: String?
    }

    private struct NodeValidationResult {
        let available: Bool
        let path: String?
        let packageInstalled: Bool
    }

    private func validateClaudeCli() async -> ValidationResult {
        guard let path = findClaudeCli() else {
            return ValidationResult(available: false, path: nil)
        }

        // Validate by running --version
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return ValidationResult(available: process.terminationStatus == 0, path: path)
        } catch {
            return ValidationResult(available: false, path: nil)
        }
    }

    private func validateNodeAndPackage() async -> NodeValidationResult {
        guard let path = findNode() else {
            return NodeValidationResult(available: false, path: nil, packageInstalled: false)
        }

        // Validate Node.js by running --version
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let nodeAvailable = process.terminationStatus == 0

            if nodeAvailable {
                // Also check if the npm package is installed
                let packageInstalled = checkClaudeCodePackage(nodePath: path)
                return NodeValidationResult(available: true, path: path, packageInstalled: packageInstalled)
            }

            return NodeValidationResult(available: false, path: nil, packageInstalled: false)
        } catch {
            return NodeValidationResult(available: false, path: nil, packageInstalled: false)
        }
    }
}

// MARK: - Convenience Extensions

extension BackendDetector {
    /// Quickly checks if the headless backend is available
    public static func isHeadlessAvailable(configuration: ClaudeCodeConfiguration = .default) -> Bool {
        BackendDetector(configuration: configuration).detect().headlessAvailable
    }

    /// Quickly checks if the Agent SDK backend is available
    public static func isAgentSDKAvailable(configuration: ClaudeCodeConfiguration = .default) -> Bool {
        BackendDetector(configuration: configuration).detect().agentSDKAvailable
    }

    /// Returns the recommended backend for the current system
    public static func recommendedBackend(configuration: ClaudeCodeConfiguration = .default) -> BackendType {
        BackendDetector(configuration: configuration).detect().recommendedBackend
    }
}
