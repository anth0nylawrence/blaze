import Foundation

// MARK: - Model Service

/// Central service for managing AI model information across different engine types.
///
/// This service provides a single source of truth for available models,
/// their display names, and recommended defaults for each engine.
struct ModelService {

    // MARK: - Model Info

    /// Information about an AI model
    struct ModelInfo: Identifiable {
        let id: String
        let displayName: String
        let isRecommended: Bool

        var pickerLabel: String {
            isRecommended ? "\(displayName) (Recommended)" : displayName
        }
    }

    // MARK: - Model Lists

    /// Get all available models for a specific engine type
    static func models(for engine: EngineType) -> [ModelInfo] {
        switch engine {
        case .claude:
            return claudeModels
        case .gemini:
            return geminiModels
        case .codex:
            return codexModels
        }
    }

    /// Get the default model ID for a specific engine type
    static func defaultModel(for engine: EngineType) -> String {
        switch engine {
        case .claude:
            return "opus"
        case .gemini:
            return "gemini-2.5-pro"
        case .codex:
            return "gpt-5.2-high"
        }
    }

    // MARK: - Private Model Lists

    private static let claudeModels: [ModelInfo] = [
        ModelInfo(id: "opus", displayName: "Opus 4.5", isRecommended: true),
        ModelInfo(id: "sonnet", displayName: "Sonnet 4.5", isRecommended: false),
        ModelInfo(id: "haiku", displayName: "Haiku 4.5", isRecommended: false)
    ]

    private static let geminiModels: [ModelInfo] = [
        ModelInfo(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", isRecommended: true),
        ModelInfo(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", isRecommended: false)
    ]

    private static let codexModels: [ModelInfo] = [
        ModelInfo(id: "gpt-5.2-extra-high", displayName: "GPT 5.2 Extra High", isRecommended: false),
        ModelInfo(id: "gpt-5.2-high", displayName: "GPT 5.2 High", isRecommended: true),
        ModelInfo(id: "gpt-5.2-medium", displayName: "GPT 5.2 Medium", isRecommended: false)
    ]
}
