import XCTest
import GRDB
@testable import Blaze

final class ReadStateStoreTests: XCTestCase {

    var tempDir: URL!
    var dbPath: String!
    var sessionStore: SessionStore!
    var readStateStore: ReadStateStore!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("test.db").path

        // SessionStore runs migrations that create tables
        sessionStore = try SessionStore(path: dbPath)
        _ = try await sessionStore.runMigrations()

        // ReadStateStore uses same database pool
        readStateStore = ReadStateStore(dbPool: sessionStore.database)
    }

    override func tearDown() async throws {
        readStateStore = nil
        sessionStore = nil
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - ReadState Model Tests

    func testReadStateModelProperties() {
        let sessionId = UUID()
        let now = Date()
        let state = ReadState(sessionId: sessionId, lastReadSequence: 42, lastReadAt: now)

        XCTAssertEqual(state.sessionId, sessionId)
        XCTAssertEqual(state.lastReadSequence, 42)
        XCTAssertEqual(state.lastReadAt, now)
    }

    // MARK: - Get/Set Tests

    func testGetLastReadSequenceReturnsZeroForNewSession() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        let sequence = try await readStateStore.getLastReadSequence(sessionId: sessionId)
        XCTAssertEqual(sequence, 0, "New session should have lastReadSequence of 0")
    }

    func testMarkAsReadPersistsSequence() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read up to sequence 10
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 10)

        let sequence = try await readStateStore.getLastReadSequence(sessionId: sessionId)
        XCTAssertEqual(sequence, 10)
    }

    func testMarkAsReadUpdatesExistingRecord() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read multiple times
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 5)
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 15)

        let sequence = try await readStateStore.getLastReadSequence(sessionId: sessionId)
        XCTAssertEqual(sequence, 15, "Should update to latest sequence")
    }

    // MARK: - Unread Count Tests

    func testGetUnreadCountWithNoReadState() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        let unreadCount = try await readStateStore.getUnreadCount(sessionId: sessionId, totalEvents: 10)
        XCTAssertEqual(unreadCount, 10, "All events should be unread when no read state exists")
    }

    func testGetUnreadCountWithPartialRead() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read up to sequence 5
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 5)

        let unreadCount = try await readStateStore.getUnreadCount(sessionId: sessionId, totalEvents: 10)
        XCTAssertEqual(unreadCount, 5, "Should have 5 unread events (10 - 5)")
    }

    func testGetUnreadCountWithAllRead() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read up to sequence 10
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 10)

        let unreadCount = try await readStateStore.getUnreadCount(sessionId: sessionId, totalEvents: 10)
        XCTAssertEqual(unreadCount, 0, "Should have 0 unread events when all are read")
    }

    func testGetUnreadCountNeverNegative() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read beyond total events
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 100)

        let unreadCount = try await readStateStore.getUnreadCount(sessionId: sessionId, totalEvents: 10)
        XCTAssertEqual(unreadCount, 0, "Unread count should not be negative")
    }

    // MARK: - Load All States Tests

    func testLoadAllReadStatesReturnsEmpty() async throws {
        let states = try await readStateStore.loadAllReadStates()
        XCTAssertTrue(states.isEmpty, "Should return empty dictionary for fresh database")
    }

    func testLoadAllReadStatesReturnsMultipleSessions() async throws {
        let sessionId1 = UUID()
        let sessionId2 = UUID()

        // Create sessions in database
        try await sessionStore.create(Session(id: sessionId1, name: "Session 1"))
        try await sessionStore.create(Session(id: sessionId2, name: "Session 2"))

        // Mark read states
        try await readStateStore.markAsRead(sessionId: sessionId1, sequence: 5)
        try await readStateStore.markAsRead(sessionId: sessionId2, sequence: 10)

        let states = try await readStateStore.loadAllReadStates()
        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states[sessionId1]?.lastReadSequence, 5)
        XCTAssertEqual(states[sessionId2]?.lastReadSequence, 10)
    }

    // MARK: - Persistence Tests

    func testReadStatePersistsAcrossStoreInstances() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 42)

        // Create new store instance with same database
        let newStore = ReadStateStore(dbPool: sessionStore.database)

        let sequence = try await newStore.getLastReadSequence(sessionId: sessionId)
        XCTAssertEqual(sequence, 42, "Read state should persist across store instances")
    }

    // MARK: - Edge Cases

    func testMarkAsReadWithSequenceZero() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Mark as read with sequence 0 (explicit "nothing read")
        try await readStateStore.markAsRead(sessionId: sessionId, sequence: 0)

        let sequence = try await readStateStore.getLastReadSequence(sessionId: sessionId)
        XCTAssertEqual(sequence, 0)
    }

    func testConcurrentMarksAsRead() async throws {
        let sessionId = UUID()

        // Create session in database
        let session = Session(id: sessionId, name: "Test Session")
        try await sessionStore.create(session)

        // Concurrent writes
        async let mark1: Void = readStateStore.markAsRead(sessionId: sessionId, sequence: 5)
        async let mark2: Void = readStateStore.markAsRead(sessionId: sessionId, sequence: 10)
        async let mark3: Void = readStateStore.markAsRead(sessionId: sessionId, sequence: 15)

        try await mark1
        try await mark2
        try await mark3

        let sequence = try await readStateStore.getLastReadSequence(sessionId: sessionId)
        // One of the writes should succeed - we expect 15 since it's the highest
        XCTAssertGreaterThanOrEqual(sequence, 5)
    }
}
