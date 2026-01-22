import XCTest
import GRDB
@testable import Blaze

final class EventPersistenceTests: XCTestCase {
    private var tempDirectory: URL!
    private var dbPath: String!
    private var jsonlPath: String!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlazeEventTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        dbPath = tempDirectory.appendingPathComponent("test.db").path
        jsonlPath = tempDirectory.appendingPathComponent("events.jsonl").path
    }

    override func tearDown() async throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    /// Test that events are loaded from EventStore when a session is selected
    @MainActor
    func testEventsLoadedOnSessionSelection() async throws {
        // Given: An EventStore with persisted events for a session
        let sessionId = UUID()

        // SessionStore runs migrations that create the events table
        let sessionStore = try SessionStore(path: dbPath)
        _ = try await sessionStore.runMigrations()
        let eventStore = try EventStore(dbPath: dbPath, jsonlPath: jsonlPath)

        // Create the session in database (required for foreign key constraint)
        let testSession = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(testSession)

        // Store some events
        let event1 = NormalizedEvent.assistantDelta(AssistantDelta(
            text: "Hello ",
            timestamp: Date()
        ))
        let event2 = NormalizedEvent.assistantDelta(AssistantDelta(
            text: "World!",
            timestamp: Date()
        ))
        let event3 = NormalizedEvent.assistantComplete(AssistantComplete(
            fullText: "Hello World!",
            timestamp: Date(),
            stopReason: .endTurn
        ))

        try await eventStore.append(event1, sessionId: sessionId, sequence: 1)
        try await eventStore.append(event2, sessionId: sessionId, sequence: 2)
        try await eventStore.append(event3, sessionId: sessionId, sequence: 3)

        // When: AppState is created and session is selected
        let appState = AppState(eventStore: eventStore)

        // Use the session we created
        appState.sessions = [testSession]

        // Select the session
        appState.currentSessionId = sessionId

        // Give async loading time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Events should be loaded from EventStore
        let loadedEvents = appState.eventsForSession(sessionId)
        XCTAssertEqual(loadedEvents.count, 3, "Should load 3 events from EventStore")

        // Verify event content (guard against empty array)
        guard loadedEvents.count >= 1 else {
            XCTFail("Not enough events loaded")
            return
        }
        if case .assistantDelta(let delta) = loadedEvents[0].event {
            XCTAssertEqual(delta.text, "Hello ")
        } else {
            XCTFail("Expected assistantDelta event")
        }
    }

    /// Test that events persist across app restart (simulated by new AppState)
    @MainActor
    func testEventsPersistAcrossRestart() async throws {
        let sessionId = UUID()

        // First "app session" - store events
        do {
            // SessionStore runs migrations that create the events table
            let sessionStore = try SessionStore(path: dbPath)
            _ = try await sessionStore.runMigrations()
            let eventStore = try EventStore(dbPath: dbPath, jsonlPath: jsonlPath)

            // Create session in database (required for foreign key constraint)
            let testSession = Session(id: sessionId, name: "Test Session")
            try await sessionStore.create(testSession)

            let event = NormalizedEvent.assistantComplete(AssistantComplete(
                fullText: "Persisted message",
                timestamp: Date(),
                stopReason: .endTurn
            ))
            try await eventStore.append(event, sessionId: sessionId, sequence: 1)
        }

        // Second "app session" - new EventStore, same DB
        let eventStore2 = try EventStore(dbPath: dbPath, jsonlPath: jsonlPath)
        let appState = AppState(eventStore: eventStore2)

        let session = Session(id: sessionId, name: "Test Session")
        appState.sessions = [session]
        appState.currentSessionId = sessionId

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Events should be loaded from persisted storage
        let loadedEvents = appState.eventsForSession(sessionId)
        XCTAssertEqual(loadedEvents.count, 1, "Should load 1 persisted event")

        // Guard against empty array
        guard loadedEvents.count >= 1 else {
            XCTFail("Not enough events loaded")
            return
        }
        if case .assistantComplete(let complete) = loadedEvents[0].event {
            XCTAssertEqual(complete.fullText, "Persisted message")
        } else {
            XCTFail("Expected assistantComplete event")
        }
    }
}

// MARK: - NDJSON Parser System Contract Tests

/// Tests for NDJSON parser invariants from Phase 2 System Contract

final class MigrationTests: XCTestCase {

    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Schema Version Tests

    func testSchemaVersionTableCreated() async throws {
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)
        _ = try await store.runMigrations()

        let version = try await store.getSchemaVersion()
        XCTAssertGreaterThan(version, 0)
    }

    func testMigrationIsIdempotent() async throws {
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)

        // Run migrations first time
        let version1 = try await store.runMigrations()

        // Run migrations second time (should be safe)
        let version2 = try await store.runMigrations()

        XCTAssertEqual(version1, version2, "Idempotent migrations should return same version")
    }

    func testSchemaVersionIncrementsOnMigration() async throws {
        let dbPath = tempDir.appendingPathComponent("test.db").path
        let store = try SessionStore(path: dbPath)

        let version = try await store.runMigrations()
        XCTAssertEqual(version, currentSchemaVersion)
    }
}

// MARK: - NDJSON Logger Tests


final class NDJSONLoggerTests: XCTestCase {

    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLogFileCreatedPerSession() async throws {
        let sessionId = UUID()
        let logger = try NDJSONLogger(sessionId: sessionId, baseDirectory: tempDir)

        let logPath = await logger.getLogPath()
        XCTAssertTrue(FileManager.default.fileExists(atPath: logPath.path))
        XCTAssertTrue(logPath.path.contains(sessionId.uuidString))
    }

    func testEventsAppendedSequentially() async throws {
        let sessionId = UUID()
        let logger = try NDJSONLogger(sessionId: sessionId, baseDirectory: tempDir)

        // Append events
        let event1 = NormalizedEvent.assistantDelta(AssistantDelta(text: "Hello", timestamp: Date()))
        let event2 = NormalizedEvent.assistantDelta(AssistantDelta(text: " World", timestamp: Date()))

        let envelope1 = EventEnvelope(sessionId: sessionId, sequence: 0, event: event1)
        let envelope2 = EventEnvelope(sessionId: sessionId, sequence: 1, event: event2)

        try await logger.append(envelope1)
        try await logger.append(envelope2)

        // Read back
        let events = try await logger.readAll()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].sequence, 0)
        XCTAssertEqual(events[1].sequence, 1)
    }

    func testListSessionsWithLogs() async throws {
        // Create logs for two sessions
        let session1 = UUID()
        let session2 = UUID()

        let logger1 = try NDJSONLogger(sessionId: session1, baseDirectory: tempDir)
        let logger2 = try NDJSONLogger(sessionId: session2, baseDirectory: tempDir)

        let event = NormalizedEvent.assistantDelta(AssistantDelta(text: "Test", timestamp: Date()))
        try await logger1.append(EventEnvelope(sessionId: session1, sequence: 0, event: event))
        try await logger2.append(EventEnvelope(sessionId: session2, sequence: 0, event: event))

        // List sessions
        let sessions = try NDJSONLogger.listSessions(baseDirectory: tempDir)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.contains(session1))
        XCTAssertTrue(sessions.contains(session2))
    }
}

// MARK: - Cache Store Tests


final class CacheStoreTests: XCTestCase {

    var tempDir: URL!
    var dbPool: DatabasePool!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbPath = tempDir.appendingPathComponent("test.db").path
        dbPool = try DatabasePool(path: dbPath)

        // Run migrations to create tables
        let migrator = MigrationRunner(dbPool: dbPool)
        _ = try await migrator.runMigrations()
    }

    override func tearDown() async throws {
        dbPool = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Helper to create a repo record for FK constraints
    private func createTestRepo(id: UUID) async throws {
        try await dbPool.write { db in
            try db.execute(
                sql: "INSERT INTO repos (id, canonical_path, created_at, updated_at) VALUES (?, ?, ?, ?)",
                arguments: [id.uuidString, "/test/repo", Date(), Date()]
            )
        }
    }

    func testFileCacheRoundTrip() async throws {
        let store = CacheStore(dbPool: dbPool)
        let repoId = UUID()

        // Create repo first for FK constraint
        try await createTestRepo(id: repoId)

        let entries = [
            FileCacheEntry(repoId: repoId, path: "src", isDirectory: true),
            FileCacheEntry(repoId: repoId, path: "src/main.swift", isDirectory: false, size: 1024),
            FileCacheEntry(repoId: repoId, path: "README.md", isDirectory: false, size: 256),
        ]

        // Cache entries
        try await store.cacheFileTree(repoId: repoId, entries: entries)

        // Retrieve entries
        let retrieved = try await store.getFileTree(repoId: repoId)
        XCTAssertEqual(retrieved.count, 3)
    }

    func testSearchIndexRoundTrip() async throws {
        let store = CacheStore(dbPool: dbPool)
        let repoId = UUID()

        // Create repo first for FK constraint
        try await createTestRepo(id: repoId)

        let entry = SearchIndexEntry(
            repoId: repoId,
            path: "src/main.swift",
            contentHash: "abc123",
            fileType: "swift",
            lineCount: 100
        )

        // Index entry
        try await store.updateSearchIndex(entry)

        // Check if needs reindexing
        let needsReindex = try await store.needsReindexing(repoId: repoId, path: "src/main.swift", contentHash: "abc123")
        XCTAssertFalse(needsReindex)

        let needsReindexChanged = try await store.needsReindexing(repoId: repoId, path: "src/main.swift", contentHash: "xyz789")
        XCTAssertTrue(needsReindexChanged)
    }

    func testCacheStatsComputation() async throws {
        let store = CacheStore(dbPool: dbPool)
        let repoId = UUID()

        // Create repo first for FK constraint
        try await createTestRepo(id: repoId)

        let entries = [
            FileCacheEntry(repoId: repoId, path: "src", isDirectory: true),
            FileCacheEntry(repoId: repoId, path: "src/a.swift", isDirectory: false),
            FileCacheEntry(repoId: repoId, path: "src/b.swift", isDirectory: false),
        ]
        try await store.cacheFileTree(repoId: repoId, entries: entries)

        let indexEntry = SearchIndexEntry(repoId: repoId, path: "src/a.swift", contentHash: "hash")
        try await store.updateSearchIndex(indexEntry)

        let stats = try await store.getCacheStats(repoId: repoId)
        XCTAssertEqual(stats.fileCount, 3)
        XCTAssertEqual(stats.directoryCount, 1)
        XCTAssertEqual(stats.indexedCount, 1)
    }
}

// MARK: - Backup Manager Tests


final class BackupManagerTests: XCTestCase {

    var tempDir: URL!
    var appSupportDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        appSupportDir = tempDir.appendingPathComponent("AppSupport")
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testExportProducesZipWithManifest() async throws {
        // Create test database
        let dbPath = appSupportDir.appendingPathComponent("blaze.sqlite")
        let db = try DatabaseQueue(path: dbPath.path)
        try await db.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO test VALUES (1)")
        }

        // Create test settings
        let settingsPath = appSupportDir.appendingPathComponent("settings.json")
        try "{\"theme\": \"dark\"}".write(to: settingsPath, atomically: true, encoding: .utf8)

        // Export backup
        let backupManager = BackupManager(appSupportPath: appSupportDir)
        let exportPath = tempDir.appendingPathComponent("backup.blazebackup")

        let manifest = try await backupManager.exportBackup(
            to: exportPath,
            includeSessionLogs: false
        )

        // Verify zip exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportPath.path))

        // Verify manifest
        XCTAssertEqual(manifest.version, BackupManager.backupVersion)
        XCTAssertGreaterThan(manifest.files.count, 0)
        XCTAssertTrue(manifest.files.contains { $0.relativePath == "blaze.sqlite" })
        XCTAssertTrue(manifest.files.contains { $0.relativePath == "settings.json" })
    }

    func testExportIncludesChecksums() async throws {
        // Create test database
        let dbPath = appSupportDir.appendingPathComponent("blaze.sqlite")
        let db = try DatabaseQueue(path: dbPath.path)
        try await db.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY)")
        }

        let backupManager = BackupManager(appSupportPath: appSupportDir)
        let exportPath = tempDir.appendingPathComponent("backup.blazebackup")

        let manifest = try await backupManager.exportBackup(
            to: exportPath,
            includeSessionLogs: false
        )

        // All files should have checksums
        for file in manifest.files {
            XCTAssertFalse(file.sha256.isEmpty, "File \(file.relativePath) should have checksum")
            XCTAssertEqual(file.sha256.count, 64, "SHA256 should be 64 hex chars")
        }
    }

    func testRestoreValidatesChecksums() async throws {
        // Create a backup first
        let dbPath = appSupportDir.appendingPathComponent("blaze.sqlite")
        let db = try DatabaseQueue(path: dbPath.path)
        try await db.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY)")
        }

        let backupManager = BackupManager(appSupportPath: appSupportDir)
        let exportPath = tempDir.appendingPathComponent("backup.blazebackup")

        _ = try await backupManager.exportBackup(
            to: exportPath,
            includeSessionLogs: false
        )

        // Validate the backup
        let validatedManifest = try await backupManager.validateBackup(at: exportPath)
        XCTAssertNotNil(validatedManifest)
    }

    func testRestoreIsAtomic() async throws {
        // Create a backup
        let dbPath = appSupportDir.appendingPathComponent("blaze.sqlite")
        let db = try DatabaseQueue(path: dbPath.path)
        try await db.write { db in
            try db.execute(sql: "CREATE TABLE test (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO test VALUES (1)")
        }

        let backupManager = BackupManager(appSupportPath: appSupportDir)
        let exportPath = tempDir.appendingPathComponent("backup.blazebackup")

        _ = try await backupManager.exportBackup(
            to: exportPath,
            includeSessionLogs: false
        )

        // Modify the original data
        try await db.write { db in
            try db.execute(sql: "INSERT INTO test VALUES (2)")
        }

        // Create new app support dir for restore
        let restoreDir = tempDir.appendingPathComponent("Restored")
        try FileManager.default.createDirectory(at: restoreDir, withIntermediateDirectories: true)

        let restoreManager = BackupManager(appSupportPath: restoreDir)
        let restoredManifest = try await restoreManager.restoreBackup(from: exportPath)

        XCTAssertNotNil(restoredManifest)

        // Verify restored database only has original data
        let restoredDbPath = restoreDir.appendingPathComponent("blaze.sqlite")
        let restoredDb = try DatabaseQueue(path: restoredDbPath.path)
        let count = try await restoredDb.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM test")
        }
        XCTAssertEqual(count, 1, "Restored DB should have original data")
    }

    func testFailedRestorePreservesData() async throws {
        // Create original data
        let originalData = "original content"
        let testFile = appSupportDir.appendingPathComponent("settings.json")
        try originalData.write(to: testFile, atomically: true, encoding: .utf8)

        // Create an invalid backup (empty zip)
        let invalidBackup = tempDir.appendingPathComponent("invalid.blazebackup")
        let invalidDir = tempDir.appendingPathComponent("invalid_content")
        try FileManager.default.createDirectory(at: invalidDir, withIntermediateDirectories: true)
        try "not json".write(to: invalidDir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", invalidBackup.path, "."]
        process.currentDirectoryURL = invalidDir
        try process.run()
        process.waitUntilExit()

        let backupManager = BackupManager(appSupportPath: appSupportDir)

        // Restore should fail
        do {
            _ = try await backupManager.restoreBackup(from: invalidBackup)
            XCTFail("Expected restore to fail")
        } catch {
            // Expected failure
        }

        // Original data should be preserved
        let preserved = try String(contentsOf: testFile)
        XCTAssertEqual(preserved, originalData, "Original data should be preserved after failed restore")
    }
}

// MARK: - Integration Tests (Phase 2.10)

/// Integration tests for session lifecycle, tool approval, and file tree operations.

