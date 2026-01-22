import Foundation

// MARK: - Hook Configuration

/// Configuration for a single hook command.
/// Maps to the "hooks" array entries in settings.json.
public struct HookCommand: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID

    /// The type of hook execution (currently only "command" supported).
    public var type: String

    /// The shell command to execute.
    public var command: String

    /// Timeout in seconds (nil = provider default).
    public var timeout: Int?

    public init(
        id: UUID = UUID(),
        type: String = "command",
        command: String,
        timeout: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.command = command
        self.timeout = timeout
    }

    // Custom coding to exclude id from JSON
    enum CodingKeys: String, CodingKey {
        case type, command, timeout
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.type = try container.decode(String.self, forKey: .type)
        self.command = try container.decode(String.self, forKey: .command)
        self.timeout = try container.decodeIfPresent(Int.self, forKey: .timeout)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(timeout, forKey: .timeout)
    }
}

/// A hook configuration entry with optional matcher and commands.
/// Maps to entries in the "hooks" object in settings.json.
public struct HookConfiguration: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID

    /// The event type this configuration handles.
    public var eventType: CLIHookEventType

    /// Optional matcher pattern (tool names, glob patterns).
    /// If nil, matches all events of this type.
    public var matcher: String?

    /// The hook commands to execute.
    public var hooks: [HookCommand]

    public init(
        id: UUID = UUID(),
        eventType: CLIHookEventType,
        matcher: String? = nil,
        hooks: [HookCommand]
    ) {
        self.id = id
        self.eventType = eventType
        self.matcher = matcher
        self.hooks = hooks
    }

    // Custom coding keys - eventType stored separately, not in JSON
    enum CodingKeys: String, CodingKey {
        case matcher, hooks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        // eventType must be set after decoding by the parent
        self.eventType = .preToolUse // placeholder
        self.matcher = try container.decodeIfPresent(String.self, forKey: .matcher)
        self.hooks = try container.decode([HookCommand].self, forKey: .hooks)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(matcher, forKey: .matcher)
        try container.encode(hooks, forKey: .hooks)
    }
}


// MARK: - Errors

/// Errors from MultiProviderHooksService operations.
public enum HooksServiceError: Error, LocalizedError {
    case providerDoesNotSupportHooks(HookProvider)
    case configDirectoryNotFound(URL)
    case settingsFileNotFound(URL)
    case invalidSettingsFormat(String)
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .providerDoesNotSupportHooks(let provider):
            return "\(provider.displayName) does not support hooks"
        case .configDirectoryNotFound(let url):
            return "Config directory not found: \(url.path)"
        case .settingsFileNotFound(let url):
            return "Settings file not found: \(url.path)"
        case .invalidSettingsFormat(let detail):
            return "Invalid settings format: \(detail)"
        case .saveFailed(let error):
            return "Failed to save hooks: \(error.localizedDescription)"
        }
    }
}

// MARK: - MultiProviderHooksService

/// Service for managing CLI provider hook configurations.
///
/// Handles reading and writing hook configurations from provider-specific
/// settings.json files. Supports Claude Code, Gemini CLI, and Codex CLI
/// (when hooks support is available).
///
/// **E005-F004-S001-T003-A001**
public final class MultiProviderHooksService: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance for app-wide use.
    public static let shared = MultiProviderHooksService()

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Resolves the config path for a provider's settings.json.
    ///
    /// - Parameters:
    ///   - provider: The CLI provider.
    ///   - worktreePath: The project/worktree path (used for project-local configs).
    /// - Returns: URL to the settings.json file.
    ///
    /// Path resolution:
    /// - Project-local: `<worktreePath>/<configDir>/settings.json`
    /// - Falls back to: `~/<configDir>/settings.json`
    public func resolveConfigPath(for provider: HookProvider, worktreePath: String) -> URL {
        let worktreeURL = URL(fileURLWithPath: worktreePath)
        let projectConfigURL = worktreeURL
            .appendingPathComponent(provider.configDirectoryName)
            .appendingPathComponent(provider.settingsFilename)

        // Check project-local first
        if fileManager.fileExists(atPath: projectConfigURL.path) {
            return projectConfigURL
        }

        // Fall back to user home directory
        let homeURL = fileManager.homeDirectoryForCurrentUser
        return homeURL
            .appendingPathComponent(provider.configDirectoryName)
            .appendingPathComponent(provider.settingsFilename)
    }

    /// Loads hook configurations from a provider's settings.json.
    ///
    /// - Parameters:
    ///   - provider: The CLI provider.
    ///   - worktreePath: The project/worktree path.
    /// - Returns: Array of hook configurations.
    /// - Throws: `HooksServiceError` on failure.
    public func loadHooks(
        for provider: HookProvider,
        worktreePath: String
    ) async throws -> [HookConfiguration] {
        // Check if provider supports hooks
        guard provider.supportsHooks else {
            throw HooksServiceError.providerDoesNotSupportHooks(provider)
        }

        let configURL = resolveConfigPath(for: provider, worktreePath: worktreePath)

        // Check file exists
        guard fileManager.fileExists(atPath: configURL.path) else {
            // Return empty array if no settings file (not an error - just no hooks)
            return []
        }

        // Read and parse
        let data = try Data(contentsOf: configURL)
        return try parseHooksFromSettings(data: data)
    }

    /// Saves hook configurations to a provider's settings.json.
    ///
    /// Preserves other settings in the file (permissions, etc.).
    ///
    /// - Parameters:
    ///   - hooks: The hook configurations to save.
    ///   - provider: The CLI provider.
    ///   - worktreePath: The project/worktree path.
    /// - Throws: `HooksServiceError` on failure.
    public func saveHooks(
        _ hooks: [HookConfiguration],
        for provider: HookProvider,
        worktreePath: String
    ) async throws {
        // Check if provider supports hooks
        guard provider.supportsHooks else {
            throw HooksServiceError.providerDoesNotSupportHooks(provider)
        }

        let configURL = resolveConfigPath(for: provider, worktreePath: worktreePath)

        // Ensure config directory exists
        let configDir = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: configDir.path) {
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        // Load existing settings or create new
        var existingData: [String: Any] = [:]
        if fileManager.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existingData = json
            }
        }

        // Build hooks dictionary grouped by event type
        var hooksDict: [String: [[String: Any]]] = [:]
        for config in hooks {
            let eventKey = config.eventType.rawValue
            var entry: [String: Any] = [:]

            if let matcher = config.matcher {
                entry["matcher"] = matcher
            }

            entry["hooks"] = config.hooks.map { hook -> [String: Any] in
                var hookDict: [String: Any] = [
                    "type": hook.type,
                    "command": hook.command
                ]
                if let timeout = hook.timeout {
                    hookDict["timeout"] = timeout
                }
                return hookDict
            }

            if hooksDict[eventKey] == nil {
                hooksDict[eventKey] = []
            }
            hooksDict[eventKey]?.append(entry)
        }

        // Update settings
        existingData["hooks"] = hooksDict

        // Write back
        let outputData = try JSONSerialization.data(
            withJSONObject: existingData,
            options: [.prettyPrinted, .sortedKeys]
        )

        do {
            try outputData.write(to: configURL, options: .atomic)
        } catch {
            throw HooksServiceError.saveFailed(error)
        }
    }

    /// Returns the supported event types for a provider.
    ///
    /// - Parameter provider: The CLI provider.
    /// - Returns: Array of supported event types.
    public func getSupportedEvents(for provider: HookProvider) -> [CLIHookEventType] {
        let capability = HookCapability.forProvider(provider)
        return Array(capability.supportedEvents).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Private Helpers

    /// Parses hook configurations from settings.json data.
    private func parseHooksFromSettings(data: Data) throws -> [HookConfiguration] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HooksServiceError.invalidSettingsFormat("Root is not a dictionary")
        }

        guard let hooksDict = json["hooks"] as? [String: [[String: Any]]] else {
            // No hooks key = empty hooks
            return []
        }

        var configurations: [HookConfiguration] = []

        for (eventKey, entries) in hooksDict {
            // Map event key to CLIHookEventType
            guard let eventType = CLIHookEventType(rawValue: eventKey) else {
                // Skip unknown event types
                continue
            }

            for entry in entries {
                let matcher = entry["matcher"] as? String

                guard let hooksArray = entry["hooks"] as? [[String: Any]] else {
                    continue
                }

                let hookCommands = hooksArray.compactMap { hookDict -> HookCommand? in
                    guard let type = hookDict["type"] as? String,
                          let command = hookDict["command"] as? String else {
                        return nil
                    }
                    let timeout = hookDict["timeout"] as? Int
                    return HookCommand(type: type, command: command, timeout: timeout)
                }

                let config = HookConfiguration(
                    eventType: eventType,
                    matcher: matcher,
                    hooks: hookCommands
                )
                configurations.append(config)
            }
        }

        return configurations
    }
}
