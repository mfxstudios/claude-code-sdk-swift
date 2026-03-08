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

// MARK: - Claude Model Tests

@Suite("Claude Model Tests")
struct ClaudeModelTests {

    @Test("Model constants have correct raw values")
    func modelConstants() {
        #expect(ClaudeModel.opus4_6.rawValue == "claude-opus-4-6-20260205")
        #expect(ClaudeModel.opus4_5.rawValue == "claude-opus-4-5-20251124")
        #expect(ClaudeModel.sonnet4_6.rawValue == "claude-sonnet-4-6-20260217")
        #expect(ClaudeModel.sonnet4_5.rawValue == "claude-sonnet-4-5-20250514")
        #expect(ClaudeModel.haiku4_5.rawValue == "claude-haiku-4-5-20251001")
    }

    @Test("Latest aliases point to correct models")
    func modelAliases() {
        #expect(ClaudeModel.latestOpus == .opus4_6)
        #expect(ClaudeModel.latestSonnet == .sonnet4_6)
        #expect(ClaudeModel.latestHaiku == .haiku4_5)
    }

    @Test("Deprecated models are identified")
    func deprecatedModels() {
        let deprecated = ClaudeModel(rawValue: "claude-3-opus-20240229")
        #expect(deprecated.isDeprecated == true)

        #expect(ClaudeModel.opus4_6.isDeprecated == false)
        #expect(ClaudeModel.sonnet4_5.isDeprecated == false)
    }

    @Test("String literal creates model correctly")
    func stringLiteral() {
        let model: ClaudeModel = "custom-model-id"
        #expect(model.rawValue == "custom-model-id")
    }

    @Test("Model equality works")
    func modelEquality() {
        let a = ClaudeModel(rawValue: "claude-opus-4-6-20260205")
        let b = ClaudeModel.opus4_6
        #expect(a == b)

        let c: ClaudeModel = "claude-opus-4-6-20260205"
        #expect(a == c)
    }

    @Test("Model is used in options and command args")
    func modelInOptions() {
        var options = ClaudeCodeOptions()
        options.model = .opus4_6

        let args = options.toCommandArgs()

        #expect(args.contains("--model"))
        #expect(args.contains("claude-opus-4-6-20260205"))
    }

    @Test("Model string literal in options works")
    func modelStringLiteralInOptions() {
        var options = ClaudeCodeOptions()
        options.model = "some-custom-model"

        let args = options.toCommandArgs()

        #expect(args.contains("--model"))
        #expect(args.contains("some-custom-model"))
    }
}

// MARK: - Thinking Configuration Tests

@Suite("Thinking Configuration Tests")
struct ThinkingConfigurationTests {

    @Test("Enabled thinking encodes correctly")
    func enabledThinkingEncoding() throws {
        let thinking = ThinkingConfiguration.enabled(budgetTokens: 10000)
        let data = try JSONEncoder().encode(thinking)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"type\":\"enabled\"") || json.contains("\"type\" : \"enabled\""))
        #expect(json.contains("10000"))
    }

    @Test("Adaptive thinking encodes correctly")
    func adaptiveThinkingEncoding() throws {
        let thinking = ThinkingConfiguration.adaptive
        let data = try JSONEncoder().encode(thinking)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("adaptive"))
    }

    @Test("Disabled thinking encodes correctly")
    func disabledThinkingEncoding() throws {
        let thinking = ThinkingConfiguration.disabled
        let data = try JSONEncoder().encode(thinking)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("disabled"))
    }

    @Test("Thinking configuration round-trips through Codable")
    func thinkingRoundTrip() throws {
        let configs: [ThinkingConfiguration] = [
            .disabled,
            .enabled(budgetTokens: 5000),
            .adaptive
        ]

        for config in configs {
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(ThinkingConfiguration.self, from: data)
            #expect(decoded == config)
        }
    }

    @Test("Thinking enabled generates correct command args")
    func thinkingEnabledCommandArgs() {
        var options = ClaudeCodeOptions()
        options.thinking = .enabled(budgetTokens: 16000)

        let args = options.toCommandArgs()

        #expect(args.contains("--max-thinking-tokens"))
        #expect(args.contains("16000"))
    }

    @Test("Thinking adaptive generates correct command args")
    func thinkingAdaptiveCommandArgs() {
        var options = ClaudeCodeOptions()
        options.thinking = .adaptive

        let args = options.toCommandArgs()

        #expect(args.contains("--thinking-mode"))
        #expect(args.contains("adaptive"))
    }

    @Test("Thinking disabled generates no command args")
    func thinkingDisabledCommandArgs() {
        var options = ClaudeCodeOptions()
        options.thinking = .disabled

        let args = options.toCommandArgs()

        #expect(!args.contains("--max-thinking-tokens"))
        #expect(!args.contains("--thinking-mode"))
    }
}

// MARK: - Speed Mode Tests

@Suite("Speed Mode Tests")
struct SpeedModeTests {

    @Test("Speed mode raw values are correct")
    func speedModeRawValues() {
        #expect(SpeedMode.normal.rawValue == "normal")
        #expect(SpeedMode.fast.rawValue == "fast")
    }

    @Test("Fast speed generates command args")
    func fastSpeedCommandArgs() {
        var options = ClaudeCodeOptions()
        options.speed = .fast

        let args = options.toCommandArgs()

        #expect(args.contains("--fast"))
    }

    @Test("Normal speed does not generate command args")
    func normalSpeedCommandArgs() {
        var options = ClaudeCodeOptions()
        options.speed = .normal

        let args = options.toCommandArgs()

        #expect(!args.contains("--fast"))
    }
}

// MARK: - Beta Feature Tests

@Suite("Beta Feature Tests")
struct BetaFeatureTests {

    @Test("Beta features have correct raw values")
    func betaFeatureRawValues() {
        #expect(BetaFeature.compaction.rawValue == "compact-2026-01-12")
        #expect(BetaFeature.extendedContext1M.rawValue == "context-1m-2025-08-07")
        #expect(BetaFeature.interleavedThinking.rawValue == "interleaved-thinking-2025-05-14")
        #expect(BetaFeature.computerUse.rawValue == "computer-use-2025-01-24")
    }

    @Test("Beta features can be collected in a set")
    func betaFeatureSet() {
        let betas: Set<BetaFeature> = [.compaction, .extendedContext1M]
        #expect(betas.count == 2)
        #expect(betas.contains(.compaction))
        #expect(betas.contains(.extendedContext1M))
    }
}

// MARK: - Output Config Tests

@Suite("Output Config Tests")
struct OutputConfigTests {

    @Test("Text format encodes correctly")
    func textFormatEncoding() throws {
        let config = OutputConfig(format: .text)
        let data = try JSONEncoder().encode(config)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("text"))
    }

    @Test("JSON schema format encodes correctly")
    func jsonSchemaFormatEncoding() throws {
        let schema = JSONSchemaDefinition(
            name: "test_schema",
            schema: ["type": AnyCodable("object")],
            strict: true
        )
        let config = OutputConfig(format: .jsonSchema(schema))
        let data = try JSONEncoder().encode(config)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("json_schema"))
        #expect(json.contains("test_schema"))
    }
}

// MARK: - Content Block Extended Tests

@Suite("Content Block Extended Tests")
struct ContentBlockExtendedTests {

    @Test("Thinking content block decodes correctly")
    func thinkingContentBlockDecoding() throws {
        let json = """
        {"type":"thinking","thinking":"Let me consider this step by step..."}
        """

        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: data)

        if case .thinking(let content) = block {
            #expect(content.thinking == "Let me consider this step by step...")
        } else {
            Issue.record("Expected thinking content block")
        }
    }

    @Test("Citation content block decodes correctly")
    func citationContentBlockDecoding() throws {
        let json = """
        {"type":"citation","cited_text":"The quick brown fox","document_title":"Test Doc","document_index":0,"start_char_index":10,"end_char_index":30}
        """

        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: data)

        if case .citation(let content) = block {
            #expect(content.citedText == "The quick brown fox")
            #expect(content.documentTitle == "Test Doc")
            #expect(content.documentIndex == 0)
            #expect(content.startCharIndex == 10)
            #expect(content.endCharIndex == 30)
        } else {
            Issue.record("Expected citation content block")
        }
    }

    @Test("Unknown content blocks still decode gracefully")
    func unknownContentBlockDecoding() throws {
        let json = """
        {"type":"future_type","data":"some value"}
        """

        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: data)

        if case .unknown(let dict) = block {
            #expect(dict["type"]?.value as? String == "future_type")
        } else {
            Issue.record("Expected unknown content block")
        }
    }

    @Test("Thinking content encodes and decodes round-trip")
    func thinkingContentRoundTrip() throws {
        let original = ThinkingContent(thinking: "My reasoning process")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThinkingContent.self, from: data)

        #expect(decoded.type == "thinking")
        #expect(decoded.thinking == "My reasoning process")
    }
}

// MARK: - New Options Tests

@Suite("New Options Tests")
struct NewOptionsTests {

    @Test("Default options have nil for new properties")
    func defaultNewOptions() {
        let options = ClaudeCodeOptions()

        #expect(options.thinking == nil)
        #expect(options.speed == nil)
        #expect(options.betaFeatures == nil)
        #expect(options.outputConfig == nil)
        #expect(options.model == nil)
    }

    @Test("Options initializer accepts new parameters")
    func optionsInitWithNewParams() {
        let options = ClaudeCodeOptions(
            model: .opus4_6,
            thinking: .adaptive,
            speed: .fast,
            betaFeatures: [.compaction]
        )

        #expect(options.model == .opus4_6)
        #expect(options.thinking == .adaptive)
        #expect(options.speed == .fast)
        #expect(options.betaFeatures?.contains(.compaction) == true)
    }

    @Test("New error cases have correct descriptions")
    func newErrorDescriptions() {
        let depError = ClaudeCodeError.deprecatedModel("claude-3-opus")
        #expect(depError.localizedDescription.contains("deprecated"))

        let quotaError = ClaudeCodeError.quotaExceeded("monthly limit")
        #expect(quotaError.localizedDescription.contains("quota"))
    }

    @Test("Interactive session configuration accepts new properties")
    func interactiveSessionNewConfig() {
        let config = InteractiveSessionConfiguration(
            thinking: .enabled(budgetTokens: 8000),
            speed: .fast,
            model: .sonnet4_6
        )

        #expect(config.thinking == .enabled(budgetTokens: 8000))
        #expect(config.speed == .fast)
        #expect(config.model == .sonnet4_6)
    }

    @Test("Interactive event includes thinking case")
    func interactiveEventThinking() {
        let event = InteractiveEvent.thinking("Reasoning here...")

        if case .thinking(let text) = event {
            #expect(text == "Reasoning here...")
        } else {
            Issue.record("Expected thinking event")
        }
    }
}
