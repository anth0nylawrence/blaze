import Foundation

// MARK: - Validation Severity

/// Severity level for validation issues.
/// **E005-F009-S002-T005-A001**
public enum ValidationSeverity: String, Codable, Sendable, Comparable {
    case error      // Blocking - hook will not work
    case warning    // Non-blocking but problematic
    case info       // Informational suggestions

    public static func < (lhs: ValidationSeverity, rhs: ValidationSeverity) -> Bool {
        let order: [ValidationSeverity] = [.info, .warning, .error]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Validation Issue

/// A single validation issue found during hook validation.
/// **E005-F009-S002-T005-A001**
public struct ValidationIssue: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let severity: ValidationSeverity
    public let code: String
    public let message: String
    public let suggestion: String?
    public let location: String?  // Line number or field name

    public init(
        id: UUID = UUID(),
        severity: ValidationSeverity,
        code: String,
        message: String,
        suggestion: String? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.code = code
        self.message = message
        self.suggestion = suggestion
        self.location = location
    }

    /// SF Symbol for this issue's severity.
    public var icon: String {
        switch severity {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    /// Color name for SwiftUI (use with Color(_:)).
    public var colorName: String {
        switch severity {
        case .error: return "red"
        case .warning: return "orange"
        case .info: return "blue"
        }
    }
}

// MARK: - Validation Result

/// Result of validating a hook configuration.
/// **E005-F009-S002-T005-A001**
public struct ValidationResult: Sendable {
    /// All issues found during validation.
    public let issues: [ValidationIssue]

    /// Whether the hook configuration is valid (no errors).
    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    /// Filter issues by severity.
    public var errors: [ValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var infos: [ValidationIssue] {
        issues.filter { $0.severity == .info }
    }

    /// Create a successful validation result.
    public static let success = ValidationResult(issues: [])

    /// Create a result with a single error.
    public static func error(_ code: String, _ message: String, suggestion: String? = nil) -> ValidationResult {
        ValidationResult(issues: [
            ValidationIssue(severity: .error, code: code, message: message, suggestion: suggestion)
        ])
    }

    /// Create a result with a single warning.
    public static func warning(_ code: String, _ message: String, suggestion: String? = nil) -> ValidationResult {
        ValidationResult(issues: [
            ValidationIssue(severity: .warning, code: code, message: message, suggestion: suggestion)
        ])
    }

    /// Merge multiple validation results.
    public static func merge(_ results: [ValidationResult]) -> ValidationResult {
        ValidationResult(issues: results.flatMap { $0.issues })
    }

    /// Add an issue to the result.
    public func adding(_ issue: ValidationIssue) -> ValidationResult {
        ValidationResult(issues: issues + [issue])
    }
}

// MARK: - HookValidator Actor

/// Actor for comprehensive hook validation.
///
/// Validates hook configurations including:
/// - Structure (name, type, matcher, content)
/// - Script syntax (basic checks for shell/python)
/// - Dangerous command patterns
/// - Template variable usage
///
/// **E005-F009-S002-T005-A001**
public actor HookValidator {

    // MARK: - Dangerous Patterns

    /// Patterns that indicate dangerous shell commands.
    private static let dangerousShellPatterns: [(pattern: String, description: String, severity: ValidationSeverity)] = [
        // Catastrophic data loss
        ("rm\\s+-rf\\s+/(?!\\w)", "Recursive delete from root", .error),
        ("rm\\s+-rf\\s+~", "Recursive delete from home directory", .error),
        ("rm\\s+-rf\\s+\\*", "Recursive delete with wildcard", .error),
        ("rm\\s+-rf\\s+\\$\\{?HOME\\}?", "Recursive delete from $HOME", .error),

        // System destruction
        ("mkfs\\.", "Filesystem formatting", .error),
        ("dd\\s+if=.*of=/dev/", "Direct disk write", .error),
        (">\\s*/dev/sd", "Overwriting disk device", .error),
        (">\\s*/dev/nvme", "Overwriting NVMe device", .error),

        // Fork bomb
        (":\\(\\)\\{\\s*:\\|:\\&\\s*\\};:", "Fork bomb pattern", .error),

        // Dangerous git operations
        ("git\\s+reset\\s+--hard", "Destructive git reset", .warning),
        ("git\\s+clean\\s+-fd", "Force clean untracked files", .warning),
        ("git\\s+push.*--force", "Force push to remote", .warning),
        ("git\\s+push.*-f\\b", "Force push to remote", .warning),

        // Privilege escalation
        ("sudo\\s+rm", "Sudo delete operations", .warning),
        ("sudo\\s+chmod", "Sudo permission changes", .warning),
        ("sudo\\s+chown", "Sudo ownership changes", .warning),

        // Sensitive file access
        ("chmod\\s+-R\\s+777", "Overly permissive chmod", .warning),
        ("chmod\\s+777\\s+/", "Overly permissive root chmod", .error),

        // Credential exposure
        ("curl.*\\$\\{?.*TOKEN", "Potential token in URL", .warning),
        ("wget.*\\$\\{?.*TOKEN", "Potential token in URL", .warning),
        ("echo.*password", "Password in echo (may leak to logs)", .info),

        // Network dangers
        ("curl.*\\|\\s*bash", "Pipe curl to bash", .warning),
        ("wget.*\\|\\s*bash", "Pipe wget to bash", .warning),
        ("curl.*\\|\\s*sh", "Pipe curl to shell", .warning),
    ]

    /// Patterns that indicate issues in Python scripts.
    private static let dangerousPythonPatterns: [(pattern: String, description: String, severity: ValidationSeverity)] = [
        ("os\\.system\\s*\\(", "os.system is unsafe; use subprocess", .warning),
        ("eval\\s*\\(", "eval() is dangerous with untrusted input", .warning),
        ("exec\\s*\\(", "exec() is dangerous with untrusted input", .warning),
        ("__import__\\s*\\(", "Dynamic imports can be unsafe", .info),
        ("subprocess\\..*shell\\s*=\\s*True", "shell=True in subprocess", .warning),
        ("pickle\\.load", "Pickle can execute arbitrary code", .warning),
        ("shutil\\.rmtree\\s*\\(['\"]?/", "rmtree on root-relative path", .warning),
    ]

    /// Patterns that indicate issues in Node.js scripts.
    private static let dangerousNodePatterns: [(pattern: String, description: String, severity: ValidationSeverity)] = [
        ("eval\\s*\\(", "eval() is dangerous with untrusted input", .warning),
        ("Function\\s*\\(", "Dynamic Function() can execute arbitrary code", .warning),
        ("child_process.*exec\\s*\\(", "exec() with unsanitized input is unsafe", .info),
        ("require\\s*\\(\\s*[^'\"]", "Dynamic require can be unsafe", .info),
    ]

    // MARK: - Known Template Variables

    /// Known template variables for validation.
    private static let knownTemplateVariables: Set<String> = [
        // From HookTemplateVariables
        "TOOL_NAME", "TOOL_INPUT", "TOOL_OUTPUT", "FILE_PATH",
        "SESSION_ID", "PROJECT_PATH", "TIMESTAMP", "DURATION_MS",
        "LOG_FILE", "MESSAGE", "WEBHOOK_URL", "NOTIFICATION_TITLE",
        // From HookType.templateVariables
        "TOOL_RESULT", "USER_PROMPT", "TRANSCRIPT_PATH",
        "CLAUDE_PROJECT_DIR", "CLAUDE_PLUGIN_ROOT", "CLAUDE_ENV_FILE", "CLAUDE_CODE_REMOTE",
        // Common environment variables that are valid
        "HOME", "USER", "PATH", "PWD", "SHELL", "TERM",
        // Custom user variables (allow any BLAZE_ prefix)
        // Validated separately
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Main Validation Entry Points

    /// Validate a HookDefinition.
    public func validate(_ hook: HookDefinition) async -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Structure validation
        issues.append(contentsOf: validateStructure(hook))

        // Content/script validation based on type
        switch hook.type {
        case .command:
            issues.append(contentsOf: validateShellScript(hook.content))
        case .prompt:
            issues.append(contentsOf: validatePromptContent(hook.content))
        case .agent:
            issues.append(contentsOf: validateAgentConfig(hook.content))
        }

        // Template variable validation
        issues.append(contentsOf: validateTemplateVariables(hook.content, hookType: hook.type))

        // Matcher validation
        if let matcher = hook.matcher {
            issues.append(contentsOf: validateMatcher(matcher))
        }

        return ValidationResult(issues: issues)
    }

    /// Validate a HookTemplate.
    public func validate(_ template: HookTemplate) async -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Basic structure
        if template.id.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "TMPL_EMPTY_ID",
                message: "Template ID cannot be empty"
            ))
        }

        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "TMPL_EMPTY_NAME",
                message: "Template name cannot be empty"
            ))
        }

        // Validate code template based on script type
        switch template.scriptType {
        case .shell:
            issues.append(contentsOf: validateShellScript(template.codeTemplate))
        case .python:
            issues.append(contentsOf: validatePythonScript(template.codeTemplate))
        case .node:
            issues.append(contentsOf: validateNodeScript(template.codeTemplate))
        case .applescript:
            issues.append(contentsOf: validateAppleScript(template.codeTemplate))
        }

        // Validate template variables are defined
        let usedVars = extractTemplateVariables(template.codeTemplate)
        let declaredVarNames = Set(template.variables.map { $0.name })

        for varName in usedVars {
            if !declaredVarNames.contains(varName) && !Self.knownTemplateVariables.contains(varName) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "TMPL_UNDECLARED_VAR",
                    message: "Template uses undeclared variable: $\(varName)",
                    suggestion: "Add \(varName) to the template's variables array"
                ))
            }
        }

        // Event type consistency
        if template.supportedEventTypes.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "TMPL_NO_EVENTS",
                message: "Template must support at least one event type"
            ))
        }

        if !template.supportedEventTypes.contains(template.defaultEventType) {
            issues.append(ValidationIssue(
                severity: .error,
                code: "TMPL_DEFAULT_NOT_SUPPORTED",
                message: "Default event type is not in supported event types"
            ))
        }

        return ValidationResult(issues: issues)
    }

    /// Validate a Hook (from HookStore).
    public func validate(_ hook: Hook) async -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Name validation
        if hook.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "HOOK_EMPTY_NAME",
                message: "Hook name cannot be empty"
            ))
        }

        // Script validation if inline
        if let script = hook.inlineScript {
            switch hook.scriptType {
            case .shell:
                issues.append(contentsOf: validateShellScript(script))
            case .python:
                issues.append(contentsOf: validatePythonScript(script))
            case .node:
                issues.append(contentsOf: validateNodeScript(script))
            case .applescript:
                issues.append(contentsOf: validateAppleScript(script))
            }

            issues.append(contentsOf: validateTemplateVariables(script, scriptType: hook.scriptType))
        } else if let scriptPath = hook.scriptPath {
            // Validate script path exists (quick check)
            issues.append(contentsOf: validateScriptPath(scriptPath))
        } else {
            issues.append(ValidationIssue(
                severity: .error,
                code: "HOOK_NO_SCRIPT",
                message: "Hook must have either inline script or script path"
            ))
        }

        // Timeout validation
        if hook.timeoutMs <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                code: "HOOK_INVALID_TIMEOUT",
                message: "Timeout must be positive (got \(hook.timeoutMs)ms)"
            ))
        } else if hook.timeoutMs > 300_000 {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "HOOK_LONG_TIMEOUT",
                message: "Timeout of \(hook.timeoutMs / 1000)s may be too long",
                suggestion: "Consider a timeout under 60s for most hooks"
            ))
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - Static Quick Validation Methods

    /// Quick validation of a shell command (synchronous).
    public static func validateCommand(_ command: String) -> ValidationResult {
        var issues: [ValidationIssue] = []

        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .error("EMPTY_COMMAND", "Command cannot be empty")
        }

        // Check dangerous patterns
        for (pattern, description, severity) in dangerousShellPatterns {
            if let _ = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                .firstMatch(in: command, range: NSRange(command.startIndex..., in: command)) {
                issues.append(ValidationIssue(
                    severity: severity,
                    code: "DANGEROUS_PATTERN",
                    message: "Dangerous pattern detected: \(description)"
                ))
            }
        }

        return ValidationResult(issues: issues)
    }

    /// Quick validation of a template variable name.
    public static func validateVariableName(_ name: String) -> ValidationResult {
        // Variable names should be UPPER_SNAKE_CASE
        let validPattern = "^[A-Z][A-Z0-9_]*$"
        guard let regex = try? NSRegularExpression(pattern: validPattern),
              regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil else {
            return .warning(
                "INVALID_VAR_NAME",
                "Variable name '\(name)' should be UPPER_SNAKE_CASE",
                suggestion: "Use format like MY_VARIABLE_NAME"
            )
        }

        // Check if it's a known variable
        if !knownTemplateVariables.contains(name) && !name.hasPrefix("BLAZE_") {
            return .warning(
                "UNKNOWN_VAR",
                "Unknown variable: $\(name)",
                suggestion: "Ensure this variable is set in the hook environment"
            )
        }

        return .success
    }

    /// Quick check if a pattern matches dangerous commands.
    public static func isDangerous(_ content: String) -> Bool {
        for (pattern, _, severity) in dangerousShellPatterns {
            if severity == .error,
               let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Private Validation Methods

    /// Validate hook structure (name, type, matcher, content).
    private func validateStructure(_ hook: HookDefinition) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Name validation
        let trimmedName = hook.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "HOOK_EMPTY_NAME",
                message: "Hook name cannot be empty"
            ))
        } else if trimmedName.count < 3 {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "HOOK_SHORT_NAME",
                message: "Hook name is very short",
                suggestion: "Use a descriptive name for easier identification"
            ))
        }

        // Content validation
        let trimmedContent = hook.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "HOOK_EMPTY_CONTENT",
                message: "\(hook.type.displayName) content cannot be empty"
            ))
        }

        // Timeout validation
        if let timeout = hook.timeout {
            if timeout <= 0 {
                issues.append(ValidationIssue(
                    severity: .error,
                    code: "HOOK_INVALID_TIMEOUT",
                    message: "Timeout must be positive (got \(timeout)s)"
                ))
            } else if timeout > 300 {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "HOOK_LONG_TIMEOUT",
                    message: "Timeout of \(Int(timeout))s may be too long",
                    suggestion: "Consider a timeout under 60s for most hooks"
                ))
            }
        }

        return issues
    }

    /// Validate shell script syntax and patterns.
    private func validateShellScript(_ script: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for shebang (recommended)
        if !script.hasPrefix("#!") && !script.hasPrefix("#!/") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "SHELL_NO_SHEBANG",
                message: "Script lacks shebang line",
                suggestion: "Add #!/bin/bash at the start for portability"
            ))
        }

        // Check for common shell syntax issues
        let lines = script.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lineNum = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Unclosed quotes (basic check)
            let singleQuotes = trimmedLine.filter { $0 == "'" }.count
            let doubleQuotes = trimmedLine.filter { $0 == "\"" }.count
            if singleQuotes % 2 != 0 && !trimmedLine.contains("'\"'") {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "SHELL_UNCLOSED_QUOTE",
                    message: "Possible unclosed single quote",
                    location: "line \(lineNum)"
                ))
            }
            if doubleQuotes % 2 != 0 && !trimmedLine.contains("\"'\"") {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "SHELL_UNCLOSED_QUOTE",
                    message: "Possible unclosed double quote",
                    location: "line \(lineNum)"
                ))
            }

            // Missing space after [ in conditionals
            if trimmedLine.contains("[") && !trimmedLine.contains("[ ") && !trimmedLine.contains("[[") {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "SHELL_BRACKET_SPACE",
                    message: "Missing space after '[' in conditional",
                    suggestion: "Use [ condition ] with spaces",
                    location: "line \(lineNum)"
                ))
            }
        }

        // Check dangerous patterns
        for (pattern, description, severity) in Self.dangerousShellPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)) != nil {
                issues.append(ValidationIssue(
                    severity: severity,
                    code: "SHELL_DANGEROUS",
                    message: "Dangerous pattern: \(description)"
                ))
            }
        }

        // Check for required JSON output
        if !script.contains("echo") || (!script.contains("result") && !script.contains("\"result\"")) {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "SHELL_NO_JSON_OUTPUT",
                message: "Hook may not return required JSON output",
                suggestion: "Ensure script outputs {\"result\": \"continue\"} or {\"result\": \"block\"}"
            ))
        }

        return issues
    }

    /// Validate Python script syntax and patterns.
    private func validatePythonScript(_ script: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for shebang
        if !script.hasPrefix("#!") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "PYTHON_NO_SHEBANG",
                message: "Script lacks shebang line",
                suggestion: "Add #!/usr/bin/env python3 at the start"
            ))
        }

        // Check for json import (usually needed for hooks)
        if !script.contains("import json") && !script.contains("from json") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "PYTHON_NO_JSON_IMPORT",
                message: "Script may need json module for hook I/O",
                suggestion: "Add 'import json' for parsing input and formatting output"
            ))
        }

        // Check dangerous patterns
        for (pattern, description, severity) in Self.dangerousPythonPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)) != nil {
                issues.append(ValidationIssue(
                    severity: severity,
                    code: "PYTHON_DANGEROUS",
                    message: description
                ))
            }
        }

        // Basic indentation check (Python-specific)
        let lines = script.components(separatedBy: .newlines)
        var prevIndent = 0
        for (index, line) in lines.enumerated() {
            let lineNum = index + 1
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.hasPrefix("#") {
                continue
            }

            let currentIndent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            // Tab/space mixing
            let hasTab = line.prefix(while: { $0.isWhitespace }).contains("\t")
            let hasSpace = line.prefix(while: { $0.isWhitespace }).contains(" ")
            if hasTab && hasSpace {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "PYTHON_MIXED_INDENT",
                    message: "Mixed tabs and spaces in indentation",
                    suggestion: "Use consistent indentation (4 spaces recommended)",
                    location: "line \(lineNum)"
                ))
            }

            // Large indentation jumps (possible error)
            if currentIndent > prevIndent + 8 && currentIndent > 0 {
                issues.append(ValidationIssue(
                    severity: .info,
                    code: "PYTHON_INDENT_JUMP",
                    message: "Large indentation jump",
                    location: "line \(lineNum)"
                ))
            }

            if currentIndent > 0 {
                prevIndent = currentIndent
            }
        }

        return issues
    }

    /// Validate Node.js script syntax and patterns.
    private func validateNodeScript(_ script: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for shebang
        if !script.hasPrefix("#!") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "NODE_NO_SHEBANG",
                message: "Script lacks shebang line",
                suggestion: "Add #!/usr/bin/env node at the start"
            ))
        }

        // Check dangerous patterns
        for (pattern, description, severity) in Self.dangerousNodePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)) != nil {
                issues.append(ValidationIssue(
                    severity: severity,
                    code: "NODE_DANGEROUS",
                    message: description
                ))
            }
        }

        // Check for async handling
        if script.contains("async") && !script.contains("await") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "NODE_ASYNC_NO_AWAIT",
                message: "Async function without await",
                suggestion: "Ensure async operations are properly awaited"
            ))
        }

        // Check for error handling
        if !script.contains("catch") && !script.contains("try") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "NODE_NO_ERROR_HANDLING",
                message: "Script lacks error handling",
                suggestion: "Add try/catch to handle potential errors gracefully"
            ))
        }

        return issues
    }

    /// Validate AppleScript (basic checks).
    private func validateAppleScript(_ script: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // AppleScript should not start with shebang when inline
        if script.hasPrefix("#!/") && !script.contains("osascript") {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "APPLESCRIPT_WRONG_SHEBANG",
                message: "AppleScript should not have a bash shebang",
                suggestion: "Remove shebang or use #!/usr/bin/osascript"
            ))
        }

        // Check for shell injection via do shell script
        if script.contains("do shell script") {
            // Check if it's using untrusted input
            if script.contains("\" & ") || script.contains("& \"") {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "APPLESCRIPT_SHELL_INJECTION",
                    message: "String concatenation in 'do shell script' may allow injection",
                    suggestion: "Use quoted form or validate inputs"
                ))
            }
        }

        return issues
    }

    /// Validate prompt content.
    private func validatePromptContent(_ content: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if content.count < 5 {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "PROMPT_TOO_SHORT",
                message: "Prompt is very short (\(content.count) chars)",
                suggestion: "Prompts should provide meaningful context"
            ))
        }

        if content.count > 10_000 {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "PROMPT_TOO_LONG",
                message: "Prompt is very long (\(content.count) chars)",
                suggestion: "Consider breaking into smaller prompts"
            ))
        }

        return issues
    }

    /// Validate agent configuration.
    private func validateAgentConfig(_ config: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if config.count < 2 {
            issues.append(ValidationIssue(
                severity: .error,
                code: "AGENT_CONFIG_SHORT",
                message: "Agent identifier is too short"
            ))
        }

        // Agent IDs should be alphanumeric with dashes/underscores
        let validAgentPattern = "^[a-zA-Z][a-zA-Z0-9_-]*$"
        if let regex = try? NSRegularExpression(pattern: validAgentPattern),
           regex.firstMatch(in: config, range: NSRange(config.startIndex..., in: config)) == nil {
            // Might be a prompt instead of agent ID - that's ok
            if config.count < 20 {
                issues.append(ValidationIssue(
                    severity: .info,
                    code: "AGENT_ID_FORMAT",
                    message: "Agent identifier may have unusual format",
                    suggestion: "Use alphanumeric identifiers like 'my-agent' or 'claude_reviewer'"
                ))
            }
        }

        return issues
    }

    /// Validate template variables in content.
    private func validateTemplateVariables(_ content: String, hookType: HookType) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let usedVars = extractTemplateVariables(content)
        let availableVars = Set(hookType.templateVariables.map {
            $0.name.hasPrefix("$") ? String($0.name.dropFirst()) : $0.name
        })

        for varName in usedVars {
            if !Self.knownTemplateVariables.contains(varName) &&
               !availableVars.contains(varName) &&
               !varName.hasPrefix("BLAZE_") {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "UNKNOWN_TEMPLATE_VAR",
                    message: "Unknown template variable: $\(varName)",
                    suggestion: "Ensure this variable is available for \(hookType.displayName) hooks"
                ))
            }
        }

        return issues
    }

    /// Validate template variables in content (by script type).
    private func validateTemplateVariables(_ content: String, scriptType: HookScriptType) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let usedVars = extractTemplateVariables(content)

        for varName in usedVars {
            if !Self.knownTemplateVariables.contains(varName) && !varName.hasPrefix("BLAZE_") {
                issues.append(ValidationIssue(
                    severity: .info,
                    code: "CUSTOM_VAR",
                    message: "Custom variable: $\(varName)",
                    suggestion: "Ensure this variable is set in the hook environment"
                ))
            }
        }

        return issues
    }

    /// Validate matcher pattern.
    private func validateMatcher(_ matcher: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let trimmed = matcher.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "MATCHER_EMPTY",
                message: "Matcher pattern cannot be empty if provided"
            ))
            return issues
        }

        // Check for valid glob patterns
        if trimmed.contains("*") || trimmed.contains("?") {
            // Ensure not just wildcards
            if trimmed == "*" || trimmed == "**" {
                issues.append(ValidationIssue(
                    severity: .info,
                    code: "MATCHER_WILDCARD_ONLY",
                    message: "Matcher matches all events",
                    suggestion: "Use a more specific pattern if only certain tools should trigger"
                ))
            }
        }

        // Check for regex-like patterns that might be mistakes
        if trimmed.contains(".*") && !trimmed.contains("**") {
            issues.append(ValidationIssue(
                severity: .info,
                code: "MATCHER_REGEX_LIKE",
                message: "Pattern looks like regex; matchers use glob syntax",
                suggestion: "Use '*' for wildcards, '**' for recursive matching"
            ))
        }

        return issues
    }

    /// Validate script path exists and is readable.
    private func validateScriptPath(_ path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Can't do full file system check in actor context synchronously,
        // but we can do basic path validation
        if path.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                code: "SCRIPT_PATH_EMPTY",
                message: "Script path cannot be empty"
            ))
        } else if !path.hasPrefix("/") && !path.hasPrefix("~") && !path.hasPrefix("$") {
            issues.append(ValidationIssue(
                severity: .warning,
                code: "SCRIPT_PATH_RELATIVE",
                message: "Script path is relative",
                suggestion: "Use absolute path or $CLAUDE_PROJECT_DIR prefix"
            ))
        }

        // Check for suspicious paths
        let suspiciousPaths = ["/tmp/", "/var/tmp/", "/dev/"]
        for suspicious in suspiciousPaths {
            if path.hasPrefix(suspicious) {
                issues.append(ValidationIssue(
                    severity: .info,
                    code: "SCRIPT_PATH_SUSPICIOUS",
                    message: "Script in temporary/system directory",
                    suggestion: "Consider storing scripts in project directory"
                ))
                break
            }
        }

        return issues
    }

    /// Extract template variable names from content.
    private func extractTemplateVariables(_ content: String) -> Set<String> {
        var variables = Set<String>()

        // Match $VARIABLE_NAME and ${VARIABLE_NAME}
        let patterns = [
            "\\$\\{([A-Z][A-Z0-9_]*)\\}",  // ${VAR}
            "\\$([A-Z][A-Z0-9_]*)\\b"       // $VAR
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        variables.insert(String(content[range]))
                    }
                }
            }
        }

        return variables
    }
}

// MARK: - Hook Extension for Validation

extension Hook {
    /// Validate this hook using HookValidator.
    public func validateAsync() async -> ValidationResult {
        let validator = HookValidator()
        return await validator.validate(self)
    }
}

extension HookDefinition {
    /// Validate this hook definition using HookValidator.
    public func validateAsync() async -> ValidationResult {
        let validator = HookValidator()
        return await validator.validate(self)
    }
}

extension HookTemplate {
    /// Validate this template using HookValidator.
    public func validateAsync() async -> ValidationResult {
        let validator = HookValidator()
        return await validator.validate(self)
    }
}
