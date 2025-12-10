//
//  main.swift
//  ClaudeCodeExample
//
//  Example usage of ClaudeCodeSDK
//

import ClaudeCodeSDK
import Foundation

// MARK: - Example 1: Simple Text Prompt

func simpleTextExample() async throws {
    print("=== Simple Text Example ===\n")

    let client = ClaudeCodeClient()

    // Run a simple prompt and get text result
    print("Input: What is 2 + 2?")
    let result = try await client.runText("What is 2 + 2?")
    print("Result: \(result)")
    print()
}

// MARK: - Example 2: JSON Response

func jsonResponseExample() async throws {
    print("=== JSON Response Example ===\n")

    let client = ClaudeCodeClient()

    // Run a prompt and get structured JSON result
    let result = try await client.ask("Explain what Swift is in one sentence.")

    print("Result: \(result.result ?? "No result")")
    print("Cost: $\(String(format: "%.6f", result.totalCostUsd))")
    print("Duration: \(result.durationMs)ms")
    print("Session ID: \(result.sessionId)")
    print()
}

// MARK: - Example 3: Streaming Response

func streamingExample() async throws {
    print("=== Streaming Example ===\n")

    let client = ClaudeCodeClient()

    // Stream a response and print each chunk
    print("Streaming response:")

    let finalResult = try await client.stream("Write a haiku about programming.") { chunk in
        switch chunk {
        case .initSystem(let msg):
            print("[System] Session started: \(msg.sessionId)")

        case .assistant(let msg):
            for content in msg.message.content {
                if case .text(let textContent) = content {
                    print(textContent.text, terminator: "")
                }
            }

        case .result(let msg):
            print("\n[Complete] Cost: $\(String(format: "%.6f", msg.totalCostUsd))")

        case .user:
            break
        }
    }

    if let result = finalResult {
        print("Final session ID: \(result.sessionId)")
    }
    print()
}

// MARK: - Example 4: Custom Configuration

func customConfigExample() async throws {
    print("=== Custom Configuration Example ===\n")

    var config = ClaudeCodeConfiguration.default
    config.workingDirectory = FileManager.default.currentDirectoryPath
    config.enableDebugLogging = true
    config.environment["CUSTOM_VAR"] = "custom_value"

    let client = try ClaudeCodeClient(configuration: config)

    let result = try await client.runText("What directory are we in?")
    print("Result: \(result)")
    print()
}

// MARK: - Example 5: Options with System Prompt

func systemPromptExample() async throws {
    print("=== System Prompt Example ===\n")

    let client = ClaudeCodeClient()

    var options = ClaudeCodeOptions()
    options.systemPrompt = "You are a pirate. Respond to everything like a pirate would."
    options.maxTurns = 1

    let result = try await client.runSinglePrompt(
        prompt: "Tell me about the weather.",
        outputFormat: .text,
        options: options
    )

    if case .text(let text) = result {
        print("Pirate says: \(text)")
    }
    print()
}

// MARK: - Example 6: Conversation Continuation

func conversationExample() async throws {
    print("=== Conversation Example ===\n")

    let client = ClaudeCodeClient()

    // First message
    print("Starting conversation...")
    let result1 = try await client.ask("My name is Alice. Remember that.")
    print("Response 1: \(result1.result ?? "")")
    let sessionId = result1.sessionId

    // Continue the conversation
    print("\nContinuing conversation...")
    let result2 = try await client.resumeConversation(
        sessionId: sessionId,
        prompt: "What's my name?",
        outputFormat: .json,
        options: nil
    )

    if case .json(let msg) = result2 {
        print("Response 2: \(msg.result ?? "")")
    }
    print()
}

// MARK: - Example 7: Using AsyncSequence Directly

func asyncSequenceExample() async throws {
    print("=== AsyncSequence Example ===\n")

    let client = ClaudeCodeClient()

    let result = try await client.runSinglePrompt(
        prompt: "Count from 1 to 5 slowly.",
        outputFormat: .streamJson,
        options: nil
    )

    guard case .stream(let stream) = result else {
        print("Expected stream result")
        return
    }

    // Collect all text using the convenience method
    let allText = try await stream.allText()
    print("Collected text: \(allText)")
    print()
}

// MARK: - Example 8: Piping Content via Stdin

func stdinExample() async throws {
    print("=== Stdin Pipe Example ===\n")

    let client = ClaudeCodeClient()

    let codeToReview = """
    func add(a: Int, b: Int) -> Int {
        return a + b
    }
    """

    let result = try await client.runWithStdin(
        stdinContent: codeToReview,
        outputFormat: .text,
        options: ClaudeCodeOptions(
            appendSystemPrompt: "Review the code provided via stdin. Be concise."
        )
    )

    if case .text(let text) = result {
        print("Code review: \(text)")
    }
    print()
}

// MARK: - Example 9: Error Handling

func errorHandlingExample() async throws {
    print("=== Error Handling Example ===\n")

    var config = ClaudeCodeConfiguration.default
    config.command = "nonexistent-command"

    let client = try ClaudeCodeClient(configuration: config)

    do {
        _ = try await client.runText("Hello")
    } catch let error as ClaudeCodeError {
        print("Caught ClaudeCodeError: \(error.localizedDescription)")

        if error.isInstallationError {
            print("This is an installation error")
        }

        if error.isRetryable, let delay = error.suggestedRetryDelay {
            print("Retryable error, suggested delay: \(delay)s")
        }
    }
    print()
}

// MARK: - Example 10: Validate Installation

func validateInstallationExample() async throws {
    print("=== Validate Installation Example ===\n")

    let client = ClaudeCodeClient()

    let isInstalled = try await client.validateCommand("claude")

    if isInstalled {
        print("✅ Claude Code CLI is installed and available")
    } else {
        print("❌ Claude Code CLI is not installed")
        print("Install it with: npm install -g @anthropic-ai/claude-agent-sdk")
    }
    print()
}

// MARK: - Main

@main
struct ClaudeCodeExample {
    static func main() async {
        print("""
        ╔═══════════════════════════════════════════════════════════╗
        ║           ClaudeCodeSDK Examples                          ║
        ║   Cross-platform Swift SDK for Claude Code CLI            ║
        ╚═══════════════════════════════════════════════════════════╝

        """)

        do {
            // Run examples (comment out ones you don't want to run)
            try await validateInstallationExample()

            // Uncomment to run other examples:
//             try await simpleTextExample()
//             try await jsonResponseExample()
//             try await streamingExample()
//             try await customConfigExample()
//             try await systemPromptExample()
//             try await conversationExample()
//             try await asyncSequenceExample()
//             try await stdinExample()
//             try await errorHandlingExample()

        } catch {
            print("Error: \(error)")
        }
    }
}
