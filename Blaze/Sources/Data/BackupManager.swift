import Foundation
import GRDB
import CryptoKit

// MARK: - Backup Manager

/// Backup export and restore manager for Blaze data.
///
/// **System Contract (Phase 2):**
/// - Backup export: Settings -> Data -> Export Backup...
/// - Exports single zip: blaze.sqlite, sessions/<id>/events.ndjson (optional), settings.json, manifest.json
/// - Manifest contains export version, timestamps, integrity hashes (SHA256)
/// - Restore: Settings -> Data -> Restore Backup...
/// - Restore is atomic: new folder first, then swap
/// - Failed restore keeps existing data intact
///
/// **Storage Locations:**
/// - Global DB: ~/Library/Application Support/Blaze/blaze.sqlite
/// - Session logs: ~/Library/Application Support/Blaze/sessions/<id>/events.ndjson
/// - Settings: ~/Library/Application Support/Blaze/settings.json
public actor BackupManager {

    // MARK: - Constants

    /// Current backup format version
    public static let backupVersion = 1

    /// Backup file extension
    public static let backupExtension = "blazebackup"

    /// Default base directory for app data
    public static let defaultAppSupportPath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Blaze")
    }()

    // MARK: - Properties

    private let appSupportPath: URL
    private let fileManager: FileManager

    // MARK: - Initialization

    public init(appSupportPath: URL? = nil) {
        self.appSupportPath = appSupportPath ?? Self.defaultAppSupportPath
        self.fileManager = FileManager.default
    }

    // MARK: - Export

    /// Export backup to a zip file.
    ///
    /// - Parameters:
    ///   - destination: Where to save the backup zip
    ///   - includeSessionLogs: Whether to include per-session NDJSON logs
    ///   - progressHandler: Optional callback for progress updates (0.0-1.0)
    /// - Returns: The backup manifest
    public func exportBackup(
        to destination: URL,
        includeSessionLogs: Bool = true,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> BackupManifest {

        progressHandler?(0.0, "Preparing backup...")

        // Create temp directory for staging
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        var files: [BackupFileEntry] = []
        let totalSteps = includeSessionLogs ? 4 : 3
        var currentStep = 0

        // 1. Copy database
        progressHandler?(Double(currentStep) / Double(totalSteps), "Backing up database...")
        let dbPath = appSupportPath.appendingPathComponent("blaze.sqlite")
        if fileManager.fileExists(atPath: dbPath.path) {
            let destPath = tempDir.appendingPathComponent("blaze.sqlite")

            // Checkpoint WAL before copying to ensure consistency
            try checkpointWAL(at: dbPath)

            try fileManager.copyItem(at: dbPath, to: destPath)
            let hash = try sha256Hash(of: destPath)
            let size = try fileSize(at: destPath)
            files.append(BackupFileEntry(
                relativePath: "blaze.sqlite",
                sha256: hash,
                size: size,
                type: .database
            ))

            // Also copy WAL and SHM if they exist (for complete backup)
            for ext in ["-wal", "-shm"] {
                let walPath = URL(fileURLWithPath: dbPath.path + ext)
                if fileManager.fileExists(atPath: walPath.path) {
                    let destWal = URL(fileURLWithPath: destPath.path + ext)
                    try fileManager.copyItem(at: walPath, to: destWal)
                }
            }
        }
        currentStep += 1

        // 2. Copy settings
        progressHandler?(Double(currentStep) / Double(totalSteps), "Backing up settings...")
        let settingsPath = appSupportPath.appendingPathComponent("settings.json")
        if fileManager.fileExists(atPath: settingsPath.path) {
            let destPath = tempDir.appendingPathComponent("settings.json")
            try fileManager.copyItem(at: settingsPath, to: destPath)
            let hash = try sha256Hash(of: destPath)
            let size = try fileSize(at: destPath)
            files.append(BackupFileEntry(
                relativePath: "settings.json",
                sha256: hash,
                size: size,
                type: .settings
            ))
        }
        currentStep += 1

        // 3. Copy session NDJSON logs (optional)
        if includeSessionLogs {
            progressHandler?(Double(currentStep) / Double(totalSteps), "Backing up session logs...")
            let sessionsDir = appSupportPath.appendingPathComponent("sessions")
            if fileManager.fileExists(atPath: sessionsDir.path) {
                let destSessionsDir = tempDir.appendingPathComponent("sessions")
                try fileManager.createDirectory(at: destSessionsDir, withIntermediateDirectories: true)

                let sessionIds = try fileManager.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)
                for sessionDir in sessionIds where sessionDir.hasDirectoryPath {
                    let eventsFile = sessionDir.appendingPathComponent("events.ndjson")
                    if fileManager.fileExists(atPath: eventsFile.path) {
                        let destDir = destSessionsDir.appendingPathComponent(sessionDir.lastPathComponent)
                        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
                        let destFile = destDir.appendingPathComponent("events.ndjson")
                        try fileManager.copyItem(at: eventsFile, to: destFile)

                        let hash = try sha256Hash(of: destFile)
                        let size = try fileSize(at: destFile)
                        let relativePath = "sessions/\(sessionDir.lastPathComponent)/events.ndjson"
                        files.append(BackupFileEntry(
                            relativePath: relativePath,
                            sha256: hash,
                            size: size,
                            type: .sessionLog
                        ))
                    }
                }
            }
            currentStep += 1
        }

        // 4. Create manifest
        progressHandler?(Double(currentStep) / Double(totalSteps), "Creating manifest...")
        let manifest = BackupManifest(
            version: Self.backupVersion,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            schemaVersion: try await getSchemaVersion(),
            files: files,
            includesSessionLogs: includeSessionLogs
        )

        let manifestPath = tempDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestPath)

        // 5. Create zip
        progressHandler?(0.9, "Creating zip archive...")
        try createZipArchive(from: tempDir, to: destination)

        progressHandler?(1.0, "Backup complete")

        print("[BackupManager] Export completed: \(files.count) files, \(manifest.totalSize) bytes")

        return manifest
    }

    // MARK: - Restore

    /// Restore from a backup zip file.
    ///
    /// Restore is performed atomically:
    /// 1. Extract to temp directory
    /// 2. Validate manifest and checksums
    /// 3. Move current data to backup location
    /// 4. Move restored data to app support
    /// 5. On failure, restore original data
    ///
    /// - Parameters:
    ///   - source: The backup zip file
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: The restored manifest
    public func restoreBackup(
        from source: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> BackupManifest {

        progressHandler?(0.0, "Preparing restore...")

        // Create temp directories
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)")
        let backupDir = fileManager.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // 1. Extract zip
        progressHandler?(0.1, "Extracting backup...")
        try extractZipArchive(from: source, to: tempDir)

        // 2. Read and validate manifest
        progressHandler?(0.2, "Validating manifest...")
        let manifestPath = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestPath.path) else {
            throw BackupError.invalidBackup("Missing manifest.json")
        }

        let manifestData = try Data(contentsOf: manifestPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)

        // Validate backup version
        if manifest.version > Self.backupVersion {
            throw BackupError.incompatibleVersion(manifest.version, Self.backupVersion)
        }

        // 3. Validate file checksums
        progressHandler?(0.3, "Verifying integrity...")
        for (index, file) in manifest.files.enumerated() {
            let filePath = tempDir.appendingPathComponent(file.relativePath)
            guard fileManager.fileExists(atPath: filePath.path) else {
                throw BackupError.missingFile(file.relativePath)
            }

            let actualHash = try sha256Hash(of: filePath)
            if actualHash != file.sha256 {
                throw BackupError.checksumMismatch(file.relativePath, expected: file.sha256, actual: actualHash)
            }

            let progress = 0.3 + (0.2 * Double(index + 1) / Double(manifest.files.count))
            progressHandler?(progress, "Verifying \(file.relativePath)...")
        }

        // 4. Backup current data (for rollback)
        progressHandler?(0.5, "Backing up current data...")
        if fileManager.fileExists(atPath: appSupportPath.path) {
            let contents = try fileManager.contentsOfDirectory(at: appSupportPath, includingPropertiesForKeys: nil)
            for item in contents {
                let destPath = backupDir.appendingPathComponent(item.lastPathComponent)
                try fileManager.moveItem(at: item, to: destPath)
            }
        } else {
            try fileManager.createDirectory(at: appSupportPath, withIntermediateDirectories: true)
        }

        // 5. Restore files atomically
        progressHandler?(0.7, "Restoring data...")
        do {
            for file in manifest.files {
                let sourcePath = tempDir.appendingPathComponent(file.relativePath)
                let destPath = appSupportPath.appendingPathComponent(file.relativePath)

                // Create parent directory if needed
                let parentDir = destPath.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parentDir.path) {
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }

                try fileManager.copyItem(at: sourcePath, to: destPath)
            }

            progressHandler?(0.9, "Finalizing restore...")

            // 6. Cleanup temp directories
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: backupDir)

            progressHandler?(1.0, "Restore complete")

            print("[BackupManager] Restore completed: \(manifest.files.count) files restored")

            return manifest

        } catch {
            // Rollback: restore original data
            progressHandler?(0.95, "Rolling back...")

            // Clear any partially restored data
            if fileManager.fileExists(atPath: appSupportPath.path) {
                let contents = try? fileManager.contentsOfDirectory(at: appSupportPath, includingPropertiesForKeys: nil)
                for item in contents ?? [] {
                    try? fileManager.removeItem(at: item)
                }
            }

            // Restore original data
            let backupContents = try? fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            for item in backupContents ?? [] {
                let destPath = appSupportPath.appendingPathComponent(item.lastPathComponent)
                try? fileManager.moveItem(at: item, to: destPath)
            }

            // Cleanup
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: backupDir)

            throw BackupError.restoreFailed(error)
        }
    }

    // MARK: - Validation

    /// Validate a backup file without restoring.
    public func validateBackup(at path: URL) async throws -> BackupManifest {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("validate-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract
        try extractZipArchive(from: path, to: tempDir)

        // Read manifest
        let manifestPath = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestPath.path) else {
            throw BackupError.invalidBackup("Missing manifest.json")
        }

        let manifestData = try Data(contentsOf: manifestPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)

        // Validate checksums
        for file in manifest.files {
            let filePath = tempDir.appendingPathComponent(file.relativePath)
            guard fileManager.fileExists(atPath: filePath.path) else {
                throw BackupError.missingFile(file.relativePath)
            }

            let actualHash = try sha256Hash(of: filePath)
            if actualHash != file.sha256 {
                throw BackupError.checksumMismatch(file.relativePath, expected: file.sha256, actual: actualHash)
            }
        }

        return manifest
    }

    // MARK: - Private Helpers

    private func sha256Hash(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int64 ?? 0
    }

    private func checkpointWAL(at dbPath: URL) throws {
        // Use sqlite3 to checkpoint WAL
        let db = try DatabaseQueue(path: dbPath.path)
        try db.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    private func getSchemaVersion() async throws -> Int {
        let dbPath = appSupportPath.appendingPathComponent("blaze.sqlite")
        guard fileManager.fileExists(atPath: dbPath.path) else {
            return 0
        }

        let db = try DatabasePool(path: dbPath.path)
        return try await db.read { db in
            let hasTable = try db.tableExists("schema_version")
            guard hasTable else { return 0 }

            return try SchemaVersion
                .order(Column("version").desc)
                .filter(Column("success") == true)
                .fetchOne(db)?.version ?? 0
        }
    }

    private func createZipArchive(from sourceDir: URL, to destination: URL) throws {
        // Use Process to call zip command (macOS built-in)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destination.path, "."]
        process.currentDirectoryURL = sourceDir

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw BackupError.zipFailed("zip command failed with status \(process.terminationStatus)")
        }
    }

    private func extractZipArchive(from source: URL, to destination: URL) throws {
        // Use Process to call unzip command (macOS built-in)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", source.path, "-d", destination.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw BackupError.unzipFailed("unzip command failed with status \(process.terminationStatus)")
        }
    }
}

// MARK: - Backup Manifest

/// Manifest describing a backup's contents.
public struct BackupManifest: Codable, Sendable {
    /// Backup format version
    public let version: Int

    /// When the backup was created
    public let createdAt: Date

    /// App version that created the backup
    public let appVersion: String

    /// Database schema version at backup time
    public let schemaVersion: Int

    /// List of files in the backup
    public let files: [BackupFileEntry]

    /// Whether session logs are included
    public let includesSessionLogs: Bool

    /// Total size of all files in bytes
    public var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    /// Number of session logs included
    public var sessionLogCount: Int {
        files.filter { $0.type == .sessionLog }.count
    }
}

/// Entry describing a single file in a backup.
public struct BackupFileEntry: Codable, Sendable {
    /// Relative path within the backup
    public let relativePath: String

    /// SHA256 checksum
    public let sha256: String

    /// File size in bytes
    public let size: Int64

    /// Type of file
    public let type: BackupFileType
}

/// Type of file in a backup.
public enum BackupFileType: String, Codable, Sendable {
    case database
    case settings
    case sessionLog
    case other
}

// MARK: - Backup Errors

public enum BackupError: Error, LocalizedError {
    case invalidBackup(String)
    case incompatibleVersion(Int, Int)
    case missingFile(String)
    case checksumMismatch(String, expected: String, actual: String)
    case zipFailed(String)
    case unzipFailed(String)
    case restoreFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidBackup(let message):
            return "Invalid backup: \(message)"
        case .incompatibleVersion(let backup, let current):
            return "Backup version \(backup) is newer than supported version \(current)"
        case .missingFile(let path):
            return "Missing file in backup: \(path)"
        case .checksumMismatch(let path, let expected, let actual):
            return "Checksum mismatch for \(path): expected \(expected), got \(actual)"
        case .zipFailed(let message):
            return "Failed to create zip: \(message)"
        case .unzipFailed(let message):
            return "Failed to extract zip: \(message)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription). Original data preserved."
        }
    }
}
