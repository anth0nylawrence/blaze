import Foundation

// MARK: - Hook Installation Scope

/// Installation scope for hooks: user-level or project-level
public enum HookInstallScope: String, Sendable, CaseIterable {
    case user       // ~/.claude/settings.json
    case project    // <CLAUDE_PROJECT_DIR>/.claude/settings.json

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .user: return "User (Global)"
        case .project: return "Project"
        }
    }
}

// MARK: - Hook Verification Error

/// Errors that can occur during hook verification
public enum HookVerificationError: Error, LocalizedError, Sendable {
    case cliNotFound
    case writePermissionDenied(path: String)
    case invalidJSON(reason: String)
    case timeout
    case settingsFileNotFound(path: String)
    case backupDirectoryCreationFailed(path: String)

    public var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "Claude Code CLI not found in PATH"
        case .writePermissionDenied(let path):
            return "Permission denied writing to \(path)"
        case .invalidJSON(let reason):
            return "Invalid JSON in settings file: \(reason)"
        case .timeout:
            return "Verification timed out"
        case .settingsFileNotFound(let path):
            return "Settings file not found at \(path)"
        case .backupDirectoryCreationFailed(let path):
            return "Failed to create backup directory at \(path)"
        }
    }
}

// MARK: - Installed Hook Summary

/// Summary of an installed hook for listing/inspection
public struct InstalledHookSummary: Sendable, Identifiable {
    public let id: UUID
    public let scope: HookInstallScope
    public let eventName: String
    public let matcher: [String]
    public let isEnabled: Bool
    /// Optional user-provided description of what this hook does
    public let description: String?
    /// Raw hook entry JSON data for reconstruction in visual builder
    public let rawHookEntryData: Data?

    public init(
        id: UUID = UUID(),
        scope: HookInstallScope,
        eventName: String,
        matcher: [String],
        isEnabled: Bool,
        description: String? = nil,
        rawHookEntryData: Data? = nil
    ) {
        self.id = id
        self.scope = scope
        self.eventName = eventName
        self.matcher = matcher
        self.isEnabled = isEnabled
        self.description = description
        self.rawHookEntryData = rawHookEntryData
    }

    /// Convert raw hook entry back to a HooksPipeline for visual editing
    public func toPipeline() -> HooksPipeline {
        var nodes: [HookNode] = []
        var connections: [HookConnection] = []

        // Start position - centered in typical viewport (canvas is 2000x2000)
        // Place at ~400,400 to ensure visible with padding from edges
        let startX: CGFloat = 400
        let startY: CGFloat = 400
        let horizontalSpacing: CGFloat = 300
        let verticalSpacing: CGFloat = 120

        // Create event node
        let eventNodeType = HookNodeType(rawValue: eventName.lowercased()) ?? .postToolUse
        let eventNode = HookNode(
            type: eventNodeType,
            eventType: eventName,
            config: !matcher.isEmpty ? ["matcher": AnyCodable(matcher)] : [:],
            position: CGPoint(x: startX, y: startY)
        )
        nodes.append(eventNode)

        // Parse hooks array and create action nodes from raw data
        if let data = rawHookEntryData,
           let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hooksArray = entry["hooks"] as? [[String: Any]] {
            for (index, hookConfig) in hooksArray.enumerated() {
                let actionNode = parseHookConfig(
                    hookConfig,
                    index: index,
                    baseX: startX + horizontalSpacing,
                    baseY: startY,
                    verticalSpacing: verticalSpacing
                )
                nodes.append(actionNode)

                // Connect event node to action node
                let connection = HookConnection(
                    sourceNodeId: eventNode.id,
                    targetNodeId: actionNode.id
                )
                connections.append(connection)
            }
        }

        return HooksPipeline(nodes: nodes, connections: connections)
    }

    /// Parse a single hook config entry into a HookNode
    private func parseHookConfig(
        _ config: [String: Any],
        index: Int,
        baseX: CGFloat,
        baseY: CGFloat,
        verticalSpacing: CGFloat
    ) -> HookNode {
        let hookType = config["type"] as? String ?? "command"

        var nodeType: HookNodeType
        var nodeConfig: [String: AnyCodable] = [:]

        switch hookType {
        case "command":
            nodeType = .command
            if let command = config["command"] as? String {
                nodeConfig["command"] = AnyCodable(command)
            }
            if let timeout = config["timeout"] as? Int {
                nodeConfig["timeout"] = AnyCodable(timeout)
            }
        case "prompt":
            nodeType = .prompt
            if let prompt = config["prompt"] as? String {
                nodeConfig["prompt"] = AnyCodable(prompt)
            }
        default:
            nodeType = .command
        }

        // Position action nodes to the right of event, stacked vertically
        return HookNode(
            type: nodeType,
            config: nodeConfig,
            position: CGPoint(x: baseX, y: baseY + CGFloat(index) * verticalSpacing)
        )
    }
}

// MARK: - Hooks Installation Service

/// Thread-safe service for installing compiled hooks to Claude Code settings.json
public actor HooksInstallationService {

    // MARK: - Properties

    private let fileManager: FileManager

    // MARK: - Initialization

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Path Resolution

    /// Resolve settings path and backup directory for a given scope
    public func resolveHookPaths(scope: HookInstallScope) throws -> (settingsPath: URL, backupDir: URL) {
        let settingsPath: URL

        switch scope {
        case .user:
            // ~/.claude/settings.json
            let homeDir = fileManager.homeDirectoryForCurrentUser
            settingsPath = homeDir
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")

        case .project:
            // <CLAUDE_PROJECT_DIR>/.claude/settings.json
            // Use environment variable if set, otherwise fall back to current directory
            let projectDir: String
            if let envProjectDir = ProcessInfo.processInfo.environment["CLAUDE_PROJECT_DIR"] {
                projectDir = envProjectDir
            } else {
                projectDir = fileManager.currentDirectoryPath
            }

            settingsPath = URL(fileURLWithPath: projectDir)
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
        }

        // Backup directory is in same .claude directory
        let backupDir = settingsPath.deletingLastPathComponent()
            .appendingPathComponent("backups")

        return (settingsPath, backupDir)
    }

    // MARK: - Installation

    /// Install hooks to settings.json
    /// Creates backup before writing, uses atomic write
    public func installHooks(scope: HookInstallScope, compiledHooks: [String: Any]) throws {
        let (settingsPath, backupDir) = try resolveHookPaths(scope: scope)

        // Create .claude directory if it doesn't exist
        let claudeDir = settingsPath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: claudeDir.path) {
            try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        // Read existing settings or create empty object
        var settingsDict: [String: Any]
        if fileManager.fileExists(atPath: settingsPath.path) {
            let data = try Data(contentsOf: settingsPath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw HookVerificationError.invalidJSON(reason: "Root is not a JSON object")
            }
            settingsDict = json
        } else {
            settingsDict = [:]
        }

        // Create backup before modifying
        try createBackup(settingsPath: settingsPath, backupDir: backupDir)

        // Merge hooks into settings
        settingsDict["hooks"] = compiledHooks

        // Validate JSON before writing
        guard JSONSerialization.isValidJSONObject(settingsDict) else {
            throw HookVerificationError.invalidJSON(reason: "Compiled settings are not valid JSON")
        }

        // Atomic write via temp file
        let settingsData = try JSONSerialization.data(withJSONObject: settingsDict, options: .prettyPrinted)
        try atomicWrite(data: settingsData, to: settingsPath)
    }

    /// Uninstall all hooks from settings.json (removes hooks key)
    public func uninstallHooks(scope: HookInstallScope) throws {
        let (settingsPath, backupDir) = try resolveHookPaths(scope: scope)

        // If settings file doesn't exist, nothing to do
        guard fileManager.fileExists(atPath: settingsPath.path) else {
            return
        }

        // Read existing settings
        let data = try Data(contentsOf: settingsPath)
        guard var settingsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookVerificationError.invalidJSON(reason: "Root is not a JSON object")
        }

        // Create backup before modifying
        try createBackup(settingsPath: settingsPath, backupDir: backupDir)

        // Remove hooks key
        settingsDict.removeValue(forKey: "hooks")

        // Atomic write
        let settingsData = try JSONSerialization.data(withJSONObject: settingsDict, options: .prettyPrinted)
        try atomicWrite(data: settingsData, to: settingsPath)
    }

    // MARK: - Listing

    /// List all installed hooks from both user and project scopes
    public func listInstalledHooks() async throws -> [InstalledHookSummary] {
        var summaries: [InstalledHookSummary] = []

        for scope in HookInstallScope.allCases {
            let scopeSummaries = try await listInstalledHooks(scope: scope)
            summaries.append(contentsOf: scopeSummaries)
        }

        return summaries
    }

    /// List installed hooks for a specific scope
    private func listInstalledHooks(scope: HookInstallScope) async throws -> [InstalledHookSummary] {
        let (settingsPath, _) = try resolveHookPaths(scope: scope)

        // If settings file doesn't exist, return empty
        guard fileManager.fileExists(atPath: settingsPath.path) else {
            return []
        }

        // Read settings
        let data = try Data(contentsOf: settingsPath)
        guard let settingsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        // Extract hooks
        guard let hooksDict = settingsDict["hooks"] as? [String: Any] else {
            return []
        }

        var summaries: [InstalledHookSummary] = []

        // Parse each event's hooks
        for (eventName, eventHooks) in hooksDict {
            guard let hookEntries = eventHooks as? [[String: Any]] else { continue }

            for entry in hookEntries {
                let matcher = entry["matcher"] as? [String] ?? []
                let description = entry["description"] as? String

                // Assume enabled by default (no explicit disabled flag in schema)
                let isEnabled = true

                // Serialize entry to Data for Sendable compliance
                let entryData = try? JSONSerialization.data(withJSONObject: entry)

                summaries.append(InstalledHookSummary(
                    scope: scope,
                    eventName: eventName,
                    matcher: matcher,
                    isEnabled: isEnabled,
                    description: description,
                    rawHookEntryData: entryData
                ))
            }
        }

        return summaries
    }

    // MARK: - Verification

    /// Verify hooks installation (basic check)
    public func verifyHooks(scope: HookInstallScope) async throws -> Result<Void, HookVerificationError> {
        let (settingsPath, _) = try resolveHookPaths(scope: scope)

        // Check settings file exists
        guard fileManager.fileExists(atPath: settingsPath.path) else {
            return .failure(.settingsFileNotFound(path: settingsPath.path))
        }

        // Check readable
        guard fileManager.isReadableFile(atPath: settingsPath.path) else {
            return .failure(.writePermissionDenied(path: settingsPath.path))
        }

        // Check valid JSON
        do {
            let data = try Data(contentsOf: settingsPath)
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure(.invalidJSON(reason: error.localizedDescription))
        }

        return .success(())
    }

    // MARK: - Private Helpers

    /// Create timestamped backup of settings file
    private func createBackup(settingsPath: URL, backupDir: URL) throws {
        // Create backup directory if needed
        if !fileManager.fileExists(atPath: backupDir.path) {
            do {
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            } catch {
                throw HookVerificationError.backupDirectoryCreationFailed(path: backupDir.path)
            }
        }

        // Only backup if settings file exists
        guard fileManager.fileExists(atPath: settingsPath.path) else {
            return
        }

        // Generate timestamped backup filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFilename = "settings.json.bak-\(timestamp)"
        let backupPath = backupDir.appendingPathComponent(backupFilename)

        // Copy to backup
        try fileManager.copyItem(at: settingsPath, to: backupPath)
    }

    /// Atomic write: write to temp file, then rename
    private func atomicWrite(data: Data, to url: URL) throws {
        let tempDir = fileManager.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)

        // Write to temp file
        try data.write(to: tempFile, options: .atomic)

        // Replace original (atomic on most filesystems)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: tempFile)
        } else {
            try fileManager.moveItem(at: tempFile, to: url)
        }
    }
}
