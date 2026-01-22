import XCTest
import GRDB
@testable import Blaze

final class ToolApprovalPipelineTests: XCTestCase {

    // MARK: - Request/Decision Flow Tests

    /// Test: Submit tool request and verify it blocks until decision
    func testRequestBlocksUntilDecision() async {
        let pipeline = ToolApprovalPipeline(trustMode: .prompt)

        let request = ToolRequestEvent(
            toolCallId: "toolu_123",
            toolName: "Write",
            input: "{\"file_path\": \"/test.txt\"}",
            riskLevel: .medium
        )

        // Start the request in a task
        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        // Give the request time to be submitted
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Verify request is pending
        let isPending = await pipeline.isPending(request.id)
        XCTAssertTrue(isPending, "Request should be pending")

        // Record decision
        _ = await pipeline.approve(requestId: request.id, decidedBy: "user")

        // Wait for decision task to complete
        let decision = await decisionTask.value

        XCTAssertEqual(decision.decision, .approved)
        XCTAssertEqual(decision.decidedBy, "user")
    }

    /// Test: Reject request and verify decision recorded
    func testRejectRequest() async {
        let pipeline = ToolApprovalPipeline(trustMode: .prompt)

        let request = ToolRequestEvent(
            toolCallId: "toolu_456",
            toolName: "Bash",
            input: "rm -rf /",
            riskLevel: .high
        )

        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        _ = await pipeline.reject(requestId: request.id, decidedBy: "user", rationale: "Too dangerous")

        let decision = await decisionTask.value

        XCTAssertEqual(decision.decision, .rejected)
        XCTAssertEqual(decision.rationale, "Too dangerous")
    }

    /// Test: Result recorded after decision
    func testResultRecordedAfterDecision() async {
        let pipeline = ToolApprovalPipeline(trustMode: .prompt)

        let request = ToolRequestEvent(
            id: UUID(),
            toolCallId: "toolu_789",
            toolName: "Read",
            input: "{\"file_path\": \"/test.txt\"}",
            riskLevel: .low
        )

        // In review mode, even low-risk tools need approval
        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        _ = await pipeline.approve(requestId: request.id)
        _ = await decisionTask.value

        // Record result
        let result = ToolResultEvent(
            toolRequestId: request.id,
            toolCallId: "toolu_789",
            toolName: "Read",
            output: "File contents here",
            durationMs: 50
        )

        await pipeline.recordResult(result)

        let storedResult = await pipeline.getResult(for: request.id)
        XCTAssertNotNil(storedResult)
        XCTAssertEqual(storedResult?.output, "File contents here")
    }

    // MARK: - Trust Mode Tests

    /// Test: Unrestricted mode auto-approves low/medium risk
    func testUnrestrictedModeAutoApproves() async {
        let pipeline = ToolApprovalPipeline(trustMode: .unrestricted)

        let request = ToolRequestEvent(
            toolCallId: "toolu_100",
            toolName: "Write",
            input: "{}",
            riskLevel: .medium
        )

        let decision = await pipeline.submitRequest(request)

        // Should be auto-approved without blocking
        XCTAssertEqual(decision.decision, .approved)
        XCTAssertEqual(decision.decidedBy, "system:unrestricted_mode")
    }

    /// Test: Unrestricted mode still gates high risk
    func testUnrestrictedModeGatesHighRisk() async {
        let pipeline = ToolApprovalPipeline(trustMode: .unrestricted)

        let request = ToolRequestEvent(
            toolCallId: "toolu_101",
            toolName: "Bash",
            input: "{}",
            riskLevel: .high
        )

        // This should block, so we approve manually
        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let isPending = await pipeline.isPending(request.id)
        XCTAssertTrue(isPending, "High risk should still be pending in unrestricted mode")

        _ = await pipeline.approve(requestId: request.id)
        _ = await decisionTask.value
    }

    /// Test: LockedDown mode only allows low risk
    func testLockedDownModeOnlyAllowsLowRisk() async {
        let pipeline = ToolApprovalPipeline(trustMode: .lockedDown)

        // Low risk - should auto-approve
        let lowRequest = ToolRequestEvent(
            toolCallId: "toolu_200",
            toolName: "Read",
            input: "{}",
            riskLevel: .low
        )

        let lowDecision = await pipeline.submitRequest(lowRequest)
        XCTAssertEqual(lowDecision.decision, .approved)
        XCTAssertEqual(lowDecision.decidedBy, "system:locked_down_mode")

        // Medium risk - should auto-reject
        let medRequest = ToolRequestEvent(
            toolCallId: "toolu_201",
            toolName: "Write",
            input: "{}",
            riskLevel: .medium
        )

        let medDecision = await pipeline.submitRequest(medRequest)
        XCTAssertEqual(medDecision.decision, .rejected)
        XCTAssertTrue(medDecision.rationale?.contains("read-only") ?? false)
    }

    // MARK: - Allowlist Tests

    /// Test: Allowlist auto-approves matching requests
    func testAllowlistAutoApproves() async {
        let rule = AllowlistRule(
            toolName: "Write",
            scope: ToolScope(paths: ["/project/src/"]),
            riskLevel: .medium
        )

        let pipeline = ToolApprovalPipeline(trustMode: .prompt, allowlistRules: [rule])

        let request = ToolRequestEvent(
            toolCallId: "toolu_300",
            toolName: "Write",
            input: "{}",
            riskLevel: .medium,
            scope: ToolScope(paths: ["/project/src/file.txt"])
        )

        let decision = await pipeline.submitRequest(request)

        XCTAssertEqual(decision.decision, .approved)
        XCTAssertEqual(decision.decidedBy, "system:allowlist")
        XCTAssertEqual(decision.allowlistRuleId, rule.id)
    }

    /// Test: Allowlist doesn't match different tool
    func testAllowlistDoesNotMatchDifferentTool() async {
        let rule = AllowlistRule(toolName: "Write")
        let pipeline = ToolApprovalPipeline(trustMode: .prompt, allowlistRules: [rule])

        let request = ToolRequestEvent(
            toolCallId: "toolu_301",
            toolName: "Bash",  // Different tool
            input: "{}",
            riskLevel: .high
        )

        // Should block because allowlist doesn't match
        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let isPending = await pipeline.isPending(request.id)
        XCTAssertTrue(isPending, "Different tool should not match allowlist")

        _ = await pipeline.approve(requestId: request.id)
        _ = await decisionTask.value
    }

    /// Test: Always allow creates allowlist rule
    func testAlwaysAllowCreatesRule() async {
        let pipeline = ToolApprovalPipeline(trustMode: .prompt)

        let request = ToolRequestEvent(
            toolCallId: "toolu_400",
            toolName: "Read",
            input: "{}",
            riskLevel: .low
        )

        let decisionTask = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let (decision, rule) = await pipeline.alwaysAllow(requestId: request.id)

        XCTAssertEqual(decision?.decision, .alwaysAllow)
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.toolName, "Read")

        // Verify rule was added
        let rules = await pipeline.currentAllowlistRules
        XCTAssertEqual(rules.count, 1)

        _ = await decisionTask.value
    }

    // MARK: - Risk Classification Tests

    func testToolRiskClassification() {
        // Safe tools
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Read", scope: nil), .low)
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Glob", scope: nil), .low)
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Grep", scope: nil), .low)

        // Dangerous tools
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Bash", scope: nil), .high)
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Task", scope: nil), .high)

        // Medium risk
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Write", scope: nil), .medium)
        XCTAssertEqual(ToolRiskClassifier.classify(toolName: "Edit", scope: nil), .medium)
    }

    // MARK: - Reset Tests

    func testResetClearsPendingRequests() async {
        let pipeline = ToolApprovalPipeline(trustMode: .prompt)

        let request = ToolRequestEvent(
            toolCallId: "toolu_500",
            toolName: "Write",
            input: "{}",
            riskLevel: .medium
        )

        // Submit but don't approve
        _ = Task {
            await pipeline.submitRequest(request)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let pendingBefore = await pipeline.pendingToolRequests.count
        XCTAssertEqual(pendingBefore, 1)

        await pipeline.reset()

        let pendingAfter = await pipeline.pendingToolRequests.count
        XCTAssertEqual(pendingAfter, 0)
    }

    // MARK: - Allowlist Rule Tests

    func testAllowlistRuleMatching() {
        let rule = AllowlistRule(
            toolName: "Write",
            scope: ToolScope(paths: ["/project/src/"]),
            riskLevel: .medium
        )

        // Matching request
        let matchingRequest = ToolRequestEvent(
            toolCallId: "test",
            toolName: "Write",
            input: "{}",
            riskLevel: .low,  // Lower than rule
            scope: ToolScope(paths: ["/project/src/main.swift"])
        )
        XCTAssertTrue(rule.matches(matchingRequest))

        // Non-matching: different tool
        let differentTool = ToolRequestEvent(
            toolCallId: "test",
            toolName: "Bash",
            input: "{}",
            riskLevel: .low
        )
        XCTAssertFalse(rule.matches(differentTool))

        // Non-matching: higher risk
        let higherRisk = ToolRequestEvent(
            toolCallId: "test",
            toolName: "Write",
            input: "{}",
            riskLevel: .high,  // Higher than rule
            scope: ToolScope(paths: ["/project/src/"])
        )
        XCTAssertFalse(rule.matches(higherRisk))
    }
}

// MARK: - TrustMode Migration Tests (Atom A004)

/// Tests for TrustMode enum and migration handling

final class TrustModeMigrationTests: XCTestCase {

    // MARK: - Legacy Migration Tests

    func testLegacyMigrationFromSandbox() {
        let mode = TrustMode(fromLegacy: "sandbox")
        XCTAssertEqual(mode, .lockedDown)
    }

    func testLegacyMigrationFromReview() {
        let mode = TrustMode(fromLegacy: "review")
        XCTAssertEqual(mode, .prompt)
    }

    func testLegacyMigrationFromTrusted() {
        let mode = TrustMode(fromLegacy: "trusted")
        XCTAssertEqual(mode, .unrestricted)
    }

    func testLegacyMigrationCaseInsensitive() {
        XCTAssertEqual(TrustMode(fromLegacy: "SANDBOX"), .lockedDown)
        XCTAssertEqual(TrustMode(fromLegacy: "Review"), .prompt)
        XCTAssertEqual(TrustMode(fromLegacy: "TRUSTED"), .unrestricted)
    }

    func testLegacyMigrationUnknownDefaultsToPrompt() {
        let mode = TrustMode(fromLegacy: "unknown_value")
        XCTAssertEqual(mode, .prompt, "Unknown values should default to prompt for safety")
    }

    // MARK: - Decoding Migration Tests

    func testDecodingNewFormat() throws {
        let json = "\"prompt\""
        let mode = try JSONDecoder().decode(TrustMode.self, from: Data(json.utf8))
        XCTAssertEqual(mode, .prompt)
    }

    func testDecodingLegacyFormat() throws {
        // Legacy "review" should decode to .prompt
        let json = "\"review\""
        let mode = try JSONDecoder().decode(TrustMode.self, from: Data(json.utf8))
        XCTAssertEqual(mode, .prompt)
    }

    func testDecodingLegacySandbox() throws {
        let json = "\"sandbox\""
        let mode = try JSONDecoder().decode(TrustMode.self, from: Data(json.utf8))
        XCTAssertEqual(mode, .lockedDown)
    }

    func testDecodingLegacyTrusted() throws {
        let json = "\"trusted\""
        let mode = try JSONDecoder().decode(TrustMode.self, from: Data(json.utf8))
        XCTAssertEqual(mode, .unrestricted)
    }

    // MARK: - Ordering Tests

    func testTrustModeOrdering() {
        XCTAssertEqual(TrustMode.lockedDown.order, 0)
        XCTAssertEqual(TrustMode.prompt.order, 1)
        XCTAssertEqual(TrustMode.allowlisted.order, 2)
        XCTAssertEqual(TrustMode.unrestricted.order, 3)
    }

    func testIsAtLeastAsPermissive() {
        XCTAssertTrue(TrustMode.unrestricted.isAtLeastAsPermissive(as: .lockedDown))
        XCTAssertTrue(TrustMode.unrestricted.isAtLeastAsPermissive(as: .prompt))
        XCTAssertTrue(TrustMode.unrestricted.isAtLeastAsPermissive(as: .allowlisted))
        XCTAssertTrue(TrustMode.unrestricted.isAtLeastAsPermissive(as: .unrestricted))

        XCTAssertFalse(TrustMode.lockedDown.isAtLeastAsPermissive(as: .prompt))
        XCTAssertFalse(TrustMode.prompt.isAtLeastAsPermissive(as: .unrestricted))
    }

    func testIsMoreRestrictive() {
        XCTAssertTrue(TrustMode.lockedDown.isMoreRestrictive(than: .prompt))
        XCTAssertTrue(TrustMode.prompt.isMoreRestrictive(than: .allowlisted))
        XCTAssertTrue(TrustMode.allowlisted.isMoreRestrictive(than: .unrestricted))

        XCTAssertFalse(TrustMode.unrestricted.isMoreRestrictive(than: .lockedDown))
        XCTAssertFalse(TrustMode.prompt.isMoreRestrictive(than: .prompt))
    }

    // MARK: - Auto-Approval Threshold Tests

    func testAutoApproveThresholds() {
        XCTAssertEqual(TrustMode.lockedDown.autoApproveThreshold, .low)
        XCTAssertNil(TrustMode.prompt.autoApproveThreshold)
        XCTAssertNil(TrustMode.allowlisted.autoApproveThreshold)
        XCTAssertEqual(TrustMode.unrestricted.autoApproveThreshold, .medium)
    }

    func testAutoRejectBehavior() {
        XCTAssertTrue(TrustMode.lockedDown.autoRejectAboveThreshold)
        XCTAssertFalse(TrustMode.prompt.autoRejectAboveThreshold)
        XCTAssertFalse(TrustMode.allowlisted.autoRejectAboveThreshold)
        XCTAssertFalse(TrustMode.unrestricted.autoRejectAboveThreshold)
    }

    // MARK: - Legacy Alias Tests

    func testLegacyAliasesWork() {
        // Static aliases should map to new values
        XCTAssertEqual(TrustMode.sandbox, .lockedDown)
        XCTAssertEqual(TrustMode.review, .prompt)
        XCTAssertEqual(TrustMode.trusted, .unrestricted)
    }
}

// MARK: - Repo Lock Manager Tests (Atom A005)


final class ToolRiskClassifierTests: XCTestCase {

    // MARK: - Safe Tools (Low Risk)

    func testReadToolIsLowRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Read", scope: nil)
        XCTAssertEqual(risk, .low)
    }

    func testGlobToolIsLowRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Glob", scope: nil)
        XCTAssertEqual(risk, .low)
    }

    func testGrepToolIsLowRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Grep", scope: nil)
        XCTAssertEqual(risk, .low)
    }

    func testWebFetchIsLowRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "WebFetch", scope: nil)
        XCTAssertEqual(risk, .low)
    }

    func testWebSearchIsLowRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "WebSearch", scope: nil)
        XCTAssertEqual(risk, .low)
    }

    // MARK: - Dangerous Tools (High Risk)

    func testBashToolIsHighRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Bash", scope: nil)
        XCTAssertEqual(risk, .high)
    }

    func testTaskToolIsHighRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Task", scope: nil)
        XCTAssertEqual(risk, .high)
    }

    // MARK: - Medium Risk Tools

    func testWriteToolIsMediumRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Write", scope: nil)
        XCTAssertEqual(risk, .medium)
    }

    func testEditToolIsMediumRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "Edit", scope: nil)
        XCTAssertEqual(risk, .medium)
    }

    func testUnknownToolIsMediumRisk() {
        let risk = ToolRiskClassifier.classify(toolName: "UnknownTool", scope: nil)
        XCTAssertEqual(risk, .medium)
    }

    // MARK: - Safe Tools Set

    func testSafeToolsSet() {
        XCTAssertTrue(ToolRiskClassifier.safeTools.contains("Read"))
        XCTAssertTrue(ToolRiskClassifier.safeTools.contains("Glob"))
        XCTAssertTrue(ToolRiskClassifier.safeTools.contains("Grep"))
        XCTAssertTrue(ToolRiskClassifier.safeTools.contains("WebFetch"))
        XCTAssertTrue(ToolRiskClassifier.safeTools.contains("WebSearch"))
        XCTAssertFalse(ToolRiskClassifier.safeTools.contains("Bash"))
    }

    // MARK: - Dangerous Tools Set

    func testDangerousToolsSet() {
        XCTAssertTrue(ToolRiskClassifier.dangerousTools.contains("Bash"))
        XCTAssertTrue(ToolRiskClassifier.dangerousTools.contains("Task"))
        XCTAssertFalse(ToolRiskClassifier.dangerousTools.contains("Read"))
    }
}

// MARK: - Persistence Layer Tests


