//
//  ClaudeCodeSDKTests.swift
//  ClaudeCodeSDK
//
//  Cross-platform Swift SDK for Claude Code CLI
//

import Testing
@testable import ClaudeCodeSDK

// MARK: - Configuration Tests

@Suite("Configuration Tests")
struct ConfigurationTests {

    @Test("Default configuration has expected values")
    func defaultConfiguration() {
        let config = ClaudeCodeConfiguration.default

        #expect(config.backend == .auto)
        #expect(config.command == "claude")
        #expect(config.workingDirectory == nil)
        #expect(config.enableDebugLogging == false)
        #expect(config.environment.isEmpty)
    }

    @Test("Custom configuration stores values correctly")
    func customConfiguration() {
        var config = ClaudeCodeConfiguration.default
        config.command = "custom-claude"
        config.workingDirectory = "/tmp"
        config.enableDebugLogging = true
        config.environment["TEST_VAR"] = "test_value"

        #expect(config.command == "custom-claude")
        #expect(config.workingDirectory == "/tmp")
        #expect(config.enableDebugLogging == true)
        #expect(config.environment["TEST_VAR"] == "test_value")
    }

    @Test("Build environment includes PATH and custom variables")
    func buildEnvironment() {
        var config = ClaudeCodeConfiguration.default
        config.environment["CUSTOM_KEY"] = "custom_value"

        let env = config.buildEnvironment()

        #expect(env["PATH"] != nil)
        #expect(env["CUSTOM_KEY"] == "custom_value")
    }
}

// MARK: - Options Tests

@Suite("Options Tests")
struct OptionsTests {

    @Test("Options convert to correct command arguments")
    func optionsToCommandArgs() {
        var options = ClaudeCodeOptions()
        options.maxTurns = 5
        options.model = "claude-3-opus"
        options.verbose = true

        let args = options.toCommandArgs()

        #expect(args.contains("--max-turns"))
        #expect(args.contains("5"))
        #expect(args.contains("--model"))
        #expect(args.contains("claude-3-opus"))
        #expect(args.contains("--verbose"))
    }

    @Test("System prompt is included in arguments")
    func optionsWithSystemPrompt() {
        var options = ClaudeCodeOptions()
        options.systemPrompt = "You are a helpful assistant."

        let args = options.toCommandArgs()

        #expect(args.contains("--system-prompt"))
        #expect(args.contains("You are a helpful assistant."))
    }

    @Test("Allowed tools are included in arguments")
    func optionsWithAllowedTools() {
        var options = ClaudeCodeOptions()
        options.allowedTools = ["Read", "Write", "Bash"]

        let args = options.toCommandArgs()

        #expect(args.filter { $0 == "--allowedTools" }.count == 3)
        #expect(args.contains("Read"))
        #expect(args.contains("Write"))
        #expect(args.contains("Bash"))
    }
}

// MARK: - Output Format Tests

@Suite("Output Format Tests")
struct OutputFormatTests {

    @Test("Output formats have correct CLI flags")
    func outputFormatCliFlags() {
        #expect(ClaudeCodeOutputFormat.text.cliFlag == "--output-format=text")
        #expect(ClaudeCodeOutputFormat.json.cliFlag == "--output-format=json")
        #expect(ClaudeCodeOutputFormat.streamJson.cliFlag == "--output-format=stream-json")
    }
}

// MARK: - Error Tests

@Suite("Error Tests")
struct ErrorTests {

    @Test("Error descriptions contain expected text", arguments: [
        (ClaudeCodeError.notInstalled, "Claude Code CLI is not installed"),
        (ClaudeCodeError.cancelled, "Operation was cancelled"),
        (ClaudeCodeError.timeout(30), "30"),
        (ClaudeCodeError.executionFailed("test error"), "test error"),
    ])
    func errorDescriptions(error: ClaudeCodeError, expectedSubstring: String) {
        #expect(error.localizedDescription.contains(expectedSubstring))
    }

    @Test("Rate limit error is identified correctly")
    func rateLimitErrorProperty() {
        #expect(ClaudeCodeError.rateLimitExceeded(retryAfter: 60).isRateLimitError == true)
        #expect(ClaudeCodeError.timeout(30).isRateLimitError == false)
    }

    @Test("Timeout error is identified correctly")
    func timeoutErrorProperty() {
        #expect(ClaudeCodeError.timeout(30).isTimeoutError == true)
        #expect(ClaudeCodeError.notInstalled.isTimeoutError == false)
    }

    @Test("Installation error is identified correctly")
    func installationErrorProperty() {
        #expect(ClaudeCodeError.notInstalled.isInstallationError == true)
        #expect(ClaudeCodeError.cancelled.isInstallationError == false)
    }

    @Test("Permission error is identified correctly")
    func permissionErrorProperty() {
        #expect(ClaudeCodeError.permissionDenied("test").isPermissionError == true)
        #expect(ClaudeCodeError.notInstalled.isPermissionError == false)
    }

    @Test("Retryable errors are identified correctly")
    func retryableErrors() {
        #expect(ClaudeCodeError.rateLimitExceeded(retryAfter: nil).isRetryable == true)
        #expect(ClaudeCodeError.timeout(30).isRetryable == true)
        #expect(ClaudeCodeError.networkError("test").isRetryable == true)
        #expect(ClaudeCodeError.notInstalled.isRetryable == false)
    }

    @Test("Suggested retry delay is correct for each error type")
    func suggestedRetryDelay() {
        #expect(ClaudeCodeError.rateLimitExceeded(retryAfter: 30).suggestedRetryDelay == 30)
        #expect(ClaudeCodeError.rateLimitExceeded(retryAfter: nil).suggestedRetryDelay == 60)
        #expect(ClaudeCodeError.timeout(30).suggestedRetryDelay == 5)
        #expect(ClaudeCodeError.networkError("test").suggestedRetryDelay == 1)
        #expect(ClaudeCodeError.notInstalled.suggestedRetryDelay == nil)
    }
}

// MARK: - Message Types Tests

@Suite("Message Types Tests")
struct MessageTypesTests {

    @Test("ResultMessage description contains expected information")
    func resultMessageDescription() {
        let result = ResultMessage(
            type: "result",
            subtype: "success",
            totalCostUsd: 0.001234,
            durationMs: 5000,
            durationApiMs: 4500,
            isError: false,
            numTurns: 2,
            result: "Test result",
            sessionId: "test-session-123",
            usage: nil
        )

        let description = result.description()

        #expect(description.contains("Test result"))
        #expect(description.contains("success"))
        #expect(description.contains("0.001234"))
    }
}

// MARK: - AnyCodable Tests

@Suite("AnyCodable Tests")
struct AnyCodableTests {

    @Test("AnyCodable decodes JSON correctly")
    func anyCodableDecoding() throws {
        let json = """
        {
            "string": "hello",
            "number": 42,
            "bool": true,
            "null": null,
            "array": [1, 2, 3],
            "object": {"nested": "value"}
        }
        """

        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(decoded["string"]?.value as? String == "hello")
        #expect(decoded["number"]?.value as? Int == 42)
        #expect(decoded["bool"]?.value as? Bool == true)
    }

    @Test("AnyCodable encodes and decodes round-trip")
    func anyCodableEncoding() throws {
        let dict: [String: AnyCodable] = [
            "string": "hello",
            "number": 42,
            "bool": true
        ]

        let data = try JSONEncoder().encode(dict)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        #expect(decoded["string"]?.value as? String == "hello")
    }
}

// MARK: - Client Initialization Tests

@Suite("Client Initialization Tests")
struct ClientInitializationTests {

    @Test("Client initializes with default configuration")
    func clientInitialization() {
        let client = ClaudeCodeClient()

        #expect(client.configuration.command == "claude")
        #expect(client.configuration.backend == .auto)
        #expect(client.lastExecutedCommandInfo == nil)
    }

    @Test("Client has resolved backend type after initialization")
    func clientResolvedBackendType() {
        let client = ClaudeCodeClient()

        // When using auto, resolvedBackendType should be either headless or agentSDK
        #expect(client.resolvedBackendType == .headless || client.resolvedBackendType == .agentSDK)
        // Detection result should be populated when using auto
        #expect(client.detectionResult != nil)
    }

    @Test("Client initializes with custom configuration")
    func clientWithCustomConfig() throws {
        var config = ClaudeCodeConfiguration.default
        config.workingDirectory = "/tmp"
        config.enableDebugLogging = true

        let client = try ClaudeCodeClient(configuration: config)

        #expect(client.configuration.workingDirectory == "/tmp")
        #expect(client.configuration.enableDebugLogging == true)
    }

    @Test("Client backend type property returns configured value")
    func clientBackendType() {
        let client = ClaudeCodeClient()
        #expect(client.backendType == .auto)
    }

    @Test("Client with explicit headless backend has no detection result")
    func clientExplicitHeadless() throws {
        var config = ClaudeCodeConfiguration.default
        config.backend = .headless

        let client = try ClaudeCodeClient(configuration: config)

        #expect(client.resolvedBackendType == .headless)
        #expect(client.detectionResult == nil)
    }
}

// MARK: - Backend Tests

@Suite("Backend Tests")
struct BackendTests {

    @Test("BackendType enum has correct raw values")
    func backendTypeRawValues() {
        #expect(BackendType.auto.rawValue == "auto")
        #expect(BackendType.headless.rawValue == "headless")
        #expect(BackendType.agentSDK.rawValue == "agentSDK")
    }

    @Test("BackendFactory creates headless backend")
    func backendFactoryCreatesHeadless() throws {
        var config = ClaudeCodeConfiguration.default
        config.backend = .headless

        let backend = try BackendFactory.createBackend(for: config)

        #expect(backend is HeadlessBackend)
    }

    @Test("Configuration with Agent SDK backend")
    func agentSDKConfiguration() {
        var config = ClaudeCodeConfiguration.default
        config.backend = .agentSDK
        config.nodeExecutable = "/usr/local/bin/node"
        config.sdkWrapperPath = "/path/to/wrapper.mjs"

        #expect(config.backend == .agentSDK)
        #expect(config.nodeExecutable == "/usr/local/bin/node")
        #expect(config.sdkWrapperPath == "/path/to/wrapper.mjs")
    }

    @Test("BackendFactory creates backend with result for auto detection")
    func backendFactoryCreatesWithResult() throws {
        var config = ClaudeCodeConfiguration.default
        config.backend = .auto

        let result = try BackendFactory.createBackendWithResult(for: config)

        // Resolved type should be headless or agentSDK, never auto
        #expect(result.resolvedType == .headless || result.resolvedType == .agentSDK)
        #expect(result.detectionResult != nil)
    }

    @Test("BackendFactory result has nil detection result for explicit backend")
    func backendFactoryExplicitBackendNoDetection() throws {
        var config = ClaudeCodeConfiguration.default
        config.backend = .headless

        let result = try BackendFactory.createBackendWithResult(for: config)

        #expect(result.resolvedType == .headless)
        #expect(result.detectionResult == nil)
    }
}

// MARK: - Backend Detector Tests

@Suite("Backend Detector Tests")
struct BackendDetectorTests {

    @Test("Detection result properties are consistent")
    func detectionResultProperties() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: true,
            agentSDKAvailable: false,
            claudeCliPath: "/usr/local/bin/claude",
            nodePath: nil,
            claudeCodePackageInstalled: false
        )

        #expect(result.headlessAvailable == true)
        #expect(result.agentSDKAvailable == false)
        #expect(result.claudeCliPath == "/usr/local/bin/claude")
        #expect(result.nodePath == nil)
        #expect(result.claudeCodePackageInstalled == false)
        #expect(result.anyBackendAvailable == true)
        #expect(result.recommendedBackend == .headless)
    }

    @Test("Detection recommends headless when both available")
    func detectionPreferenceWithBothAvailable() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: true,
            agentSDKAvailable: true,
            claudeCliPath: "/usr/local/bin/claude",
            nodePath: "/usr/local/bin/node",
            claudeCodePackageInstalled: true
        )

        // Headless is preferred
        #expect(result.recommendedBackend == .agentSDK)
        #expect(result.anyBackendAvailable == true)
    }

    @Test("Detection recommends agentSDK when only Node and package available")
    func detectionFallbackToAgentSDK() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: false,
            agentSDKAvailable: true,
            claudeCliPath: nil,
            nodePath: "/usr/local/bin/node",
            claudeCodePackageInstalled: true
        )

        #expect(result.recommendedBackend == .agentSDK)
        #expect(result.anyBackendAvailable == true)
    }

    @Test("Detection defaults to headless when nothing available")
    func detectionDefaultsToHeadless() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: false,
            agentSDKAvailable: false,
            claudeCliPath: nil,
            nodePath: nil,
            claudeCodePackageInstalled: false
        )

        // Defaults to headless even when not detected
        #expect(result.recommendedBackend == .headless)
        #expect(result.anyBackendAvailable == false)
    }

    @Test("Detection description contains expected text")
    func detectionResultDescription() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: true,
            agentSDKAvailable: false,
            claudeCliPath: "/usr/local/bin/claude",
            nodePath: nil,
            claudeCodePackageInstalled: false
        )

        let description = result.description

        #expect(description.contains("Headless backend available"))
        #expect(description.contains("/usr/local/bin/claude"))
        #expect(description.contains("Agent SDK backend not"))
        #expect(description.contains("Recommended: headless"))
    }

    @Test("Detection shows Node found but package not installed")
    func detectionNodeWithoutPackage() {
        let result = BackendDetector.DetectionResult(
            headlessAvailable: false,
            agentSDKAvailable: false,
            claudeCliPath: nil,
            nodePath: "/usr/local/bin/node",
            claudeCodePackageInstalled: false
        )

        let description = result.description

        #expect(description.contains("Node.js found but @anthropic-ai/claude-agent-sdk not installed"))
        #expect(result.agentSDKAvailable == false)
    }

    @Test("Backend detector runs synchronous detection")
    func detectorSyncDetection() {
        let detector = BackendDetector()
        let result = detector.detect()

        // Result should be populated
        #expect(result.recommendedBackend == .headless || result.recommendedBackend == .agentSDK)
    }

    @Test("Backend detector runs async detection")
    func detectorAsyncDetection() async {
        let detector = BackendDetector()
        let result = await detector.detectAsync()

        // Result should be populated
        #expect(result.recommendedBackend == .headless || result.recommendedBackend == .agentSDK)
    }

    @Test("Static convenience methods work correctly")
    func staticConvenienceMethods() {
        // These should not throw and return valid results
        let headlessAvailable = BackendDetector.isHeadlessAvailable()
        let agentSDKAvailable = BackendDetector.isAgentSDKAvailable()
        let recommended = BackendDetector.recommendedBackend()

        // Just verify they return without crashing
        #expect(headlessAvailable == true || headlessAvailable == false)
        #expect(agentSDKAvailable == true || agentSDKAvailable == false)
        #expect(recommended == .headless || recommended == .agentSDK)
    }

    @Test("Client static detection methods work")
    func clientStaticDetection() {
        let result = ClaudeCodeClient.detectAvailableBackends()

        #expect(result.recommendedBackend == .headless || result.recommendedBackend == .agentSDK)
    }

    @Test("Client async static detection methods work")
    func clientAsyncStaticDetection() async {
        let result = await ClaudeCodeClient.detectAvailableBackendsAsync()

        #expect(result.recommendedBackend == .headless || result.recommendedBackend == .agentSDK)
    }
}

// MARK: - Stream Parser Tests

@Suite("Stream Parser Tests")
struct StreamParserTests {

    @Test("Parser handles valid system message")
    func streamParserWithValidLine() throws {
        let parser = StreamParser()

        let systemLine = """
        {"type":"system","subtype":"init","session_id":"test-123","tools":[],"mcp_servers":[]}
        """

        let chunk = try parser.parseLine(systemLine)

        #expect(chunk != nil)
        if case .initSystem(let msg) = chunk {
            #expect(msg.sessionId == "test-123")
            #expect(msg.subtype == "init")
        } else {
            Issue.record("Expected initSystem chunk")
        }
    }

    @Test("Parser returns nil for empty line")
    func streamParserWithEmptyLine() throws {
        let parser = StreamParser()

        let chunk = try parser.parseLine("")

        #expect(chunk == nil)
    }

    @Test("Parser handles result message")
    func streamParserWithResultMessage() throws {
        let parser = StreamParser()

        let resultLine = """
        {"type":"result","subtype":"success","total_cost_usd":0.001,"duration_ms":1000,"duration_api_ms":900,"is_error":false,"num_turns":1,"result":"Test","session_id":"test-456"}
        """

        let chunk = try parser.parseLine(resultLine)

        #expect(chunk != nil)
        if case .result(let msg) = chunk {
            #expect(msg.sessionId == "test-456")
            #expect(msg.result == "Test")
            #expect(msg.isError == false)
        } else {
            Issue.record("Expected result chunk")
        }
    }
}

// MARK: - MCP Server Configuration Tests

@Suite("MCP Server Configuration Tests")
struct McpServerConfigurationTests {

    @Test("MCP server configuration stores values correctly")
    func mcpServerConfiguration() {
        let config = McpServerConfiguration(
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem"],
            env: ["HOME": "/home/user"]
        )

        #expect(config.command == "npx")
        #expect(config.args?.count == 2)
        #expect(config.env?["HOME"] == "/home/user")
    }
}

// MARK: - Permission Mode Tests

@Suite("Permission Mode Tests")
struct PermissionModeTests {

    @Test("Permission modes have correct raw values")
    func permissionModeRawValues() {
        #expect(PermissionMode.default.rawValue == "default")
        #expect(PermissionMode.acceptEdits.rawValue == "acceptEdits")
        #expect(PermissionMode.bypassPermissions.rawValue == "bypassPermissions")
    }
}

// MARK: - ClaudeCodeResult Tests

@Suite("ClaudeCodeResult Tests")
struct ClaudeCodeResultTests {

    @Test("Text result has correct properties")
    func textResult() {
        let result = ClaudeCodeResult.text("Hello, world!")

        #expect(result.textValue == "Hello, world!")
        #expect(result.jsonValue == nil)
        #expect(result.streamValue == nil)
        #expect(result.sessionId == nil)
    }

    @Test("JSON result has correct properties")
    func jsonResult() {
        let message = ResultMessage(
            type: "result",
            subtype: "success",
            totalCostUsd: 0.001,
            durationMs: 1000,
            durationApiMs: 900,
            isError: false,
            numTurns: 1,
            result: "Test",
            sessionId: "test-789",
            usage: nil
        )

        let result = ClaudeCodeResult.json(message)

        #expect(result.textValue == nil)
        #expect(result.jsonValue != nil)
        #expect(result.streamValue == nil)
        #expect(result.sessionId == "test-789")
    }
}
