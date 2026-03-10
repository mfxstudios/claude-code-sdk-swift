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
        #expect(PermissionMode.plan.rawValue == "plan")
        #expect(PermissionMode.bypassPermissions.rawValue == "bypassPermissions")
    }

    @Test("Permission mode generates correct command args")
    func permissionModeCommandArgs() {
        var options = ClaudeCodeOptions()
        options.permissionMode = .plan

        let args = options.toCommandArgs()

        #expect(args.contains("--permission-mode"))
        #expect(args.contains("plan"))
    }

    @Test("Permission prompt tool name generates correct command args")
    func permissionPromptToolNameCommandArgs() {
        var options = ClaudeCodeOptions()
        options.permissionPromptToolName = "deny-all"

        let args = options.toCommandArgs()

        #expect(args.contains("--permission-prompt-tool"))
        #expect(args.contains("deny-all"))
    }

    @Test("Permission prompt tool name is absent when nil")
    func permissionPromptToolNameAbsentWhenNil() {
        let options = ClaudeCodeOptions()
        let args = options.toCommandArgs()

        #expect(!args.contains("--permission-prompt-tool"))
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

// MARK: - Tool Permission Rule Tests

@Suite("Tool Permission Rule Tests")
struct ToolPermissionRuleTests {

    @Test("Basic tool rule creates correct string")
    func basicToolRule() {
        let rule = ToolPermissionRule.tool("Bash")
        #expect(rule.rule == "Bash")
    }

    @Test("Tool rule with argument creates correct pattern")
    func toolRuleWithArgument() {
        let rule = ToolPermissionRule.tool("Bash", argument: "git *")
        #expect(rule.rule == "Bash(git *)")
    }

    @Test("Tool rule with path argument creates correct pattern")
    func toolRuleWithPathArgument() {
        let rule = ToolPermissionRule.tool("Read", argument: "/src/*")
        #expect(rule.rule == "Read(/src/*)")
    }

    @Test("Tool rule with wildcard argument")
    func toolRuleWithWildcardArgument() {
        let rule = ToolPermissionRule.tool("Write", argument: "*")
        #expect(rule.rule == "Write(*)")
    }

    @Test("String literal creates tool rule")
    func stringLiteralToolRule() {
        let rule: ToolPermissionRule = "Bash(npm *)"
        #expect(rule.rule == "Bash(npm *)")
    }

    @Test("Common tool constants are correct")
    func commonToolConstants() {
        #expect(ToolPermissionRule.bash.rule == "Bash")
        #expect(ToolPermissionRule.read.rule == "Read")
        #expect(ToolPermissionRule.write.rule == "Write")
        #expect(ToolPermissionRule.edit.rule == "Edit")
        #expect(ToolPermissionRule.glob.rule == "Glob")
        #expect(ToolPermissionRule.grep.rule == "Grep")
        #expect(ToolPermissionRule.webFetch.rule == "WebFetch")
        #expect(ToolPermissionRule.webSearch.rule == "WebSearch")
        #expect(ToolPermissionRule.notebookEdit.rule == "NotebookEdit")
        #expect(ToolPermissionRule.agent.rule == "Agent")
    }

    @Test("Common pattern constants are correct")
    func commonPatternConstants() {
        #expect(ToolPermissionRule.bashGit.rule == "Bash(git *)")
        #expect(ToolPermissionRule.bashNpm.rule == "Bash(npm *)")
        #expect(ToolPermissionRule.bashAny.rule == "Bash(*)")
        #expect(ToolPermissionRule.readAny.rule == "Read(*)")
        #expect(ToolPermissionRule.writeAny.rule == "Write(*)")
    }

    @Test("Tool rules are equatable")
    func toolRuleEquality() {
        let a = ToolPermissionRule.tool("Bash", argument: "git *")
        let b: ToolPermissionRule = "Bash(git *)"
        #expect(a == b)

        let c = ToolPermissionRule.bashGit
        #expect(a == c)
    }

    @Test("Tool rules are hashable")
    func toolRuleHashable() {
        let set: Set<ToolPermissionRule> = [.bash, .read, .write, .bash]
        #expect(set.count == 3)
    }

    @Test("Tool rule encodes and decodes correctly")
    func toolRuleCodable() throws {
        let rule = ToolPermissionRule.tool("Bash", argument: "git *")
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(ToolPermissionRule.self, from: data)

        #expect(decoded == rule)
        #expect(decoded.rule == "Bash(git *)")
    }

    @Test("Tool rules in array encode as strings")
    func toolRuleArrayCodable() throws {
        let rules: [ToolPermissionRule] = [.bash, .read, .tool("Write", argument: "/src/*")]
        let data = try JSONEncoder().encode(rules)
        let decoded = try JSONDecoder().decode([ToolPermissionRule].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].rule == "Bash")
        #expect(decoded[1].rule == "Read")
        #expect(decoded[2].rule == "Write(/src/*)")
    }

    @Test("Tool rule description matches rule string")
    func toolRuleDescription() {
        let rule = ToolPermissionRule.tool("Bash", argument: "git *")
        #expect(rule.description == "Bash(git *)")
    }
}

// MARK: - Per-Tool Permission Tests

@Suite("Per-Tool Permission Tests")
struct PerToolPermissionTests {

    @Test("Allowed tools with patterns generate correct command args")
    func allowedToolPatternsCommandArgs() {
        var options = ClaudeCodeOptions()
        options.allowedTools = [
            .read,
            .glob,
            .tool("Bash", argument: "git *"),
        ]

        let args = options.toCommandArgs()

        #expect(args.filter { $0 == "--allowedTools" }.count == 3)
        #expect(args.contains("Read"))
        #expect(args.contains("Glob"))
        #expect(args.contains("Bash(git *)"))
    }

    @Test("Disallowed tools with patterns generate correct command args")
    func disallowedToolPatternsCommandArgs() {
        var options = ClaudeCodeOptions()
        options.disallowedTools = [
            .bash,
            .tool("Write", argument: "/etc/*"),
        ]

        let args = options.toCommandArgs()

        #expect(args.filter { $0 == "--disallowedTools" }.count == 2)
        #expect(args.contains("Bash"))
        #expect(args.contains("Write(/etc/*)"))
    }

    @Test("String literals work as tool permission rules in options")
    func stringLiteralsInOptions() {
        var options = ClaudeCodeOptions()
        options.allowedTools = ["Read", "Write", "Bash(git *)"]

        let args = options.toCommandArgs()

        #expect(args.contains("Read"))
        #expect(args.contains("Write"))
        #expect(args.contains("Bash(git *)"))
    }

    @Test("Options initializer accepts tool permission rules")
    func optionsInitWithPermissionRules() {
        let options = ClaudeCodeOptions(
            allowedTools: [.read, .glob, .bashGit],
            disallowedTools: [.tool("Write", argument: "/etc/*")],
            permissionMode: .plan
        )

        #expect(options.allowedTools?.count == 3)
        #expect(options.disallowedTools?.count == 1)
        #expect(options.permissionMode == .plan)

        let args = options.toCommandArgs()
        #expect(args.contains("Bash(git *)"))
        #expect(args.contains("Write(/etc/*)"))
        #expect(args.contains("plan"))
    }

    @Test("Interactive session configuration accepts permission rules")
    func interactiveSessionPermissionConfig() {
        let config = InteractiveSessionConfiguration(
            allowedTools: [.read, .glob, .grep],
            disallowedTools: [.bash],
            permissionMode: .acceptEdits
        )

        #expect(config.allowedTools?.count == 3)
        #expect(config.disallowedTools?.count == 1)
        #expect(config.permissionMode == .acceptEdits)
    }

    @Test("Interactive session configuration with string literal tools")
    func interactiveSessionStringLiterals() {
        let config = InteractiveSessionConfiguration(
            allowedTools: ["Read", "Glob", "Bash(git *)"],
            disallowedTools: ["Write"]
        )

        #expect(config.allowedTools?.count == 3)
        #expect(config.disallowedTools?.count == 1)
    }

    @Test("Combined permission mode and tool rules generate correct args")
    func combinedPermissionArgs() {
        var options = ClaudeCodeOptions()
        options.permissionMode = .bypassPermissions
        options.allowedTools = [.read, .write]
        options.permissionPromptToolName = "allow-all"

        let args = options.toCommandArgs()

        #expect(args.contains("--permission-mode"))
        #expect(args.contains("bypassPermissions"))
        #expect(args.contains("--permission-prompt-tool"))
        #expect(args.contains("allow-all"))
        #expect(args.filter { $0 == "--allowedTools" }.count == 2)
    }
}

// MARK: - User Question and Tool Permission Tests

@Suite("UserQuestion Types Tests")
struct UserQuestionTypesTests {
    @Test("UserQuestion encodes and decodes correctly")
    func userQuestionCodable() throws {
        let question = UserQuestion(
            question: "Which framework?",
            options: [
                UserQuestionOption(label: "SwiftUI", description: "Apple's declarative framework"),
                UserQuestionOption(label: "UIKit", description: "Apple's imperative framework"),
            ],
            multiSelect: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(question)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserQuestion.self, from: data)

        #expect(decoded.question == "Which framework?")
        #expect(decoded.options.count == 2)
        #expect(decoded.options[0].label == "SwiftUI")
        #expect(decoded.options[1].description == "Apple's imperative framework")
        #expect(decoded.multiSelect == false)
    }

    @Test("UserQuestion uses snake_case for multiSelect")
    func userQuestionSnakeCase() throws {
        let question = UserQuestion(
            question: "Pick tools",
            options: [UserQuestionOption(label: "A", description: "Opt A")],
            multiSelect: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(question)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("multi_select"))
        #expect(!json.contains("multiSelect"))
    }

    @Test("UserQuestionRequest holds array of questions")
    func userQuestionRequest() throws {
        let request = UserQuestionRequest(questions: [
            UserQuestion(
                question: "Q1?",
                options: [UserQuestionOption(label: "Yes", description: "Affirmative")],
                multiSelect: false
            ),
            UserQuestion(
                question: "Q2?",
                options: [UserQuestionOption(label: "No", description: "Negative")],
                multiSelect: true
            ),
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserQuestionRequest.self, from: data)

        #expect(decoded.questions.count == 2)
        #expect(decoded.questions[0].question == "Q1?")
        #expect(decoded.questions[1].multiSelect == true)
    }

    @Test("UserQuestionResponse encodes with correct keys")
    func userQuestionResponse() throws {
        let response = UserQuestionResponse(
            requestId: "req_42",
            answers: ["Which framework?" : "SwiftUI"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("request_id"))
        #expect(json.contains("req_42"))
        #expect(json.contains("input_response"))
        #expect(json.contains("SwiftUI"))
    }

    @Test("UserQuestionOption equality")
    func userQuestionOptionEquality() {
        let a = UserQuestionOption(label: "X", description: "desc")
        let b = UserQuestionOption(label: "X", description: "desc")
        let c = UserQuestionOption(label: "Y", description: "desc")

        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("ToolPermission Types Tests")
struct ToolPermissionTypesTests {
    @Test("ToolPermissionRequest encodes with snake_case")
    func toolPermissionRequestEncoding() throws {
        let request = ToolPermissionRequest(
            toolName: "Bash",
            input: ["command": AnyCodable("ls -la")]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("tool_name"))
        #expect(json.contains("Bash"))
    }

    @Test("ToolPermissionRequest decodes correctly")
    func toolPermissionRequestDecoding() throws {
        let json = """
        {"tool_name":"Write","input":{"file_path":"/tmp/test.txt","content":"hello"}}
        """

        let decoder = JSONDecoder()
        let request = try decoder.decode(ToolPermissionRequest.self, from: json.data(using: .utf8)!)

        #expect(request.toolName == "Write")
        #expect(request.input.count == 2)
    }

    @Test("ToolPermissionDecision raw values")
    func toolPermissionDecisionRawValues() {
        #expect(ToolPermissionDecision.allow.rawValue == "allow")
        #expect(ToolPermissionDecision.deny.rawValue == "deny")
    }

    @Test("ToolPermissionResponse encodes correctly")
    func toolPermissionResponseEncoding() throws {
        let response = ToolPermissionResponse(
            requestId: "req_7",
            decision: .deny,
            reason: "Not allowed in sandbox"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolPermissionResponse.self, from: data)

        #expect(decoded.requestId == "req_7")
        #expect(decoded.decision == .deny)
        #expect(decoded.reason == "Not allowed in sandbox")
        #expect(decoded.type == "input_response")
    }

    @Test("ToolPermissionResponse with nil reason")
    func toolPermissionResponseNilReason() throws {
        let response = ToolPermissionResponse(
            requestId: "req_8",
            decision: .allow
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolPermissionResponse.self, from: data)

        #expect(decoded.decision == .allow)
        #expect(decoded.reason == nil)
    }

    @Test("ToolPermissionRequest equality")
    func toolPermissionRequestEquality() {
        let a = ToolPermissionRequest(toolName: "Bash", input: ["cmd": AnyCodable("echo hi")])
        let b = ToolPermissionRequest(toolName: "Bash", input: ["cmd": AnyCodable("echo hi")])
        let c = ToolPermissionRequest(toolName: "Read", input: [:])

        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("InputRequest Tests")
struct InputRequestTests {
    @Test("InputRequest decodes user_question type")
    func inputRequestUserQuestion() throws {
        let json = """
        {
            "type": "input_request",
            "request_id": "req_1",
            "input_type": "user_question",
            "payload": {
                "questions": [
                    {
                        "question": "Which DB?",
                        "options": [
                            {"label": "SQLite", "description": "Local DB"},
                            {"label": "Postgres", "description": "Server DB"}
                        ],
                        "multi_select": false
                    }
                ]
            }
        }
        """

        let decoder = JSONDecoder()
        let request = try decoder.decode(InputRequest.self, from: json.data(using: .utf8)!)

        #expect(request.type == "input_request")
        #expect(request.requestId == "req_1")
        #expect(request.inputType == "user_question")

        if case .userQuestion(let uq) = request.payload {
            #expect(uq.questions.count == 1)
            #expect(uq.questions[0].question == "Which DB?")
            #expect(uq.questions[0].options.count == 2)
        } else {
            Issue.record("Expected userQuestion payload")
        }
    }

    @Test("InputRequest decodes tool_permission type")
    func inputRequestToolPermission() throws {
        let json = """
        {
            "type": "input_request",
            "request_id": "req_2",
            "input_type": "tool_permission",
            "payload": {
                "tool_name": "Bash",
                "input": {"command": "rm -rf /"}
            }
        }
        """

        let decoder = JSONDecoder()
        let request = try decoder.decode(InputRequest.self, from: json.data(using: .utf8)!)

        #expect(request.inputType == "tool_permission")

        if case .toolPermission(let tp) = request.payload {
            #expect(tp.toolName == "Bash")
        } else {
            Issue.record("Expected toolPermission payload")
        }
    }

    @Test("InputRequest encodes with correct keys")
    func inputRequestEncoding() throws {
        let request = InputRequest(
            type: "input_request",
            requestId: "req_99",
            inputType: "user_question",
            payload: .userQuestion(UserQuestionRequest(questions: []))
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("request_id"))
        #expect(json.contains("input_type"))
        #expect(json.contains("req_99"))
    }
}

@Suite("StreamParser InputRequest Tests")
struct StreamParserInputRequestTests {
    @Test("StreamParser parses input_request lines")
    func parseInputRequestLine() throws {
        let parser = StreamParser()
        let line = """
        {"type":"input_request","request_id":"req_5","input_type":"user_question","payload":{"questions":[{"question":"Pick one","options":[{"label":"A","description":"Option A"}],"multi_select":false}]}}
        """

        let chunk = try parser.parseLine(line)
        #expect(chunk != nil)

        if case .inputRequest(let request) = chunk {
            #expect(request.requestId == "req_5")
            #expect(request.inputType == "user_question")
        } else {
            Issue.record("Expected inputRequest chunk")
        }
    }

    @Test("StreamParser parses tool_permission input_request")
    func parseToolPermissionLine() throws {
        let parser = StreamParser()
        let line = """
        {"type":"input_request","request_id":"req_6","input_type":"tool_permission","payload":{"tool_name":"Write","input":{"file_path":"/test"}}}
        """

        let chunk = try parser.parseLine(line)
        #expect(chunk != nil)

        if case .inputRequest(let request) = chunk {
            #expect(request.requestId == "req_6")
            if case .toolPermission(let tp) = request.payload {
                #expect(tp.toolName == "Write")
            } else {
                Issue.record("Expected toolPermission payload")
            }
        } else {
            Issue.record("Expected inputRequest chunk")
        }
    }
}

@Suite("ResponseChunk InputRequest Tests")
struct ResponseChunkInputRequestTests {
    @Test("ResponseChunk.inputRequest has empty sessionId")
    func inputRequestSessionId() {
        let request = InputRequest(
            type: "input_request",
            requestId: "req_1",
            inputType: "user_question",
            payload: .userQuestion(UserQuestionRequest(questions: []))
        )

        let chunk = ResponseChunk.inputRequest(request)
        #expect(chunk.sessionId == "")
    }
}

@Suite("ProcessStdinWriter Tests")
struct ProcessStdinWriterTests {
    @Test("ProcessStdinWriter write and close are safe to call")
    func writeAndClose() {
        // ProcessStdinWriter should be safe to create, write to (no-op without handle), and close
        let writer = ProcessStdinWriter()
        writer.write(Data("test".utf8))
        writer.writeLine("test line")
        writer.close()
        // Should not crash even after close
        writer.write(Data("after close".utf8))
        writer.close()
    }
}

@Suite("Interactive Session Handler Tests")
struct InteractiveSessionHandlerTests {
    @Test("InteractiveSessionConfiguration stores handlers")
    func configurationWithHandlers() {
        let config = InteractiveSessionConfiguration(
            userQuestionHandler: { _ in [:] },
            toolPermissionHandler: { _ in (.allow, nil) }
        )

        #expect(config.userQuestionHandler != nil)
        #expect(config.toolPermissionHandler != nil)
    }

    @Test("InteractiveSessionConfiguration default has nil handlers")
    func defaultConfigurationNoHandlers() {
        let config = InteractiveSessionConfiguration.default

        #expect(config.userQuestionHandler == nil)
        #expect(config.toolPermissionHandler == nil)
    }

    @Test("ClaudeCodeOptions interactive mode defaults to false")
    func optionsInteractiveDefault() {
        let options = ClaudeCodeOptions()
        #expect(options.interactive == false)
        #expect(options.userQuestionHandler == nil)
        #expect(options.toolPermissionHandler == nil)
    }

    @Test("ClaudeCodeOptions interactive mode can be set")
    func optionsInteractiveSet() {
        var options = ClaudeCodeOptions()
        options.interactive = true
        options.userQuestionHandler = { _ in ["q": "a"] }

        #expect(options.interactive == true)
        #expect(options.userQuestionHandler != nil)
    }
}

// MARK: - RawContentBlock Codable Fix Tests

@Suite("RawContentBlock Codable Tests")
struct RawContentBlockCodableTests {
    @Test("RawContentBlock decodes text content block from JSON object")
    func decodeTextBlock() throws {
        let json = """
        {"type": "text", "text": "Hello, world!"}
        """
        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(RawContentBlock.self, from: data)

        if case .text(let text) = block.type {
            #expect(text == "Hello, world!")
        } else {
            Issue.record("Expected .text, got \(block.type)")
        }
    }

    @Test("RawContentBlock decodes tool_use content block")
    func decodeToolUseBlock() throws {
        let json = """
        {"type": "tool_use", "id": "tu_123", "name": "Read", "input": {"file_path": "/tmp/test"}}
        """
        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(RawContentBlock.self, from: data)

        if case .toolUse(let id, let name) = block.type {
            #expect(id == "tu_123")
            #expect(name == "Read")
        } else {
            Issue.record("Expected .toolUse, got \(block.type)")
        }
    }

    @Test("RawContentBlock decodes tool_result content block")
    func decodeToolResultBlock() throws {
        let json = """
        {"type": "tool_result", "tool_use_id": "tu_456", "content": "file contents"}
        """
        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(RawContentBlock.self, from: data)

        if case .toolResult(let toolUseId) = block.type {
            #expect(toolUseId == "tu_456")
        } else {
            Issue.record("Expected .toolResult, got \(block.type)")
        }
    }

    @Test("RawContentBlock decodes unknown type as .other")
    func decodeUnknownBlock() throws {
        let json = """
        {"type": "image", "source": {"type": "base64"}}
        """
        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(RawContentBlock.self, from: data)

        if case .other = block.type {
            // Expected
        } else {
            Issue.record("Expected .other, got \(block.type)")
        }
    }

    @Test("RawContentBlock round-trips through encode/decode")
    func roundTrip() throws {
        let json = """
        {"type": "text", "text": "round trip test"}
        """
        let data = json.data(using: .utf8)!
        let block = try JSONDecoder().decode(RawContentBlock.self, from: data)
        let reEncoded = try JSONEncoder().encode(block)
        let reDecoded = try JSONDecoder().decode(RawContentBlock.self, from: reEncoded)

        if case .text(let text) = reDecoded.type {
            #expect(text == "round trip test")
        } else {
            Issue.record("Expected .text after round-trip")
        }
    }

    @Test("RawMessageContent decodes array of content blocks")
    func decodeArrayContent() throws {
        let json = """
        [
            {"type": "text", "text": "First paragraph"},
            {"type": "text", "text": "Second paragraph"},
            {"type": "tool_use", "id": "tu_1", "name": "Bash", "input": {"command": "ls"}}
        ]
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(RawMessageContent.self, from: data)

        if case .array(let blocks) = content {
            #expect(blocks.count == 3)
            if case .text(let t1) = blocks[0].type {
                #expect(t1 == "First paragraph")
            } else {
                Issue.record("Expected first block to be text")
            }
            if case .text(let t2) = blocks[1].type {
                #expect(t2 == "Second paragraph")
            } else {
                Issue.record("Expected second block to be text")
            }
            if case .toolUse(let id, let name) = blocks[2].type {
                #expect(id == "tu_1")
                #expect(name == "Bash")
            } else {
                Issue.record("Expected third block to be toolUse")
            }
        } else {
            Issue.record("Expected .array content")
        }
    }

    @Test("RawMessageContent textContent extracts text from array blocks")
    func textContentFromArray() throws {
        let json = """
        [
            {"type": "text", "text": "Hello"},
            {"type": "tool_use", "id": "tu_1", "name": "Read", "input": {}},
            {"type": "text", "text": "World"}
        ]
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(RawMessageContent.self, from: data)

        #expect(content.textContent == "Hello\nWorld")
    }

    @Test("RawMessageContent decodes string content")
    func decodeStringContent() throws {
        let json = """
        "Just a plain string message"
        """
        let data = json.data(using: .utf8)!
        let content = try JSONDecoder().decode(RawMessageContent.self, from: data)

        if case .string(let text) = content {
            #expect(text == "Just a plain string message")
        } else {
            Issue.record("Expected .string content")
        }
    }

    @Test("Full assistant session entry with array content decodes correctly")
    func fullAssistantEntryDecode() throws {
        let json = """
        {
            "type": "assistant",
            "uuid": "msg-001",
            "parentUuid": "msg-000",
            "sessionId": "sess-123",
            "timestamp": "2026-01-15T10:30:00Z",
            "message": {
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "I'll help you with that."},
                    {"type": "tool_use", "id": "tu_abc", "name": "Read", "input": {"file_path": "/src/main.swift"}}
                ],
                "model": "claude-sonnet-4-5-20250514"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let entry = try JSONDecoder().decode(RawSessionEntry.self, from: data)

        #expect(entry.type == "assistant")
        #expect(entry.uuid == "msg-001")
        #expect(entry.message?.role == "assistant")
        #expect(entry.message?.model == "claude-sonnet-4-5-20250514")

        if case .array(let blocks) = entry.message?.content {
            #expect(blocks.count == 2)
            if case .text(let text) = blocks[0].type {
                #expect(text == "I'll help you with that.")
            } else {
                Issue.record("Expected text block")
            }
            if case .toolUse(let id, let name) = blocks[1].type {
                #expect(id == "tu_abc")
                #expect(name == "Read")
            } else {
                Issue.record("Expected toolUse block")
            }
        } else {
            Issue.record("Expected array content in assistant message")
        }
    }
}
