import Foundation
import Combine

// MARK: - Provider Defaults Service

/// Service for persisting user's provider and model preferences.
///
/// Implements atom E005-F001-S001-T008-A001: Provider Defaults and Persistence.
///
/// **Responsibilities:**
/// - Store last-used provider identifier in UserDefaults
/// - Store last-used model identifier in UserDefaults
/// - Detect directory hints (.claude/, .gemini/, .codex/) to override preferences
/// - Provide Combine publisher for preference changes
///
/// **Usage:**
/// ```swift
/// let service = ProviderDefaultsService.shared
///
/// // Get effective provider for a directory (considers hints)
/// let provider = service.effectiveProvider(for: projectURL)
///
/// // Save user's selection after session creation
/// service.setLastUsedProvider(.gemini)
/// service.setLastUsedModel("gemini-2.5-pro")
/// ```
public final class ProviderDefaultsService: @unchecked Sendable {

    // MARK: - Shared Instance

    /// Shared singleton instance using standard UserDefaults.
    public static let shared = ProviderDefaultsService(userDefaults: .standard)

    // MARK: - Keys

    /// UserDefaults keys for provider preferences.
    public enum Keys {
        /// Key for last-used provider identifier (String: EngineType.rawValue).
        public static let lastUsedProvider = "blazeLastUsedProvider"

        /// Key for last-used model identifier (String: model ID).
        public static let lastUsedModel = "blazeLastUsedModel"
    }

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private let providerSubject = PassthroughSubject<EngineType, Never>()
    private let modelSubject = PassthroughSubject<String, Never>()

    // MARK: - Initialization

    /// Creates a new ProviderDefaultsService with the specified UserDefaults.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence.
    ///   Defaults to `.standard`. Use a custom suite for testing.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Provider Persistence

    /// The last-used provider, or `.claude` if none stored or invalid.
    ///
    /// This returns the stored preference without considering directory hints.
    /// Use `effectiveProvider(for:)` to get the provider with hint override.
    public var lastUsedProvider: EngineType {
        guard let rawValue = userDefaults.string(forKey: Keys.lastUsedProvider),
              let provider = EngineType(rawValue: rawValue) else {
            return .claude // Default to Anthropic/Claude
        }
        return provider
    }

    /// Persists the provider selection to UserDefaults.
    ///
    /// - Parameter provider: The provider to store.
    public func setLastUsedProvider(_ provider: EngineType) {
        userDefaults.set(provider.rawValue, forKey: Keys.lastUsedProvider)
        providerSubject.send(provider)
    }

    // MARK: - Model Persistence

    /// The last-used model ID, or the default model for the default provider if none stored.
    public var lastUsedModel: String {
        if let model = userDefaults.string(forKey: Keys.lastUsedModel), !model.isEmpty {
            return model
        }
        // Return default model for default provider
        return ModelService.defaultModel(for: .claude)
    }

    /// Persists the model selection to UserDefaults.
    ///
    /// - Parameter modelId: The model ID to store.
    public func setLastUsedModel(_ modelId: String) {
        userDefaults.set(modelId, forKey: Keys.lastUsedModel)
        modelSubject.send(modelId)
    }

    // MARK: - Reset

    /// Clears all provider preference keys from UserDefaults.
    ///
    /// After reset, `lastUsedProvider` returns `.claude` and
    /// `lastUsedModel` returns the default Claude model.
    public func resetProviderDefaults() {
        userDefaults.removeObject(forKey: Keys.lastUsedProvider)
        userDefaults.removeObject(forKey: Keys.lastUsedModel)
    }

    // MARK: - Directory Hint Detection

    /// Detects provider hint from directory contents.
    ///
    /// Checks for presence of `.claude/`, `.gemini/`, or `.codex/` directories.
    /// When multiple hints exist, uses priority: `.claude` > `.gemini` > `.codex`.
    ///
    /// - Parameter path: The directory URL to scan.
    /// - Returns: The detected provider, or `nil` if no hint directories found.
    public func detectDirectoryHint(at path: URL) -> EngineType? {
        let fileManager = FileManager.default

        // Check if path exists and is a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        // Priority order: .claude > .gemini > .codex
        let hintMappings: [(directory: String, provider: EngineType)] = [
            (".claude", .claude),
            (".gemini", .gemini),
            (".codex", .codex)
        ]

        for (directory, provider) in hintMappings {
            let hintPath = path.appendingPathComponent(directory)
            var isHintDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: hintPath.path, isDirectory: &isHintDirectory),
               isHintDirectory.boolValue {
                return provider
            }
        }

        return nil
    }

    // MARK: - Effective Provider

    /// Returns the effective provider for a directory, considering hints.
    ///
    /// Directory hints take precedence over stored preferences.
    ///
    /// - Parameter path: The directory URL, or `nil` to use stored preference only.
    /// - Returns: The effective provider to use.
    public func effectiveProvider(for path: URL?) -> EngineType {
        // If we have a path, check for directory hints first
        if let path = path, let hint = detectDirectoryHint(at: path) {
            return hint
        }

        // Fall back to stored preference
        return lastUsedProvider
    }

    // MARK: - Combine Publishers

    /// Publisher that emits when the provider preference changes.
    ///
    /// Use this to react to provider changes in SwiftUI views:
    /// ```swift
    /// .onReceive(ProviderDefaultsService.shared.providerChangePublisher) { provider in
    ///     // Update UI
    /// }
    /// ```
    public var providerChangePublisher: AnyPublisher<EngineType, Never> {
        providerSubject.eraseToAnyPublisher()
    }

    /// Publisher that emits when the model preference changes.
    public var modelChangePublisher: AnyPublisher<String, Never> {
        modelSubject.eraseToAnyPublisher()
    }
}
