//
//  ClaudeCodeError.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Foundation

/// Errors that can occur during Claude Code execution
public enum ClaudeCodeError: Error, Sendable {
    /// The command execution failed with a message
    case executionFailed(String)

    /// The output from Claude Code was invalid or unexpected
    case invalidOutput(String)

    /// JSON parsing failed
    case jsonParsingError(String)

    /// The operation was cancelled
    case cancelled

    /// Claude Code CLI is not installed
    case notInstalled

    /// The operation timed out
    case timeout(TimeInterval)

    /// Rate limit was exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)

    /// A network error occurred
    case networkError(String)

    /// Permission was denied
    case permissionDenied(String)

    /// Failed to launch the process
    case processLaunchFailed(String)

    /// Invalid configuration
    case invalidConfiguration(String)

    /// Process terminated with signal
    case signalTerminated(Int32)

    /// A deprecated model was specified
    case deprecatedModel(String)

    /// API quota exceeded
    case quotaExceeded(String)
}

extension ClaudeCodeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .invalidOutput(let message):
            return "Invalid output: \(message)"
        case .jsonParsingError(let message):
            return "JSON parsing error: \(message)"
        case .cancelled:
            return "Operation was cancelled"
        case .notInstalled:
            return "Claude Code CLI is not installed. Please install it with: curl -fsSL https://claude.ai/install.sh | bash"
        case .timeout(let duration):
            return "Operation timed out after \(duration) seconds"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after \(retry) seconds"
            }
            return "Rate limit exceeded"
        case .networkError(let message):
            return "Network error: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .processLaunchFailed(let message):
            return "Failed to launch process: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .signalTerminated(let signal):
            return "Process terminated by signal: \(signal)"
        case .deprecatedModel(let model):
            return "Model '\(model)' has been deprecated. Please use a current model."
        case .quotaExceeded(let message):
            return "API quota exceeded: \(message)"
        }
    }
}

extension ClaudeCodeError {
    /// Whether this error is due to rate limiting
    public var isRateLimitError: Bool {
        if case .rateLimitExceeded = self { return true }
        return false
    }

    /// Whether this error is due to a timeout
    public var isTimeoutError: Bool {
        if case .timeout = self { return true }
        return false
    }

    /// Whether this error is retryable
    public var isRetryable: Bool {
        switch self {
        case .rateLimitExceeded, .timeout, .networkError:
            return true
        default:
            return false
        }
    }

    /// Whether this error indicates Claude Code is not installed
    public var isInstallationError: Bool {
        if case .notInstalled = self { return true }
        return false
    }

    /// Whether this error is a permission error
    public var isPermissionError: Bool {
        if case .permissionDenied = self { return true }
        return false
    }

    /// Suggested delay before retrying (if applicable)
    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return retryAfter ?? 60.0
        case .timeout:
            return 5.0
        case .networkError:
            return 1.0
        default:
            return nil
        }
    }
}
