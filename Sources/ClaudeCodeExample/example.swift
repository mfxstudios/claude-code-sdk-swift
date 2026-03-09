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

        case .inputRequest:
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

// MARK: - Example 11: Interactive Session

func interactiveSessionExample() async throws {
    print("=== Interactive Session Example ===\n")

    let client = ClaudeCodeClient()

    // Create an interactive session
    let session = try client.createInteractiveSession(
        systemPrompt: "You are a helpful assistant. Keep responses brief.",
        maxTurns: 1
    )

    print("Session created. Session is active: \(session.isActive)")
    print()

    // First message with streaming
    print("Sending: Hello! What's your name?")
    print("Response: ", terminator: "")

    for try await event in session.send("Hello! What's your name?") {
        switch event {
        case .text(let chunk):
            print(chunk, terminator: "")
            fflush(stdout)
        case .sessionStarted(let info):
            print("\n[Session started: \(info.sessionId)]")
        case .toolUse(let tool):
            print("\n[Using tool: \(tool.name)]")
        case .completed(let result):
            print("\n[Completed - Cost: $\(String(format: "%.6f", result.totalCostUsd))]")
        case .error(let error):
            print("\n[Error: \(error)]")
        default:
            break
        }
    }
    print()

    // Second message using sendAndWait
    print("\nSending: What did I just ask you?")
    let result = try await session.sendAndWait("What did I just ask you?")
    print("Response: \(result.text)")
    print("Turns: \(result.numTurns), Cost: $\(String(format: "%.6f", result.totalCostUsd))")

    // End the session
    await session.end()
    print("\nSession ended. Session is active: \(session.isActive)")
    print()
}

// MARK: - Example 12: Interactive CLI Chat Loop

func interactiveChatExample() async throws {
    print("=== Interactive Chat Example ===\n")
    print("Type your messages and press Enter. Type 'exit' to quit.\n")

    let client = ClaudeCodeClient()
    let session = try client.createInteractiveSession(maxTurns: 1)

    while true {
        print("> ", terminator: "")
        fflush(stdout)

        guard let input = readLine(), !input.isEmpty else {
            continue
        }

        if input.lowercased() == "exit" {
            print("Goodbye!")
            break
        }

        do {
            // Stream the response
            for try await event in session.send(input) {
                if case .text(let chunk) = event {
                    print(chunk, terminator: "")
                    fflush(stdout)
                }
            }
            print("\n")
        } catch {
            print("\nError: \(error)\n")
        }
    }

    await session.end()
}

// MARK: - Example 13: Collect Response Text

func collectTextExample() async throws {
    print("=== Collect Response Text Example ===\n")

    let client = ClaudeCodeClient()
    let session = try client.createInteractiveSession(maxTurns: 1)

    // Use collectText() to get the full response as a string
    let text = try await session.send("Write a one-line joke about programming.").collectText()

    print("Joke: \(text)")
    print()

    await session.end()
}

// MARK: - Example 14: Extended Thinking

func extendedThinkingExample() async throws {
    print("=== Extended Thinking Example ===\n")

    let client = ClaudeCodeClient()

    // Use extended thinking with a specific token budget
    var options = ClaudeCodeOptions(
        model: .opus4_6,
        thinking: .enabled(budgetTokens: 10000)
    )
    options.maxTurns = 1

    let result = try await client.ask(
        "What is the sum of all prime numbers less than 100?",
        options: options
    )
    print("Result: \(result.result ?? "No result")")
    print("Cost: $\(String(format: "%.6f", result.totalCostUsd))")
    print()
}

// MARK: - Example 15: Fast Mode

func fastModeExample() async throws {
    print("=== Fast Mode Example ===\n")

    let client = ClaudeCodeClient()

    var options = ClaudeCodeOptions(
        model: .opus4_6,
        speed: .fast
    )
    options.maxTurns = 1

    let result = try await client.ask("What is 2 + 2?", options: options)
    print("Result: \(result.result ?? "No result")")
    print("Duration: \(result.durationMs)ms")
    print()
}

// MARK: - Example 16: Model Constants

func modelConstantsExample() async throws {
    print("=== Model Constants Example ===\n")

    // Using predefined model constants
    print("Latest Opus: \(ClaudeModel.latestOpus.rawValue)")
    print("Latest Sonnet: \(ClaudeModel.latestSonnet.rawValue)")
    print("Latest Haiku: \(ClaudeModel.latestHaiku.rawValue)")

    // Check deprecation
    let oldModel = ClaudeModel(rawValue: "claude-3-opus-20240229")
    print("Is claude-3-opus deprecated? \(oldModel.isDeprecated)")
    print("Is opus 4.6 deprecated? \(ClaudeModel.opus4_6.isDeprecated)")

    // Use string literal assignment (backwards compatible)
    var options = ClaudeCodeOptions()
    options.model = "claude-sonnet-4-5-20250514"
    print("\nModel from string literal: \(options.model?.rawValue ?? "nil")")
    print()
}

// MARK: - Example 17: Streaming with Thinking Events

func streamWithThinkingExample() async throws {
    print("=== Streaming with Thinking Example ===\n")

    let client = ClaudeCodeClient()

    let session = try client.createInteractiveSession(
        configuration: InteractiveSessionConfiguration(
            maxTurns: 1,
            thinking: .adaptive,
            model: .opus4_6
        )
    )

    print("Sending prompt with adaptive thinking enabled...")
    print()

    for try await event in session.send("Explain why 0.1 + 0.2 != 0.3 in floating point.") {
        switch event {
        case .thinking(let thought):
            print("[Thinking] \(thought.prefix(100))...")
        case .text(let chunk):
            print(chunk, terminator: "")
        case .completed(let result):
            print("\n\n[Completed - Cost: $\(String(format: "%.6f", result.totalCostUsd))]")
        default:
            break
        }
    }

    await session.end()
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

            // Interactive Session examples:
//             try await interactiveSessionExample()
//             try await collectTextExample()
//             try await interactiveChatExample()  // Interactive chat loop

            // New feature examples:
//             try await extendedThinkingExample()
//             try await fastModeExample()
//             try await modelConstantsExample()
//             try await streamWithThinkingExample()

        } catch {
            print("Error: \(error)")
        }
    }
}
