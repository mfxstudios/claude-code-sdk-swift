//
//  ClaudeNativeSessionStorage.swift
//  ClaudeCodeSDK
//
//  Native session storage implementation reading from ~/.claude/projects/
//

import Foundation

/// Native session storage that reads from Claude CLI's session storage
/// Sessions are stored in ~/.claude/projects/{encoded-path}/{session-id}.jsonl
public final class ClaudeNativeSessionStorage: ClaudeSessionStorage, @unchecked Sendable {
    /// Base path for Claude session storage
    private let basePath: String

    /// File manager for file operations
    private let fileManager: FileManager

    /// JSON decoder for parsing
    private let decoder: JSONDecoder

    /// Date formatter for ISO8601 timestamps
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback date formatter without fractional seconds
    private nonisolated(unsafe) static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Creates a new native session storage instance
    /// - Parameter basePath: Custom base path (defaults to ~/.claude/projects)
    public init(basePath: String? = nil) {
        if let customPath = basePath {
            self.basePath = customPath
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            self.basePath = "\(homeDir)/.claude/projects"
        }
        self.fileManager = FileManager.default
        self.decoder = JSONDecoder()
    }

    // MARK: - ClaudeSessionStorage Protocol

    public func listProjects() async throws -> [ClaudeProject] {
        guard fileManager.fileExists(atPath: basePath) else {
            throw ClaudeSessionStorageError.storageNotFound(basePath)
        }

        let contents = try fileManager.contentsOfDirectory(atPath: basePath)
        var projects: [ClaudeProject] = []

        for folderName in contents {
            let folderPath = (basePath as NSString).appendingPathComponent(folderName)
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let decodedPath = decodeProjectPath(folderName)
            let sessionFiles = try? fileManager.contentsOfDirectory(atPath: folderPath)
                .filter { $0.hasSuffix(".jsonl") }

            let sessionCount = sessionFiles?.count ?? 0
            var lastActivity: Date?

            // Get last modification time of most recent session file
            if let files = sessionFiles {
                for file in files {
                    let filePath = (folderPath as NSString).appendingPathComponent(file)
                    if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                       let modDate = attrs[.modificationDate] as? Date {
                        if lastActivity == nil || modDate > lastActivity! {
                            lastActivity = modDate
                        }
                    }
                }
            }

            projects.append(ClaudeProject(
                id: folderName,
                path: decodedPath,
                sessionCount: sessionCount,
                lastActivityAt: lastActivity
            ))
        }

        // Sort by last activity (most recent first)
        return projects.sorted { ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast) }
    }

    public func getSessions(for projectPath: String) async throws -> [ClaudeStoredSession] {
        let encodedPath = encodeProjectPath(projectPath)
        let projectFolder = (basePath as NSString).appendingPathComponent(encodedPath)

        guard fileManager.fileExists(atPath: projectFolder) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: projectFolder)
        var sessions: [ClaudeStoredSession] = []

        for fileName in contents {
            guard fileName.hasSuffix(".jsonl") else { continue }

            let sessionId = String(fileName.dropLast(6)) // Remove .jsonl
            let filePath = (projectFolder as NSString).appendingPathComponent(fileName)

            if let session = try? await parseSessionFile(at: filePath, sessionId: sessionId, projectPath: projectPath) {
                sessions.append(session)
            }
        }

        // Sort by last access time (most recent first)
        return sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    public func getSession(id: String, projectPath: String?) async throws -> ClaudeStoredSession? {
        if let projectPath = projectPath {
            let encodedPath = encodeProjectPath(projectPath)
            let projectFolder = (basePath as NSString).appendingPathComponent(encodedPath)
            let filePath = (projectFolder as NSString).appendingPathComponent("\(id).jsonl")

            if fileManager.fileExists(atPath: filePath) {
                return try await parseSessionFile(at: filePath, sessionId: id, projectPath: projectPath)
            }
            return nil
        }

        // Search all projects for the session
        let projects = try await listProjects()
        for project in projects {
            let projectFolder = (basePath as NSString).appendingPathComponent(project.id)
            let filePath = (projectFolder as NSString).appendingPathComponent("\(id).jsonl")

            if fileManager.fileExists(atPath: filePath) {
                return try await parseSessionFile(at: filePath, sessionId: id, projectPath: project.path)
            }
        }

        return nil
    }

    public func getAllSessions() async throws -> [ClaudeStoredSession] {
        let projects = try await listProjects()
        var allSessions: [ClaudeStoredSession] = []

        for project in projects {
            let sessions = try await getSessions(for: project.path)
            allSessions.append(contentsOf: sessions)
        }

        return allSessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    public func searchSessions(query: String, projectPath: String?) async throws -> [ClaudeStoredSession] {
        let sessions: [ClaudeStoredSession]

        if let projectPath = projectPath {
            sessions = try await getSessions(for: projectPath)
        } else {
            sessions = try await getAllSessions()
        }

        let lowercaseQuery = query.lowercased()
        return sessions.filter { session in
            session.messages.contains { message in
                message.content.lowercased().contains(lowercaseQuery)
            }
        }
    }

    public func getMostRecentSession(for projectPath: String) async throws -> ClaudeStoredSession? {
        let sessions = try await getSessions(for: projectPath)
        return sessions.first
    }

    public func getSessions(forBranch branch: String, projectPath: String?) async throws -> [ClaudeStoredSession] {
        let sessions: [ClaudeStoredSession]

        if let projectPath = projectPath {
            sessions = try await getSessions(for: projectPath)
        } else {
            sessions = try await getAllSessions()
        }

        return sessions.filter { $0.gitBranch == branch }
    }

    // MARK: - Private Methods

    /// Encodes a project path to folder name format (slashes to dashes)
    private func encodeProjectPath(_ path: String) -> String {
        return path.replacingOccurrences(of: "/", with: "-")
    }

    /// Decodes a folder name back to project path
    private func decodeProjectPath(_ folderName: String) -> String {
        // The first character is always a dash (from leading /)
        // Convert remaining dashes back to slashes
        var result = folderName
        if result.hasPrefix("-") {
            result = "/" + String(result.dropFirst())
        }
        return result.replacingOccurrences(of: "-", with: "/")
    }

    /// Parses a session JSONL file
    private func parseSessionFile(at path: String, sessionId: String, projectPath: String) async throws -> ClaudeStoredSession {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let content = String(data: data, encoding: .utf8) ?? ""
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var messages: [ClaudeStoredMessage] = []
        var gitBranch: String?
        var version: String?
        var cwd: String?
        var summary: String?
        var createdAt: Date?
        var lastAccessedAt: Date?

        for line in lines {
            guard let lineData = line.data(using: .utf8) else { continue }

            do {
                let entry = try decoder.decode(RawSessionEntry.self, from: lineData)

                // Extract metadata from first entry
                if gitBranch == nil, let branch = entry.gitBranch, !branch.isEmpty {
                    gitBranch = branch
                }
                if version == nil {
                    version = entry.version
                }
                if cwd == nil {
                    cwd = entry.cwd
                }

                // Parse timestamp
                if let timestampStr = entry.timestamp,
                   let timestamp = parseTimestamp(timestampStr) {
                    if createdAt == nil {
                        createdAt = timestamp
                    }
                    lastAccessedAt = timestamp
                }

                // Handle different entry types
                switch entry.type {
                case "user", "assistant", "system":
                    if let message = parseMessage(from: entry) {
                        messages.append(message)
                    }
                case "summary":
                    summary = entry.summary
                default:
                    // Skip queue-operation and other types
                    break
                }
            } catch {
                // Skip malformed lines
                continue
            }
        }

        // Use file modification date as fallback
        if createdAt == nil || lastAccessedAt == nil {
            if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                if createdAt == nil {
                    createdAt = attrs[.creationDate] as? Date ?? Date()
                }
                if lastAccessedAt == nil {
                    lastAccessedAt = attrs[.modificationDate] as? Date ?? Date()
                }
            }
        }

        return ClaudeStoredSession(
            id: sessionId,
            projectPath: projectPath,
            gitBranch: gitBranch,
            createdAt: createdAt ?? Date(),
            lastAccessedAt: lastAccessedAt ?? Date(),
            messages: messages,
            summary: summary,
            version: version,
            cwd: cwd
        )
    }

    /// Parses a message from a raw session entry
    private func parseMessage(from entry: RawSessionEntry) -> ClaudeStoredMessage? {
        guard let uuid = entry.uuid,
              let message = entry.message,
              let roleStr = message.role,
              let role = ClaudeMessageRole(rawValue: roleStr) else {
            return nil
        }

        let content: String
        if let messageContent = message.content {
            content = messageContent.textContent
        } else {
            content = ""
        }

        let timestamp: Date
        if let timestampStr = entry.timestamp {
            timestamp = parseTimestamp(timestampStr) ?? Date()
        } else {
            timestamp = Date()
        }

        var usage: ClaudeTokenUsage?
        if let rawUsage = message.usage {
            usage = ClaudeTokenUsage(
                inputTokens: rawUsage.inputTokens,
                outputTokens: rawUsage.outputTokens,
                cacheCreationInputTokens: rawUsage.cacheCreationInputTokens,
                cacheReadInputTokens: rawUsage.cacheReadInputTokens
            )
        }

        return ClaudeStoredMessage(
            id: uuid,
            parentId: entry.parentUuid,
            role: role,
            content: content,
            timestamp: timestamp,
            isSidechain: entry.isSidechain ?? false,
            model: message.model,
            usage: usage
        )
    }

    /// Parses an ISO8601 timestamp string
    private func parseTimestamp(_ string: String) -> Date? {
        // Try with fractional seconds first
        if let date = Self.iso8601Formatter.date(from: string) {
            return date
        }
        // Fallback without fractional seconds
        return Self.iso8601FallbackFormatter.date(from: string)
    }
}

// MARK: - Convenience Extensions

extension ClaudeNativeSessionStorage {
    /// Gets sessions for the current working directory
    public func getSessionsForCurrentDirectory() async throws -> [ClaudeStoredSession] {
        let cwd = FileManager.default.currentDirectoryPath
        return try await getSessions(for: cwd)
    }

    /// Gets the most recent session for the current working directory
    public func getMostRecentSessionForCurrentDirectory() async throws -> ClaudeStoredSession? {
        let cwd = FileManager.default.currentDirectoryPath
        return try await getMostRecentSession(for: cwd)
    }

    /// Checks if the native session storage exists
    public var storageExists: Bool {
        fileManager.fileExists(atPath: basePath)
    }

    /// Gets the base storage path
    public var storagePath: String {
        basePath
    }
}
