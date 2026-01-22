import XCTest
import GRDB
@testable import Blaze

final class HookRunnerTests: XCTestCase {

    private var dbPool: DatabasePool!
    private var hookStore: HookStore!
    private var hookRunner: HookRunner!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        dbPool = try DatabasePool(path: tempDir.appendingPathComponent("test.db").path)

        // Create repos table first (HookStore has foreign key reference to it)
        try await dbPool.write { db in
            try db.create(table: "repos", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("path", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }
        }

        hookStore = try HookStore(dbPool: dbPool)
        hookRunner = HookRunner(hookStore: hookStore)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Basic Execution Tests

    func testExecuteSimpleShellHook() async throws {
        // Create a hook that echoes something
        let hook = Hook(
            name: "Test Echo Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'Hello from hook'",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        // Execute hooks for the event type
        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertEqual(results[0].exitCode, 0)
        XCTAssertTrue(results[0].stdout?.contains("Hello from hook") ?? false)
    }

    func testExecuteHookWithEnvironmentVariables() async throws {
        // Create a hook that reads environment variables
        let hook = Hook(
            name: "Env Test Hook",
            eventType: .postToolCall,
            inlineScript: "echo \"Hook: $BLAZE_HOOK_NAME, Event: $BLAZE_EVENT_TYPE\"",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertTrue(results[0].stdout?.contains("Hook: Env Test Hook") ?? false)
        XCTAssertTrue(results[0].stdout?.contains("Event: post_tool_call") ?? false)
    }

    func testExecuteHookWithTriggerData() async throws {
        // Create a hook that reads trigger data
        let hook = Hook(
            name: "Trigger Data Hook",
            eventType: .postFileWrite,
            inlineScript: "echo \"File: $BLAZE_TRIGGER_PATH\"",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerData: ["path": "/src/main.swift"],
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertTrue(results[0].stdout?.contains("/src/main.swift") ?? false)
    }

    func testExecuteFailingHook() async throws {
        // Create a hook that exits with error
        let hook = Hook(
            name: "Failing Hook",
            eventType: .postToolCall,
            inlineScript: "exit 1",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].success)
        XCTAssertEqual(results[0].exitCode, 1)
    }

    func testExecuteHookWithStderr() async throws {
        // Create a hook that writes to stderr
        let hook = Hook(
            name: "Stderr Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'This is stderr' >&2",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success) // Exit code 0
        XCTAssertTrue(results[0].stderr?.contains("This is stderr") ?? false)
    }

    // MARK: - Pattern Matching Tests

    func testGlobPatternMatching() async throws {
        // Create a hook with glob pattern for Swift files
        let hook = Hook(
            name: "Swift File Hook",
            eventType: .postFileWrite,
            triggerPattern: "*.swift",
            inlineScript: "echo 'Swift file modified'",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        // Should match .swift file
        var results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerContext: "main.swift",
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)

        // Should not match .js file
        results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerContext: "main.js",
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 0)
    }

    func testPathGlobPatternMatching() async throws {
        // Create a hook with path glob pattern
        let hook = Hook(
            name: "Source Directory Hook",
            eventType: .postFileWrite,
            triggerPattern: "src/*",
            inlineScript: "echo 'Source file modified'",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        // Should match files in src/
        var results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerContext: "src/main.swift",
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 1)

        // Should not match files in other directories
        results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerContext: "tests/test.swift",
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 0)
    }

    func testNoPatternMatchesEverything() async throws {
        // Create a hook without pattern
        let hook = Hook(
            name: "Universal Hook",
            eventType: .postFileWrite,
            inlineScript: "echo 'Any file'",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        // Should match any context
        var results = await hookRunner.executeHooks(
            for: .postFileWrite,
            triggerContext: "any/path/file.txt",
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 1)

        // Should match with no context
        results = await hookRunner.executeHooks(
            for: .postFileWrite,
            sessionId: UUID()
        )
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Priority and Ordering Tests

    func testHooksExecuteInPriorityOrder() async throws {
        // Create hooks with different priorities
        let hook1 = Hook(
            name: "Priority 10",
            eventType: .postToolCall,
            inlineScript: "echo '10'",
            scriptType: .shell,
            priority: 10
        )
        let hook2 = Hook(
            name: "Priority 1",
            eventType: .postToolCall,
            inlineScript: "echo '1'",
            scriptType: .shell,
            priority: 1
        )
        let hook3 = Hook(
            name: "Priority 5",
            eventType: .postToolCall,
            inlineScript: "echo '5'",
            scriptType: .shell,
            priority: 5
        )

        try await hookStore.create(hook1)
        try await hookStore.create(hook2)
        try await hookStore.create(hook3)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        // Should be ordered by priority: 1, 5, 10
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].stdout?.contains("1") ?? false)
        XCTAssertTrue(results[1].stdout?.contains("5") ?? false)
        XCTAssertTrue(results[2].stdout?.contains("10") ?? false)
    }

    // MARK: - Disabled Hook Tests

    func testDisabledHooksAreSkipped() async throws {
        // Create an enabled and disabled hook
        var enabledHook = Hook(
            name: "Enabled Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'enabled'",
            scriptType: .shell
        )
        enabledHook.enabled = true

        var disabledHook = Hook(
            name: "Disabled Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'disabled'",
            scriptType: .shell
        )
        disabledHook.enabled = false

        // Note: Hook init sets enabled = true by default, we need to modify after
        try await hookStore.create(enabledHook)
        try await hookStore.create(disabledHook)

        // Disable the second hook
        try await hookStore.setEnabled(id: disabledHook.id, enabled: false)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        // Only enabled hook should run
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].stdout?.contains("enabled") ?? false)
    }

    // MARK: - Script Type Tests

    func testPythonScript() async throws {
        let hook = Hook(
            name: "Python Hook",
            eventType: .postToolCall,
            inlineScript: "print('Hello from Python')",
            scriptType: .python
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertTrue(results[0].stdout?.contains("Hello from Python") ?? false)
    }

    func testExternalScriptFile() async throws {
        // Create a temp script file
        let scriptPath = tempDir.appendingPathComponent("test_hook.sh")
        let scriptContent = """
        #!/bin/bash
        echo "Hello from script file"
        """
        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)

        // Make executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let hook = Hook(
            name: "Script File Hook",
            eventType: .postToolCall,
            scriptPath: scriptPath.path,
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)
        XCTAssertTrue(results[0].stdout?.contains("Hello from script file") ?? false)
    }

    // MARK: - Validation Tests

    func testValidateExistingScript() async throws {
        // Create a temp script file
        let scriptPath = tempDir.appendingPathComponent("valid_hook.sh")
        try "echo hello".write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let hook = Hook(
            name: "Valid Hook",
            eventType: .postToolCall,
            scriptPath: scriptPath.path,
            scriptType: .shell
        )

        let result = await hookRunner.validateScript(hook)

        XCTAssertTrue(result.valid)
        XCTAssertNil(result.message)
    }

    func testValidateMissingScript() async throws {
        let hook = Hook(
            name: "Missing Script Hook",
            eventType: .postToolCall,
            scriptPath: "/nonexistent/script.sh",
            scriptType: .shell
        )

        let result = await hookRunner.validateScript(hook)

        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message?.contains("not found") ?? false)
    }

    func testValidateNoScriptConfigured() async throws {
        let hook = Hook(
            name: "No Script Hook",
            eventType: .postToolCall,
            scriptType: .shell
        )

        let result = await hookRunner.validateScript(hook)

        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.message?.contains("No script configured") ?? false)
    }

    // MARK: - Execution History Tests

    func testExecutionIsRecorded() async throws {
        let hook = Hook(
            name: "Recorded Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'recorded'",
            scriptType: .shell
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success)

        // Check execution was recorded
        let executions = try await hookStore.getExecutions(hookId: hook.id)
        XCTAssertEqual(executions.count, 1)
        XCTAssertEqual(executions[0].success, true)
        XCTAssertEqual(executions[0].exitCode, 0)
    }

    // MARK: - Timeout Tests

    func testHookTimeout() async throws {
        // Create a hook with a very short timeout
        let hook = Hook(
            name: "Slow Hook",
            eventType: .postToolCall,
            inlineScript: "sleep 10",
            scriptType: .shell,
            timeoutMs: 100 // 100ms timeout
        )
        try await hookStore.create(hook)

        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].success) // Should fail due to timeout/termination
    }

    // MARK: - Blocking Hook Tests

    func testBlockingHookStopsOnFailure() async throws {
        // Create a blocking hook (preToolCall) that fails
        let failingHook = Hook(
            name: "Failing Pre Hook",
            eventType: .preToolCall,
            inlineScript: "exit 1",
            scriptType: .shell,
            priority: 1
        )
        let secondHook = Hook(
            name: "Second Pre Hook",
            eventType: .preToolCall,
            inlineScript: "echo 'should not run'",
            scriptType: .shell,
            priority: 2
        )

        try await hookStore.create(failingHook)
        try await hookStore.create(secondHook)

        let results = await hookRunner.executeHooks(
            for: .preToolCall,
            sessionId: UUID()
        )

        // Only first hook should run because preToolCall is blocking and it failed
        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].success)
    }

    // MARK: - Event Type Filtering Tests

    func testOnlyMatchingEventTypeHooksRun() async throws {
        let postToolHook = Hook(
            name: "Post Tool Hook",
            eventType: .postToolCall,
            inlineScript: "echo 'post tool'",
            scriptType: .shell
        )
        let postFileHook = Hook(
            name: "Post File Hook",
            eventType: .postFileWrite,
            inlineScript: "echo 'post file'",
            scriptType: .shell
        )

        try await hookStore.create(postToolHook)
        try await hookStore.create(postFileHook)

        // Only postToolCall hooks should run
        let results = await hookRunner.executeHooks(
            for: .postToolCall,
            sessionId: UUID()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].stdout?.contains("post tool") ?? false)
    }
}
