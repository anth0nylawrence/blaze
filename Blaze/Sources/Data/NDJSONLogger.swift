import Foundation

// MARK: - NDJSON Logger

/// Per-session NDJSON log writer for append-only event storage.
///
/// **System Contract (Phase 2):**
/// - Raw session event logs are NDJSON files on disk (append-only)
/// - One file per session at ~/Library/Application Support/Blaze/sessions/<sessionId>/events.ndjson
/// - Events are strictly ordered by emission time
/// - Supports crash recovery by reading back persisted events
///
/// **Storage Location:**
/// - `~/Library/Application Support/Blaze/sessions/<sessionId>/events.ndjson`
/// - `~/Library/Application Support/Blaze/sessions/<sessionId>/terminals/<terminalId>.ndjson` (optional)
public actor NDJSONLogger {
    /// Session ID this logger is associated with
    public let sessionId: UUID

    /// Path to the NDJSON log file
    public let logPath: URL

    /// File handle for append operations
    private var fileHandle: FileHandle?

    /// JSON encoder configured for NDJSON output
    private let encoder: JSONEncoder

    /// Number of events written
    private var eventCount: Int = 0

    /// Last write timestamp
    private var lastWriteTime: Date?

    // MARK: - Initialization

    /// Create a logger for a specific session.
    /// Creates the session directory and log file if they don't exist.
    public init(sessionId: UUID, baseDirectory: URL? = nil) throws {
        self.sessionId = sessionId

        // Determine base directory
        let base = baseDirectory ?? Self.defaultBaseDirectory()
        let sessionDir = base.appendingPathComponent(sessionId.uuidString)
        self.logPath = sessionDir.appendingPathComponent("events.ndjson")

        // Configure encoder
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]  // Deterministic output

        // Create directory structure
        try FileManager.default.createDirectory(
            at: sessionDir,
            withIntermediateDirectories: true
        )

        // Create or open log file
        if !FileManager.default.fileExists(atPath: logPath.path) {
            FileManager.default.createFile(atPath: logPath.path, contents: nil)
        }

        // Open for appending
        fileHandle = try FileHandle(forWritingTo: logPath)
        try fileHandle?.seekToEnd()
    }

    deinit {
        try? fileHandle?.close()
    }

    // MARK: - Public API

    /// Append an event envelope to the NDJSON log.
    /// Thread-safe via actor isolation.
    public func append(_ envelope: EventEnvelope) async throws {
        guard let handle = fileHandle else {
            throw NDJSONLoggerError.fileNotOpen
        }

        // Encode to JSON (single line)
        var data = try encoder.encode(envelope)
        data.append(contentsOf: "\n".utf8)

        // Write and sync to disk
        try handle.write(contentsOf: data)
        try handle.synchronize()

        eventCount += 1
        lastWriteTime = Date()
    }

    /// Append multiple events atomically.
    public func appendBatch(_ envelopes: [EventEnvelope]) async throws {
        guard let handle = fileHandle else {
            throw NDJSONLoggerError.fileNotOpen
        }

        var combinedData = Data()
        for envelope in envelopes {
            var data = try encoder.encode(envelope)
            data.append(contentsOf: "\n".utf8)
            combinedData.append(data)
        }

        // Write all at once and sync
        try handle.write(contentsOf: combinedData)
        try handle.synchronize()

        eventCount += envelopes.count
        lastWriteTime = Date()
    }

    /// Read all events from the log file.
    /// Used for crash recovery and session replay.
    public func readAll() async throws -> [EventEnvelope] {
        let data = try Data(contentsOf: logPath)
        return try Self.parseNDJSON(data)
    }

    /// Read events after a specific sequence number.
    public func readAfterSequence(_ sequence: Int) async throws -> [EventEnvelope] {
        let allEvents = try await readAll()
        return allEvents.filter { $0.sequence > sequence }
    }

    /// Get the path to this session's NDJSON log.
    public func getLogPath() -> URL {
        logPath
    }

    /// Get statistics about the log.
    public func getStats() -> NDJSONLogStats {
        NDJSONLogStats(
            sessionId: sessionId,
            logPath: logPath,
            eventCount: eventCount,
            lastWriteTime: lastWriteTime,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: logPath.path)[.size] as? Int64) ?? 0
        )
    }

    /// Close the log file.
    public func close() throws {
        try fileHandle?.close()
        fileHandle = nil
    }

    /// Truncate the log file (for testing or cleanup).
    public func truncate() throws {
        try fileHandle?.truncate(atOffset: 0)
        eventCount = 0
        lastWriteTime = nil
    }

    // MARK: - Static Helpers

    /// Default base directory for session logs.
    public static func defaultBaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Blaze/sessions")
    }

    /// Get the log path for a session without creating a logger.
    public static func logPath(for sessionId: UUID, baseDirectory: URL? = nil) -> URL {
        let base = baseDirectory ?? defaultBaseDirectory()
        return base.appendingPathComponent(sessionId.uuidString).appendingPathComponent("events.ndjson")
    }

    /// Check if a session has an NDJSON log.
    public static func logExists(for sessionId: UUID, baseDirectory: URL? = nil) -> Bool {
        let path = logPath(for: sessionId, baseDirectory: baseDirectory)
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Parse NDJSON data into event envelopes.
    public static func parseNDJSON(_ data: Data) throws -> [EventEnvelope] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        var envelopes: [EventEnvelope] = []

        for (index, line) in lines.enumerated() {
            do {
                let envelope = try decoder.decode(EventEnvelope.self, from: Data(line.utf8))
                envelopes.append(envelope)
            } catch {
                // Log but don't fail - skip malformed lines per System Contract
                print("[NDJSONLogger] Skipping malformed line \(index + 1): \(error)")
            }
        }

        return envelopes.sorted { $0.sequence < $1.sequence }
    }

    /// List all session IDs that have NDJSON logs.
    public static func listSessions(baseDirectory: URL? = nil) throws -> [UUID] {
        let base = baseDirectory ?? defaultBaseDirectory()

        guard FileManager.default.fileExists(atPath: base.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.compactMap { url -> UUID? in
            guard url.hasDirectoryPath else { return nil }
            guard let uuid = UUID(uuidString: url.lastPathComponent) else { return nil }
            // Check if events.ndjson exists
            let logFile = url.appendingPathComponent("events.ndjson")
            guard FileManager.default.fileExists(atPath: logFile.path) else { return nil }
            return uuid
        }
    }

    /// Delete the NDJSON log for a session.
    public static func deleteLog(for sessionId: UUID, baseDirectory: URL? = nil) throws {
        let base = baseDirectory ?? defaultBaseDirectory()
        let sessionDir = base.appendingPathComponent(sessionId.uuidString)

        if FileManager.default.fileExists(atPath: sessionDir.path) {
            try FileManager.default.removeItem(at: sessionDir)
        }
    }
}

// MARK: - Terminal NDJSON Logger

/// Separate NDJSON logger for terminal output (optional per spec).
public actor TerminalNDJSONLogger {
    public let sessionId: UUID
    public let terminalId: UUID
    public let logPath: URL

    private var fileHandle: FileHandle?
    private let encoder: JSONEncoder

    public init(sessionId: UUID, terminalId: UUID, baseDirectory: URL? = nil) throws {
        self.sessionId = sessionId
        self.terminalId = terminalId

        let base = baseDirectory ?? NDJSONLogger.defaultBaseDirectory()
        let terminalDir = base
            .appendingPathComponent(sessionId.uuidString)
            .appendingPathComponent("terminals")
        self.logPath = terminalDir.appendingPathComponent("\(terminalId.uuidString).ndjson")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        try FileManager.default.createDirectory(at: terminalDir, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: logPath.path) {
            FileManager.default.createFile(atPath: logPath.path, contents: nil)
        }

        fileHandle = try FileHandle(forWritingTo: logPath)
        try fileHandle?.seekToEnd()
    }

    deinit {
        try? fileHandle?.close()
    }

    /// Append terminal output to the log.
    public func append(_ output: TerminalOutput) async throws {
        guard let handle = fileHandle else {
            throw NDJSONLoggerError.fileNotOpen
        }

        var data = try encoder.encode(output)
        data.append(contentsOf: "\n".utf8)
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    /// Read all terminal output from the log.
    public func readAll() async throws -> [TerminalOutput] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try Data(contentsOf: logPath)
        guard let content = String(data: data, encoding: .utf8) else { return [] }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.compactMap { line in
            try? decoder.decode(TerminalOutput.self, from: Data(line.utf8))
        }
    }
}

// MARK: - Supporting Types

/// Statistics about an NDJSON log file.
public struct NDJSONLogStats: Codable, Sendable {
    public let sessionId: UUID
    public let logPath: URL
    public let eventCount: Int
    public let lastWriteTime: Date?
    public let fileSize: Int64
}

/// Terminal output entry for NDJSON logging.
public struct TerminalOutput: Codable, Sendable, Identifiable {
    public let id: UUID
    public let terminalId: UUID
    public let sequence: Int
    public let timestamp: Date
    public let kind: TerminalOutputKind
    public let data: String

    public init(
        id: UUID = UUID(),
        terminalId: UUID,
        sequence: Int,
        timestamp: Date = Date(),
        kind: TerminalOutputKind,
        data: String
    ) {
        self.id = id
        self.terminalId = terminalId
        self.sequence = sequence
        self.timestamp = timestamp
        self.kind = kind
        self.data = data
    }
}

/// Kind of terminal output.
public enum TerminalOutputKind: String, Codable, Sendable {
    case stdout
    case stderr
    case input
    case control  // Terminal control sequences
}

// MARK: - Errors

public enum NDJSONLoggerError: Error, LocalizedError {
    case fileNotOpen
    case invalidPath
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotOpen:
            return "NDJSON log file is not open"
        case .invalidPath:
            return "Invalid log file path"
        case .parseError(let message):
            return "Failed to parse NDJSON: \(message)"
        }
    }
}
