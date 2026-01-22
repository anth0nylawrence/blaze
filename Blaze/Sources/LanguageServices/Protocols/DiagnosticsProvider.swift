import Foundation

/// Protocol for diagnostic providers (linters, LSP, etc.)
///
/// Providers analyze text snapshots and return diagnostics.
/// They should be Sendable and safe to call from any thread.
public protocol DiagnosticsProvider: Sendable {
    /// Unique identifier for this provider
    var providerId: String { get }

    /// Human-readable name
    var displayName: String { get }

    /// Languages this provider supports
    var supportedLanguages: Set<String> { get }

    /// Provide diagnostics for the given text snapshot.
    ///
    /// - Parameter snapshot: Immutable text snapshot with UTF-16 semantics
    /// - Returns: Array of diagnostics for the document
    func provideDiagnostics(_ snapshot: TextSnapshot) async throws -> [Diagnostic]
}

// MARK: - Provider Registry

/// Registry of available diagnostics providers
public final class DiagnosticsProviderRegistry: @unchecked Sendable {
    public static let shared = DiagnosticsProviderRegistry()

    private var providers: [any DiagnosticsProvider] = []
    private let lock = NSLock()

    private init() {}

    /// Register a diagnostics provider
    public func register(_ provider: any DiagnosticsProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers.append(provider)
    }

    /// Get all providers for the given language
    public func providers(for languageId: String) -> [any DiagnosticsProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers.filter { $0.supportedLanguages.contains(languageId) || $0.supportedLanguages.isEmpty }
    }

    /// Get all registered providers
    public var allProviders: [any DiagnosticsProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }
}
