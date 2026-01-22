import XCTest
@testable import Blaze

/// Tests for EngineRouter - factory pattern for creating adapters based on EngineType
final class EngineRouterTests: XCTestCase {

    // MARK: - Factory Method Tests

    @MainActor
    func testCreateAdapterForClaude() {
        let adapter = EngineRouter.createAdapter(for: .claude)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .claude)
        XCTAssertTrue(adapter is ClaudeCodeAdapter)
    }

    @MainActor
    func testCreateAdapterForGemini() {
        let adapter = EngineRouter.createAdapter(for: .gemini)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .gemini)
        XCTAssertTrue(adapter is GeminiCliAdapter)
    }

    @MainActor
    func testCreateAdapterForCodex() {
        let adapter = EngineRouter.createAdapter(for: .codex)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .codex)
        XCTAssertTrue(adapter is CodexCliAdapter)
    }

    // MARK: - All Engine Types Covered

    @MainActor
    func testAllEngineTypesReturnAdapter() {
        // Ensure every EngineType case returns a valid adapter
        for engineType in EngineType.allCases {
            let adapter = EngineRouter.createAdapter(for: engineType)
            XCTAssertNotNil(adapter, "Adapter should exist for \(engineType)")
            XCTAssertEqual(adapter?.engineType, engineType, "Adapter engineType should match requested type")
        }
    }

    // MARK: - Session-Based Routing Tests

    @MainActor
    func testGetAdapterForSessionWithClaudeEngine() {
        let session = Session(name: "Test Session", engineType: .claude)

        let adapter = EngineRouter.getAdapter(for: session)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .claude)
        XCTAssertTrue(adapter is ClaudeCodeAdapter)
    }

    @MainActor
    func testGetAdapterForSessionWithGeminiEngine() {
        let session = Session(name: "Gemini Session", engineType: .gemini)

        let adapter = EngineRouter.getAdapter(for: session)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .gemini)
        XCTAssertTrue(adapter is GeminiCliAdapter)
    }

    @MainActor
    func testGetAdapterForSessionWithCodexEngine() {
        let session = Session(name: "Codex Session", engineType: .codex)

        let adapter = EngineRouter.getAdapter(for: session)

        XCTAssertNotNil(adapter)
        XCTAssertEqual(adapter?.engineType, .codex)
        XCTAssertTrue(adapter is CodexCliAdapter)
    }

    // MARK: - Adapter Independence Tests

    @MainActor
    func testCreateAdapterReturnsNewInstances() {
        // Factory should create new instances each time
        let adapter1 = EngineRouter.createAdapter(for: .claude)
        let adapter2 = EngineRouter.createAdapter(for: .claude)

        XCTAssertNotNil(adapter1)
        XCTAssertNotNil(adapter2)
        XCTAssertFalse(adapter1 === adapter2, "Each call should return a new instance")
    }

    // MARK: - Adapter Feature Verification

    @MainActor
    func testClaudeAdapterHasExpectedFeatures() {
        guard let adapter = EngineRouter.createAdapter(for: .claude) else {
            XCTFail("Claude adapter should be created")
            return
        }

        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .toolUse))
        XCTAssertTrue(adapter.supports(feature: .mcpSupport))
    }

    @MainActor
    func testGeminiAdapterHasExpectedFeatures() {
        guard let adapter = EngineRouter.createAdapter(for: .gemini) else {
            XCTFail("Gemini adapter should be created")
            return
        }

        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .sessionPersistence))
    }

    @MainActor
    func testCodexAdapterHasExpectedFeatures() {
        guard let adapter = EngineRouter.createAdapter(for: .codex) else {
            XCTFail("Codex adapter should be created")
            return
        }

        XCTAssertTrue(adapter.supports(feature: .streaming))
        XCTAssertTrue(adapter.supports(feature: .sandboxMode))
    }
}
