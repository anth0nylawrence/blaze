import Foundation

// MARK: - Token Estimator

/// Estimates token counts for various content types.
/// Uses ~4 characters per token approximation for quick estimates.
///
/// **Phase 2 Spec:**
/// - Pre-loaded tokens: CLAUDE.md + context files
/// - Session tokens: Conversation history + tool outputs
/// - Model limits: Claude Sonnet 4 default (200K context)
public actor TokenEstimator {

    // MARK: - Constants

    /// Approximate characters per token (conservative estimate)
    /// GPT-4/Claude typically average 4 chars per token for English text
    public static let charsPerToken: Double = 4.0

    /// Model context limits (in tokens)
    public enum ModelLimit: String, CaseIterable {
        case claudeSonnet4 = "claude_sonnet_4"
        case claudeOpus4 = "claude_opus_4"
        case claudeHaiku = "claude_haiku"
        case geminiPro = "gemini_pro"
        case gpt4 = "gpt_4"

        public var contextLimit: Int {
            switch self {
            case .claudeSonnet4: return 200_000
            case .claudeOpus4: return 200_000
            case .claudeHaiku: return 200_000
            case .geminiPro: return 1_000_000
            case .gpt4: return 128_000
            }
        }

        public var displayName: String {
            switch self {
            case .claudeSonnet4: return "Claude Sonnet 4"
            case .claudeOpus4: return "Claude Opus 4"
            case .claudeHaiku: return "Claude Haiku"
            case .geminiPro: return "Gemini Pro"
            case .gpt4: return "GPT-4"
            }
        }

        public var formattedLimit: String {
            let limit = contextLimit
            if limit >= 1_000_000 {
                return String(format: "%.1fM", Double(limit) / 1_000_000)
            } else {
                return String(format: "%.0fK", Double(limit) / 1_000)
            }
        }
    }

    // MARK: - Token Usage Breakdown

    /// Breakdown of token usage by category
    public struct TokenBreakdown: Sendable {
        public let preloaded: Int      // CLAUDE.md, context files
        public let systemPrompt: Int   // Engine system prompt
        public let conversation: Int   // Messages back and forth
        public let toolOutputs: Int    // Tool call results
        public let available: Int      // Remaining tokens

        public var total: Int {
            preloaded + systemPrompt + conversation + toolOutputs
        }

        public var usagePercentage: Double {
            guard available > 0 else { return 1.0 }
            return Double(total) / Double(total + available)
        }

        public init(
            preloaded: Int = 0,
            systemPrompt: Int = 0,
            conversation: Int = 0,
            toolOutputs: Int = 0,
            available: Int = 0
        ) {
            self.preloaded = preloaded
            self.systemPrompt = systemPrompt
            self.conversation = conversation
            self.toolOutputs = toolOutputs
            self.available = available
        }
    }

    // MARK: - Estimation Methods

    /// Estimate tokens for a text string
    public func estimateTokens(_ text: String) -> Int {
        let charCount = Double(text.count)
        return Int(ceil(charCount / Self.charsPerToken))
    }

    /// Estimate tokens for multiple text strings
    public func estimateTokens(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimateTokens($1) }
    }

    /// Estimate tokens from CLAUDE.md and context files
    public func estimatePreloadedTokens(
        claudeMD: URL?,
        contextFiles: [URL]
    ) async -> Int {
        var total = 0

        // CLAUDE.md
        if let claudeURL = claudeMD {
            if let tokens = try? await estimateFileTokens(claudeURL) {
                total += tokens
            }
        }

        // Context files
        for fileURL in contextFiles {
            if let tokens = try? await estimateFileTokens(fileURL) {
                total += tokens
            }
        }

        return total
    }

    /// Estimate tokens for a file
    public func estimateFileTokens(_ url: URL) async throws -> Int {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            // For binary files, estimate based on size
            return Int(ceil(Double(data.count) / Self.charsPerToken))
        }
        return estimateTokens(text)
    }

    /// Estimate tokens for message content
    public func estimateMessageTokens(_ text: String) -> Int {
        // Messages have additional overhead for role markers, etc.
        let baseTokens = estimateTokens(text)
        let overhead = 4 // Approximate overhead per message
        return baseTokens + overhead
    }

    /// Calculate full token breakdown for a session
    public func calculateBreakdown(
        preloadedContent: String?,
        systemPrompt: String?,
        messages: [String],
        toolOutputs: [String],
        modelLimit: ModelLimit = .claudeSonnet4
    ) -> TokenBreakdown {
        let preloaded = preloadedContent.map { estimateTokens($0) } ?? 0
        let system = systemPrompt.map { estimateTokens($0) } ?? 0
        let conversation = messages.reduce(0) { $0 + estimateMessageTokens($1) }
        let tools = toolOutputs.reduce(0) { $0 + estimateTokens($1) }

        let total = preloaded + system + conversation + tools
        let available = max(0, modelLimit.contextLimit - total)

        return TokenBreakdown(
            preloaded: preloaded,
            systemPrompt: system,
            conversation: conversation,
            toolOutputs: tools,
            available: available
        )
    }
}

// MARK: - Token Formatting

public extension Int {
    /// Format token count for display (e.g., "1.2K", "150K")
    var formattedTokens: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}
