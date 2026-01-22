import XCTest
@testable import Blaze

// MARK: - Provider Defaults Service Tests

/// Tests for ProviderDefaultsService persistence and directory hint detection.
/// Implements test cases from atom E005-F001-S001-T008-A001.
final class ProviderDefaultsTests: XCTestCase {

    var tempDirectory: URL!
    var suiteName: String!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        // Use a unique suite name to avoid polluting real UserDefaults
        suiteName = "com.cogit0.Blaze.Tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Create temp directory for directory hint tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlazeProviderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test defaults
        if let suiteName = suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil

        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Last Used Provider Tests

    func testLastUsedProviderReturnsClaudeWhenEmpty() throws {
        // Given: Fresh UserDefaults with no stored provider
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Reading last used provider
        let provider = service.lastUsedProvider

        // Then: Should return .claude (Anthropic) as default
        XCTAssertEqual(provider, .claude, "Should default to Claude/Anthropic provider")
    }

    func testLastUsedProviderReturnsStoredValue() throws {
        // Given: UserDefaults with stored provider
        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedProvider(.gemini)

        // When: Reading last used provider
        let provider = service.lastUsedProvider

        // Then: Should return stored value
        XCTAssertEqual(provider, .gemini)
    }

    func testLastUsedProviderFallsBackOnInvalidValue() throws {
        // Given: UserDefaults with invalid provider string
        testDefaults.set("invalid_provider", forKey: ProviderDefaultsService.Keys.lastUsedProvider)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Reading last used provider
        let provider = service.lastUsedProvider

        // Then: Should fall back to Claude default
        XCTAssertEqual(provider, .claude, "Should fall back to Claude on invalid value")
    }

    func testSetLastUsedProviderPersistsValue() throws {
        // Given: Service with test defaults
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Setting provider
        service.setLastUsedProvider(.codex)

        // Then: Value should be persisted in UserDefaults
        let storedValue = testDefaults.string(forKey: ProviderDefaultsService.Keys.lastUsedProvider)
        XCTAssertEqual(storedValue, "Codex CLI", "Should persist provider raw value")
    }

    // MARK: - Last Used Model Tests

    func testLastUsedModelReturnsDefaultWhenEmpty() throws {
        // Given: Fresh UserDefaults with no stored model
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Reading last used model
        let model = service.lastUsedModel

        // Then: Should return default model for default provider (Claude)
        XCTAssertEqual(model, ModelService.defaultModel(for: .claude))
    }

    func testLastUsedModelReturnsStoredValue() throws {
        // Given: UserDefaults with stored model
        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedModel("custom-model-id")

        // When: Reading last used model
        let model = service.lastUsedModel

        // Then: Should return stored value
        XCTAssertEqual(model, "custom-model-id")
    }

    func testSetLastUsedModelPersistsValue() throws {
        // Given: Service with test defaults
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Setting model
        service.setLastUsedModel("gemini-2.5-pro")

        // Then: Value should be persisted in UserDefaults
        let storedValue = testDefaults.string(forKey: ProviderDefaultsService.Keys.lastUsedModel)
        XCTAssertEqual(storedValue, "gemini-2.5-pro")
    }

    // MARK: - Reset Tests

    func testResetProviderDefaultsClearsAllKeys() throws {
        // Given: Service with stored values
        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedProvider(.gemini)
        service.setLastUsedModel("gemini-2.5-flash")

        // When: Resetting defaults
        service.resetProviderDefaults()

        // Then: All keys should be cleared (return to defaults)
        XCTAssertNil(testDefaults.string(forKey: ProviderDefaultsService.Keys.lastUsedProvider))
        XCTAssertNil(testDefaults.string(forKey: ProviderDefaultsService.Keys.lastUsedModel))

        // And computed properties should return defaults
        XCTAssertEqual(service.lastUsedProvider, .claude)
        XCTAssertEqual(service.lastUsedModel, ModelService.defaultModel(for: .claude))
    }

    // MARK: - Directory Hint Detection Tests

    func testDetectDirectoryHintReturnsClaudeForDotClaude() throws {
        // Given: Directory containing .claude/
        let claudeDir = tempDirectory.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return .claude
        XCTAssertEqual(hint, .claude, "Should detect .claude/ as Claude provider")
    }

    func testDetectDirectoryHintReturnsGeminiForDotGemini() throws {
        // Given: Directory containing .gemini/
        let geminiDir = tempDirectory.appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return .gemini
        XCTAssertEqual(hint, .gemini, "Should detect .gemini/ as Gemini provider")
    }

    func testDetectDirectoryHintReturnsCodexForDotCodex() throws {
        // Given: Directory containing .codex/
        let codexDir = tempDirectory.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return .codex
        XCTAssertEqual(hint, .codex, "Should detect .codex/ as Codex provider")
    }

    func testDetectDirectoryHintReturnsNilWhenNoHint() throws {
        // Given: Directory without any hint directories
        // (tempDirectory is empty)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return nil
        XCTAssertNil(hint, "Should return nil when no hint directories exist")
    }

    func testDetectDirectoryHintPriorityWhenMultipleHints() throws {
        // Given: Directory containing multiple hint directories
        // Priority order: .claude > .gemini > .codex
        let claudeDir = tempDirectory.appendingPathComponent(".claude")
        let geminiDir = tempDirectory.appendingPathComponent(".gemini")
        let codexDir = tempDirectory.appendingPathComponent(".codex")

        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return .claude (highest priority)
        XCTAssertEqual(hint, .claude, "Should return Claude when multiple hints exist (highest priority)")
    }

    func testDetectDirectoryHintIgnoresFiles() throws {
        // Given: Directory containing .claude as a file (not directory)
        let claudeFile = tempDirectory.appendingPathComponent(".claude")
        try "test content".write(to: claudeFile, atomically: true, encoding: .utf8)

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: tempDirectory)

        // Then: Should return nil (file doesn't count)
        XCTAssertNil(hint, "Should ignore files, only detect directories")
    }

    func testDetectDirectoryHintHandlesInvalidPath() throws {
        // Given: Invalid/non-existent path
        let invalidPath = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist")

        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Detecting directory hint
        let hint = service.detectDirectoryHint(at: invalidPath)

        // Then: Should return nil gracefully
        XCTAssertNil(hint, "Should return nil for invalid paths")
    }

    // MARK: - Effective Provider Tests (Directory Hint Override)

    func testEffectiveProviderReturnsHintWhenPresent() throws {
        // Given: Directory with hint and different stored preference
        let geminiDir = tempDirectory.appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)

        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedProvider(.codex) // Store different provider

        // When: Getting effective provider for directory with hint
        let effective = service.effectiveProvider(for: tempDirectory)

        // Then: Directory hint should override stored preference
        XCTAssertEqual(effective, .gemini, "Directory hint should override stored preference")
    }

    func testEffectiveProviderReturnsStoredWhenNoHint() throws {
        // Given: Directory without hint and stored preference
        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedProvider(.codex)

        // When: Getting effective provider for directory without hint
        let effective = service.effectiveProvider(for: tempDirectory)

        // Then: Should return stored preference
        XCTAssertEqual(effective, .codex)
    }

    func testEffectiveProviderReturnsDefaultWhenNoHintNoStored() throws {
        // Given: Directory without hint and no stored preference
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        // When: Getting effective provider for directory without hint
        let effective = service.effectiveProvider(for: tempDirectory)

        // Then: Should return default (.claude)
        XCTAssertEqual(effective, .claude)
    }

    func testEffectiveProviderWithNilDirectory() throws {
        // Given: Nil directory and stored preference
        let service = ProviderDefaultsService(userDefaults: testDefaults)
        service.setLastUsedProvider(.gemini)

        // When: Getting effective provider with nil directory
        let effective = service.effectiveProvider(for: nil)

        // Then: Should return stored preference
        XCTAssertEqual(effective, .gemini)
    }

    // MARK: - Combine Publisher Tests

    func testProviderChangePublisherEmitsOnSet() async throws {
        // Given: Service with change publisher
        let service = ProviderDefaultsService(userDefaults: testDefaults)

        var receivedProviders: [EngineType] = []
        let expectation = XCTestExpectation(description: "Provider change published")

        // Subscribe to changes
        let cancellable = service.providerChangePublisher
            .sink { provider in
                receivedProviders.append(provider)
                if receivedProviders.count >= 2 {
                    expectation.fulfill()
                }
            }

        // When: Setting providers
        service.setLastUsedProvider(.gemini)
        service.setLastUsedProvider(.codex)

        // Then: Should receive both changes
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedProviders, [.gemini, .codex])

        cancellable.cancel()
    }
}
