import Foundation

// MARK: - AIModel

/// Represents an AI model with its capabilities and metadata.
///
/// Models belong to a provider and tier, and include:
/// - Token limits (context window, max output)
/// - Pricing (input/output costs per million tokens)
/// - Capabilities (vision, tool use)
/// - CLI flags for provider-specific invocation
///
/// **E005-F001-S001-T001-A001**
public struct AIModel: Codable, Sendable, Hashable, Identifiable {
    /// Unique model identifier (matches CLI --model flag value).
    public let id: String

    /// Human-readable model name.
    public let name: String

    /// Provider this model belongs to.
    public let provider: AIProvider

    /// Capability tier (flagship/balanced/fast).
    public let tier: ModelTier

    /// Maximum context window in tokens.
    public let contextWindow: Int

    /// Whether this is the default model for its provider.
    public let isDefault: Bool

    /// When this model was released.
    public let releaseDate: Date

    /// When this model will be/was deprecated (nil if not deprecated).
    public let deprecationDate: Date?

    /// Cost per million input tokens (USD).
    public let inputCostPerMillion: Double

    /// Cost per million output tokens (USD).
    public let outputCostPerMillion: Double

    /// Maximum tokens the model can generate in one response.
    public let maxOutputTokens: Int

    /// Whether the model supports image input.
    public let supportsVision: Bool

    /// Whether the model supports tool/function calling.
    public let supportsToolUse: Bool

    /// Additional CLI flags for this model.
    public let cliFlags: [String]

    // MARK: - Computed Properties

    /// Human-readable context window (e.g., "200K", "1M").
    public var contextWindowFormatted: String {
        if contextWindow >= 1_000_000 {
            return "\(contextWindow / 1_000_000)M"
        } else if contextWindow >= 1_000 {
            return "\(contextWindow / 1_000)K"
        } else {
            return "\(contextWindow)"
        }
    }

    /// Whether this model is past its deprecation date.
    public var isDeprecated: Bool {
        guard let deprecationDate = deprecationDate else { return false }
        return deprecationDate < Date()
    }

    /// Full display name including provider (e.g., "Anthropic Claude Opus 4.5").
    public var fullDisplayName: String {
        "\(provider.displayName) \(name)"
    }

    // MARK: - Initialization

    public init(
        id: String,
        name: String,
        provider: AIProvider,
        tier: ModelTier,
        contextWindow: Int,
        isDefault: Bool,
        releaseDate: Date,
        deprecationDate: Date?,
        inputCostPerMillion: Double,
        outputCostPerMillion: Double,
        maxOutputTokens: Int,
        supportsVision: Bool,
        supportsToolUse: Bool,
        cliFlags: [String]
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.tier = tier
        self.contextWindow = contextWindow
        self.isDefault = isDefault
        self.releaseDate = releaseDate
        self.deprecationDate = deprecationDate
        self.inputCostPerMillion = inputCostPerMillion
        self.outputCostPerMillion = outputCostPerMillion
        self.maxOutputTokens = maxOutputTokens
        self.supportsVision = supportsVision
        self.supportsToolUse = supportsToolUse
        self.cliFlags = cliFlags
    }
}
