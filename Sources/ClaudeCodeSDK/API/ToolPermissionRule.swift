//
//  ToolPermissionRule.swift
//  ClaudeCodeSDK
//
//  Type-safe per-tool permission rules for Claude Code
//

import Foundation

/// A rule specifying permission for a specific tool or tool pattern.
///
/// Claude Code supports fine-grained per-tool permissions using patterns:
/// - `"Bash"` — matches any use of the Bash tool
/// - `"Bash(*)"` — matches Bash with any argument
/// - `"Bash(git commit *)"` — matches Bash with a specific command prefix
/// - `"Read(/path/to/dir/*)"` — matches Read scoped to a directory
/// - `"WebFetch(example.com)"` — matches WebFetch scoped to a domain
///
/// Use `ToolPermissionRule` to construct rules in a type-safe way, or pass
/// raw strings using `ExpressibleByStringLiteral`:
///
/// ```swift
/// var options = ClaudeCodeOptions()
///
/// // Type-safe construction
/// options.allowedTools = [
///     .tool("Read"),
///     .tool("Bash", argument: "git *"),
///     .tool("Write", argument: "/src/*"),
/// ]
///
/// // String literals (backwards compatible)
/// options.allowedTools = ["Read", "Bash(git *)"]
/// ```
public struct ToolPermissionRule: Sendable, Equatable, Hashable {
    /// The raw rule string (e.g., "Bash(git *)")
    public let rule: String

    /// Creates a rule from a raw string
    public init(_ rule: String) {
        self.rule = rule
    }

    /// Creates a rule matching any use of a tool
    /// - Parameter name: The tool name (e.g., "Bash", "Read", "Write")
    /// - Returns: A rule matching any invocation of the tool
    public static func tool(_ name: String) -> ToolPermissionRule {
        ToolPermissionRule(name)
    }

    /// Creates a rule matching a tool with a specific argument pattern
    /// - Parameters:
    ///   - name: The tool name
    ///   - argument: The argument pattern (e.g., "git *", "/src/*", "example.com")
    /// - Returns: A rule matching the tool with the specified argument pattern
    public static func tool(_ name: String, argument: String) -> ToolPermissionRule {
        ToolPermissionRule("\(name)(\(argument))")
    }
}

// MARK: - ExpressibleByStringLiteral

extension ToolPermissionRule: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rule = value
    }
}

// MARK: - Codable

extension ToolPermissionRule: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rule = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rule)
    }
}

// MARK: - CustomStringConvertible

extension ToolPermissionRule: CustomStringConvertible {
    public var description: String { rule }
}

// MARK: - Common Rules

extension ToolPermissionRule {
    // MARK: Tool Names

    /// Matches any use of the Bash tool
    public static let bash = ToolPermissionRule("Bash")

    /// Matches any use of the Read tool
    public static let read = ToolPermissionRule("Read")

    /// Matches any use of the Write tool
    public static let write = ToolPermissionRule("Write")

    /// Matches any use of the Edit tool
    public static let edit = ToolPermissionRule("Edit")

    /// Matches any use of the Glob tool
    public static let glob = ToolPermissionRule("Glob")

    /// Matches any use of the Grep tool
    public static let grep = ToolPermissionRule("Grep")

    /// Matches any use of the WebFetch tool
    public static let webFetch = ToolPermissionRule("WebFetch")

    /// Matches any use of the WebSearch tool
    public static let webSearch = ToolPermissionRule("WebSearch")

    /// Matches any use of the NotebookEdit tool
    public static let notebookEdit = ToolPermissionRule("NotebookEdit")

    /// Matches any use of the Agent tool
    public static let agent = ToolPermissionRule("Agent")

    // MARK: Common Patterns

    /// Allows Bash for git commands only
    public static let bashGit = ToolPermissionRule("Bash(git *)")

    /// Allows Bash for npm/npx commands only
    public static let bashNpm = ToolPermissionRule("Bash(npm *)")

    /// Allows Bash for any command (wildcard)
    public static let bashAny = ToolPermissionRule("Bash(*)")

    /// Allows Read for any path (wildcard)
    public static let readAny = ToolPermissionRule("Read(*)")

    /// Allows Write for any path (wildcard)
    public static let writeAny = ToolPermissionRule("Write(*)")
}
