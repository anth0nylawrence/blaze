import Foundation
import os.log

// MARK: - Theme Store Errors

/// Errors that can occur during theme storage operations
public enum ThemeStoreError: Error, LocalizedError {
    case directoryCreationFailed(URL, Error)
    case encodingFailed(UUID, Error)
    case writeFailed(URL, Error)
    case themeNotFound(UUID)
    case deleteFailed(URL, Error)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url, let error):
            return "Failed to create themes directory at \(url.path): \(error.localizedDescription)"
        case .encodingFailed(let id, let error):
            return "Failed to encode theme \(id): \(error.localizedDescription)"
        case .writeFailed(let url, let error):
            return "Failed to write theme to \(url.path): \(error.localizedDescription)"
        case .themeNotFound(let id):
            return "Theme not found: \(id)"
        case .deleteFailed(let url, let error):
            return "Failed to delete theme at \(url.path): \(error.localizedDescription)"
        }
    }
}

// MARK: - Theme Store

/// Actor-based persistent storage for custom user themes.
///
/// Stores each theme as a separate JSON file in:
/// `~/Library/Application Support/Blaze/themes/{uuid}.json`
public actor ThemeStore {
    private let themesURL: URL
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "ThemeStore")

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    /// Initialize with default Application Support location
    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.themesURL = appSupport.appendingPathComponent("Blaze/themes", isDirectory: true)
    }

    /// Initialize with custom themes directory (for testing)
    public init(themesURL: URL) {
        self.themesURL = themesURL
    }

    // MARK: - Directory Management

    private func ensureDirectory() throws {
        guard !fileManager.fileExists(atPath: themesURL.path) else { return }
        do {
            try fileManager.createDirectory(at: themesURL, withIntermediateDirectories: true)
            logger.info("Created themes directory at \(self.themesURL.path)")
        } catch {
            throw ThemeStoreError.directoryCreationFailed(themesURL, error)
        }
    }

    private func themeFileURL(for id: UUID) -> URL {
        themesURL.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - Public API

    /// Load all custom themes from disk
    /// - Returns: Array of valid theme profiles (invalid files are skipped with warnings)
    public func loadThemes() async -> [ThemeProfile] {
        guard fileManager.fileExists(atPath: themesURL.path) else {
            logger.debug("Themes directory does not exist, returning empty list")
            return []
        }

        var themes: [ThemeProfile] = []

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: themesURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in contents where fileURL.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let theme = try decoder.decode(ThemeProfile.self, from: data)
                    themes.append(theme)
                } catch {
                    logger.warning("Skipping invalid theme file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to enumerate themes directory: \(error.localizedDescription)")
        }

        logger.info("Loaded \(themes.count) custom themes")
        return themes
    }

    /// Save a theme to disk with atomic write
    /// - Parameter theme: The theme profile to persist
    public func saveTheme(_ theme: ThemeProfile) async throws {
        try ensureDirectory()

        let data: Data
        do {
            data = try encoder.encode(theme)
        } catch {
            throw ThemeStoreError.encodingFailed(theme.id, error)
        }

        let fileURL = themeFileURL(for: theme.id)
        do {
            try data.write(to: fileURL, options: .atomic)
            logger.info("Saved theme '\(theme.name)' (\(theme.id))")
        } catch {
            throw ThemeStoreError.writeFailed(fileURL, error)
        }
    }

    /// Delete a theme from disk
    /// - Parameter id: The UUID of the theme to delete
    /// - Throws: `ThemeStoreError.themeNotFound` if the file does not exist
    public func deleteTheme(id: UUID) async throws {
        let fileURL = themeFileURL(for: id)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ThemeStoreError.themeNotFound(id)
        }

        do {
            try fileManager.removeItem(at: fileURL)
            logger.info("Deleted theme \(id)")
        } catch {
            throw ThemeStoreError.deleteFailed(fileURL, error)
        }
    }
}
