import Foundation

// MARK: - AIModelRegistry

/// Static registry of all known AI models.
///
/// The registry provides:
/// - Model lookup by ID (O(n) linear scan, fast enough for 9 models)
/// - Model lists by provider and tier
/// - Default model resolution for each provider
///
/// **Note:** This is a static registry. Dynamic model fetching from
/// provider APIs is deferred to feature F006.
///
/// **E005-F001-S001-T001-A001**
public enum AIModelRegistry {
    // MARK: - Model Lists by Provider

    /// Anthropic Claude models.
    /// IDs match Claude Code CLI --model flag values (opus, sonnet, haiku).
    public static let anthropic: [AIModel] = [
        AIModel(
            id: "opus",
            name: "Opus",
            provider: .anthropic,
            tier: .flagship,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-11-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 15.0,
            outputCostPerMillion: 75.0,
            maxOutputTokens: 32_768,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["--model", "opus"]
        ),
        AIModel(
            id: "sonnet",
            name: "Sonnet",
            provider: .anthropic,
            tier: .balanced,
            contextWindow: 200_000,
            isDefault: true,
            releaseDate: ISO8601DateFormatter().date(from: "2025-11-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 3.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 16_384,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["--model", "sonnet"]
        ),
        AIModel(
            id: "haiku",
            name: "Haiku",
            provider: .anthropic,
            tier: .fast,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-11-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 0.25,
            outputCostPerMillion: 1.25,
            maxOutputTokens: 8_192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["--model", "haiku"]
        ),
    ]

    /// OpenAI Codex CLI models.
    /// IDs match Codex CLI -m/--model flag values.
    public static let openai: [AIModel] = [
        AIModel(
            id: "o3",
            name: "o3",
            provider: .openai,
            tier: .flagship,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 20.0,
            outputCostPerMillion: 60.0,
            maxOutputTokens: 100_000,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "o3"]
        ),
        AIModel(
            id: "gpt-5.2-codex",
            name: "GPT-5.2 Codex",
            provider: .openai,
            tier: .balanced,
            contextWindow: 200_000,
            isDefault: true,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 5.0,
            outputCostPerMillion: 15.0,
            maxOutputTokens: 16_384,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "gpt-5.2-codex"]
        ),
        AIModel(
            id: "o4-mini",
            name: "o4-mini",
            provider: .openai,
            tier: .fast,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 1.1,
            outputCostPerMillion: 4.4,
            maxOutputTokens: 65_536,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "o4-mini"]
        ),
        AIModel(
            id: "gpt-5.1-codex-max",
            name: "GPT-5.1 Codex Max",
            provider: .openai,
            tier: .flagship,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 10.0,
            outputCostPerMillion: 30.0,
            maxOutputTokens: 65_536,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "gpt-5.1-codex-max"]
        ),
        AIModel(
            id: "gpt-5.1-codex-mini",
            name: "GPT-5.1 Codex Mini",
            provider: .openai,
            tier: .fast,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 2.0,
            outputCostPerMillion: 8.0,
            maxOutputTokens: 65_536,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "gpt-5.1-codex-mini"]
        ),
        AIModel(
            id: "gpt-5.2",
            name: "GPT-5.2",
            provider: .openai,
            tier: .flagship,
            contextWindow: 200_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 8.0,
            outputCostPerMillion: 24.0,
            maxOutputTokens: 65_536,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: ["-m", "gpt-5.2"]
        ),
    ]

    /// Google Gemini models.
    public static let google: [AIModel] = [
        AIModel(
            id: "gemini-3.0-ultra",
            name: "Gemini 3.0 Ultra",
            provider: .google,
            tier: .flagship,
            contextWindow: 2_000_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 12.5,
            outputCostPerMillion: 37.5,
            maxOutputTokens: 32_768,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        ),
        AIModel(
            id: "gemini-3.0-pro",
            name: "Gemini 3.0 Pro",
            provider: .google,
            tier: .balanced,
            contextWindow: 1_000_000,
            isDefault: true,
            releaseDate: ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 2.5,
            outputCostPerMillion: 10.0,
            maxOutputTokens: 16_384,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        ),
        AIModel(
            id: "gemini-3.0-flash",
            name: "Gemini 3.0 Flash",
            provider: .google,
            tier: .fast,
            contextWindow: 1_000_000,
            isDefault: false,
            releaseDate: ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z") ?? Date(),
            deprecationDate: nil,
            inputCostPerMillion: 0.15,
            outputCostPerMillion: 0.60,
            maxOutputTokens: 8_192,
            supportsVision: true,
            supportsToolUse: true,
            cliFlags: []
        ),
    ]

    /// Community models (empty - community models are not pre-defined).
    public static let community: [AIModel] = []

    // MARK: - All Models

    /// All registered models across all providers.
    public static let all: [AIModel] = anthropic + openai + google + community

    // MARK: - Lookup Methods

    /// Get all models for a specific provider.
    public static func models(for provider: AIProvider) -> [AIModel] {
        switch provider {
        case .anthropic: return anthropic
        case .openai: return openai
        case .google: return google
        case .community: return community
        }
    }

    /// Get the default model for a provider (nil if no models defined).
    public static func defaultModel(for provider: AIProvider) -> AIModel? {
        models(for: provider).first { $0.isDefault }
    }

    /// Look up a model by its ID string.
    public static func model(byId id: String) -> AIModel? {
        all.first { $0.id == id }
    }

    /// Get all models of a specific tier.
    public static func models(byTier tier: ModelTier) -> [AIModel] {
        all.filter { $0.tier == tier }
    }

    /// Determine which provider owns a model ID (nil if unknown).
    public static func provider(forModelId id: String) -> AIProvider? {
        model(byId: id)?.provider
    }
}
