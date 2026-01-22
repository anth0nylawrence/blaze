import Foundation

// MARK: - Export Result

/// Result of exporting hook configurations to provider-specific paths.
public struct HookExportResult: Sendable {
    /// Per-provider export status.
    public let providerResults: [HookProvider: Result<URL, HookExportError>]

    /// All providers that exported successfully.
    public var successfulProviders: [HookProvider] {
        providerResults.compactMap { provider, result in
            if case .success = result { return provider }
            return nil
        }
    }

    /// All providers that failed.
    public var failedProviders: [HookProvider] {
        providerResults.compactMap { provider, result in
            if case .failure = result { return provider }
            return nil
        }
    }

    /// Whether all requested providers succeeded.
    public var allSucceeded: Bool {
        failedProviders.isEmpty
    }
}

/// Errors that can occur during hook export.
public enum HookExportError: Error, LocalizedError, Sendable {
    case providerDoesNotSupportHooks(HookProvider)
    case directoryCreationFailed(path: String, underlying: String)
    case writeFailed(path: String, underlying: String)
    case invalidJSON(reason: String)

    public var errorDescription: String? {
        switch self {
        case .providerDoesNotSupportHooks(let provider):
            return "\(provider.displayName) does not support hooks"
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create directory at \(path): \(underlying)"
        case .writeFailed(let path, let underlying):
            return "Failed to write to \(path): \(underlying)"
        case .invalidJSON(let reason):
            return "Invalid JSON: \(reason)"
        }
    }
}

// MARK: - Export Scope

/// Where to export hooks: user-level or project-level.
public enum HookExportScope: Sendable {
    /// User home directory (e.g., ~/.claude/settings.json)
    case user
    /// Project directory (e.g., <project>/.claude/settings.json)
    case project(path: String)
}

// MARK: - HooksInstallationService Export Extension

extension HooksInstallationService {

    // MARK: - Private FileManager Access

    /// Use default FileManager since the actor's fileManager is private.
    private var fm: FileManager { FileManager.default }

    // MARK: - Export API

    /// Export hook configurations to provider-specific settings files.
    ///
    /// - Parameters:
    ///   - hooks: Hook configurations to export.
    ///   - providers: Which providers to export to. Defaults to all supporting hooks.
    ///   - scope: Where to write the files (user home or project directory).
    /// - Returns: Export result with success/failure per provider.
    ///
    /// **E005-F004-S001-T008-A001**
    public func exportHooks(
        _ hooks: [HookConfiguration],
        to providers: [HookProvider]? = nil,
        scope: HookExportScope
    ) async -> HookExportResult {
        let targetProviders = providers ?? HookProvider.allCases.filter(\.supportsHooks)
        var results: [HookProvider: Result<URL, HookExportError>] = [:]

        for provider in targetProviders {
            let result = await exportToProvider(
                hooks: hooks,
                provider: provider,
                scope: scope
            )
            results[provider] = result
        }

        return HookExportResult(providerResults: results)
    }

    /// Export hooks to a single provider.
    ///
    /// - Parameters:
    ///   - hooks: Hook configurations to export.
    ///   - provider: Target provider.
    ///   - scope: Where to write the file.
    /// - Returns: URL of written file on success, error on failure.
    public func exportToProvider(
        hooks: [HookConfiguration],
        provider: HookProvider,
        scope: HookExportScope
    ) async -> Result<URL, HookExportError> {
        // Check provider supports hooks
        guard provider.supportsHooks else {
            return .failure(.providerDoesNotSupportHooks(provider))
        }

        // Resolve target path
        let configURL = resolveExportPath(for: provider, scope: scope)
        let configDir = configURL.deletingLastPathComponent()

        // Create config directory if needed
        if !fm.fileExists(atPath: configDir.path) {
            do {
                try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
            } catch {
                return .failure(.directoryCreationFailed(
                    path: configDir.path,
                    underlying: error.localizedDescription
                ))
            }
        }

        // Load existing settings or create empty
        var existingData: [String: Any] = [:]
        if fm.fileExists(atPath: configURL.path) {
            if let data = try? Data(contentsOf: configURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                existingData = json
            }
        }

        // Build provider-specific hooks JSON
        let hooksDict = buildHooksJSON(hooks: hooks, for: provider)
        existingData["hooks"] = hooksDict

        // Validate
        guard JSONSerialization.isValidJSONObject(existingData) else {
            return .failure(.invalidJSON(reason: "Generated settings are not valid JSON"))
        }

        // Write with pretty printing and sorted keys
        do {
            let outputData = try JSONSerialization.data(
                withJSONObject: existingData,
                options: [.prettyPrinted, .sortedKeys]
            )
            try outputData.write(to: configURL, options: .atomic)
            return .success(configURL)
        } catch {
            return .failure(.writeFailed(
                path: configURL.path,
                underlying: error.localizedDescription
            ))
        }
    }

    // MARK: - Private Helpers

    /// Resolve the export path for a provider and scope.
    private func resolveExportPath(for provider: HookProvider, scope: HookExportScope) -> URL {
        let baseURL: URL
        switch scope {
        case .user:
            baseURL = fm.homeDirectoryForCurrentUser
        case .project(let path):
            baseURL = URL(fileURLWithPath: path)
        }

        return baseURL
            .appendingPathComponent(provider.configDirectoryName)
            .appendingPathComponent(provider.settingsFilename)
    }

    /// Build hooks JSON dictionary in provider-specific format.
    ///
    /// All providers use the same structure currently:
    /// ```json
    /// {
    ///   "hooks": {
    ///     "EventType": [{ "matcher": [...], "hooks": [...] }]
    ///   }
    /// }
    /// ```
    private func buildHooksJSON(
        hooks: [HookConfiguration],
        for provider: HookProvider
    ) -> [String: [[String: Any]]] {
        // Filter hooks to only those supported by this provider
        let capability = HookCapability.forProvider(provider)
        let supportedHooks = hooks.filter { capability.supports(event: $0.eventType) }

        // Group by event type
        var hooksDict: [String: [[String: Any]]] = [:]

        for config in supportedHooks {
            let eventKey = config.eventType.rawValue
            var entry: [String: Any] = [:]

            // Add matcher if present
            if let matcher = config.matcher {
                entry["matcher"] = [matcher]
            }

            // Build hooks array
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

        return hooksDict
    }
}
