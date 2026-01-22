import XCTest
@testable import Blaze

/// Tests for AIProvider, AIModel, ModelTier, DirectorySource, and AIModelRegistry types.
/// Follows E005-F001-S001-T001-A001 atom spec.
final class AIProviderTests: XCTestCase {

    // MARK: - AIProvider Tests

    func testAIProviderHasFourCases() {
        XCTAssertEqual(AIProvider.allCases.count, 4)
    }

    func testAIProviderDisplayNames() {
        XCTAssertEqual(AIProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(AIProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(AIProvider.google.displayName, "Google")
        XCTAssertEqual(AIProvider.community.displayName, "Community")
    }

    func testAIProviderEngineTypes() {
        XCTAssertEqual(AIProvider.anthropic.engineType, .claude)
        XCTAssertEqual(AIProvider.openai.engineType, .codex)
        XCTAssertEqual(AIProvider.google.engineType, .gemini)
        XCTAssertEqual(AIProvider.community.engineType, .claude) // Falls back to claude
    }

    func testAIProviderCliBinary() {
        XCTAssertEqual(AIProvider.anthropic.cliBinary, "claude")
        XCTAssertEqual(AIProvider.openai.cliBinary, "codex")
        XCTAssertEqual(AIProvider.google.cliBinary, "gemini")
        XCTAssertEqual(AIProvider.community.cliBinary, "aider")
    }

    func testAIProviderSupportsHooks() {
        XCTAssertTrue(AIProvider.anthropic.supportsHooks)
        XCTAssertFalse(AIProvider.openai.supportsHooks)
        XCTAssertTrue(AIProvider.google.supportsHooks)
        XCTAssertFalse(AIProvider.community.supportsHooks)
    }

    func testAIProviderHookEventCount() {
        XCTAssertGreaterThan(AIProvider.anthropic.hookEventCount, 0)
        XCTAssertEqual(AIProvider.openai.hookEventCount, 0)
        XCTAssertGreaterThan(AIProvider.google.hookEventCount, 0)
        XCTAssertEqual(AIProvider.community.hookEventCount, 0)
    }

    func testAIProviderCodable() throws {
        let provider = AIProvider.anthropic
        let encoded = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(AIProvider.self, from: encoded)
        XCTAssertEqual(decoded, provider)
    }

    func testAIProviderRawValues() {
        // Ensure lowercase for JSON consistency
        XCTAssertEqual(AIProvider.anthropic.rawValue, "anthropic")
        XCTAssertEqual(AIProvider.openai.rawValue, "openai")
        XCTAssertEqual(AIProvider.google.rawValue, "google")
        XCTAssertEqual(AIProvider.community.rawValue, "community")
    }

    // MARK: - ModelTier Tests

    func testModelTierHasThreeCases() {
        XCTAssertEqual(ModelTier.allCases.count, 3)
    }

    func testModelTierDisplayNames() {
        XCTAssertEqual(ModelTier.flagship.displayName, "Flagship")
        XCTAssertEqual(ModelTier.balanced.displayName, "Balanced")
        XCTAssertEqual(ModelTier.fast.displayName, "Fast")
    }

    func testModelTierCostMultipliers() {
        XCTAssertEqual(ModelTier.flagship.costMultiplier, 3.0)
        XCTAssertEqual(ModelTier.balanced.costMultiplier, 1.0)
        XCTAssertEqual(ModelTier.fast.costMultiplier, 0.5)
    }

    func testModelTierIcons() {
        XCTAssertEqual(ModelTier.flagship.icon, "star.fill")
        XCTAssertEqual(ModelTier.balanced.icon, "scale.3d")
        XCTAssertEqual(ModelTier.fast.icon, "hare.fill")
    }

    func testModelTierCodable() throws {
        let tier = ModelTier.flagship
        let encoded = try JSONEncoder().encode(tier)
        let decoded = try JSONDecoder().decode(ModelTier.self, from: encoded)
        XCTAssertEqual(decoded, tier)
    }

    // MARK: - AIModel Tests

    func testAIModelContextWindowFormatted() {
        // Test K formatting
        let model128K = AIModel(
            id: "test-128k",
            name: "Test 128K",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 128000,
            isDefault: false,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertEqual(model128K.contextWindowFormatted, "128K")

        // Test M formatting
        let model1M = AIModel(
            id: "test-1m",
            name: "Test 1M",
            provider: .google,
            tier: .flagship,
            contextWindow: 1000000,
            isDefault: false,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 5.0,
            outputCostPerMillion: 20.0,
            maxOutputTokens: 16384,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertEqual(model1M.contextWindowFormatted, "1M")

        // Test small value (under 1000)
        let modelSmall = AIModel(
            id: "test-small",
            name: "Test Small",
            provider: .anthropic,
            tier: .fast,
            contextWindow: 512,
            isDefault: false,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 1.0,
            outputCostPerMillion: 5.0,
            maxOutputTokens: 256,
            supportsVision: false,
            supportsToolUse: false,
            cliFlags: []
        )
        XCTAssertEqual(modelSmall.contextWindowFormatted, "512")
    }

    func testAIModelIsDeprecated() {
        // Not deprecated (nil date)
        let activeModel = AIModel(
            id: "active",
            name: "Active",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200000,
            isDefault: true,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertFalse(activeModel.isDeprecated)

        // Deprecated (past date)
        let deprecatedModel = AIModel(
            id: "deprecated",
            name: "Deprecated",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200000,
            isDefault: false,
            releaseDate: Date().addingTimeInterval(-365 * 24 * 60 * 60), // 1 year ago
            deprecationDate: Date().addingTimeInterval(-1), // Yesterday
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertTrue(deprecatedModel.isDeprecated)

        // Not yet deprecated (future date)
        let futureDeprecation = AIModel(
            id: "future",
            name: "Future",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200000,
            isDefault: false,
            releaseDate: Date(),
            deprecationDate: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year from now
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertFalse(futureDeprecation.isDeprecated)
    }

    func testAIModelFullDisplayName() {
        let model = AIModel(
            id: "claude-sonnet-4-5-20251101",
            name: "Claude Sonnet 4.5",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200000,
            isDefault: true,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        )
        XCTAssertEqual(model.fullDisplayName, "Anthropic Claude Sonnet 4.5")
    }

    func testAIModelCodable() throws {
        let model = AIModel(
            id: "test-model",
            name: "Test Model",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200000,
            isDefault: true,
            releaseDate: Date(),
            deprecationDate: nil,
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 8192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["--beta"]
        )
        let encoded = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AIModel.self, from: encoded)
        XCTAssertEqual(decoded.id, model.id)
        XCTAssertEqual(decoded.name, model.name)
        XCTAssertEqual(decoded.provider, model.provider)
        XCTAssertEqual(decoded.tier, model.tier)
    }

    // MARK: - AIModelRegistry Tests

    func testRegistryAnthropicCount() {
        XCTAssertEqual(AIModelRegistry.anthropic.count, 3)
    }

    func testRegistryOpenAICount() {
        XCTAssertEqual(AIModelRegistry.openai.count, 3)
    }

    func testRegistryGoogleCount() {
        XCTAssertEqual(AIModelRegistry.google.count, 3)
    }

    func testRegistryAllCount() {
        XCTAssertEqual(AIModelRegistry.all.count, 9)
    }

    func testRegistryDefaultModelForAnthropic() {
        let defaultModel = AIModelRegistry.defaultModel(for: .anthropic)
        XCTAssertNotNil(defaultModel)
        XCTAssertEqual(defaultModel?.id, "claude-sonnet-4-5-20251101")
    }

    func testRegistryDefaultModelForCommunity() {
        let defaultModel = AIModelRegistry.defaultModel(for: .community)
        XCTAssertNil(defaultModel) // No community models defined
    }

    func testRegistryModelById() {
        let opus = AIModelRegistry.model(byId: "claude-opus-4-5-20251101")
        XCTAssertNotNil(opus)
        XCTAssertEqual(opus?.name, "Claude Opus 4.5")
        XCTAssertEqual(opus?.tier, .flagship)

        let unknown = AIModelRegistry.model(byId: "unknown-model")
        XCTAssertNil(unknown)
    }

    func testRegistryModelsByTier() {
        let flagships = AIModelRegistry.models(byTier: .flagship)
        XCTAssertEqual(flagships.count, 3) // One flagship per provider

        let balanced = AIModelRegistry.models(byTier: .balanced)
        XCTAssertEqual(balanced.count, 3)

        let fast = AIModelRegistry.models(byTier: .fast)
        XCTAssertEqual(fast.count, 3)
    }

    func testRegistryProviderForModelId() {
        XCTAssertEqual(AIModelRegistry.provider(forModelId: "claude-opus-4-5-20251101"), .anthropic)
        XCTAssertEqual(AIModelRegistry.provider(forModelId: "gemini-3.0-pro"), .google)
        XCTAssertEqual(AIModelRegistry.provider(forModelId: "codex-5.2-flagship"), .openai)
        XCTAssertNil(AIModelRegistry.provider(forModelId: "unknown-model"))
    }

    func testRegistryModelsForProvider() {
        let anthropicModels = AIModelRegistry.models(for: .anthropic)
        XCTAssertEqual(anthropicModels.count, 3)
        XCTAssertTrue(anthropicModels.allSatisfy { $0.provider == .anthropic })

        let communityModels = AIModelRegistry.models(for: .community)
        XCTAssertEqual(communityModels.count, 0)
    }

    // MARK: - DirectorySource Tests

    func testDirectorySourceHasThreeCases() {
        XCTAssertEqual(DirectorySource.allCases.count, 3)
    }

    func testDirectorySourceDisplayNames() {
        XCTAssertEqual(DirectorySource.browse.displayName, "Browse")
        XCTAssertEqual(DirectorySource.clone.displayName, "Clone")
        XCTAssertEqual(DirectorySource.create.displayName, "Create")
    }

    func testDirectorySourceIcons() {
        XCTAssertEqual(DirectorySource.browse.icon, "folder")
        XCTAssertEqual(DirectorySource.clone.icon, "arrow.down.circle")
        XCTAssertEqual(DirectorySource.create.icon, "plus.circle")
    }

    func testDirectorySourceDescriptions() {
        XCTAssertEqual(DirectorySource.browse.description, "Select an existing project folder")
        XCTAssertEqual(DirectorySource.clone.description, "Clone a Git repository")
        XCTAssertEqual(DirectorySource.create.description, "Create a new project")
    }

    func testDirectorySourceCodable() throws {
        let source = DirectorySource.clone
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(DirectorySource.self, from: encoded)
        XCTAssertEqual(decoded, source)
    }

    // MARK: - Performance Tests

    func testRegistryModelByIdPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = AIModelRegistry.model(byId: "claude-opus-4-5-20251101")
            }
        }
    }

    func testAIModelEncodingPerformance() throws {
        let model = AIModelRegistry.anthropic[0]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        measure {
            for _ in 0..<1000 {
                let data = try! encoder.encode(model)
                _ = try! decoder.decode(AIModel.self, from: data)
            }
        }
    }

    // MARK: - Security Tests

    func testAIProviderRejectsUnknownRawValue() {
        let json = "\"unknown_provider\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(AIProvider.self, from: data))
    }

    func testModelIdsContainOnlyValidCharacters() {
        let validPattern = #"^[a-zA-Z0-9.\-]+$"#
        let regex = try! NSRegularExpression(pattern: validPattern)

        for model in AIModelRegistry.all {
            let range = NSRange(model.id.startIndex..., in: model.id)
            let matches = regex.numberOfMatches(in: model.id, range: range)
            XCTAssertEqual(matches, 1, "Model ID '\(model.id)' contains invalid characters")
        }
    }

    func testCliFlagsDoNotContainShellInjection() {
        let dangerousPatterns = [";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">"]

        for model in AIModelRegistry.all {
            for flag in model.cliFlags {
                for pattern in dangerousPatterns {
                    XCTAssertFalse(
                        flag.contains(pattern),
                        "CLI flag '\(flag)' in model '\(model.id)' contains potentially dangerous character '\(pattern)'"
                    )
                }
            }
        }
    }
}
