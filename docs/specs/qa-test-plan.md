# QA Test Plan

> Cogit0 Blaze - Comprehensive Quality Assurance Strategy

## Overview

This document defines the test strategy, test cases, automation framework, and quality gates for Cogit0 Blaze. Our goal: **ship with confidence** through comprehensive automated testing and strategic manual QA.

---

## 1. Test Strategy

### 1.1 Testing Pyramid

```
                    ┌─────────────┐
                    │   Manual    │  5%  - Exploratory, UX validation
                    │   E2E       │
                    ├─────────────┤
                   │    UI/E2E    │  15% - Critical user journeys
                  │   Automated   │
                  ├───────────────┤
                │   Integration    │  30% - CLI interaction, persistence
               │      Tests        │
              ├─────────────────────┤
            │       Unit Tests       │  50% - Business logic, parsing
           └─────────────────────────┘
```

### 1.2 Quality Gates

| Gate | Criteria | Enforcement |
|------|----------|-------------|
| **PR Merge** | 100% unit tests pass, 0 new warnings | CI blocking |
| **Main Branch** | All tests pass, coverage ≥ 80% | CI blocking |
| **Release Candidate** | Full E2E suite pass, manual QA sign-off | Release blocker |
| **Production** | Smoke tests pass, no P0/P1 regressions | Deploy blocker |

---

## 2. Test Categories

### 2.1 Unit Tests

**Scope:** Individual functions, view models, parsers, utilities

| Component | Coverage Target | Priority |
|-----------|-----------------|----------|
| Event Parser | 95% | P0 |
| Stream JSON Decoder | 95% | P0 |
| Diff Processor | 90% | P0 |
| Session Store | 85% | P1 |
| Policy Engine | 90% | P0 |
| View Models | 80% | P1 |
| Utilities | 85% | P2 |

```swift
// Example: EventParserTests.swift

import XCTest
@testable import Blaze

final class EventParserTests: XCTestCase {

    var parser: StreamJSONParser!

    override func setUp() {
        parser = StreamJSONParser()
    }

    // MARK: - Init Event

    func testParseInitEvent() throws {
        let json = """
        {"type":"init","session_id":"abc123","model":"claude-3-opus"}
        """

        let event = try parser.parse(line: json)

        guard case .init(let data) = event else {
            XCTFail("Expected init event")
            return
        }

        XCTAssertEqual(data.sessionId, "abc123")
        XCTAssertEqual(data.model, "claude-3-opus")
    }

    // MARK: - Assistant Delta

    func testParseAssistantDelta() throws {
        let json = """
        {"type":"assistant","subtype":"delta","content":"Hello, ","index":0}
        """

        let event = try parser.parse(line: json)

        guard case .assistantDelta(let delta) = event else {
            XCTFail("Expected assistant delta")
            return
        }

        XCTAssertEqual(delta.content, "Hello, ")
        XCTAssertEqual(delta.index, 0)
    }

    // MARK: - Tool Use

    func testParseToolCallStarted() throws {
        let json = """
        {"type":"tool_use","status":"started","tool":"Read","input":{"file_path":"/foo/bar.swift"}}
        """

        let event = try parser.parse(line: json)

        guard case .toolCallStarted(let tool) = event else {
            XCTFail("Expected tool call started")
            return
        }

        XCTAssertEqual(tool.name, "Read")
        XCTAssertEqual(tool.input["file_path"] as? String, "/foo/bar.swift")
    }

    // MARK: - Error Handling

    func testParseMalformedJSON() {
        let badJSON = "not valid json"

        XCTAssertThrowsError(try parser.parse(line: badJSON)) { error in
            XCTAssertTrue(error is StreamJSONParser.ParseError)
        }
    }

    func testParseUnknownEventType() throws {
        let json = """
        {"type":"unknown_future_type","data":"something"}
        """

        let event = try parser.parse(line: json)

        guard case .unknown(let raw) = event else {
            XCTFail("Expected unknown event wrapper")
            return
        }

        XCTAssertTrue(raw.contains("unknown_future_type"))
    }
}
```

### 2.2 Integration Tests

**Scope:** CLI process interaction, database operations, file system

```swift
// Example: CLIIntegrationTests.swift

import XCTest
@testable import Blaze

final class CLIIntegrationTests: XCTestCase {

    var processRunner: ProcessRunner!
    var mockCLI: MockCLIProcess!

    override func setUp() async throws {
        mockCLI = MockCLIProcess()
        processRunner = ProcessRunner(executable: mockCLI.path)
    }

    // MARK: - Process Lifecycle

    func testSpawnAndTerminate() async throws {
        let session = try await processRunner.spawn(prompt: "Hello")

        XCTAssertTrue(session.isRunning)

        await session.terminate()

        XCTAssertFalse(session.isRunning)
    }

    func testGracefulShutdown() async throws {
        let session = try await processRunner.spawn(prompt: "Long task")

        // Simulate Ctrl+C
        await session.interrupt()

        // Should send SIGINT first
        XCTAssertEqual(mockCLI.receivedSignals.first, .interrupt)

        // Wait for graceful exit
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(session.isRunning)
    }

    // MARK: - Streaming Events

    func testReceiveStreamedEvents() async throws {
        mockCLI.queueEvents([
            .init(sessionId: "test"),
            .assistantDelta(content: "Hello"),
            .assistantDelta(content: " World"),
            .result(success: true)
        ])

        var events: [NormalizedEvent] = []
        let session = try await processRunner.spawn(prompt: "Hi")

        for await event in session.events {
            events.append(event)
        }

        XCTAssertEqual(events.count, 4)
        XCTAssertTrue(events.first?.isInit ?? false)
        XCTAssertTrue(events.last?.isResult ?? false)
    }

    // MARK: - Database Persistence

    func testEventsPersisted() async throws {
        let storage = try SessionStorage(path: testDBPath)

        mockCLI.queueEvents([
            .init(sessionId: "persist-test"),
            .assistantDelta(content: "Persisted content"),
            .result(success: true)
        ])

        let session = try await processRunner.spawn(prompt: "Test", storage: storage)

        for await _ in session.events { }

        // Verify persisted
        let loaded = try await storage.loadEvents(sessionId: "persist-test")
        XCTAssertEqual(loaded.count, 3)
    }
}
```

### 2.3 UI Tests (SwiftUI)

**Scope:** View rendering, user interactions, navigation

```swift
// Example: ChatViewUITests.swift

import XCTest

final class ChatViewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Message Display

    func testUserMessageDisplayed() {
        let inputField = app.textFields["ChatInput"]
        inputField.tap()
        inputField.typeText("Hello Claude")

        app.buttons["SendButton"].tap()

        XCTAssertTrue(app.staticTexts["Hello Claude"].waitForExistence(timeout: 2))
    }

    func testStreamingIndicator() {
        sendMessage("Start streaming")

        // Streaming indicator should appear
        XCTAssertTrue(app.activityIndicators["StreamingIndicator"].exists)

        // Wait for completion
        let completed = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'complete'")
        ).firstMatch.waitForExistence(timeout: 30)

        XCTAssertTrue(completed)
        XCTAssertFalse(app.activityIndicators["StreamingIndicator"].exists)
    }

    // MARK: - Tool Cards

    func testToolCardExpansion() {
        triggerToolUse(tool: "Read", file: "test.swift")

        let toolCard = app.buttons["ToolCard-Read"]
        XCTAssertTrue(toolCard.waitForExistence(timeout: 5))

        toolCard.tap()

        // Should show expanded content
        XCTAssertTrue(app.staticTexts["test.swift"].exists)
    }

    // MARK: - Diff Viewer

    func testDiffViewerRendering() {
        triggerFileDiff(file: "example.swift", additions: 10, deletions: 5)

        let diffView = app.scrollViews["DiffViewer"]
        XCTAssertTrue(diffView.waitForExistence(timeout: 5))

        // Check line count indicators
        XCTAssertTrue(app.staticTexts["+10"].exists)
        XCTAssertTrue(app.staticTexts["-5"].exists)
    }

    // MARK: - Session Management

    func testSessionSwitching() {
        createSession(name: "Session 1")
        createSession(name: "Session 2")

        app.buttons["SessionList-Session 1"].tap()
        XCTAssertTrue(app.staticTexts["Session 1"].exists)

        app.buttons["SessionList-Session 2"].tap()
        XCTAssertTrue(app.staticTexts["Session 2"].exists)
    }

    // MARK: - Keyboard Navigation

    func testKeyboardShortcuts() {
        // Cmd+N for new session
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.sheets["NewSessionSheet"].waitForExistence(timeout: 2))

        app.typeKey(.escape, modifierFlags: [])

        // Cmd+K for command palette
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.popovers["CommandPalette"].waitForExistence(timeout: 2))
    }

    // MARK: - Helpers

    private func sendMessage(_ text: String) {
        let input = app.textFields["ChatInput"]
        input.tap()
        input.typeText(text)
        app.buttons["SendButton"].tap()
    }
}
```

### 2.4 End-to-End Tests

**Scope:** Complete user journeys with real CLI processes

```swift
// Example: E2ETests.swift

import XCTest

final class EndToEndTests: XCTestCase {

    // MARK: - Full Conversation Flow

    func testCompleteConversation() async throws {
        // Requires real Claude Code CLI installed
        try XCTSkipUnless(CLIDetector.claudeCodeInstalled)

        let app = launchApp()

        // Start new session
        app.buttons["NewSession"].tap()

        // Send a prompt
        let input = app.textFields["ChatInput"]
        input.tap()
        input.typeText("What is 2+2?")
        app.buttons["SendButton"].tap()

        // Wait for response
        let response = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '4'")
        ).firstMatch

        XCTAssertTrue(response.waitForExistence(timeout: 60))

        // Session should be saved
        XCTAssertTrue(app.buttons["SessionList"].staticTexts.count > 0)
    }

    // MARK: - File Operations

    func testFileReadOperation() async throws {
        try XCTSkipUnless(CLIDetector.claudeCodeInstalled)

        let testFile = createTestFile(content: "Test content 12345")
        defer { removeTestFile(testFile) }

        let app = launchApp()
        app.buttons["NewSession"].tap()

        sendPrompt(app, "Read the file at \(testFile)")

        // Should show Read tool card
        let readCard = app.buttons["ToolCard-Read"]
        XCTAssertTrue(readCard.waitForExistence(timeout: 30))

        // Response should contain file content
        let content = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Test content 12345'")
        ).firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 30))
    }

    // MARK: - Approval Flow

    func testWriteApprovalRequired() async throws {
        try XCTSkipUnless(CLIDetector.claudeCodeInstalled)

        let app = launchApp(mode: .review) // Review mode requires approval

        sendPrompt(app, "Create a file called test-output.txt with 'hello'")

        // Should show approval dialog
        let approvalSheet = app.sheets["ApprovalRequired"]
        XCTAssertTrue(approvalSheet.waitForExistence(timeout: 30))

        // Should show the proposed action
        XCTAssertTrue(approvalSheet.staticTexts["Write"].exists)
        XCTAssertTrue(approvalSheet.staticTexts["test-output.txt"].exists)

        // Approve
        approvalSheet.buttons["Approve"].tap()

        // Should complete
        let success = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'created'")
        ).firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 30))
    }
}
```

---

## 3. Test Data & Fixtures

### 3.1 Mock CLI Process

```swift
// MockCLIProcess.swift

actor MockCLIProcess {
    let path: URL

    private var eventQueue: [NormalizedEvent] = []
    private(set) var receivedSignals: [ProcessSignal] = []
    private(set) var receivedInputs: [String] = []

    init() {
        self.path = Bundle.module.url(forResource: "mock-cli", withExtension: nil)!
    }

    func queueEvents(_ events: [NormalizedEvent]) {
        eventQueue.append(contentsOf: events)
    }

    func queueEventsFromFile(_ name: String) throws {
        let url = Bundle.module.url(forResource: name, withExtension: "jsonl")!
        let lines = try String(contentsOf: url).components(separatedBy: .newlines)
        let parser = StreamJSONParser()

        for line in lines where !line.isEmpty {
            let event = try parser.parse(line: line)
            eventQueue.append(event)
        }
    }
}
```

### 3.2 Test Fixtures

```
tests/fixtures/
├── events/
│   ├── simple-response.jsonl       # Basic Q&A
│   ├── tool-read-file.jsonl        # Read tool usage
│   ├── tool-write-file.jsonl       # Write tool usage
│   ├── tool-bash-command.jsonl     # Bash execution
│   ├── multi-tool-sequence.jsonl   # Complex tool chain
│   ├── large-diff.jsonl            # Big file modifications
│   ├── error-response.jsonl        # Error handling
│   └── streaming-burst.jsonl       # High-frequency events
├── diffs/
│   ├── simple-addition.diff
│   ├── simple-deletion.diff
│   ├── mixed-changes.diff
│   └── large-refactor.diff
└── sessions/
    ├── empty-session.db
    ├── loaded-session.db
    └── corrupt-session.db
```

---

## 4. Test Automation

### 4.1 CI Pipeline

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main]
  pull_request:

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -scheme Blaze \
            -destination 'platform=macOS' \
            -testPlan UnitTests \
            -resultBundlePath results/unit.xcresult

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-results
          path: results/

  integration-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run Integration Tests
        run: |
          xcodebuild test \
            -scheme Blaze \
            -destination 'platform=macOS' \
            -testPlan IntegrationTests \
            -resultBundlePath results/integration.xcresult

  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run UI Tests
        run: |
          xcodebuild test \
            -scheme BlazeUITests \
            -destination 'platform=macOS' \
            -testPlan UITests \
            -resultBundlePath results/ui.xcresult

      - name: Capture Screenshots
        if: failure()
        run: |
          xcparse screenshots results/ui.xcresult screenshots/

      - name: Upload Screenshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: failure-screenshots
          path: screenshots/

  e2e-tests:
    runs-on: macos-14
    needs: [unit-tests, integration-tests]
    steps:
      - uses: actions/checkout@v4

      - name: Install Claude Code CLI
        run: npm install -g @anthropic/claude-code

      - name: Run E2E Tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          xcodebuild test \
            -scheme BlazeE2ETests \
            -destination 'platform=macOS' \
            -testPlan E2ETests

  coverage:
    runs-on: macos-14
    needs: [unit-tests]
    steps:
      - uses: actions/checkout@v4

      - name: Generate Coverage Report
        run: |
          xcodebuild test \
            -scheme Blaze \
            -destination 'platform=macOS' \
            -enableCodeCoverage YES \
            -resultBundlePath coverage.xcresult

          xcrun xccov view --report coverage.xcresult > coverage.txt

      - name: Check Coverage Threshold
        run: |
          COVERAGE=$(grep 'Blaze.app' coverage.txt | awk '{print $NF}' | tr -d '%')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi
```

### 4.2 Test Plans

```xml
<!-- UnitTests.xctestplan -->
<TestPlan version="1.0">
    <TestTargets>
        <TestTarget name="BlazeTests">
            <Tests>
                <Test name="EventParserTests"/>
                <Test name="DiffProcessorTests"/>
                <Test name="PolicyEngineTests"/>
                <Test name="SessionStoreTests"/>
                <Test name="ViewModelTests"/>
            </Tests>
        </TestTarget>
    </TestTargets>
    <Configurations>
        <Configuration name="Default">
            <Options>
                <CodeCoverage enabled="true"/>
                <ThreadSanitizer enabled="true"/>
            </Options>
        </Configuration>
    </Configurations>
</TestPlan>
```

---

## 5. Manual QA Checklist

### 5.1 Pre-Release Checklist

#### Installation & Setup
- [ ] Fresh install from DMG works
- [ ] Upgrade from previous version preserves data
- [ ] CLI detection works for all supported CLIs
- [ ] First-run onboarding completes successfully
- [ ] API key / OAuth flow works

#### Core Functionality
- [ ] New session creation
- [ ] Message sending and receiving
- [ ] Streaming response rendering
- [ ] Tool card display and expansion
- [ ] Diff viewer rendering
- [ ] Session persistence and reload
- [ ] Session search and filtering

#### Security Features
- [ ] Review mode shows approval dialogs
- [ ] Trusted mode bypasses correctly
- [ ] Sandbox mode blocks dangerous operations
- [ ] Policy violations are caught

#### Accessibility
- [ ] VoiceOver navigation works
- [ ] Keyboard-only operation possible
- [ ] Reduced motion respected
- [ ] High contrast mode works

#### Performance
- [ ] App launches in < 1 second
- [ ] Scrolling is smooth (60fps)
- [ ] Large diffs render without freeze
- [ ] Memory stays under 500MB

#### Edge Cases
- [ ] Network interruption handling
- [ ] CLI crash recovery
- [ ] Corrupt session recovery
- [ ] Very long messages
- [ ] Unicode and emoji content
- [ ] Binary file handling

### 5.2 Regression Test Suite

| ID | Test Case | Steps | Expected Result |
|----|-----------|-------|-----------------|
| REG-001 | Session persistence | 1. Create session 2. Send message 3. Quit app 4. Relaunch | Session and messages restored |
| REG-002 | Streaming interruption | 1. Send long prompt 2. Click Stop | Streaming stops, partial response saved |
| REG-003 | Tool approval | 1. Enable Review mode 2. Trigger Write tool | Approval dialog shown |
| REG-004 | Branch creation | 1. Open session 2. Create branch at message | New branch visible in tree |
| REG-005 | Search functionality | 1. Have multiple sessions 2. Search for keyword | Matching sessions highlighted |

---

## 6. Bug Tracking

### 6.1 Severity Definitions

| Severity | Definition | SLA |
|----------|------------|-----|
| **P0 - Critical** | App crash, data loss, security vulnerability | Fix within 24 hours |
| **P1 - High** | Core feature broken, no workaround | Fix within 3 days |
| **P2 - Medium** | Feature degraded, workaround exists | Fix within 1 week |
| **P3 - Low** | Minor issue, cosmetic | Fix in next release |

### 6.2 Bug Report Template

```markdown
## Bug Report

**Title:** [Concise description]

**Severity:** P0 / P1 / P2 / P3

**Environment:**
- Blaze version:
- macOS version:
- CLI version:
- Hardware:

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**

**Actual Behavior:**

**Screenshots/Videos:**

**Logs:**
```console
[Attach relevant logs from ~/Library/Logs/Blaze/]
```

**Additional Context:**
```

---

## 7. Test Metrics

### 7.1 KPIs

| Metric | Target | Current |
|--------|--------|---------|
| Unit test coverage | ≥ 80% | - |
| Integration test coverage | ≥ 70% | - |
| UI test coverage | ≥ 60% | - |
| Test pass rate | 100% | - |
| Flaky test rate | < 1% | - |
| Mean time to detect regression | < 30 min | - |

### 7.2 Test Reports

Weekly test health reports include:
- Coverage trends
- Flaky test identification
- Slowest tests
- Most-failed tests
- Untested code paths
