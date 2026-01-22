import Foundation
import os.log

// MARK: - Engine Router

/// Factory for creating engine adapters based on provider or engine type.
///
/// The router provides a simple interface for selecting the correct adapter
/// implementation based on the session's engine type or provider.
///
/// **E005-F001-S001-T006-A001**
///
/// Usage:
/// ```swift
/// // Get adapter by engine type
/// let adapter = EngineRouter.createAdapter(for: .claude)
///
/// // Get adapter for a session
/// let adapter = EngineRouter.getAdapter(for: session)
/// ```
@MainActor
enum EngineRouter {

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.cogit0.blaze",
        category: "EngineRouter"
    )

    // MARK: - Factory Methods

    /// Creates a new adapter instance for the specified engine type.
    ///
    /// - Parameter type: The engine type to create an adapter for
    /// - Returns: A new adapter instance, or nil if the type is not supported
    ///
    /// Each call returns a new instance - adapters are not cached.
    static func createAdapter(for type: EngineType) -> (any EngineAdapter)? {
        logger.debug("Creating adapter for engine type: \(type.rawValue)")

        switch type {
        case .claude:
            return ClaudeCodeAdapter()
        case .gemini:
            return GeminiCliAdapter()
        case .codex:
            return CodexCliAdapter()
        }
    }

    /// Gets an adapter for the specified session's engine type.
    ///
    /// - Parameter session: The session to get an adapter for
    /// - Returns: A new adapter instance matching the session's engine type
    ///
    /// This is a convenience method that extracts the engine type from the session
    /// and creates the appropriate adapter.
    static func getAdapter(for session: Session) -> (any EngineAdapter)? {
        logger.debug("Getting adapter for session: \(session.id), engine type: \(session.engineType.rawValue)")
        return createAdapter(for: session.engineType)
    }

    /// Creates an adapter for the specified AI provider.
    ///
    /// - Parameter provider: The AI provider to create an adapter for
    /// - Returns: A new adapter instance for the provider's engine type
    ///
    /// This maps the AIProvider to its underlying EngineType and creates
    /// the appropriate adapter.
    static func createAdapter(for provider: AIProvider) -> (any EngineAdapter)? {
        logger.debug("Creating adapter for provider: \(provider.rawValue)")
        return createAdapter(for: provider.engineType)
    }

    // MARK: - Supported Engines

    /// All engine types that have adapter implementations.
    static var supportedEngineTypes: [EngineType] {
        EngineType.allCases
    }

    /// Checks if an engine type has an adapter implementation.
    ///
    /// - Parameter type: The engine type to check
    /// - Returns: True if an adapter exists for this type
    static func isSupported(_ type: EngineType) -> Bool {
        // All EngineType cases have adapters
        true
    }
}
