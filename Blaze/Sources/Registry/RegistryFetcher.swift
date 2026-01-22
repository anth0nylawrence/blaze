import Foundation
import CryptoKit

// MARK: - Registry Fetch Errors

/// Errors that can occur during registry fetching
enum RegistryFetchError: Error, LocalizedError {
    case networkError(underlying: Error)
    case invalidResponse(statusCode: Int?, message: String)
    case signatureInvalid(reason: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let code, let message):
            if let code {
                return "Invalid response (HTTP \(code)): \(message)"
            }
            return "Invalid response: \(message)"
        case .signatureInvalid(let reason):
            return "Signature verification failed: \(reason)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - Registry Fetcher

/// Actor responsible for fetching and caching the registry catalog.
///
/// Features:
/// - ETag-based conditional fetching for bandwidth efficiency
/// - Exponential backoff retry (3 attempts)
/// - Primary + fallback URL support
/// - Ed25519 signature verification (TODO: implement when keys available)
actor RegistryFetcher {

    // MARK: - Configuration

    private static let primaryURL = URL(string: "https://api.cogit0.com/registry/v1/catalog")!
    private static let fallbackURL = URL(string: "https://raw.githubusercontent.com/cogit0/registry/main/catalog.json")!

    private static let requestTimeout: TimeInterval = 30
    private static let maxRetryAttempts = 3
    private static let retryDelays: [TimeInterval] = [1, 2, 4]

    // MARK: - State

    /// Cached ETag for conditional requests
    private var cachedETag: String?

    /// Cached response for 304 Not Modified handling
    private var cachedResponse: RegistryResponse?

    /// URLSession configured for registry requests
    private let session: URLSession

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.timeoutIntervalForResource = Self.requestTimeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetches the registry catalog with automatic retry and fallback.
    ///
    /// - Returns: The registry response containing available adapters and metadata
    /// - Throws: `RegistryFetchError` if all attempts fail
    func fetchRegistry() async throws -> RegistryResponse {
        // Try primary URL first
        do {
            return try await fetchWithRetry(from: Self.primaryURL)
        } catch {
            // Primary failed, try fallback
            do {
                return try await fetchWithRetry(from: Self.fallbackURL)
            } catch let fallbackError {
                // Both failed - throw the fallback error (usually more informative)
                throw fallbackError
            }
        }
    }

    /// Clears the cached ETag and response, forcing a fresh fetch on next request.
    func clearCache() {
        cachedETag = nil
        cachedResponse = nil
    }

    // MARK: - Private Implementation

    /// Fetches from a URL with exponential backoff retry.
    private func fetchWithRetry(from url: URL) async throws -> RegistryResponse {
        var lastError: Error?

        for attempt in 0..<Self.maxRetryAttempts {
            do {
                return try await performFetch(from: url)
            } catch {
                lastError = error

                // Don't retry on certain errors
                if case RegistryFetchError.signatureInvalid = error {
                    throw error
                }

                // Apply delay before retry (except on last attempt)
                if attempt < Self.maxRetryAttempts - 1 {
                    let delay = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? RegistryFetchError.networkError(underlying: URLError(.unknown))
    }

    /// Performs a single fetch attempt.
    private func performFetch(from url: URL) async throws -> RegistryResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Blaze/1.0", forHTTPHeaderField: "User-Agent")

        // Add ETag for conditional request if we have a cached response
        if let etag = cachedETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw RegistryFetchError.timeout
            }
            throw RegistryFetchError.networkError(underlying: urlError)
        } catch {
            throw RegistryFetchError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistryFetchError.invalidResponse(statusCode: nil, message: "Not an HTTP response")
        }

        // Handle 304 Not Modified - return cached response
        if httpResponse.statusCode == 304, let cached = cachedResponse {
            return cached
        }

        // Handle non-success status codes
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RegistryFetchError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        // Parse the response
        let registryResponse: RegistryResponse
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            registryResponse = try decoder.decode(RegistryResponse.self, from: data)
        } catch {
            throw RegistryFetchError.invalidResponse(
                statusCode: httpResponse.statusCode,
                message: "Failed to decode response: \(error.localizedDescription)"
            )
        }

        // TODO: Ed25519 signature verification
        // When implemented, verify the signature from response headers or body
        // against the known public key before accepting the response.
        // try verifySignature(data: data, response: httpResponse)

        // Cache the ETag and response for future conditional requests
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            cachedETag = etag
            cachedResponse = registryResponse
        }

        return registryResponse
    }

    // MARK: - Signature Verification (Stub)

    /// Verifies the Ed25519 signature of the registry response.
    ///
    /// - Parameters:
    ///   - data: The raw response data
    ///   - response: The HTTP response containing signature headers
    /// - Throws: `RegistryFetchError.signatureInvalid` if verification fails
    @available(*, unavailable, message: "Ed25519 verification not yet implemented")
    private func verifySignature(data: Data, response: HTTPURLResponse) throws {
        // TODO: Implement Ed25519 signature verification
        //
        // Expected implementation:
        // 1. Extract signature from response header (e.g., "X-Signature")
        // 2. Load the trusted public key (bundled with app or fetched securely)
        // 3. Verify: Curve25519.Signing.PublicKey.isValidSignature(_:for:)
        //
        // Example:
        // guard let signatureHeader = response.value(forHTTPHeaderField: "X-Signature"),
        //       let signatureData = Data(base64Encoded: signatureHeader) else {
        //     throw RegistryFetchError.signatureInvalid(reason: "Missing signature header")
        // }
        //
        // let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: knownPublicKeyData)
        // guard publicKey.isValidSignature(signatureData, for: data) else {
        //     throw RegistryFetchError.signatureInvalid(reason: "Signature does not match")
        // }

        throw RegistryFetchError.signatureInvalid(reason: "Not implemented")
    }
}
