import Foundation

// MARK: - Prompt Policy

/// Policy decisions for tool prompts with safety guardrails.
/// Uses conservative defaults - permission-like prompts require confirmation.
public enum PromptPolicyDecision: Equatable, Sendable {
    /// User can respond freely
    case allow
    /// Show "are you sure?" confirmation before submit
    case requireConfirmation(reason: String)
    /// Block submission with explanation
    case deny(reason: String)
}

/// Evaluates tool prompts against safety policies.
/// Conservative by default - errs on side of caution for permission-related prompts.
@MainActor
public final class PromptPolicyEvaluator: ObservableObject {

    // MARK: - Configuration

    /// Keywords that indicate permission/dangerous action prompts
    private static let dangerousKeywords: Set<String> = [
        "delete", "remove", "overwrite", "erase", "destroy",
        "permission", "allow", "approve", "grant", "authorize",
        "execute", "run", "shell", "command", "sudo",
        "deploy", "publish", "push", "merge",
        "password", "credential", "secret", "token", "key",
        "install", "uninstall"
    ]

    /// Keywords that indicate low-risk informational prompts
    private static let safeKeywords: Set<String> = [
        "prefer", "preference", "style", "format",
        "color", "theme", "approach", "method",
        "option", "choice", "select", "choose"
    ]

    // MARK: - Evaluation

    /// Evaluate a tool prompt against safety policy.
    /// - Parameter prompt: The tool prompt to evaluate
    /// - Returns: Policy decision (allow, requireConfirmation, or deny)
    public func evaluate(_ prompt: ToolPromptEvent) -> PromptPolicyDecision {
        // Gather all text to analyze
        let textToCheck = gatherText(from: prompt).lowercased()

        // Check for dangerous keywords
        let dangerMatches = Self.dangerousKeywords.filter { textToCheck.contains($0) }

        if !dangerMatches.isEmpty {
            // Found dangerous keywords - require confirmation
            let matchedKeywords = dangerMatches.prefix(3).joined(separator: ", ")
            return .requireConfirmation(
                reason: "This prompt contains potentially sensitive actions (\(matchedKeywords)). Please confirm before submitting."
            )
        }

        // Check for safe keywords (override if present)
        let hasSafeIndicator = Self.safeKeywords.contains { textToCheck.contains($0) }

        if hasSafeIndicator {
            // Clearly a preference/style question
            return .allow
        }

        // Check options for dangerous actions
        let optionsDangerous = prompt.options.contains { option in
            let optionText = "\(option.label) \(option.description ?? "")".lowercased()
            return Self.dangerousKeywords.contains { optionText.contains($0) }
        }

        if optionsDangerous {
            return .requireConfirmation(
                reason: "Some options may perform sensitive actions. Please review before submitting."
            )
        }

        // Default: allow
        return .allow
    }

    /// Gather all text from a prompt for analysis
    private func gatherText(from prompt: ToolPromptEvent) -> String {
        var parts: [String] = []

        if let title = prompt.title {
            parts.append(title)
        }

        if let body = prompt.body {
            parts.append(body)
        }

        for option in prompt.options {
            parts.append(option.label)
            if let desc = option.description {
                parts.append(desc)
            }
        }

        // Include tool name for additional context
        parts.append(prompt.toolName)

        return parts.joined(separator: " ")
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension PromptPolicyEvaluator {
    /// Create a test prompt for previews
    static func testPrompt(
        title: String = "Test Question",
        options: [ToolPromptOption] = []
    ) -> ToolPromptEvent {
        ToolPromptEvent(
            toolUseId: "test_\(UUID().uuidString)",
            toolName: "AskUserQuestion",
            title: title,
            body: nil,
            options: options,
            responseType: options.isEmpty ? .freeText : .singleSelect,
            rawInput: "{}",
            timestamp: Date()
        )
    }
}
#endif
