import Foundation

// MARK: - Migration Warning

/// A warning produced during hook migration.
/// Captures issues that don't block migration but require user attention.
public struct MigrationWarning: Sendable, Equatable, Identifiable {
    public var id: UUID

    /// Severity of the warning.
    public enum Severity: String, Sendable {
        case info       // FYI - no action needed
        case warning    // May affect behavior
        case error      // Hook will not work
    }

    public var severity: Severity

    /// The hook configuration that triggered this warning.
    public var hookId: UUID

    /// Human-readable description of the issue.
    public var message: String

    /// Suggested remediation (if any).
    public var suggestion: String?

    public init(
        id: UUID = UUID(),
        severity: Severity,
        hookId: UUID,
        message: String,
        suggestion: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.hookId = hookId
        self.message = message
        self.suggestion = suggestion
    }
}

// MARK: - Migration Report

/// Report produced by hook migration, including results and warnings.
public struct MigrationReport: Sendable {
    /// Source provider hooks were migrated from.
    public var sourceProvider: HookProvider

    /// Target provider hooks were migrated to.
    public var targetProvider: HookProvider

    /// Successfully migrated hooks.
    public var migratedHooks: [HookConfiguration]

    /// Hooks that could not be migrated (unsupported events, etc.).
    public var skippedHooks: [HookConfiguration]

    /// Warnings and notes from migration process.
    public var warnings: [MigrationWarning]

    /// Total hooks in input.
    public var totalInput: Int

    /// Hooks successfully migrated.
    public var successCount: Int { migratedHooks.count }

    /// Hooks skipped due to incompatibility.
    public var skippedCount: Int { skippedHooks.count }

    /// Whether all hooks were migrated without errors.
    public var isFullyMigrated: Bool {
        skippedHooks.isEmpty && !warnings.contains { $0.severity == .error }
    }

    public init(
        sourceProvider: HookProvider,
        targetProvider: HookProvider,
        migratedHooks: [HookConfiguration] = [],
        skippedHooks: [HookConfiguration] = [],
        warnings: [MigrationWarning] = [],
        totalInput: Int = 0
    ) {
        self.sourceProvider = sourceProvider
        self.targetProvider = targetProvider
        self.migratedHooks = migratedHooks
        self.skippedHooks = skippedHooks
        self.warnings = warnings
        self.totalInput = totalInput
    }

    /// Human-readable summary of the migration.
    public var summary: String {
        var lines: [String] = []
        lines.append("Migration: \(sourceProvider.displayName) → \(targetProvider.displayName)")
        lines.append("  Migrated: \(successCount)/\(totalInput) hooks")

        if skippedCount > 0 {
            lines.append("  Skipped: \(skippedCount) hooks (unsupported)")
        }

        let errorCount = warnings.filter { $0.severity == .error }.count
        let warnCount = warnings.filter { $0.severity == .warning }.count

        if errorCount > 0 {
            lines.append("  Errors: \(errorCount)")
        }
        if warnCount > 0 {
            lines.append("  Warnings: \(warnCount)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - HookMigrator

/// Migrates hook configurations between CLI providers.
///
/// Handles event name mapping, tool name translation, and capability
/// differences. Produces a migration report with warnings for any
/// hooks that couldn't be fully migrated.
///
/// **E005-F004-S001-T007-A001**
public struct HookMigrator: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Migrates hooks from one provider to another.
    ///
    /// - Parameters:
    ///   - hooks: The hook configurations to migrate.
    ///   - source: The source provider.
    ///   - target: The target provider.
    /// - Returns: Migration report with migrated hooks and warnings.
    public func migrate(
        hooks: [HookConfiguration],
        from source: HookProvider,
        to target: HookProvider
    ) -> MigrationReport {
        var report = MigrationReport(
            sourceProvider: source,
            targetProvider: target,
            totalInput: hooks.count
        )

        // Same provider = no-op
        if source == target {
            report.migratedHooks = hooks
            return report
        }

        let targetCapability = HookCapability.forProvider(target)

        // Check if target supports hooks at all
        if !target.supportsHooks {
            report.warnings.append(MigrationWarning(
                severity: .error,
                hookId: UUID(), // General warning
                message: "\(target.displayName) does not support hooks",
                suggestion: "Wait for hook support to be added to \(target.displayName)"
            ))
            report.skippedHooks = hooks
            return report
        }

        for hook in hooks {
            let migrationResult = migrateHook(
                hook,
                from: source,
                to: target,
                targetCapability: targetCapability
            )

            if let migratedHook = migrationResult.hook {
                report.migratedHooks.append(migratedHook)
            } else {
                report.skippedHooks.append(hook)
            }

            report.warnings.append(contentsOf: migrationResult.warnings)
        }

        return report
    }

    // MARK: - Private Helpers

    /// Result of migrating a single hook.
    private struct SingleMigrationResult {
        var hook: HookConfiguration?
        var warnings: [MigrationWarning]
    }

    /// Migrates a single hook configuration.
    private func migrateHook(
        _ hook: HookConfiguration,
        from source: HookProvider,
        to target: HookProvider,
        targetCapability: HookCapability
    ) -> SingleMigrationResult {
        var warnings: [MigrationWarning] = []

        // 1. Check if event type is supported in target
        guard targetCapability.supports(event: hook.eventType) else {
            warnings.append(MigrationWarning(
                severity: .error,
                hookId: hook.id,
                message: "Event '\(hook.eventType.displayName)' not supported in \(target.displayName)",
                suggestion: findAlternativeEvent(hook.eventType, in: target)
            ))
            return SingleMigrationResult(hook: nil, warnings: warnings)
        }

        // 2. Migrate matcher patterns
        let migratedMatcher = migrateMatcher(
            hook.matcher,
            from: source,
            to: target,
            hookId: hook.id,
            warnings: &warnings
        )

        // 3. Migrate hook commands
        let migratedCommands = migrateCommands(
            hook.hooks,
            from: source,
            to: target,
            hookId: hook.id,
            warnings: &warnings
        )

        // 4. Check for capability differences
        checkCapabilityDifferences(
            hook: hook,
            from: source,
            to: target,
            targetCapability: targetCapability,
            warnings: &warnings
        )

        // 5. Build migrated configuration
        let migratedHook = HookConfiguration(
            id: UUID(), // New ID for migrated hook
            eventType: hook.eventType,
            matcher: migratedMatcher,
            hooks: migratedCommands
        )

        return SingleMigrationResult(hook: migratedHook, warnings: warnings)
    }

    /// Migrates matcher patterns between providers.
    private func migrateMatcher(
        _ matcher: String?,
        from source: HookProvider,
        to target: HookProvider,
        hookId: UUID,
        warnings: inout [MigrationWarning]
    ) -> String? {
        guard let matcher = matcher else { return nil }

        var migratedMatcher = matcher

        // Translate tool names if different between providers
        migratedMatcher = translateToolNames(migratedMatcher, from: source, to: target)

        // Check for provider-specific syntax
        if containsProviderSpecificSyntax(matcher, provider: source) {
            warnings.append(MigrationWarning(
                severity: .warning,
                hookId: hookId,
                message: "Matcher contains \(source.displayName)-specific syntax",
                suggestion: "Review matcher pattern for \(target.displayName) compatibility"
            ))
        }

        return migratedMatcher
    }

    /// Migrates hook commands.
    private func migrateCommands(
        _ commands: [HookCommand],
        from source: HookProvider,
        to target: HookProvider,
        hookId: UUID,
        warnings: inout [MigrationWarning]
    ) -> [HookCommand] {
        return commands.map { command in
            var migratedCommand = HookCommand(
                id: UUID(),
                type: command.type,
                command: translateCommandPath(command.command, from: source, to: target),
                timeout: command.timeout
            )

            // Check for provider-specific paths in command
            if command.command.contains(source.configDirectoryName) {
                let newCommand = command.command.replacingOccurrences(
                    of: source.configDirectoryName,
                    with: target.configDirectoryName
                )
                migratedCommand = HookCommand(
                    id: UUID(),
                    type: command.type,
                    command: newCommand,
                    timeout: command.timeout
                )

                warnings.append(MigrationWarning(
                    severity: .info,
                    hookId: hookId,
                    message: "Updated config directory path: \(source.configDirectoryName) → \(target.configDirectoryName)"
                ))
            }

            return migratedCommand
        }
    }

    /// Checks for capability differences that may affect hook behavior.
    private func checkCapabilityDifferences(
        hook: HookConfiguration,
        from source: HookProvider,
        to target: HookProvider,
        targetCapability: HookCapability,
        warnings: inout [MigrationWarning]
    ) {
        let sourceCapability = HookCapability.forProvider(source)

        // Check if blocking was used but target doesn't support it
        if hook.eventType.canBlock && sourceCapability.supportsBlocking && !targetCapability.supportsBlocking {
            warnings.append(MigrationWarning(
                severity: .warning,
                hookId: hook.id,
                message: "\(target.displayName) does not support blocking hooks",
                suggestion: "Hook will run but cannot block tool execution"
            ))
        }

        // Check system message support
        if sourceCapability.supportsSystemMessage && !targetCapability.supportsSystemMessage {
            warnings.append(MigrationWarning(
                severity: .warning,
                hookId: hook.id,
                message: "\(target.displayName) does not support system message injection",
                suggestion: "Hook messages will not be shown to the agent"
            ))
        }

        // Check input modification support
        if sourceCapability.supportsInputModification && !targetCapability.supportsInputModification {
            warnings.append(MigrationWarning(
                severity: .warning,
                hookId: hook.id,
                message: "\(target.displayName) does not support input modification",
                suggestion: "Hook cannot modify tool inputs"
            ))
        }

        // Check hook limit
        if targetCapability.maxHooksPerEvent > 0 {
            warnings.append(MigrationWarning(
                severity: .info,
                hookId: hook.id,
                message: "\(target.displayName) limits hooks to \(targetCapability.maxHooksPerEvent) per event type"
            ))
        }
    }

    // MARK: - Tool Name Translation

    /// Known tool name mappings between providers.
    /// Format: [sourceProvider: [sourceTool: targetTool]]
    private static let toolNameMappings: [HookProvider: [HookProvider: [String: String]]] = [
        .claude: [
            .gemini: [
                "Bash": "shell",
                "Read": "read_file",
                "Write": "write_file",
                "Edit": "edit_file",
                "Glob": "list_files",
                "Grep": "search",
                "WebFetch": "web_fetch",
                "WebSearch": "web_search"
            ],
            .codex: [
                "Bash": "shell",
                "Read": "read",
                "Write": "write",
                "Edit": "patch"
            ]
        ],
        .gemini: [
            .claude: [
                "shell": "Bash",
                "read_file": "Read",
                "write_file": "Write",
                "edit_file": "Edit",
                "list_files": "Glob",
                "search": "Grep"
            ]
        ]
    ]

    /// Translates tool names in a matcher pattern.
    private func translateToolNames(
        _ matcher: String,
        from source: HookProvider,
        to target: HookProvider
    ) -> String {
        guard let providerMappings = Self.toolNameMappings[source],
              let targetMappings = providerMappings[target] else {
            return matcher
        }

        var result = matcher
        for (sourceTool, targetTool) in targetMappings {
            // Handle exact matches and patterns
            result = result.replacingOccurrences(of: sourceTool, with: targetTool)
        }
        return result
    }

    /// Translates command paths between providers.
    private func translateCommandPath(
        _ command: String,
        from source: HookProvider,
        to target: HookProvider
    ) -> String {
        // Replace CLAUDE_PROJECT_DIR-style vars if needed
        var result = command

        // Provider-specific env vars
        let envVarMappings: [HookProvider: String] = [
            .claude: "CLAUDE_PROJECT_DIR",
            .gemini: "GEMINI_PROJECT_DIR",
            .codex: "CODEX_PROJECT_DIR"
        ]

        if let sourceVar = envVarMappings[source],
           let targetVar = envVarMappings[target] {
            result = result.replacingOccurrences(of: "$\(sourceVar)", with: "$\(targetVar)")
            result = result.replacingOccurrences(of: "${\(sourceVar)}", with: "${\(targetVar)}")
        }

        return result
    }

    /// Checks if a matcher contains provider-specific syntax.
    private func containsProviderSpecificSyntax(_ matcher: String, provider: HookProvider) -> Bool {
        switch provider {
        case .claude:
            // Claude uses MCP tool patterns like "mcp__*"
            return matcher.contains("mcp__")
        case .gemini:
            // Gemini-specific patterns (placeholder for future)
            return false
        case .codex:
            // Codex-specific patterns (placeholder for future)
            return false
        }
    }

    /// Suggests an alternative event if the target doesn't support the source event.
    private func findAlternativeEvent(
        _ event: CLIHookEventType,
        in target: HookProvider
    ) -> String? {
        let targetCapability = HookCapability.forProvider(target)

        switch event {
        case .preCompact:
            if targetCapability.supports(event: .sessionStart) {
                return "Consider using 'Session Start' event for initialization"
            }
        case .notification:
            if targetCapability.supports(event: .stop) {
                return "Consider using 'Stop' event for end-of-turn notifications"
            }
        case .permissionRequest:
            if targetCapability.supports(event: .preToolUse) {
                return "Use 'Pre Tool Use' event with matcher for permission checks"
            }
        case .userPromptSubmit:
            if targetCapability.supports(event: .sessionStart) {
                return "Use 'Session Start' for prompt preprocessing"
            }
        default:
            break
        }

        return nil
    }
}
