//
//  RegistryInstaller.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - Registry Item Type

/// Types of items that can be installed from the registry.
public enum RegistryItemType: String, Sendable, CaseIterable {
    case skill
    case plugin
    case agent

    /// Installation directory name within the CLI config folder
    var directoryName: String {
        switch self {
        case .skill: return "skills"
        case .plugin: return "plugins"
        case .agent: return "agents"
        }
    }
}

// MARK: - Installable Item Protocol

/// Protocol for registry items that can be installed.
/// Implemented by SkillItem, PluginItem, AgentItem.
public protocol InstallableItem: Sendable {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var downloadURL: URL { get }
    var sha256Checksum: String { get }
    var itemType: RegistryItemType { get }
    /// CLI providers this item supports (e.g., ["claude", "gemini"])
    var supportedCLIs: [String] { get }
}

// MARK: - Installation Errors

/// Errors that can occur during registry item installation.
public enum RegistryInstallerError: Error, LocalizedError, Sendable {
    case downloadFailed(reason: String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(reason: String)
    case installationFailed(reason: String)
    case itemNotFound(id: String, type: RegistryItemType)
    case stagingDirectoryCreationFailed(path: String)
    case atomicMoveFailed(reason: String)
    case rollbackFailed(reason: String)
    case unsupportedCLI(cli: String, supported: [String])

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum verification failed. Expected: \(expected), Got: \(actual)"
        case .extractionFailed(let reason):
            return "Failed to extract archive: \(reason)"
        case .installationFailed(let reason):
            return "Installation failed: \(reason)"
        case .itemNotFound(let id, let type):
            return "\(type.rawValue.capitalized) '\(id)' not found"
        case .stagingDirectoryCreationFailed(let path):
            return "Failed to create staging directory at \(path)"
        case .atomicMoveFailed(let reason):
            return "Failed to move files to final location: \(reason)"
        case .rollbackFailed(let reason):
            return "Rollback failed: \(reason)"
        case .unsupportedCLI(let cli, let supported):
            return "CLI '\(cli)' is not supported. Supported: \(supported.joined(separator: ", "))"
        }
    }
}

// MARK: - Registry Installer Actor

/// Thread-safe service for installing registry items (skills, plugins, agents).
/// Handles download, verification, extraction, and atomic installation with rollback.
public actor RegistryInstaller {

    // MARK: - Properties

    private let fileManager: FileManager
    private let urlSession: URLSession
    private let stagingBaseDir: URL

    // MARK: - Initialization

    public init(
        fileManager: FileManager = .default,
        urlSession: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.urlSession = urlSession

        // Staging directory in temporary folder
        self.stagingBaseDir = fileManager.temporaryDirectory
            .appendingPathComponent("blaze-registry-staging")
    }

    // MARK: - Public Installation Methods

    /// Install an InstallableSkillItem.
    /// - Parameters:
    ///   - skill: The skill item to install
    ///   - cli: Target CLI (e.g., "claude", "gemini")
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        skill: InstallableSkillItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await installItem(skill, cli: cli, progressHandler: progressHandler)
    }

    /// Install an InstallablePluginItem.
    /// - Parameters:
    ///   - plugin: The plugin item to install
    ///   - cli: Target CLI (e.g., "claude")
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        plugin: InstallablePluginItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await installItem(plugin, cli: cli, progressHandler: progressHandler)
    }

    /// Install an InstallableAgentItem.
    /// - Parameters:
    ///   - agent: The agent item to install
    ///   - cli: Target CLI (e.g., "claude")
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        agent: InstallableAgentItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await installItem(agent, cli: cli, progressHandler: progressHandler)
    }

    /// Install a SkillItem from RegistryModels (requires downloadURL and sha256Checksum).
    /// - Parameters:
    ///   - skill: The skill item from the registry API
    ///   - cli: Target CLI (e.g., "claude", "gemini")
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        skill: SkillItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let downloadURL = skill.downloadURL,
              let checksum = skill.sha256Checksum else {
            throw RegistryInstallerError.installationFailed(
                reason: "Skill '\(skill.id)' is missing download URL or checksum"
            )
        }
        let installable = InstallableSkillItem(
            id: skill.id,
            name: skill.name,
            version: skill.version,
            downloadURL: downloadURL,
            sha256Checksum: checksum,
            supportedCLIs: skill.compatibleCLIs
        )
        try await installItem(installable, cli: cli, progressHandler: progressHandler)
    }

    /// Install a PluginItem from RegistryModels (requires downloadURL and sha256Checksum).
    /// - Parameters:
    ///   - plugin: The plugin item from the registry API
    ///   - cli: Target CLI (defaults to plugin's forCLI)
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        plugin: PluginItem,
        cli: String? = nil,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let downloadURL = plugin.downloadURL,
              let checksum = plugin.sha256Checksum else {
            throw RegistryInstallerError.installationFailed(
                reason: "Plugin '\(plugin.id)' is missing download URL or checksum"
            )
        }
        let targetCLI = cli ?? plugin.forCLI
        let installable = InstallablePluginItem(
            id: plugin.id,
            name: plugin.name,
            version: plugin.version,
            downloadURL: downloadURL,
            sha256Checksum: checksum,
            supportedCLIs: [plugin.forCLI]
        )
        try await installItem(installable, cli: targetCLI, progressHandler: progressHandler)
    }

    /// Install an AgentItem from RegistryModels (requires downloadURL and sha256Checksum).
    /// - Parameters:
    ///   - agent: The agent item from the registry API
    ///   - cli: Target CLI (e.g., "claude")
    ///   - progressHandler: Called with progress (0.0 to 1.0)
    public func install(
        agent: AgentItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let downloadURL = agent.downloadURL,
              let checksum = agent.sha256Checksum else {
            throw RegistryInstallerError.installationFailed(
                reason: "Agent '\(agent.id)' is missing download URL or checksum"
            )
        }
        let installable = InstallableAgentItem(
            id: agent.id,
            name: agent.name,
            version: agent.version,
            downloadURL: downloadURL,
            sha256Checksum: checksum,
            supportedCLIs: ["claude"]  // Agents currently only for Claude
        )
        try await installItem(installable, cli: cli, progressHandler: progressHandler)
    }

    /// Generic install method for any InstallableItem.
    public func install(
        item: any InstallableItem,
        cli: String = "claude",
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await installItem(item, cli: cli, progressHandler: progressHandler)
    }

    /// Uninstall a registry item.
    /// - Parameters:
    ///   - itemId: The ID of the item to uninstall
    ///   - type: The type of item (skill, plugin, agent)
    ///   - cli: Target CLI (e.g., "claude")
    public func uninstall(
        itemId: String,
        type: RegistryItemType,
        cli: String = "claude"
    ) async throws {
        let installDir = try resolveInstallDirectory(for: type, cli: cli)
        let itemDir = installDir.appendingPathComponent(itemId)

        guard fileManager.fileExists(atPath: itemDir.path) else {
            throw RegistryInstallerError.itemNotFound(id: itemId, type: type)
        }

        do {
            try fileManager.removeItem(at: itemDir)
        } catch {
            throw RegistryInstallerError.installationFailed(
                reason: "Failed to remove \(itemId): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Private Installation Logic

    private func installItem(
        _ item: any InstallableItem,
        cli: String,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        // Validate CLI support
        if !item.supportedCLIs.contains(cli) && !item.supportedCLIs.isEmpty {
            throw RegistryInstallerError.unsupportedCLI(cli: cli, supported: item.supportedCLIs)
        }

        let stagingDir = stagingBaseDir.appendingPathComponent(UUID().uuidString)
        var rollbackPath: URL?

        do {
            // Phase 1: Setup staging (0-5%)
            progressHandler(0.0)
            try createStagingDirectory(at: stagingDir)
            progressHandler(0.05)

            // Phase 2: Download (5-50%)
            let downloadedFile = try await downloadFile(
                from: item.downloadURL,
                to: stagingDir,
                progressHandler: { progress in
                    // Map download progress to 5-50% range
                    progressHandler(0.05 + progress * 0.45)
                }
            )
            progressHandler(0.50)

            // Phase 3: Verify checksum (50-60%)
            try verifyChecksum(of: downloadedFile, expected: item.sha256Checksum)
            progressHandler(0.60)

            // Phase 4: Extract (60-80%)
            let extractedDir = try extractArchive(downloadedFile, to: stagingDir)
            progressHandler(0.80)

            // Phase 5: Install atomically (80-95%)
            let installDir = try resolveInstallDirectory(for: item.itemType, cli: cli)
            let finalPath = installDir.appendingPathComponent(item.id)

            // Backup existing installation for rollback
            if fileManager.fileExists(atPath: finalPath.path) {
                rollbackPath = stagingDir.appendingPathComponent("rollback-\(item.id)")
                try fileManager.moveItem(at: finalPath, to: rollbackPath!)
            }

            try atomicMove(from: extractedDir, to: finalPath)
            progressHandler(0.95)

            // Phase 6: Cleanup staging (95-100%)
            try? fileManager.removeItem(at: stagingDir)
            progressHandler(1.0)

        } catch {
            // Rollback on failure
            if let rollbackPath = rollbackPath {
                let installDir = try resolveInstallDirectory(for: item.itemType, cli: cli)
                let finalPath = installDir.appendingPathComponent(item.id)

                do {
                    if fileManager.fileExists(atPath: finalPath.path) {
                        try fileManager.removeItem(at: finalPath)
                    }
                    try fileManager.moveItem(at: rollbackPath, to: finalPath)
                } catch let rollbackError {
                    throw RegistryInstallerError.rollbackFailed(
                        reason: "Original error: \(error.localizedDescription). Rollback error: \(rollbackError.localizedDescription)"
                    )
                }
            }

            // Cleanup staging on failure
            try? fileManager.removeItem(at: stagingDir)

            throw error
        }
    }

    // MARK: - Path Resolution

    /// Resolve the installation directory for a given item type and CLI.
    private func resolveInstallDirectory(for type: RegistryItemType, cli: String) throws -> URL {
        let homeDir = fileManager.homeDirectoryForCurrentUser

        // CLI config directories
        let cliConfigDir: URL
        switch cli.lowercased() {
        case "claude":
            cliConfigDir = homeDir.appendingPathComponent(".claude")
        case "gemini":
            cliConfigDir = homeDir.appendingPathComponent(".gemini")
        case "codex", "openai":
            cliConfigDir = homeDir.appendingPathComponent(".codex")
        default:
            // Default to .claude for unknown CLIs
            cliConfigDir = homeDir.appendingPathComponent(".claude")
        }

        let installDir = cliConfigDir.appendingPathComponent(type.directoryName)

        // Ensure directory exists
        if !fileManager.fileExists(atPath: installDir.path) {
            try fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)
        }

        return installDir
    }

    // MARK: - Download

    private func downloadFile(
        from url: URL,
        to directory: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let destinationFile = directory.appendingPathComponent(url.lastPathComponent)

        let (tempURL, response) = try await urlSession.download(from: url, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RegistryInstallerError.downloadFailed(
                reason: "HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            )
        }

        // Move downloaded file to staging
        try fileManager.moveItem(at: tempURL, to: destinationFile)
        progressHandler(1.0)

        return destinationFile
    }

    // MARK: - Checksum Verification

    private func verifyChecksum(of file: URL, expected: String) throws {
        let data = try Data(contentsOf: file)
        let hash = SHA256.hash(data: data)
        let actual = hash.compactMap { String(format: "%02x", $0) }.joined()

        guard actual.lowercased() == expected.lowercased() else {
            throw RegistryInstallerError.checksumMismatch(expected: expected, actual: actual)
        }
    }

    // MARK: - Archive Extraction

    private func extractArchive(_ archive: URL, to directory: URL) throws -> URL {
        let extractedDir = directory.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractedDir, withIntermediateDirectories: true)

        // Use ditto for ZIP extraction (available on macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", archive.path, extractedDir.path]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw RegistryInstallerError.extractionFailed(reason: errorMessage)
            }
        } catch let error as RegistryInstallerError {
            throw error
        } catch {
            throw RegistryInstallerError.extractionFailed(reason: error.localizedDescription)
        }

        // Find the extracted content (may be nested in a single folder)
        let contents = try fileManager.contentsOfDirectory(at: extractedDir, includingPropertiesForKeys: nil)

        // If there's a single directory, use that as the extracted content
        if contents.count == 1, let singleItem = contents.first {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: singleItem.path, isDirectory: &isDir), isDir.boolValue {
                return singleItem
            }
        }

        return extractedDir
    }

    // MARK: - File Operations

    private func createStagingDirectory(at url: URL) throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw RegistryInstallerError.stagingDirectoryCreationFailed(path: url.path)
        }
    }

    private func atomicMove(from source: URL, to destination: URL) throws {
        // Ensure parent directory exists
        let parentDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        do {
            // If destination exists, remove it first
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            // Move source to destination
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw RegistryInstallerError.atomicMoveFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Installable Item Types (for installer)

/// Installable skill item with download metadata for the installer.
/// Distinct from SkillItem in RegistryModels which is the API response type.
public struct InstallableSkillItem: InstallableItem, Sendable {
    public typealias ItemType = RegistryItemType

    public let id: String
    public let name: String
    public let version: String
    public let downloadURL: URL
    public let sha256Checksum: String
    public let supportedCLIs: [String]
    public var itemType: RegistryItemType { .skill }

    public init(
        id: String,
        name: String,
        version: String,
        downloadURL: URL,
        sha256Checksum: String,
        supportedCLIs: [String] = ["claude", "gemini"]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
        self.supportedCLIs = supportedCLIs
    }
}

/// Installable plugin item with download metadata for the installer.
/// Distinct from PluginItem in RegistryModels which is the API response type.
public struct InstallablePluginItem: InstallableItem, Sendable {
    public typealias ItemType = RegistryItemType

    public let id: String
    public let name: String
    public let version: String
    public let downloadURL: URL
    public let sha256Checksum: String
    public let supportedCLIs: [String]
    public var itemType: RegistryItemType { .plugin }

    public init(
        id: String,
        name: String,
        version: String,
        downloadURL: URL,
        sha256Checksum: String,
        supportedCLIs: [String] = ["claude"]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
        self.supportedCLIs = supportedCLIs
    }
}

/// Installable agent item with download metadata for the installer.
/// Distinct from AgentItem in RegistryModels which is the API response type.
public struct InstallableAgentItem: InstallableItem, Sendable {
    public typealias ItemType = RegistryItemType

    public let id: String
    public let name: String
    public let version: String
    public let downloadURL: URL
    public let sha256Checksum: String
    public let supportedCLIs: [String]
    public var itemType: RegistryItemType { .agent }

    public init(
        id: String,
        name: String,
        version: String,
        downloadURL: URL,
        sha256Checksum: String,
        supportedCLIs: [String] = ["claude"]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.downloadURL = downloadURL
        self.sha256Checksum = sha256Checksum
        self.supportedCLIs = supportedCLIs
    }
}
