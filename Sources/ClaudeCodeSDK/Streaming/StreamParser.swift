//
//  StreamParser.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Parser for streaming JSON responses from Claude Code
public struct StreamParser: Sendable {
    private let decoder = JSONDecoder()

    public init() {}

    /// Parses a line of streaming JSON into a ResponseChunk
    /// - Parameter line: The JSON line to parse
    /// - Returns: The parsed ResponseChunk, or nil if the line couldn't be parsed
    public func parseLine(_ line: String) throws -> ResponseChunk? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines
        guard !trimmed.isEmpty else { return nil }

        // Parse as JSON
        guard let data = trimmed.data(using: .utf8) else {
            throw ClaudeCodeError.invalidOutput("Invalid UTF-8 in line: \(trimmed)")
        }

        // Try to decode the type first
        struct TypeWrapper: Decodable {
            let type: String
        }

        let typeWrapper: TypeWrapper
        do {
            typeWrapper = try decoder.decode(TypeWrapper.self, from: data)
        } catch {
            throw ClaudeCodeError.jsonParsingError("Failed to decode type: \(error.localizedDescription)")
        }

        // Decode based on type
        switch typeWrapper.type {
        case "system":
            let message = try decoder.decode(InitSystemMessage.self, from: data)
            return .initSystem(message)

        case "user":
            let message = try decoder.decode(UserMessage.self, from: data)
            return .user(message)

        case "assistant":
            let message = try decoder.decode(AssistantMessage.self, from: data)
            return .assistant(message)

        case "result":
            let message = try decoder.decode(ResultMessage.self, from: data)
            return .result(message)

        case "input_request":
            let message = try decoder.decode(InputRequest.self, from: data)
            return .inputRequest(message)

        default:
            // Unknown type, skip it
            return nil
        }
    }

    /// Creates an async stream that parses streaming data into ResponseChunks
    /// - Parameter dataStream: The raw data stream from the process
    /// - Returns: An async stream of ResponseChunks
    public func parseStream(_ dataStream: AsyncThrowingStream<Data, any Swift.Error>) -> AsyncThrowingStream<ResponseChunk, any Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = ""

                do {
                    for try await data in dataStream {
                        guard let chunk = String(data: data, encoding: .utf8) else {
                            continue
                        }

                        buffer.append(chunk)

                        // Process complete lines
                        while let newlineIndex = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[..<newlineIndex])
                            buffer = String(buffer[buffer.index(after: newlineIndex)...])

                            if let responseChunk = try parseLine(line) {
                                continuation.yield(responseChunk)
                            }
                        }
                    }

                    // Process any remaining data in buffer
                    if !buffer.isEmpty {
                        if let responseChunk = try parseLine(buffer) {
                            continuation.yield(responseChunk)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Line Buffer

/// A buffer for accumulating partial lines from streaming data
actor LineBuffer {
    private var buffer = ""

    /// Appends data to the buffer and returns complete lines
    /// - Parameter data: The data to append
    /// - Returns: Array of complete lines
    func append(_ data: Data) -> [String] {
        guard let chunk = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer.append(chunk)

        var lines: [String] = []

        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            lines.append(line)
        }

        return lines
    }

    /// Returns and clears any remaining content in the buffer
    func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        let remaining = buffer
        buffer = ""
        return remaining
    }
}
