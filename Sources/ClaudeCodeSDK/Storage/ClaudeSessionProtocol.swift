//
//  ClaudeSessionProtocol.swift
//  ClaudeCodeSDK
//
//  Protocol for Claude session storage implementations
//

import Foundation

/// Protocol for accessing Claude session storage
public protocol ClaudeSessionStorage: Sendable {
    /// Lists all available projects (directories with sessions)
    /// - Returns: Array of projects sorted by last activity
    func listProjects() async throws -> [ClaudeProject]

    /// Lists all sessions for a specific project
    /// - Parameter projectPath: The decoded project path (e.g., "/Users/user/project")
    /// - Returns: Array of sessions sorted by last access time (most recent first)
    func getSessions(for projectPath: String) async throws -> [ClaudeStoredSession]

    /// Gets a specific session by ID
    /// - Parameters:
    ///   - id: The session UUID
    ///   - projectPath: Optional project path to narrow the search
    /// - Returns: The session if found, nil otherwise
    func getSession(id: String, projectPath: String?) async throws -> ClaudeStoredSession?

    /// Gets all sessions across all projects
    /// - Returns: Array of all sessions sorted by last access time
    func getAllSessions() async throws -> [ClaudeStoredSession]

    /// Searches sessions by content
    /// - Parameters:
    ///   - query: Search query string
    ///   - projectPath: Optional project path to limit search
    /// - Returns: Sessions containing the query in messages
    func searchSessions(query: String, projectPath: String?) async throws -> [ClaudeStoredSession]

    /// Gets the most recent session for a project
    /// - Parameter projectPath: The project path
    /// - Returns: The most recent session if any exist
    func getMostRecentSession(for projectPath: String) async throws -> ClaudeStoredSession?

    /// Gets sessions by git branch
    /// - Parameters:
    ///   - branch: The git branch name
    ///   - projectPath: Optional project path to limit search
    /// - Returns: Sessions associated with the branch
    func getSessions(forBranch branch: String, projectPath: String?) async throws -> [ClaudeStoredSession]
}

/// Errors that can occur during session storage operations
public enum ClaudeSessionStorageError: Error, LocalizedError {
    case storageNotFound(String)
    case invalidProjectPath(String)
    case sessionNotFound(String)
    case parsingError(String)
    case fileSystemError(Error)

    public var errorDescription: String? {
        switch self {
        case .storageNotFound(let path):
            return "Claude session storage not found at: \(path)"
        case .invalidProjectPath(let path):
            return "Invalid project path: \(path)"
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        case .parsingError(let message):
            return "Failed to parse session data: \(message)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}
