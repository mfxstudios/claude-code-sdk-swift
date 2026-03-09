# ClaudeCodeSDK

A cross-platform Swift SDK for interacting with Claude Code CLI. Supports macOS with modern Swift concurrency (async/await and AsyncSequence).

## Features

- **Modern Swift Concurrency**: Full async/await and AsyncSequence support
- **Dual Backend Support**: Choose between Headless CLI or Agent SDK backends with auto-detection
- **Interactive Sessions**: Multi-turn conversations with streaming responses
- **Extended Thinking**: Configure extended and adaptive thinking with `ThinkingConfiguration`
- **Fast Mode**: 2.5x faster output with `SpeedMode.fast` for supported models
- **Model Constants**: Type-safe `ClaudeModel` constants for all current models (Opus 4.6, Sonnet 4.6, etc.)
- **Structured Outputs**: JSON schema validation via `OutputConfig`
- **Per-Tool Permissions**: Fine-grained `ToolPermissionRule` with pattern support (e.g., `Bash(git *)`)
- **Beta Features**: Enable compaction, 1M context, interleaved thinking, and more
- **Native Session Storage**: Access Claude CLI session history from `~/.claude/projects/`
- **Streaming Responses**: Real-time streaming with `AsyncSequence`
- **Type-safe**: Strongly typed API with Codable message types
- **Conversation Support**: Continue and resume conversations by session ID

## Requirements

- Swift 6.0+
- macOS 15.0+

**For Headless Backend:**
- Claude Code CLI installed (`curl -fsSL https://claude.ai/install.sh | bash`)

**For Agent SDK Backend:**
- Node.js 18+ installed
- `@anthropic-ai/claude-agent-sdk` npm package (`npm install -g @anthropic-ai/claude-agent-sdk`)

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mfxstudios/ClaudeCodeSDK", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["ClaudeCodeSDK"]
)
```

### Xcode

1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version requirements
4. Add to your target

## Quick Start

```swift
import ClaudeCodeSDK

// Create a client (auto-detects best available backend)
let client = ClaudeCodeClient()

// Simple text prompt
let text = try await client.runText("What is 2 + 2?")
print(text)

// JSON response with metadata
let result = try await client.ask("Explain Swift in one sentence.")
print(result.result ?? "")
print("Cost: $\(result.totalCostUsd)")
```

## Model Selection

Use type-safe model constants or string literals:

```swift
var options = ClaudeCodeOptions()

// Using model constants
options.model = .opus4_6
options.model = .sonnet4_5
options.model = .latestSonnet  // alias for latest Sonnet

// Using string literals (backwards compatible)
options.model = "claude-sonnet-4-5-20250514"

// Check if a model is deprecated
let model = ClaudeModel(rawValue: "claude-3-opus-20240229")
print(model.isDeprecated) // true
```

Available constants: `.opus4_6`, `.opus4_5`, `.opus4_1`, `.opus4`, `.sonnet4_6`, `.sonnet4_5`, `.sonnet4`, `.haiku4_5`

## Extended Thinking

Configure Claude's extended thinking for complex reasoning tasks:

```swift
var options = ClaudeCodeOptions()

// Enabled with a specific token budget
options.thinking = .enabled(budgetTokens: 10000)

// Adaptive — Claude decides when and how much to think
options.thinking = .adaptive

// Disabled
options.thinking = .disabled

let result = try await client.ask("Solve this complex problem...", options: options)
```

Thinking events are streamed in interactive sessions:

```swift
let session = try client.createInteractiveSession(
    configuration: InteractiveSessionConfiguration(
        thinking: .adaptive,
        model: .opus4_6
    )
)

for try await event in session.send("Explain quantum computing") {
    switch event {
    case .thinking(let thought):
        print("[Thinking] \(thought)")
    case .text(let chunk):
        print(chunk, terminator: "")
    default:
        break
    }
}
```

> **Migration note**: The `maxThinkingTokens` property is deprecated. Use `thinking: .enabled(budgetTokens: N)` instead.

## Fast Mode

Get 2.5x faster output for supported models (e.g., Opus 4.6):

```swift
var options = ClaudeCodeOptions()
options.model = .opus4_6
options.speed = .fast

let result = try await client.ask("Quick question", options: options)
```

## Beta Features

Enable beta API features via headers:

```swift
var options = ClaudeCodeOptions()
options.betaFeatures = [.compaction, .extendedContext1M]

// Available beta features:
// .compaction           — Context compaction for long conversations
// .extendedContext1M    — 1M token context window
// .interleavedThinking  — Thinking between tool calls
// .computerUse          — Computer use tool support
// .searchResultsCitations — Search result citations
// .skills               — Skills API
```

## Per-Tool Permissions

Control which tools Claude can use with fine-grained permission rules:

```swift
var options = ClaudeCodeOptions()

// Type-safe tool permission rules
options.allowedTools = [
    .read,                                  // Allow Read tool
    .glob,                                  // Allow Glob tool
    .tool("Bash", argument: "git *"),       // Allow Bash for git commands only
    .tool("Write", argument: "/src/*"),     // Allow Write scoped to /src/
    .bashGit,                               // Shorthand for Bash(git *)
]

options.disallowedTools = [
    .tool("Bash"),                          // Deny all Bash usage
    .tool("Write", argument: "/etc/*"),     // Deny writes to /etc/
]

// String literals also work (backwards compatible)
options.allowedTools = ["Read", "Glob", "Bash(git *)"]
```

### Permission Modes

```swift
var options = ClaudeCodeOptions()
options.permissionMode = .default           // Standard prompting
options.permissionMode = .acceptEdits       // Auto-approve file edits
options.permissionMode = .plan              // Plan mode — no execution
options.permissionMode = .bypassPermissions // Bypass all checks
```

### Interactive Session Permissions

```swift
let session = try client.createInteractiveSession(
    configuration: InteractiveSessionConfiguration(
        allowedTools: [.read, .glob, .tool("Bash", argument: "git *")],
        disallowedTools: [.tool("Write", argument: "/etc/*")],
        permissionPromptTool: .deny,
        permissionMode: .acceptEdits
    )
)
```

### Common Permission Rule Constants

| Constant | Rule | Description |
|----------|------|-------------|
| `.bash` | `Bash` | Any Bash usage |
| `.read` | `Read` | Any Read usage |
| `.write` | `Write` | Any Write usage |
| `.edit` | `Edit` | Any Edit usage |
| `.glob` | `Glob` | Any Glob usage |
| `.grep` | `Grep` | Any Grep usage |
| `.bashGit` | `Bash(git *)` | Bash for git commands only |
| `.bashNpm` | `Bash(npm *)` | Bash for npm commands only |
| `.bashAny` | `Bash(*)` | Bash with any argument |

## Interactive Sessions

The SDK provides an interactive session API for building chat applications and CLI tools with multi-turn conversations.

### Basic Interactive Session

```swift
let client = ClaudeCodeClient()
let session = try client.createInteractiveSession()

// Stream responses in real-time
for try await event in session.send("Hello! What's your name?") {
    switch event {
    case .text(let chunk):
        print(chunk, terminator: "")
    case .toolUse(let tool):
        print("[Using tool: \(tool.name)]")
    case .completed(let result):
        print("\nCost: $\(result.totalCostUsd)")
    default:
        break
    }
}

// Continue the conversation (context is preserved)
let response = try await session.sendAndWait("What did I just ask you?")
print(response.text)

// Clean up
await session.end()
```

### Interactive CLI Chat Loop

```swift
let client = ClaudeCodeClient()
let session = try client.createInteractiveSession(maxTurns: 1)

print("Chat with Claude (type 'exit' to quit)")

while true {
    print("> ", terminator: "")
    guard let input = readLine(), input != "exit" else { break }

    for try await event in session.send(input) {
        if case .text(let chunk) = event {
            print(chunk, terminator: "")
            fflush(stdout)
        }
    }
    print()
}

await session.end()
```

### Session Configuration

```swift
let session = try client.createInteractiveSession(
    configuration: InteractiveSessionConfiguration(
        systemPrompt: "You are a helpful coding assistant.",
        maxTurns: 5,
        allowedTools: [.read, .write, .glob, .bashGit],
        disallowedTools: [.tool("Bash")],
        permissionPromptTool: .deny,
        permissionMode: .acceptEdits
    )
)
```

### Convenience Methods

```swift
// Collect all text at once
let text = try await session.send("Write a haiku").collectText()

// Wait for completion with result
let result = try await session.sendAndWait("What is 2+2?")
print(result.text)        // "4"
print(result.isError)     // false
print(result.numTurns)    // 1
```

## Streaming Responses

```swift
let client = ClaudeCodeClient()

try await client.stream("Write a poem about coding.") { chunk in
    switch chunk {
    case .assistant(let msg):
        for content in msg.message.content {
            if case .text(let textContent) = content {
                print(textContent.text, terminator: "")
            }
        }
    case .result(let msg):
        print("\n[Done] Cost: $\(msg.totalCostUsd)")
    default:
        break
    }
}
```

### Using AsyncSequence Directly

```swift
let result = try await client.runSinglePrompt(
    prompt: "Count to 5",
    outputFormat: .streamJson,
    options: nil
)

guard case .stream(let stream) = result else { return }

// Collect all text
let allText = try await stream.allText()

// Or get the final result
let finalResult = try await stream.finalResult()
```

## Backend Selection

The SDK supports two execution backends with automatic detection:

### Auto Detection (Default)

```swift
let client = ClaudeCodeClient() // Auto-detects best backend

print("Using: \(client.resolvedBackendType)")  // .headless or .agentSDK

if let detection = client.detectionResult {
    print(detection.description)
}
```

### Headless Backend

Uses the `claude` CLI subprocess. Requires Claude Code CLI installed.

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .headless
let client = try ClaudeCodeClient(configuration: config)
```

### Agent SDK Backend

Uses Node.js wrapper around `@anthropic-ai/claude-agent-sdk`.

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK
let client = try ClaudeCodeClient(configuration: config)
```

### Backend Detection

```swift
let detection = ClaudeCodeClient.detectAvailableBackends()
print(detection.headlessAvailable)   // true/false
print(detection.agentSDKAvailable)   // true/false
print(detection.recommendedBackend)  // .headless or .agentSDK

// Async detection with validation
let detection = await ClaudeCodeClient.detectAvailableBackendsAsync()
```

## Native Session Storage

Access Claude CLI's stored sessions from `~/.claude/projects/`:

```swift
let client = ClaudeCodeClient()

// List all projects with sessions
let projects = try await client.listStoredProjects()
for project in projects {
    print("\(project.path): \(project.sessionCount) sessions")
}

// Get sessions for current project
let sessions = try await client.getStoredSessions()

// Get most recent session
if let recent = try await client.getMostRecentStoredSession() {
    print("Last session: \(recent.id)")
    print("Messages: \(recent.messages.count)")
}

// Search sessions by content
let matches = try await client.searchStoredSessions(query: "refactor")

// Get sessions by git branch
let branchSessions = try await client.getStoredSessions(forBranch: "main")
```

### Direct Storage Access

```swift
let storage = ClaudeNativeSessionStorage()

// Or with custom path
let storage = ClaudeNativeSessionStorage(basePath: "/custom/path")

let projects = try await storage.listProjects()
let sessions = try await storage.getAllSessions()
```

## Conversation Management

```swift
// Start a conversation
let result1 = try await client.ask("My name is Alice.")
let sessionId = result1.sessionId

// Resume later
let result2 = try await client.resumeConversation(
    sessionId: sessionId,
    prompt: "What's my name?",
    outputFormat: .json,
    options: nil
)
```

## Configuration

### Client Configuration

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .auto                 // .auto, .headless, or .agentSDK
config.workingDirectory = "/path"      // Working directory for operations
config.enableDebugLogging = true       // Enable debug output
config.environment["KEY"] = "value"    // Custom environment variables
config.disallowedTools = ["Bash"]      // Globally restrict tools

let client = try ClaudeCodeClient(configuration: config)
```

### Request Options

```swift
var options = ClaudeCodeOptions()
options.systemPrompt = "You are a coding assistant."
options.maxTurns = 10
options.model = .sonnet4_6
options.thinking = .adaptive
options.speed = .fast
options.timeout = 60
options.allowedTools = [.read, .write, .bashGit]
options.disallowedTools = [.tool("Bash")]
options.permissionMode = .acceptEdits
options.betaFeatures = [.compaction]
options.verbose = true

let result = try await client.ask("Help me debug this", options: options)
```

## Error Handling

```swift
do {
    let result = try await client.runText("Hello")
} catch let error as ClaudeCodeError {
    switch error {
    case .notInstalled:
        print("Claude Code CLI not installed")
    case .timeout(let duration):
        print("Timed out after \(duration)s")
    case .rateLimitExceeded(let retryAfter):
        print("Rate limited, retry after \(retryAfter ?? 60)s")
    case .executionFailed(let message):
        print("Failed: \(message)")
    case .invalidConfiguration(let message):
        print("Config error: \(message)")
    default:
        print(error.localizedDescription)
    }

    // Retry logic
    if error.isRetryable, let delay = error.suggestedRetryDelay {
        try await Task.sleep(for: .seconds(delay))
        // Retry...
    }
}
```

### Interactive Session Errors

```swift
do {
    let result = try await session.sendAndWait("Hello")
} catch let error as InteractiveError {
    switch error {
    case .sessionNotStarted:
        print("Session not initialized")
    case .sessionEnded:
        print("Session has ended")
    case .sendFailed(let message):
        print("Send failed: \(message)")
    case .streamError(let message):
        print("Stream error: \(message)")
    case .cancelled:
        print("Request was cancelled")
    }
}
```

## API Reference

### ClaudeCodeClient

```swift
// Initialization
let client = ClaudeCodeClient()
let client = try ClaudeCodeClient(configuration: config)
let client = try ClaudeCodeClient(workingDirectory: "/path", debug: true, backend: .headless)

// Core Methods
func runText(_ prompt: String) async throws -> String
func ask(_ prompt: String, options: ClaudeCodeOptions?) async throws -> ResultMessage
func stream(_ prompt: String, options: ClaudeCodeOptions?, onChunk: (ResponseChunk) async -> Void) async throws -> ResultMessage?
func runSinglePrompt(prompt:outputFormat:options:) async throws -> ClaudeCodeResult
func runWithStdin(stdinContent:outputFormat:options:) async throws -> ClaudeCodeResult
func resumeConversation(sessionId:prompt:outputFormat:options:) async throws -> ClaudeCodeResult

// Interactive Sessions
func createInteractiveSession(configuration:) throws -> ClaudeInteractiveSession
func createInteractiveSession(systemPrompt:) throws -> ClaudeInteractiveSession
func createInteractiveSession(systemPrompt:maxTurns:allowedTools:) throws -> ClaudeInteractiveSession

// Session Storage
func listStoredProjects() async throws -> [ClaudeProject]
func getStoredSessions() async throws -> [ClaudeStoredSession]
func getStoredSession(id:) async throws -> ClaudeStoredSession?
func getMostRecentStoredSession() async throws -> ClaudeStoredSession?
func searchStoredSessions(query:) async throws -> [ClaudeStoredSession]
func getStoredSessions(forBranch:) async throws -> [ClaudeStoredSession]

// Utilities
func validateBackend() async throws -> Bool
func cancel()
static func detectAvailableBackends() -> BackendDetector.DetectionResult
static func detectAvailableBackendsAsync() async -> BackendDetector.DetectionResult
```

### ClaudeInteractiveSession

```swift
// Properties
var sessionId: String? { get }
var isActive: Bool { get }
var configuration: InteractiveSessionConfiguration { get }

// Methods
func send(_ message: String) -> InteractiveResponseStream
func sendAndWait(_ message: String) async throws -> InteractiveResult
func cancel()
func end() async
```

### InteractiveEvent

```swift
enum InteractiveEvent {
    case text(String)                        // Text chunk from response
    case toolUse(ToolUseInfo)               // Tool being used
    case toolResult(ToolResultInfo)         // Tool execution result
    case sessionStarted(SessionStartInfo)   // Session initialized
    case completed(InteractiveResult)       // Response complete
    case error(InteractiveError)            // Error occurred
    case thinking(String)                   // Extended thinking content
}
```

### InteractiveResponseStream

```swift
// AsyncSequence - iterate with for-await
for try await event in session.send("Hello") { ... }

// Convenience methods
func collectText() async throws -> String
func waitForCompletion() async throws -> InteractiveResult
func collect() async throws -> [InteractiveEvent]
```


## License

MIT License - see LICENSE file for details.
