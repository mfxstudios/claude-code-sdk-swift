//
//  ClaudeCodeResult.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Response chunk for streaming output
public enum ResponseChunk: Sendable {
    case initSystem(InitSystemMessage)
    case user(UserMessage)
    case assistant(AssistantMessage)
    case result(ResultMessage)
    case inputRequest(InputRequest)

    /// The session ID from this chunk
    public var sessionId: String {
        switch self {
        case .initSystem(let msg): return msg.sessionId
        case .user(let msg): return msg.sessionId
        case .assistant(let msg): return msg.sessionId
        case .result(let msg): return msg.sessionId
        case .inputRequest: return ""
        }
    }
}

/// Result from a Claude Code execution
public enum ClaudeCodeResult: Sendable {
    /// Plain text result
    case text(String)

    /// JSON structured result
    case json(ResultMessage)

    /// Streaming result as an AsyncSequence
    case stream(ClaudeCodeStream)

    /// The session ID if available
    public var sessionId: String? {
        switch self {
        case .text:
            return nil
        case .json(let result):
            return result.sessionId
        case .stream:
            return nil
        }
    }

    /// The text result if this is a text response
    public var textValue: String? {
        if case .text(let text) = self {
            return text
        }
        return nil
    }

    /// The JSON result if this is a JSON response
    public var jsonValue: ResultMessage? {
        if case .json(let result) = self {
            return result
        }
        return nil
    }

    /// The stream if this is a streaming response
    public var streamValue: ClaudeCodeStream? {
        if case .stream(let stream) = self {
            return stream
        }
        return nil
    }
}

// MARK: - Stream Type

/// An async sequence of response chunks from Claude Code
public struct ClaudeCodeStream: AsyncSequence, Sendable {
    public typealias Element = ResponseChunk

    private let makeStream: @Sendable () -> AsyncThrowingStream<ResponseChunk, any Swift.Error>

    public init(_ makeStream: @escaping @Sendable () -> AsyncThrowingStream<ResponseChunk, any Swift.Error>) {
        self.makeStream = makeStream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: makeStream())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<ResponseChunk, any Swift.Error>.AsyncIterator

        init(stream: AsyncThrowingStream<ResponseChunk, any Swift.Error>) {
            self.iterator = stream.makeAsyncIterator()
        }

        public mutating func next() async throws -> ResponseChunk? {
            try await iterator.next()
        }
    }
}

extension ClaudeCodeStream {
    /// Collects all chunks into an array
    public func collect() async throws -> [ResponseChunk] {
        var chunks: [ResponseChunk] = []
        for try await chunk in self {
            chunks.append(chunk)
        }
        return chunks
    }

    /// Returns only the final result message
    public func finalResult() async throws -> ResultMessage? {
        var result: ResultMessage?
        for try await chunk in self {
            if case .result(let msg) = chunk {
                result = msg
            }
        }
        return result
    }

    /// Returns all text content from assistant messages
    public func allText() async throws -> String {
        var texts: [String] = []
        for try await chunk in self {
            if case .assistant(let msg) = chunk {
                for content in msg.message.content {
                    if case .text(let textContent) = content {
                        texts.append(textContent.text)
                    }
                }
            }
        }
        return texts.joined()
    }
}
