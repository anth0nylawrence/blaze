import XCTest
@testable import Blaze

final class EngineAdapterTests: XCTestCase {

    // MARK: - Engine Manager Tests

    @MainActor
    func testEngineManagerRegistration() {
        let manager = EngineManager()

        // Register adapters
        manager.register(adapter: ClaudeCodeAdapter())
        manager.register(adapter: GeminiCliAdapter())
        manager.register(adapter: CodexCliAdapter())

        // Should be able to retrieve them
        XCTAssertNotNil(manager.adapter(for: .claude))
        XCTAssertNotNil(manager.adapter(for: .gemini))
        XCTAssertNotNil(manager.adapter(for: .codex))
    }

    @MainActor
    func testClaudeAdapterFeatures() {
        let adapter = ClaudeCodeAdapter()

        // Claude supports these features
        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .toolUse))
        XCTAssertTrue(adapter.supports(feature: .multiModal))
        XCTAssertTrue(adapter.supports(feature: .mcpSupport))
        XCTAssertTrue(adapter.supports(feature: .contextCompaction))

        // Claude doesn't support these
        XCTAssertFalse(adapter.supports(feature: .sessionPersistence))
        XCTAssertFalse(adapter.supports(feature: .sandboxMode))
    }

    @MainActor
    func testGeminiAdapterFeatures() {
        let adapter = GeminiCliAdapter()

        // Gemini supports these features
        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .toolUse))
        XCTAssertTrue(adapter.supports(feature: .sessionPersistence))
        XCTAssertTrue(adapter.supports(feature: .multiModal))

        // Gemini doesn't support these
        XCTAssertFalse(adapter.supports(feature: .mcpSupport))
        XCTAssertFalse(adapter.supports(feature: .sandboxMode))
        XCTAssertFalse(adapter.supports(feature: .contextCompaction))
    }

    @MainActor
    func testCodexAdapterFeatures() {
        let adapter = CodexCliAdapter()

        // Codex supports these features
        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .toolUse))
        XCTAssertTrue(adapter.supports(feature: .sessionPersistence))
        XCTAssertTrue(adapter.supports(feature: .sandboxMode))

        // Codex doesn't support these
        XCTAssertFalse(adapter.supports(feature: .mcpSupport))
        XCTAssertFalse(adapter.supports(feature: .multiModal))
        XCTAssertFalse(adapter.supports(feature: .contextCompaction))
    }

    @MainActor
    func testEngineTypes() {
        XCTAssertEqual(ClaudeCodeAdapter().engineType, .claude)
        XCTAssertEqual(GeminiCliAdapter().engineType, .gemini)
        XCTAssertEqual(CodexCliAdapter().engineType, .codex)
    }

    // MARK: - Turn Context Tests

    func testTurnContextDefaults() {
        let context = TurnContext(sessionId: UUID())

        XCTAssertNil(context.projectPath)
        XCTAssertNil(context.allowedTools)
        XCTAssertEqual(context.trustMode, .review)
        XCTAssertNil(context.systemPrompt)
        XCTAssertTrue(context.previousMessages.isEmpty)
    }

    func testTurnContextWithAllParameters() {
        let sessionId = UUID()
        let tools: Set<String> = ["Bash", "Read", "Write"]
        let messages = [Message(role: .user, content: "Hello")]

        let context = TurnContext(
            sessionId: sessionId,
            projectPath: "/path/to/project",
            allowedTools: tools,
            trustMode: .unrestricted,
            systemPrompt: "You are a helpful assistant",
            previousMessages: messages
        )

        XCTAssertEqual(context.sessionId, sessionId)
        XCTAssertEqual(context.projectPath, "/path/to/project")
        XCTAssertEqual(context.allowedTools, tools)
        XCTAssertEqual(context.trustMode, .unrestricted)
        XCTAssertEqual(context.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(context.previousMessages.count, 1)
    }

    // MARK: - Engine Error Tests

    func testEngineErrorDescriptions() {
        let cliNotFound = EngineError.cliNotFound(.claude)
        XCTAssertTrue(cliNotFound.errorDescription?.contains("Claude Code CLI not found") ?? false)

        let versionError = EngineError.cliVersionUnsupported(version: "0.5", minimum: "1.0")
        XCTAssertTrue(versionError.errorDescription?.contains("0.5") ?? false)
        XCTAssertTrue(versionError.errorDescription?.contains("1.0") ?? false)

        let authError = EngineError.authenticationRequired
        XCTAssertTrue(authError.errorDescription?.contains("Authentication required") ?? false)

        let timeoutError = EngineError.timeout(seconds: 60)
        XCTAssertTrue(timeoutError.errorDescription?.contains("60") ?? false)

        let cancelledError = EngineError.cancelled
        XCTAssertTrue(cancelledError.errorDescription?.contains("cancelled") ?? false)
    }

    // MARK: - CLI Info Tests

    func testCLIInfo() {
        let capabilities: Set<EngineFeature> = [.streaming, .toolUse]
        let info = CLIInfo(
            version: "1.2.3",
            path: "/usr/local/bin/claude",
            capabilities: capabilities
        )

        XCTAssertEqual(info.version, "1.2.3")
        XCTAssertEqual(info.path, "/usr/local/bin/claude")
        XCTAssertTrue(info.capabilities.contains(.streaming))
        XCTAssertTrue(info.capabilities.contains(.toolUse))
        XCTAssertFalse(info.capabilities.contains(.sandboxMode))
    }

    // MARK: - Gemini Event Mapper Tests

    func testGeminiEventMapperReset() async {
        let mapper = GeminiEventMapper()

        // Map some events
        let initEvent = InitStreamEvent(
            type: "init",
            version: "1.0",
            message: .init(
                sessionId: "sess",
                version: "1.0",
                model: "gemini-pro",
                cwd: "/",
                capabilities: [],
                allowedTools: []
            ),
            uuid: "uuid",
            sessionId: "sess",
            parentUuid: nil,
            isSidechain: nil
        )
        _ = await mapper.map(.`init`(initEvent))

        // Reset
        await mapper.reset()

        // Should be able to map again without issues
        let events = await mapper.map(.`init`(initEvent))
        XCTAssertEqual(events.count, 1)
        if case .sessionStarted(let started) = events.first {
            XCTAssertEqual(started.engineType, "gemini")
        } else {
            XCTFail("Expected sessionStarted event")
        }
    }

    // MARK: - Codex Event Mapper Tests

    func testCodexEventMapperReset() async {
        let mapper = CodexEventMapper()

        let initEvent = InitStreamEvent(
            type: "init",
            version: "1.0",
            message: .init(
                sessionId: "sess",
                version: "1.0",
                model: "codex-latest",
                cwd: "/",
                capabilities: [],
                allowedTools: []
            ),
            uuid: "uuid",
            sessionId: "sess",
            parentUuid: nil,
            isSidechain: nil
        )
        _ = await mapper.map(.`init`(initEvent))

        await mapper.reset()

        let events = await mapper.map(.`init`(initEvent))
        XCTAssertEqual(events.count, 1)
        if case .sessionStarted(let started) = events.first {
            XCTAssertEqual(started.engineType, "codex")
        } else {
            XCTFail("Expected sessionStarted event")
        }
    }

    func testCodexMapperHandlesToolUse() async {
        let mapper = CodexEventMapper()

        let toolInput = ToolInput.from(dict: ["command": "ls -la"])
        let assistantEvent = AssistantStreamEvent(
            type: "assistant",
            message: .init(
                id: "msg-1",
                type: "message",
                role: "assistant",
                model: "codex",
                content: [
                    .toolUse(ToolUseBlock(type: "tool_use", id: "tool-123", name: "Bash", input: toolInput))
                ],
                stopReason: "tool_use",
                stopSequence: nil,
                usage: UsageStats(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, totalTokens: 150, serviceTier: nil)
            ),
            uuid: "uuid",
            sessionId: "sess",
            parentUuid: nil,
            isSidechain: nil,
            requestId: "req-1"
        )

        let events = await mapper.map(.assistant(assistantEvent))

        let hasToolStarted = events.contains {
            if case .toolCallStarted(let started) = $0 {
                return started.toolName == "Bash" && started.toolCallId == "tool-123"
            }
            return false
        }
        XCTAssertTrue(hasToolStarted, "Should emit toolCallStarted for tool use")
    }
}

// MARK: - Helper

private extension ToolInput {
    static func from(dict: [String: String]) -> ToolInput {
        var anyCodable: [String: AnyCodable] = [:]
        for (key, value) in dict {
            anyCodable[key] = AnyCodable(value)
        }
        return ToolInput(rawValue: anyCodable)
    }
}
