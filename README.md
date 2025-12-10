# ClaudeCodeSDK

A cross-platform Swift SDK for interacting with Claude Code. Supports macOS and Linux with modern Swift concurrency (async/await and AsyncSequence).

## Features

- **Cross-platform**: Works on macOS and Linux
- **Modern Swift Concurrency**: Full async/await and AsyncSequence support
- **Dual Backend Support**: Choose between Headless CLI or Agent SDK backends
- **Streaming Responses**: Real-time streaming with `AsyncSequence`
- **Type-safe**: Strongly typed API with Codable message types
- **Conversation Support**: Continue and resume conversations by session ID
- **Configurable**: Flexible configuration for different use cases

## Backends

The SDK supports two execution backends with automatic detection:

### Auto Detection (Default)
The SDK automatically detects and uses the best available backend. It prefers the headless backend when available, falling back to Agent SDK.

```swift
let client = ClaudeCodeClient() // Auto-detects best backend

// Check what backend was selected
print("Using: \(client.resolvedBackendType)")  // .headless or .agentSDK

// Get detailed detection info
if let detection = client.detectionResult {
    print(detection.description)
}
```

### Headless Backend
Uses the `claude -p` CLI subprocess. Simple setup, requires Claude Code CLI installed.

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .headless  // Explicitly use headless
let client = try ClaudeCodeClient(configuration: config)
```

### Agent SDK Backend
Uses Node.js wrapper around `@anthropic-ai/claude-agent-sdk` for programmatic access.

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK
config.nodeExecutable = "/usr/local/bin/node"  // Optional, auto-detected
config.sdkWrapperPath = "/path/to/sdk-wrapper.mjs"  // Optional, uses bundled

let client = try ClaudeCodeClient(configuration: config)
```

### Backend Detection Utilities

```swift
// Check available backends before creating a client
let detection = ClaudeCodeClient.detectAvailableBackends()
print(detection.headlessAvailable)  // true/false
print(detection.agentSDKAvailable)  // true/false
print(detection.recommendedBackend) // .headless or .agentSDK

// Async detection with validation
let detection = await ClaudeCodeClient.detectAvailableBackendsAsync()
```

## Requirements

- Swift 6.0+
- macOS 13+ or Linux

**For Headless Backend:**
- Claude Code CLI installed (`curl -fsSL https://claude.ai/install.sh | bash`)

**For Agent SDK Backend:**
- Node.js installed
- `@anthropic-ai/claude-agent-sdk` npm package

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mfxstudios/ClaudeCodeSDK", from: "0.1.0")
]
```

## Quick Start

```swift
import ClaudeCodeSDK

// Create a client (uses headless backend by default)
let client = ClaudeCodeClient()

// Simple text prompt
let text = try await client.runText("What is 2 + 2?")
print(text)

// JSON response with metadata
let result = try await client.ask("Explain Swift in one sentence.")
print(result.result ?? "")
print("Cost: $\(result.totalCostUsd)")
```

## Usage Examples

### Basic Prompt

```swift
let client = ClaudeCodeClient()
let result = try await client.runText("Hello, Claude!")
print(result)
```

### JSON Response

```swift
let client = ClaudeCodeClient()
let result = try await client.ask("What is the capital of France?")

print("Answer: \(result.result ?? "")")
print("Session ID: \(result.sessionId)")
print("Cost: $\(String(format: "%.6f", result.totalCostUsd))")
print("Duration: \(result.durationMs)ms")
```

### Streaming Response

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
let client = ClaudeCodeClient()

let result = try await client.runSinglePrompt(
    prompt: "Count to 5",
    outputFormat: .streamJson,
    options: nil
)

guard case .stream(let stream) = result else { return }

// Collect all text
let allText = try await stream.allText()
print(allText)

// Or get the final result
let finalResult = try await stream.finalResult()
```

### Using Agent SDK Backend

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK

let client = try ClaudeCodeClient(configuration: config)

// Same API as headless backend
let result = try await client.ask("Hello from Agent SDK!")
print(result.result ?? "")
```

### Custom Configuration

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .headless  // or .agentSDK
config.workingDirectory = "/path/to/project"
config.enableDebugLogging = true
config.environment["CUSTOM_VAR"] = "value"

let client = try ClaudeCodeClient(configuration: config)
```

### With Options

```swift
var options = ClaudeCodeOptions()
options.systemPrompt = "You are a helpful coding assistant."
options.maxTurns = 5
options.model = "claude-3-opus"

let result = try await client.runSinglePrompt(
    prompt: "Review this code",
    outputFormat: .json,
    options: options
)
```

### Continue a Conversation

```swift
// Start a conversation
let result1 = try await client.ask("My name is Alice.")
let sessionId = result1.sessionId

// Resume it later
let result2 = try await client.resumeConversation(
    sessionId: sessionId,
    prompt: "What's my name?",
    outputFormat: .json,
    options: nil
)
```

### Pipe Content via Stdin

```swift
let code = """
func add(a: Int, b: Int) -> Int {
    return a + b
}
"""

let result = try await client.runWithStdin(
    stdinContent: code,
    outputFormat: .text,
    options: ClaudeCodeOptions(appendSystemPrompt: "Review this code.")
)
```

## API Reference

### ClaudeCodeClient

The main client for interacting with Claude Code.

```swift
// Initialization
let client = ClaudeCodeClient()  // Default headless
let client = try ClaudeCodeClient(configuration: config)  // Custom config
let client = try ClaudeCodeClient(workingDirectory: "/path", debug: true, backend: .headless)

// Properties
var backendType: BackendType { get }           // Configured backend (.auto, .headless, .agentSDK)
var resolvedBackendType: BackendType { get }   // Actual backend in use (.headless or .agentSDK)
var detectionResult: BackendDetector.DetectionResult? { get }  // Detection info (when using auto)
var configuration: ClaudeCodeConfiguration { get }

// Static Detection Methods
static func detectAvailableBackends() -> BackendDetector.DetectionResult
static func detectAvailableBackendsAsync() async -> BackendDetector.DetectionResult

// Methods
func runText(_ prompt: String) async throws -> String
func ask(_ prompt: String, options: ClaudeCodeOptions?) async throws -> ResultMessage
func stream(_ prompt: String, options: ClaudeCodeOptions?, onChunk: (ResponseChunk) async -> Void) async throws -> ResultMessage?
func runSinglePrompt(prompt: String, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult
func runWithStdin(stdinContent: String, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult
func continueConversation(prompt: String?, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult
func resumeConversation(sessionId: String, prompt: String?, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult
func listSessions() async throws -> [SessionInfo]
func validateBackend() async throws -> Bool
func cancel()
```

### BackendType

```swift
enum BackendType {
    case auto       // Auto-detect best available backend (default)
    case headless   // Uses `claude -p` CLI subprocess
    case agentSDK   // Uses Node.js wrapper around @anthropic-ai/claude-agent-sdk
}
```

### BackendDetector.DetectionResult

```swift
struct DetectionResult {
    var headlessAvailable: Bool         // Whether Claude CLI is available
    var agentSDKAvailable: Bool         // Whether Node.js is available
    var claudeCliPath: String?          // Path to Claude CLI (if found)
    var nodePath: String?               // Path to Node.js (if found)
    var recommendedBackend: BackendType // Recommended backend (.headless preferred)
    var anyBackendAvailable: Bool       // Whether any backend is available
    var description: String             // Human-readable summary
}
```

### ClaudeCodeConfiguration

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .auto                 // Backend type (default: .auto)
config.command = "claude"              // CLI command name (headless)
config.nodeExecutable = "/path/node"   // Node.js path (agentSDK)
config.sdkWrapperPath = "/path/wrap"   // Wrapper script (agentSDK)
config.workingDirectory = "/path"      // Working directory
config.environment = ["KEY": "value"]  // Environment variables
config.enableDebugLogging = true       // Debug output
config.additionalPaths = ["/custom"]   // Extra PATH entries
config.commandSuffix = "--"            // Argument delimiter
config.disallowedTools = ["Bash"]      // Restricted tools
```

### ClaudeCodeOptions

```swift
var options = ClaudeCodeOptions()
options.systemPrompt = "..."           // Custom system prompt
options.appendSystemPrompt = "..."     // Append to system prompt
options.maxTurns = 10                  // Max conversation turns
options.maxThinkingTokens = 1000       // Extended reasoning budget
options.model = "claude-3-opus"        // Model selection
options.timeout = 60                   // Timeout in seconds
options.allowedTools = ["Read"]        // Allowed tools
options.disallowedTools = ["Bash"]     // Disallowed tools
options.permissionMode = .acceptEdits  // Permission handling
options.mcpServers = [...]             // MCP server configurations
options.mcpConfigPath = "/path"        // MCP config file
options.verbose = true                 // Verbose output
```

### Output Formats

```swift
enum ClaudeCodeOutputFormat {
    case text       // Plain text
    case json       // Structured JSON
    case streamJson // Real-time streaming
}
```

### Result Types

```swift
enum ClaudeCodeResult {
    case text(String)
    case json(ResultMessage)
    case stream(ClaudeCodeStream)
}
```

### Response Chunks (Streaming)

```swift
enum ResponseChunk {
    case initSystem(InitSystemMessage)
    case user(UserMessage)
    case assistant(AssistantMessage)
    case result(ResultMessage)
}
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

    // Error properties
    if error.isRetryable {
        if let delay = error.suggestedRetryDelay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            // Retry...
        }
    }
}
```

## Project Structure

```
ClaudeCodeSDK/
├── Sources/
│   └── ClaudeCodeSDK/
│       ├── API/                    # Public types
│       │   ├── ClaudeCodeConfiguration.swift
│       │   ├── ClaudeCodeOptions.swift
│       │   ├── ClaudeCodeResult.swift
│       │   ├── ClaudeCodeError.swift
│       │   └── Messages.swift
│       ├── Backend/                # Execution backends
│       │   ├── ClaudeCodeBackend.swift
│       │   ├── BackendDetector.swift   # Auto-detection logic
│       │   ├── HeadlessBackend.swift
│       │   └── AgentSDKBackend.swift
│       ├── Client/
│       │   └── ClaudeCodeClient.swift
│       ├── Process/
│       │   └── ProcessExecutor.swift
│       ├── Streaming/
│       │   └── StreamParser.swift
│       └── Resources/
│           └── sdk-wrapper.mjs     # Node.js wrapper for Agent SDK
└── Tests/
```

## License

MIT License
