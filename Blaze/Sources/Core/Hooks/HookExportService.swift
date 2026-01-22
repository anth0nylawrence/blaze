import Foundation

// MARK: - Export Format

/// Supported export formats for hook configurations.
public enum HookExportFormat: String, Sendable, CaseIterable, Identifiable {
    /// Claude Code settings.json format (for .claude/settings.json)
    case claudeSettings = "claude_settings"
    /// Standalone shell script with embedded configuration
    case shellScript = "shell_script"
    /// JSON backup format with metadata
    case jsonBackup = "json_backup"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .claudeSettings: return "Claude Code Settings"
        case .shellScript: return "Shell Script"
        case .jsonBackup: return "JSON Backup"
        }
    }

    /// File extension for this format.
    public var fileExtension: String {
        switch self {
        case .claudeSettings: return "json"
        case .shellScript: return "sh"
        case .jsonBackup: return "json"
        }
    }

    /// MIME type for this format.
    public var mimeType: String {
        switch self {
        case .claudeSettings, .jsonBackup: return "application/json"
        case .shellScript: return "text/x-shellscript"
        }
    }
}

// MARK: - Export Metadata

/// Metadata included in JSON backup exports.
public struct HookExportMetadata: Codable, Sendable {
    public let version: String
    public let exportedAt: Date
    public let provider: String
    public let hookCount: Int
    public let applicationVersion: String?

    public init(
        version: String = "1.0",
        exportedAt: Date = Date(),
        provider: String,
        hookCount: Int,
        applicationVersion: String? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.provider = provider
        self.hookCount = hookCount
        self.applicationVersion = applicationVersion
    }
}

// MARK: - Backup Container

/// Container for JSON backup format with metadata and configurations.
public struct HookBackupContainer: Codable, Sendable {
    public let metadata: HookExportMetadata
    public let configurations: [HookConfigurationDTO]

    public init(metadata: HookExportMetadata, configurations: [HookConfigurationDTO]) {
        self.metadata = metadata
        self.configurations = configurations
    }
}

// MARK: - Hook Configuration DTO

/// Data transfer object for hook configuration (serializable without UUID).
public struct HookConfigurationDTO: Codable, Sendable {
    public let eventType: String
    public let matcher: String?
    public let hooks: [HookCommandDTO]

    public init(eventType: String, matcher: String?, hooks: [HookCommandDTO]) {
        self.eventType = eventType
        self.matcher = matcher
        self.hooks = hooks
    }

    /// Create from HookConfiguration.
    public init(from config: HookConfiguration) {
        self.eventType = config.eventType.rawValue
        self.matcher = config.matcher
        self.hooks = config.hooks.map { HookCommandDTO(from: $0) }
    }

    /// Convert to HookConfiguration.
    public func toHookConfiguration() -> HookConfiguration? {
        guard let eventType = CLIHookEventType(rawValue: eventType) else {
            return nil
        }
        let commands = hooks.map { $0.toHookCommand() }
        return HookConfiguration(
            eventType: eventType,
            matcher: matcher,
            hooks: commands
        )
    }
}

// MARK: - Hook Command DTO

/// Data transfer object for hook command (serializable).
public struct HookCommandDTO: Codable, Sendable {
    public let type: String
    public let command: String
    public let timeout: Int?

    public init(type: String, command: String, timeout: Int?) {
        self.type = type
        self.command = command
        self.timeout = timeout
    }

    /// Create from HookCommand.
    public init(from cmd: HookCommand) {
        self.type = cmd.type
        self.command = cmd.command
        self.timeout = cmd.timeout
    }

    /// Convert to HookCommand.
    public func toHookCommand() -> HookCommand {
        HookCommand(type: type, command: command, timeout: timeout)
    }
}

// MARK: - Export Errors

/// Errors that can occur during hook export/import.
public enum HookExportServiceError: Error, LocalizedError, Sendable {
    case noHooksToExport
    case invalidFormat(String)
    case fileWriteFailed(path: String, underlying: String)
    case fileReadFailed(path: String, underlying: String)
    case directoryCreationFailed(path: String, underlying: String)
    case permissionDenied(path: String)
    case invalidBackupFormat(String)
    case unsupportedVersion(String)
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .noHooksToExport:
            return "No hooks to export"
        case .invalidFormat(let reason):
            return "Invalid format: \(reason)"
        case .fileWriteFailed(let path, let underlying):
            return "Failed to write file at \(path): \(underlying)"
        case .fileReadFailed(let path, let underlying):
            return "Failed to read file at \(path): \(underlying)"
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create directory at \(path): \(underlying)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .invalidBackupFormat(let reason):
            return "Invalid backup format: \(reason)"
        case .unsupportedVersion(let version):
            return "Unsupported backup version: \(version)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        }
    }
}

// MARK: - Validation Result

/// Result of validating exported content.
public struct HookExportValidation: Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]

    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }

    public static let valid = HookExportValidation(isValid: true)
}

// MARK: - HookExportService Actor

/// Thread-safe service for exporting and importing hook configurations.
///
/// Supports multiple export formats:
/// - Claude Code settings.json format
/// - Standalone shell scripts
/// - JSON backup format with metadata
///
/// **E005-F009-S002-T007-A001**
public actor HookExportService {

    // MARK: - Properties

    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    // MARK: - Initialization

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        // Configure JSON encoder for pretty output
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601

        // Configure JSON decoder
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Export API

    /// Export hook configurations to a file.
    ///
    /// - Parameters:
    ///   - hooks: Hook configurations to export.
    ///   - format: Target export format.
    ///   - destinationURL: Where to write the exported file.
    ///   - provider: The provider these hooks are for (used in metadata).
    /// - Returns: URL of the written file.
    public func exportHooks(
        _ hooks: [HookConfiguration],
        format: HookExportFormat,
        to destinationURL: URL,
        provider: HookProvider = .claude
    ) async throws -> URL {
        guard !hooks.isEmpty else {
            throw HookExportServiceError.noHooksToExport
        }

        // Generate content based on format
        let content: Data
        switch format {
        case .claudeSettings:
            content = try generateClaudeSettingsJSON(hooks: hooks)
        case .shellScript:
            content = try generateShellScript(hooks: hooks, provider: provider)
        case .jsonBackup:
            content = try generateJSONBackup(hooks: hooks, provider: provider)
        }

        // Validate before writing
        let validation = validateExportContent(content, format: format)
        guard validation.isValid else {
            throw HookExportServiceError.validationFailed(validation.errors)
        }

        // Ensure parent directory exists
        let parentDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                throw HookExportServiceError.directoryCreationFailed(
                    path: parentDir.path,
                    underlying: error.localizedDescription
                )
            }
        }

        // Write file atomically
        do {
            try content.write(to: destinationURL, options: .atomic)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
                throw HookExportServiceError.permissionDenied(path: destinationURL.path)
            }
            throw HookExportServiceError.fileWriteFailed(
                path: destinationURL.path,
                underlying: error.localizedDescription
            )
        }

        // Make shell scripts executable
        if format == .shellScript {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destinationURL.path
            )
        }

        return destinationURL
    }

    /// Export hooks to a string (for clipboard, preview, etc.).
    ///
    /// - Parameters:
    ///   - hooks: Hook configurations to export.
    ///   - format: Target export format.
    ///   - provider: The provider these hooks are for.
    /// - Returns: String representation of the exported content.
    public func exportHooksToString(
        _ hooks: [HookConfiguration],
        format: HookExportFormat,
        provider: HookProvider = .claude
    ) async throws -> String {
        guard !hooks.isEmpty else {
            throw HookExportServiceError.noHooksToExport
        }

        let content: Data
        switch format {
        case .claudeSettings:
            content = try generateClaudeSettingsJSON(hooks: hooks)
        case .shellScript:
            content = try generateShellScript(hooks: hooks, provider: provider)
        case .jsonBackup:
            content = try generateJSONBackup(hooks: hooks, provider: provider)
        }

        guard let string = String(data: content, encoding: .utf8) else {
            throw HookExportServiceError.invalidFormat("Failed to convert to UTF-8 string")
        }

        return string
    }

    // MARK: - Import API

    /// Import hook configurations from a settings.json file.
    ///
    /// - Parameter sourceURL: Path to the settings.json file.
    /// - Returns: Array of imported hook configurations.
    public func importFromSettingsJSON(_ sourceURL: URL) async throws -> [HookConfiguration] {
        let data = try readFile(at: sourceURL)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookExportServiceError.invalidBackupFormat("Root is not a JSON object")
        }

        guard let hooksDict = json["hooks"] as? [String: [[String: Any]]] else {
            // No hooks key = empty
            return []
        }

        return parseHooksFromDict(hooksDict)
    }

    /// Import hook configurations from a JSON backup file.
    ///
    /// - Parameter sourceURL: Path to the backup file.
    /// - Returns: Array of imported hook configurations.
    public func importFromBackup(_ sourceURL: URL) async throws -> [HookConfiguration] {
        let data = try readFile(at: sourceURL)

        let container: HookBackupContainer
        do {
            container = try jsonDecoder.decode(HookBackupContainer.self, from: data)
        } catch {
            throw HookExportServiceError.invalidBackupFormat(error.localizedDescription)
        }

        // Check version compatibility
        let majorVersion = container.metadata.version.components(separatedBy: ".").first ?? "0"
        guard majorVersion == "1" else {
            throw HookExportServiceError.unsupportedVersion(container.metadata.version)
        }

        // Convert DTOs to configurations
        return container.configurations.compactMap { $0.toHookConfiguration() }
    }

    /// Auto-detect format and import from file.
    ///
    /// - Parameter sourceURL: Path to the file.
    /// - Returns: Array of imported hook configurations.
    public func importFromFile(_ sourceURL: URL) async throws -> [HookConfiguration] {
        let data = try readFile(at: sourceURL)

        // Try to detect format
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookExportServiceError.invalidBackupFormat("File is not valid JSON")
        }

        // Check if it's a backup format (has metadata key)
        if json["metadata"] != nil {
            return try await importFromBackup(sourceURL)
        }

        // Assume settings.json format
        return try await importFromSettingsJSON(sourceURL)
    }

    // MARK: - Validation API

    /// Validate export content before writing.
    ///
    /// - Parameters:
    ///   - content: The content to validate.
    ///   - format: The expected format.
    /// - Returns: Validation result with any errors/warnings.
    public func validateExportContent(_ content: Data, format: HookExportFormat) -> HookExportValidation {
        var errors: [String] = []
        var warnings: [String] = []

        switch format {
        case .claudeSettings, .jsonBackup:
            // Validate JSON structure
            do {
                _ = try JSONSerialization.jsonObject(with: content)
            } catch {
                errors.append("Invalid JSON: \(error.localizedDescription)")
            }

        case .shellScript:
            // Validate shell script basics
            guard let script = String(data: content, encoding: .utf8) else {
                errors.append("Script is not valid UTF-8")
                return HookExportValidation(isValid: false, errors: errors, warnings: warnings)
            }

            if !script.hasPrefix("#!/") {
                warnings.append("Script missing shebang line")
            }

            if script.contains("rm -rf /") {
                warnings.append("Script contains potentially dangerous command")
            }
        }

        return HookExportValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    /// Validate hook configurations before export.
    ///
    /// - Parameter hooks: The configurations to validate.
    /// - Returns: Validation result with any errors/warnings.
    public func validateConfigurations(_ hooks: [HookConfiguration]) -> HookExportValidation {
        var errors: [String] = []
        var warnings: [String] = []

        for (index, config) in hooks.enumerated() {
            let prefix = "Hook \(index + 1)"

            if config.hooks.isEmpty {
                errors.append("\(prefix): No commands defined")
            }

            for (cmdIndex, cmd) in config.hooks.enumerated() {
                if cmd.command.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append("\(prefix), Command \(cmdIndex + 1): Empty command")
                }

                if let timeout = cmd.timeout, timeout <= 0 {
                    warnings.append("\(prefix), Command \(cmdIndex + 1): Invalid timeout (\(timeout))")
                }
            }
        }

        return HookExportValidation(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Backup/Restore API

    /// Create a timestamped backup of hook configurations.
    ///
    /// - Parameters:
    ///   - hooks: Hook configurations to backup.
    ///   - backupDirectory: Directory to store backups.
    ///   - provider: The provider these hooks are for.
    /// - Returns: URL of the backup file.
    public func createBackup(
        _ hooks: [HookConfiguration],
        to backupDirectory: URL,
        provider: HookProvider = .claude
    ) async throws -> URL {
        // Generate timestamped filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "hooks-backup-\(timestamp).json"

        let destinationURL = backupDirectory.appendingPathComponent(filename)

        return try await exportHooks(
            hooks,
            format: .jsonBackup,
            to: destinationURL,
            provider: provider
        )
    }

    /// List available backups in a directory.
    ///
    /// - Parameter backupDirectory: Directory to scan.
    /// - Returns: Array of backup file URLs, sorted newest first.
    public func listBackups(in backupDirectory: URL) -> [URL] {
        guard fileManager.fileExists(atPath: backupDirectory.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Filter to backup files and sort by date
            return contents
                .filter { $0.lastPathComponent.hasPrefix("hooks-backup-") && $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                    return date1 > date2
                }
        } catch {
            return []
        }
    }

    /// Restore hooks from a backup file.
    ///
    /// - Parameter backupURL: Path to the backup file.
    /// - Returns: Imported hook configurations.
    public func restoreFromBackup(_ backupURL: URL) async throws -> [HookConfiguration] {
        return try await importFromBackup(backupURL)
    }

    // MARK: - Private: Content Generation

    /// Generate Claude Code settings.json format.
    private func generateClaudeSettingsJSON(hooks: [HookConfiguration]) throws -> Data {
        var hooksDict: [String: [[String: Any]]] = [:]

        for config in hooks {
            let eventKey = config.eventType.rawValue
            var entry: [String: Any] = [:]

            if let matcher = config.matcher {
                entry["matcher"] = [matcher]
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

        let settingsDict: [String: Any] = ["hooks": hooksDict]

        guard JSONSerialization.isValidJSONObject(settingsDict) else {
            throw HookExportServiceError.invalidFormat("Generated settings are not valid JSON")
        }

        return try JSONSerialization.data(
            withJSONObject: settingsDict,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Generate standalone shell script.
    private func generateShellScript(hooks: [HookConfiguration], provider: HookProvider) throws -> Data {
        var lines: [String] = []

        // Shebang and header
        lines.append("#!/bin/bash")
        lines.append("# Hook configurations exported from Blaze")
        lines.append("# Provider: \(provider.displayName)")
        lines.append("# Exported: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("# ")
        lines.append("# Usage: Run this script to install hooks to \(provider.configDirectoryName)/settings.json")
        lines.append("")
        lines.append("set -e")
        lines.append("")

        // Configuration directory
        lines.append("CONFIG_DIR=\"$HOME/\(provider.configDirectoryName)\"")
        lines.append("SETTINGS_FILE=\"$CONFIG_DIR/\(provider.settingsFilename)\"")
        lines.append("")

        // Create directory if needed
        lines.append("# Ensure config directory exists")
        lines.append("mkdir -p \"$CONFIG_DIR\"")
        lines.append("")

        // Generate JSON content
        let jsonData = try generateClaudeSettingsJSON(hooks: hooks)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw HookExportServiceError.invalidFormat("Failed to convert JSON to string")
        }

        // Escape for shell heredoc
        let escapedJSON = jsonString.replacingOccurrences(of: "$", with: "\\$")

        lines.append("# Write hooks configuration")
        lines.append("cat > \"$SETTINGS_FILE\" << 'HOOKS_EOF'")
        lines.append(escapedJSON)
        lines.append("HOOKS_EOF")
        lines.append("")
        lines.append("echo \"Hooks installed to $SETTINGS_FILE\"")

        let script = lines.joined(separator: "\n")
        guard let data = script.data(using: .utf8) else {
            throw HookExportServiceError.invalidFormat("Failed to encode script")
        }

        return data
    }

    /// Generate JSON backup with metadata.
    private func generateJSONBackup(hooks: [HookConfiguration], provider: HookProvider) throws -> Data {
        let dtos = hooks.map { HookConfigurationDTO(from: $0) }

        let metadata = HookExportMetadata(
            provider: provider.rawValue,
            hookCount: hooks.count,
            applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )

        let container = HookBackupContainer(metadata: metadata, configurations: dtos)

        return try jsonEncoder.encode(container)
    }

    // MARK: - Private: File Operations

    /// Read file with permission checking.
    private func readFile(at url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw HookExportServiceError.fileReadFailed(
                path: url.path,
                underlying: "File does not exist"
            )
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw HookExportServiceError.permissionDenied(path: url.path)
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw HookExportServiceError.fileReadFailed(
                path: url.path,
                underlying: error.localizedDescription
            )
        }
    }

    /// Parse hooks dictionary into configurations.
    private func parseHooksFromDict(_ hooksDict: [String: [[String: Any]]]) -> [HookConfiguration] {
        var configurations: [HookConfiguration] = []

        for (eventKey, entries) in hooksDict {
            guard let eventType = CLIHookEventType(rawValue: eventKey) else {
                continue
            }

            for entry in entries {
                // Handle matcher as string or array
                let matcher: String?
                if let matcherArray = entry["matcher"] as? [String], let first = matcherArray.first {
                    matcher = first
                } else if let matcherString = entry["matcher"] as? String {
                    matcher = matcherString
                } else {
                    matcher = nil
                }

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
