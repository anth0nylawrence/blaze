//
//  SecuritySettings.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

// MARK: - Security Settings Model

/// Central model for security settings that integrates with CLI behavior.
///
/// This model bridges the gap between UI settings and Claude Code CLI flags.
/// Settings are persisted via `@AppStorage` in the view layer, but the model
/// provides the logic for mapping UI choices to actual CLI invocation.
///
/// ## CLI Flag Mapping
///
/// | Trust Mode   | Claude Code CLI Behavior                                  |
/// |--------------|-----------------------------------------------------------|
/// | Review       | Default behavior - prompts for all tool confirmations     |
/// | Trusted      | `--allowedTools <list>` - auto-allow trusted tools        |
/// | YOLO         | `--dangerously-skip-permissions` - skips all prompts      |
/// | Sandbox      | Read-only tools only (enforced by Blaze, not CLI)         |
///
/// ## Usage
/// ```swift
/// let settings = SecuritySettings.load()
/// let flags = settings.cliFlags
/// // Use flags when spawning Claude CLI
/// ```
public struct SecuritySettings: Codable, Sendable {

    // MARK: - Properties

    /// Current trust mode (maps to TrustMode enum in Models.swift)
    public var trustMode: SecurityTrustMode

    /// Tools that have been granted trust (for Trusted mode "ask once" behavior)
    /// When a tool is granted, it's added here and future invocations auto-approve.
    public var trustedTools: Set<String>

    /// Commands allowed to run without confirmation (command name -> permission)
    public var commandAllowlist: [String: CommandPermissionLevel]

    /// File patterns to auto-approve for read/write operations
    public var autoApprovePatterns: [String]

    /// Whether to require confirmation for network requests
    public var requireNetworkConfirmation: Bool

    /// Whether to require confirmation for process spawning
    public var requireProcessConfirmation: Bool

    // MARK: - Defaults

    public static let `default` = SecuritySettings(
        trustMode: .review,
        trustedTools: [],
        commandAllowlist: [:],
        autoApprovePatterns: [],
        requireNetworkConfirmation: true,
        requireProcessConfirmation: true
    )

    // MARK: - Initializer

    public init(
        trustMode: SecurityTrustMode = .review,
        trustedTools: Set<String> = [],
        commandAllowlist: [String: CommandPermissionLevel] = [:],
        autoApprovePatterns: [String] = [],
        requireNetworkConfirmation: Bool = true,
        requireProcessConfirmation: Bool = true
    ) {
        self.trustMode = trustMode
        self.trustedTools = trustedTools
        self.commandAllowlist = commandAllowlist
        self.autoApprovePatterns = autoApprovePatterns
        self.requireNetworkConfirmation = requireNetworkConfirmation
        self.requireProcessConfirmation = requireProcessConfirmation
    }

    // MARK: - CLI Flag Generation

    /// Generates CLI flags for the current trust mode.
    ///
    /// ## Claude Code CLI Flags
    /// - Review Mode: No additional flags (default CLI behavior)
    /// - Trusted Mode: `--allowedTools <trusted-list>` (ask once, then auto-allow)
    /// - YOLO Mode: `--dangerously-skip-permissions`
    /// - Sandbox Mode: `--allowedTools` with only safe read-only tools
    ///
    /// - Parameter engineType: The engine type (currently only Claude uses these flags)
    /// - Returns: Array of CLI arguments to append to the command
    public func cliFlags(for engineType: String = "claude") -> [String] {
        guard engineType == "claude" else {
            // Other engines may have different flag schemes
            return []
        }

        switch trustMode {
        case .review:
            // Default CLI behavior - no flags needed
            return []

        case .trusted:
            // Ask once per tool, then auto-allow via --allowedTools
            if trustedTools.isEmpty {
                return []
            }
            return [
                "--allowedTools",
                trustedTools.sorted().joined(separator: ",")
            ]

        case .yolo:
            // Skip all permission prompts (dangerous!)
            return ["--dangerously-skip-permissions"]

        case .sandbox:
            // Restrict to safe read-only tools
            // Note: Claude Code doesn't have a built-in sandbox mode,
            // so we use --allowedTools to limit available tools
            return [
                "--allowedTools",
                SecuritySettings.safeToolsList.joined(separator: ",")
            ]
        }
    }

    /// Tools considered safe for sandbox mode (read-only operations).
    public static let safeToolsList: [String] = [
        "Read",
        "Glob",
        "Grep",
        "WebFetch",
        "WebSearch"
    ]

    // MARK: - Command Allowlist Helpers

    /// Check if a command is allowed without confirmation.
    ///
    /// - Parameters:
    ///   - command: The command name (e.g., "ls", "cat")
    ///   - requiresWrite: Whether the operation requires write access
    /// - Returns: `true` if the command can run without confirmation
    public func isCommandAllowed(_ command: String, requiresWrite: Bool = false) -> Bool {
        // In YOLO mode, everything is allowed
        if trustMode == .yolo {
            return true
        }

        // In sandbox mode, no writes are allowed
        if trustMode == .sandbox && requiresWrite {
            return false
        }

        // Check allowlist
        guard let permission = commandAllowlist[command] else {
            return false
        }

        switch permission {
        case .read:
            return !requiresWrite
        case .readWrite:
            return true
        }
    }

    /// Check if a file path matches auto-approve patterns.
    ///
    /// - Parameter path: The file path to check
    /// - Returns: `true` if the path matches any auto-approve pattern
    public func isPathAutoApproved(_ path: String) -> Bool {
        // In YOLO mode, all paths are approved
        if trustMode == .yolo {
            return true
        }

        // In sandbox mode, no writes are approved
        if trustMode == .sandbox {
            return false
        }

        // Check patterns (simple glob matching)
        for pattern in autoApprovePatterns {
            if pathMatchesPattern(path, pattern: pattern) {
                return true
            }
        }

        return false
    }

    /// Simple glob pattern matching.
    private func pathMatchesPattern(_ path: String, pattern: String) -> Bool {
        // Handle common patterns:
        // - "*.swift" matches any .swift file
        // - "src/*" matches anything in src/
        // - "**/*.ts" matches .ts files in any subdirectory

        if pattern.contains("**") {
            // Recursive glob - match anywhere in path
            let suffix = pattern.replacingOccurrences(of: "**/", with: "")
            if suffix.hasPrefix("*") {
                // **/*.ext pattern
                let ext = String(suffix.dropFirst())
                return path.hasSuffix(ext)
            }
            return path.contains(suffix)
        } else if pattern.hasPrefix("*") {
            // Simple extension match
            let ext = String(pattern.dropFirst())
            return path.hasSuffix(ext)
        } else if pattern.hasSuffix("/*") {
            // Directory prefix match
            let prefix = String(pattern.dropLast(2))
            return path.hasPrefix(prefix)
        } else {
            // Exact match
            return path == pattern
        }
    }

    // MARK: - Persistence

    /// UserDefaults key for SecuritySettings JSON
    public static let storageKey = "securitySettingsJSON"

    /// Load settings from UserDefaults.
    public static func load() -> SecuritySettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(SecuritySettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Save settings to UserDefaults.
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Migration

    /// Migrate from legacy @AppStorage values to SecuritySettings.
    ///
    /// This handles the transition from the old UI-only settings to the
    /// integrated model approach.
    ///
    /// - Parameters:
    ///   - legacyTrustMode: The old "trustMode" @AppStorage string
    ///   - legacyCommands: Any previously configured commands
    /// - Returns: Migrated SecuritySettings
    public static func migrateFromLegacy(
        legacyTrustMode: String,
        legacyCommands: [LegacyShellCommand] = []
    ) -> SecuritySettings {
        // Map legacy trust mode string to enum
        // Note: old "trusted" maps to new "yolo" (the dangerous one)
        let mode: SecurityTrustMode
        switch legacyTrustMode.lowercased() {
        case "trusted":
            // Legacy "trusted" used --dangerously-skip-permissions, so map to yolo
            mode = .yolo
        case "sandbox":
            mode = .sandbox
        default:
            mode = .review
        }

        // Convert legacy commands to allowlist
        var allowlist: [String: CommandPermissionLevel] = [:]
        for command in legacyCommands where command.isEnabled {
            allowlist[command.name] = command.permission == "Read" ? .read : .readWrite
        }

        return SecuritySettings(
            trustMode: mode,
            trustedTools: [],
            commandAllowlist: allowlist,
            autoApprovePatterns: [],
            requireNetworkConfirmation: mode != .yolo,
            requireProcessConfirmation: mode != .yolo
        )
    }

    // MARK: - Trusted Tools Management

    /// Add a tool to the trusted list (for Trusted mode "ask once" behavior).
    ///
    /// - Parameter toolName: The tool name (e.g., "Bash", "Write", "Edit")
    public mutating func grantToolTrust(_ toolName: String) {
        trustedTools.insert(toolName)
        save()
    }

    /// Remove a tool from the trusted list.
    ///
    /// - Parameter toolName: The tool name to revoke
    public mutating func revokeToolTrust(_ toolName: String) {
        trustedTools.remove(toolName)
        save()
    }

    /// Clear all trusted tools.
    public mutating func clearTrustedTools() {
        trustedTools.removeAll()
        save()
    }

    /// Check if a tool is trusted (for Trusted mode).
    ///
    /// - Parameter toolName: The tool name to check
    /// - Returns: `true` if the tool is in the trusted list
    public func isToolTrusted(_ toolName: String) -> Bool {
        trustedTools.contains(toolName)
    }
}

// MARK: - Trust Mode (View-Layer)

/// Trust mode for security settings UI.
///
/// This is separate from `TrustMode` in Models.swift to maintain a clear
/// boundary between session-level trust (per-session) and global security
/// settings (app-wide).
///
/// ## CLI Mapping
/// | Mode     | Claude CLI Flag                    | Description                         |
/// |----------|------------------------------------|-------------------------------------|
/// | Review   | (none - default)                   | Prompts for every tool invocation   |
/// | Trusted  | `--allowedTools <list>`            | Ask once per tool, then auto-allow  |
/// | YOLO     | `--dangerously-skip-permissions`   | Skips ALL permission checks         |
/// | Sandbox  | `--allowedTools Read,Glob,...`     | Read-only tools only                |
public enum SecurityTrustMode: String, Codable, CaseIterable, Sendable {
    case review = "review"
    case trusted = "trusted"
    case yolo = "yolo"
    case sandbox = "sandbox"

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .review: return "Review Mode"
        case .trusted: return "Trusted Mode"
        case .yolo: return "YOLO Mode"
        case .sandbox: return "Sandbox Mode"
        }
    }

    /// Description for UI
    public var description: String {
        switch self {
        case .review:
            return "Ask permission for every tool invocation. Default and safest option."
        case .trusted:
            return "Ask once per tool. After granting permission, that tool auto-approves."
        case .yolo:
            return "Skip ALL permission prompts. For experienced users who accept full risk."
        case .sandbox:
            return "Read-only mode with safe tools only. No file writes or command execution."
        }
    }

    /// Icon for UI
    public var icon: String {
        switch self {
        case .review: return "checkmark.shield"
        case .trusted: return "hand.raised"
        case .yolo: return "exclamationmark.triangle.fill"
        case .sandbox: return "lock.shield"
        }
    }

    /// CLI flag description for UI explainer
    public var cliFlagDescription: String {
        switch self {
        case .review:
            return "(default CLI behavior)"
        case .trusted:
            return "--allowedTools <trusted-list>"
        case .yolo:
            return "--dangerously-skip-permissions"
        case .sandbox:
            return "--allowedTools Read,Glob,Grep,WebFetch,WebSearch"
        }
    }

    /// Warning level for UI
    public var warningLevel: WarningLevel {
        switch self {
        case .review: return .none
        case .trusted: return .info
        case .yolo: return .high
        case .sandbox: return .info
        }
    }

    public enum WarningLevel {
        case none
        case info
        case high
    }
}

// MARK: - Command Permission Level

/// Permission level for allowed commands.
public enum CommandPermissionLevel: String, Codable, CaseIterable, Sendable {
    case read = "read"
    case readWrite = "readWrite"

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .read: return "Read"
        case .readWrite: return "Read+Write"
        }
    }

    /// Icon for UI
    public var icon: String {
        switch self {
        case .read: return "eye"
        case .readWrite: return "pencil"
        }
    }
}

// MARK: - Legacy Migration Support

/// Legacy shell command structure for migration.
public struct LegacyShellCommand: Codable {
    public let name: String
    public let permission: String
    public let isEnabled: Bool

    public init(name: String, permission: String, isEnabled: Bool) {
        self.name = name
        self.permission = permission
        self.isEnabled = isEnabled
    }
}
