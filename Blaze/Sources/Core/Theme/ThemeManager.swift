import SwiftUI
import os.log

// MARK: - Theme Manager

/// Central coordinator for theme management with SwiftUI environment injection.
///
/// Manages theme lifecycle: loading from storage, applying changes, and persisting
/// the active theme ID via @AppStorage.
@Observable
public final class ThemeManager {

    // MARK: - Properties

    /// Currently active theme profile
    public private(set) var activeTheme: ThemeProfile

    /// User-created custom themes (persisted to disk)
    public private(set) var customThemes: [ThemeProfile] = []

    /// Theme persistence layer
    private let themeStore: ThemeStore

    /// Persisted ID of the active theme
    @ObservationIgnored
    @AppStorage("activeThemeId") private var activeThemeId: String = ""

    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "ThemeManager")

    // MARK: - Computed Properties

    /// Fully resolved colors with DSColors fallbacks applied
    public var resolvedColors: ResolvedThemeColors {
        activeTheme.colors.resolved(with: DSColors.self)
    }

    // MARK: - Initialization

    /// Creates a new theme manager with the given store.
    /// - Parameter themeStore: Actor for persisting custom themes
    public init(themeStore: ThemeStore) {
        self.themeStore = themeStore
        // Start with default theme; call loadActiveTheme() to restore persisted selection
        self.activeTheme = BuiltInThemes.nebula
    }

    // MARK: - Public API

    /// Applies a theme, optionally with animation.
    /// - Parameters:
    ///   - theme: The theme profile to apply
    ///   - animated: Whether to animate the transition (default: true)
    ///   - persist: Whether to persist custom themes to disk (default: true)
    public func applyTheme(_ theme: ThemeProfile, animated: Bool = true, persist: Bool = true) {
        // Skip if same theme already applied
        guard theme.id != activeTheme.id else {
            logger.debug("Theme '\(theme.name)' already active, skipping")
            return
        }

        let apply = {
            self.activeTheme = theme
            self.activeThemeId = theme.id.uuidString
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                apply()
            }
        } else {
            apply()
        }

        logger.info("Applied theme '\(theme.name)' (\(theme.id))")

        // Persist custom themes to disk
        if !theme.isBuiltIn && persist {
            Task {
                await saveCustomTheme(theme)
            }
        }
    }

    /// Saves a custom theme to disk and updates the in-memory list.
    /// - Parameter theme: The custom theme to persist
    public func saveCustomTheme(_ theme: ThemeProfile) async {
        guard !theme.isBuiltIn else {
            logger.warning("Cannot save built-in theme '\(theme.name)' as custom theme")
            return
        }

        do {
            try await themeStore.saveTheme(theme)

            // Update in-memory list (replace if exists, otherwise append)
            await MainActor.run {
                if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
                    customThemes[index] = theme
                } else {
                    customThemes.append(theme)
                }
            }

            logger.info("Persisted custom theme '\(theme.name)'")
        } catch {
            logger.error("Failed to save custom theme '\(theme.name)': \(error.localizedDescription)")
        }
    }

    /// Deletes a custom theme from disk and removes it from the in-memory list.
    /// - Parameter id: The UUID of the custom theme to delete
    /// - Returns: true if deletion succeeded, false otherwise
    @discardableResult
    public func deleteCustomTheme(id: UUID) async -> Bool {
        // Prevent deletion of built-in themes
        guard !BuiltInThemes.builtInIDs.contains(id) else {
            logger.warning("Cannot delete built-in theme with id \(id)")
            return false
        }

        do {
            try await themeStore.deleteTheme(id: id)

            await MainActor.run {
                customThemes.removeAll { $0.id == id }

                // If active theme was deleted, fall back to Nebula
                if activeTheme.id == id {
                    applyTheme(BuiltInThemes.nebula, animated: true, persist: false)
                }
            }

            logger.info("Deleted custom theme \(id)")
            return true
        } catch {
            logger.error("Failed to delete custom theme \(id): \(error.localizedDescription)")
            return false
        }
    }

    /// Loads the active theme and all custom themes from storage.
    ///
    /// Resolution order for active theme:
    /// 1. Check built-in themes by stored ID
    /// 2. Check custom themes from ThemeStore
    /// 3. Fall back to Nebula if not found
    public func loadActiveTheme() async {
        // Load all custom themes into memory first
        let loadedCustomThemes = await themeStore.loadThemes()
        await MainActor.run {
            self.customThemes = loadedCustomThemes
        }
        logger.info("Loaded \(loadedCustomThemes.count) custom themes from storage")

        guard !activeThemeId.isEmpty,
              let storedId = UUID(uuidString: activeThemeId) else {
            logger.debug("No stored theme ID, using default")
            applyTheme(BuiltInThemes.nebula, animated: false, persist: false)
            return
        }

        // Check built-in themes first
        if let builtIn = BuiltInThemes.theme(forId: storedId) {
            logger.info("Loaded built-in theme '\(builtIn.name)'")
            applyTheme(builtIn, animated: false, persist: false)
            return
        }

        // Check custom themes from store
        if let custom = loadedCustomThemes.first(where: { $0.id == storedId }) {
            logger.info("Loaded custom theme '\(custom.name)'")
            applyTheme(custom, animated: false, persist: false)
            return
        }

        // Fallback to Nebula
        logger.warning("Stored theme ID '\(storedId)' not found, falling back to Nebula")
        applyTheme(BuiltInThemes.nebula, animated: false, persist: false)
    }

    /// Resets to the default theme (Nebula) with its original built-in colors.
    ///
    /// Use this when a user wants to restore built-in themes to their original state
    /// after customization.
    public func resetToDefaults() {
        logger.info("Resetting to default theme (Nebula)")
        // Force apply even if ID matches by clearing first
        activeTheme = ThemeProfile.default
        activeThemeId = ""
        applyTheme(BuiltInThemes.nebula, animated: true)
    }
}

// MARK: - Environment Integration

/// Environment key for injecting ThemeManager into SwiftUI views
public struct ThemeManagerKey: EnvironmentKey {
    public static let defaultValue: ThemeManager? = nil
}

public extension EnvironmentValues {
    /// Access the shared theme manager via `.environment(\.themeManager, manager)`
    var themeManager: ThemeManager? {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
