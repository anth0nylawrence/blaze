import Foundation

// MARK: - Hook Output Schema
//
// E005-F009-S001-T004-A001: Structures for hook output/response data.
//
// These types model the JSON output from CLI hooks (Claude Code, Gemini CLI, etc.).
// Hooks return JSON via stdout which is parsed into these structures.

// MARK: - Hook Result

/// The result action returned by a hook.
///
/// Hooks can either continue (allow the operation) or block (deny the operation).
/// This maps directly to Claude Code's hook output `result` field.
public enum HookResult: String, Codable, Sendable, Equatable {
    /// Allow the operation to proceed.
    case `continue` = "continue"

    /// Block/deny the operation.
    case block = "block"

    /// Human-readable description.
    public var displayName: String {
        switch self {
        case .continue: return "Continue"
        case .block: return "Block"
        }
    }

    /// Whether this result allows the operation to proceed.
    public var allowsExecution: Bool {
        self == .continue
    }
}

// MARK: - Permission Decision

/// Permission decision for permission request hooks.
///
/// Maps to Claude Code's `permissionDecision` output field.
/// Used when hooks need to make authorization decisions.
public enum HookPermissionDecision: String, Codable, Sendable, Equatable {
    /// Allow the action without user interaction.
    case allow = "allow"

    /// Deny the action without user interaction.
    case deny = "deny"

    /// Prompt the user for a decision.
    case ask = "ask"

    /// Human-readable description.
    public var displayName: String {
        switch self {
        case .allow: return "Allow"
        case .deny: return "Deny"
        case .ask: return "Ask User"
        }
    }

    /// Whether this decision auto-resolves (doesn't require user input).
    public var autoResolves: Bool {
        self != .ask
    }

    /// Whether the action is permitted (for auto-resolved decisions).
    public var isPermitted: Bool? {
        switch self {
        case .allow: return true
        case .deny: return false
        case .ask: return nil  // Needs user input
        }
    }
}

// MARK: - Hook Output

/// The complete output structure from a CLI hook.
///
/// Hooks return JSON via stdout that is parsed into this structure.
/// All fields except `result` are optional.
///
/// **JSON Example (PreToolUse blocking):**
/// ```json
/// {
///   "result": "block",
///   "reason": "Dangerous command detected",
///   "message": "This command would delete system files"
/// }
/// ```
///
/// **JSON Example (PermissionRequest with decision):**
/// ```json
/// {
///   "result": "continue",
///   "permissionDecision": "allow",
///   "message": "Auto-approved based on allowlist"
/// }
/// ```
public struct HookOutput: Codable, Sendable {
    // MARK: - Required Fields

    /// The result action (continue or block).
    public var result: HookResult

    // MARK: - Optional Fields

    /// Human-readable reason for blocking (used when result == .block).
    public var reason: String?

    /// System message to inject into the conversation context.
    /// Displayed to the AI as additional context.
    public var message: String?

    /// Permission decision for PermissionRequest events.
    public var permissionDecision: HookPermissionDecision?

    /// Modified tool input (for PreToolUse hooks that want to transform input).
    /// The structure depends on the tool being called.
    /// Uses `AnyCodable` from NDJSONParser for type-erased JSON values.
    public var updatedInput: AnyCodable?

    /// Modified user prompt (for UserPromptSubmit hooks).
    public var updatedPrompt: String?

    // MARK: - Initializers

    /// Create a hook output with the given result.
    public init(
        result: HookResult,
        reason: String? = nil,
        message: String? = nil,
        permissionDecision: HookPermissionDecision? = nil,
        updatedInput: AnyCodable? = nil,
        updatedPrompt: String? = nil
    ) {
        self.result = result
        self.reason = reason
        self.message = message
        self.permissionDecision = permissionDecision
        self.updatedInput = updatedInput
        self.updatedPrompt = updatedPrompt
    }

    // MARK: - Factory Methods

    /// Create a "continue" output (allow the operation).
    public static func `continue`(message: String? = nil) -> HookOutput {
        HookOutput(result: .continue, message: message)
    }

    /// Create a "block" output (deny the operation).
    public static func block(reason: String, message: String? = nil) -> HookOutput {
        HookOutput(result: .block, reason: reason, message: message)
    }

    /// Create a permission decision output.
    public static func permission(
        _ decision: HookPermissionDecision,
        message: String? = nil
    ) -> HookOutput {
        HookOutput(
            result: decision == .deny ? .block : .continue,
            message: message,
            permissionDecision: decision
        )
    }

    /// Create an output with modified tool input.
    public static func modifyInput(_ input: Any, message: String? = nil) -> HookOutput {
        HookOutput(
            result: .continue,
            message: message,
            updatedInput: AnyCodable(input)
        )
    }

    /// Create an output with modified user prompt.
    public static func modifyPrompt(_ prompt: String, message: String? = nil) -> HookOutput {
        HookOutput(
            result: .continue,
            message: message,
            updatedPrompt: prompt
        )
    }

    // MARK: - Computed Properties

    /// Whether this output blocks the operation.
    public var isBlocking: Bool {
        result == .block
    }

    /// Whether this output modifies the input.
    public var modifiesInput: Bool {
        updatedInput != nil || updatedPrompt != nil
    }

    /// Whether this output has a system message.
    public var hasMessage: Bool {
        message != nil && !message!.isEmpty
    }
}

// MARK: - Hook Output Equatable

extension HookOutput: Equatable {
    public static func == (lhs: HookOutput, rhs: HookOutput) -> Bool {
        // Compare simple fields directly
        guard lhs.result == rhs.result,
              lhs.reason == rhs.reason,
              lhs.message == rhs.message,
              lhs.permissionDecision == rhs.permissionDecision,
              lhs.updatedPrompt == rhs.updatedPrompt else {
            return false
        }

        // Compare AnyCodable values by encoding to JSON
        switch (lhs.updatedInput, rhs.updatedInput) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        case let (l?, r?):
            // Compare by JSON encoding since AnyCodable doesn't conform to Equatable
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            guard let lData = try? encoder.encode(l),
                  let rData = try? encoder.encode(r) else {
                return false
            }
            return lData == rData
        }
    }
}

// MARK: - Hook Output Validation

extension HookOutput {
    /// Validation errors for hook output.
    public enum ValidationError: Error, LocalizedError {
        case missingResult
        case blockWithoutReason
        case permissionDecisionMismatch
        case invalidJSON(String)

        public var errorDescription: String? {
            switch self {
            case .missingResult:
                return "Hook output missing required 'result' field"
            case .blockWithoutReason:
                return "Block result should include a 'reason' field"
            case .permissionDecisionMismatch:
                return "Permission decision conflicts with result"
            case .invalidJSON(let details):
                return "Invalid hook output JSON: \(details)"
            }
        }
    }

    /// Validate the hook output for consistency.
    /// - Throws: ValidationError if the output is invalid.
    public func validate() throws {
        // Block results should have a reason
        if result == .block && (reason == nil || reason!.isEmpty) {
            // This is a warning, not an error - some hooks may not provide reasons
        }

        // Permission decision should match result
        if let decision = permissionDecision {
            let expectedResult: HookResult = decision == .deny ? .block : .continue
            if result != expectedResult && decision != .ask {
                throw ValidationError.permissionDecisionMismatch
            }
        }
    }

    /// Attempt validation and return warnings instead of throwing.
    public func warnings() -> [String] {
        var warnings: [String] = []

        if result == .block && (reason == nil || reason!.isEmpty) {
            warnings.append("Block result without reason - consider adding a reason for debugging")
        }

        if let decision = permissionDecision {
            let expectedResult: HookResult = decision == .deny ? .block : .continue
            if result != expectedResult && decision != .ask {
                warnings.append("Permission decision '\(decision.rawValue)' doesn't match result '\(result.rawValue)'")
            }
        }

        return warnings
    }
}

// MARK: - Hook Output Parsing

extension HookOutput {
    /// Parse hook output from JSON string (stdout from hook process).
    /// - Parameter json: The JSON string from hook stdout.
    /// - Returns: Parsed HookOutput.
    /// - Throws: ValidationError.invalidJSON if parsing fails.
    public static func parse(from json: String) throws -> HookOutput {
        guard let data = json.data(using: .utf8) else {
            throw ValidationError.invalidJSON("Invalid UTF-8 encoding")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(HookOutput.self, from: data)
        } catch let decodingError as DecodingError {
            throw ValidationError.invalidJSON(decodingError.localizedDescription)
        } catch {
            throw ValidationError.invalidJSON(error.localizedDescription)
        }
    }

    /// Parse hook output from Data.
    /// - Parameter data: The JSON data from hook stdout.
    /// - Returns: Parsed HookOutput.
    /// - Throws: ValidationError.invalidJSON if parsing fails.
    public static func parse(from data: Data) throws -> HookOutput {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(HookOutput.self, from: data)
        } catch let decodingError as DecodingError {
            throw ValidationError.invalidJSON(decodingError.localizedDescription)
        } catch {
            throw ValidationError.invalidJSON(error.localizedDescription)
        }
    }

    /// Try to parse hook output, returning a default continue on failure.
    /// Useful for graceful degradation when hooks produce invalid output.
    /// - Parameter json: The JSON string from hook stdout.
    /// - Returns: Parsed HookOutput or default continue.
    public static func parseOrContinue(from json: String) -> HookOutput {
        do {
            return try parse(from: json)
        } catch {
            // Log the error but don't block - graceful degradation
            return .continue(message: "Hook output parsing failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - JSON Encoding

extension HookOutput {
    /// Encode the hook output to JSON string.
    /// - Returns: JSON string representation.
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Encode the hook output to compact JSON string (no whitespace).
    /// - Returns: Compact JSON string representation.
    public func toCompactJSON() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
