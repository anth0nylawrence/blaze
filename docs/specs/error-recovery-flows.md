# Error Recovery Flows Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines how Blaze handles failures across all components: CLI crashes, database errors, hook timeouts, network failures, and app crashes. Each failure scenario has a defined state machine, retry policy, and user notification strategy.

**Why This Matters:** Production apps need resilience. Without this spec, errors will be handled ad-hoc, leading to data loss and poor UX.

---

## Table of Contents

1. [Error Categories](#1-error-categories)
2. [ProcessRunner Recovery](#2-processrunner-recovery)
3. [Database Recovery](#3-database-recovery)
4. [Hook Execution Recovery](#4-hook-execution-recovery)
5. [Network Recovery](#5-network-recovery)
6. [App Crash Recovery](#6-app-crash-recovery)
7. [User Notification Strategy](#7-user-notification-strategy)
8. [Implementation](#8-implementation)

---

## 1. Error Categories

### 1.1 Error Taxonomy

| Category | Severity | Recoverable | Example |
|----------|----------|-------------|---------|
| **Transient** | Low | Yes (auto-retry) | Network timeout, rate limit |
| **Degraded** | Medium | Partial | Database slow, CLI unresponsive |
| **Fatal** | High | No (user action) | Auth expired, disk full |
| **Catastrophic** | Critical | Manual | Data corruption, hard crash |

### 1.2 Error Source Matrix

| Source | Transient | Degraded | Fatal | Catastrophic |
|--------|-----------|----------|-------|--------------|
| **CLI Process** | Timeout | Hung process | Exit code ≠ 0 | SIGKILL |
| **LanceDB** | Lock contention | Slow query | Schema mismatch | Corruption |
| **JSONL Journal** | Write delay | Disk full warning | Permission denied | Corrupt file |
| **Hooks** | Timeout | Slow execution | Script error | Infinite loop |
| **Network** | Timeout | High latency | DNS failure | No connectivity |
| **Memory** | GC pause | High usage | OOM warning | OOM kill |

---

## 2. ProcessRunner Recovery

### 2.1 State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CLI PROCESS STATE MACHINE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│       ┌────────────┐                                                │
│       │   Idle     │                                                │
│       └─────┬──────┘                                                │
│             │ spawn()                                               │
│             ▼                                                        │
│       ┌────────────┐                                                │
│       │  Starting  │──────────────────┐                             │
│       └─────┬──────┘                  │ timeout (30s)               │
│             │ process started         │                             │
│             ▼                         ▼                             │
│       ┌────────────┐           ┌────────────┐                       │
│       │  Running   │           │  Failed    │◀──────┐               │
│       └─────┬──────┘           └─────┬──────┘       │               │
│             │                        │              │               │
│    ┌────────┼────────┐               │ can retry?   │               │
│    │        │        │               │              │               │
│    │ stdout │ stderr │         ┌─────┴─────┐       │               │
│    │        │        │         │ Yes  │ No │       │               │
│    ▼        ▼        ▼         ▼      ▼    ▼       │               │
│ ┌──────┐ ┌──────┐ ┌──────┐  ┌────┐  ┌─────────┐   │               │
│ │Stream│ │Stream│ │ Exit │  │Wait│  │Terminal │   │               │
│ │ Data │ │ Data │ │      │  │    │  │ Error   │   │               │
│ └──────┘ └──────┘ └──┬───┘  └─┬──┘  └─────────┘   │               │
│                      │        │ backoff            │               │
│    ┌─────────────────┤        │                    │               │
│    │                 │        ▼                    │               │
│    │ code = 0        │   ┌────────────┐           │               │
│    ▼                 ▼   │  Retrying  │───────────┘               │
│ ┌──────┐        ┌──────┐ └────────────┘                            │
│ │ Done │        │Error │    │ spawn()                              │
│ └──────┘        └──────┘    │                                      │
│                             ▼                                       │
│                       (back to Starting)                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Failure Scenarios

| Scenario | Detection | Recovery Action |
|----------|-----------|-----------------|
| **Process won't start** | No PID after 5s | Retry 3x, then report auth/path issue |
| **Process hangs** | No output for 120s | Send SIGINT, wait 5s, SIGKILL |
| **Process crashes** | Exit code ≠ 0 | Log stderr, offer retry |
| **OOM killed** | Exit code = 137 | Suggest smaller context, offer retry |
| **Malformed output** | JSON parse error | Log raw output, continue with fallback |
| **Partial line** | Incomplete NDJSON | Buffer until newline, timeout after 30s |

### 2.3 Retry Policy

```swift
struct ProcessRetryPolicy {
    let maxRetries: Int = 3
    let baseDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 30.0
    let backoffMultiplier: Double = 2.0

    func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }

    func shouldRetry(error: ProcessError, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        switch error {
        case .timeout, .interrupted:
            return true
        case .exitCode(let code) where code == 1:
            return true // Generic error, worth retrying
        case .exitCode(let code) where code == 137:
            return false // OOM, don't retry without changes
        case .authFailure:
            return false // Need user intervention
        default:
            return false
        }
    }
}
```

### 2.4 Graceful Shutdown

```swift
func cancel(handle: ProcessHandle, gracePeriod: TimeInterval = 5.0) async {
    // Step 1: Send SIGINT (graceful)
    handle.process.interrupt()

    // Step 2: Wait for graceful exit
    let gracefulExit = await withTimeout(gracePeriod) {
        await handle.process.waitUntilExit()
    }

    if gracefulExit {
        return // Process exited gracefully
    }

    // Step 3: Force kill if still running
    handle.process.terminate() // SIGKILL

    // Step 4: Wait for termination
    await handle.process.waitUntilExit()

    // Step 5: Log forced termination
    await auditLog.record(.forcedTermination(pid: handle.process.processIdentifier))
}
```

---

## 3. Database Recovery

### 3.1 LanceDB Error Handling

| Error | Detection | Recovery |
|-------|-----------|----------|
| **Lock contention** | Transaction timeout | Retry with exponential backoff |
| **Disk full** | Write failure | Alert user, suggest cleanup |
| **Schema mismatch** | Version check fail | Run migration, or fail gracefully |
| **Corruption** | Read error / CRC mismatch | Attempt repair, fallback to JSONL |

### 3.2 JSONL Journal Guarantees

The append-only JSONL journal is the **crash-safe source of truth**:

```
Write Flow:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Event     │───▶│   JSONL     │───▶│   LanceDB   │
│   Received  │    │   Append    │    │   Insert    │
└─────────────┘    └──────┬──────┘    └──────┬──────┘
                          │                  │
                    fsync BEFORE        async (can fail)
                    returning               │
                          │                  │
                    ┌─────▼─────┐      ┌─────▼─────┐
                    │ Persisted │      │  Indexed  │
                    │  (safe)   │      │ (optional)│
                    └───────────┘      └───────────┘
```

**Recovery Flow:**
```swift
func recoverFromJournal(sessionId: Session.ID) async throws {
    let journalPath = eventJournalPath(for: sessionId)

    // Read JSONL file
    guard let data = FileManager.default.contents(atPath: journalPath.path) else {
        throw RecoveryError.journalNotFound
    }

    // Parse line by line
    let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []

    for (index, line) in lines.enumerated() {
        do {
            let event = try JSONDecoder().decode(EventEnvelope.self, from: Data(line.utf8))

            // Check if already in LanceDB
            if await lanceDB.exists(eventId: event.id) {
                continue // Already recovered
            }

            // Insert into LanceDB
            try await lanceDB.insert(event)

        } catch {
            // Log parse error but continue
            await errorLog.record(.journalParseError(line: index, error: error))
        }
    }
}
```

### 3.3 Transaction Safety

```swift
func writeEvent(_ event: EventEnvelope) async throws {
    // Step 1: Append to JSONL (synchronous, fsync)
    try appendToJournal(event)

    // Step 2: Insert to LanceDB (async, can fail)
    Task {
        do {
            try await lanceDB.insert(event)
        } catch {
            // LanceDB insert failed, but JSONL has it
            // Will be recovered on next startup
            await errorLog.record(.lanceDBInsertFailed(eventId: event.id, error: error))
        }
    }
}

func appendToJournal(_ event: EventEnvelope) throws {
    let data = try JSONEncoder().encode(event)
    let line = data + Data("\n".utf8)

    let handle = try FileHandle(forWritingTo: journalPath)
    defer { try? handle.close() }

    handle.seekToEndOfFile()
    handle.write(line)
    try handle.synchronize() // fsync
}
```

---

## 4. Hook Execution Recovery

### 4.1 Hook State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                      HOOK EXECUTION STATES                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│     ┌────────┐                                                      │
│     │ Queued │                                                      │
│     └───┬────┘                                                      │
│         │ dispatch()                                                │
│         ▼                                                            │
│     ┌────────┐     timeout (configurable)                           │
│     │Running │─────────────────────────────┐                        │
│     └───┬────┘                             │                        │
│         │                                  │                        │
│    ┌────┼────┐                             │                        │
│    │    │    │                             │                        │
│ exit=0 exit≠0 no exit                      │                        │
│    │    │    │                             │                        │
│    ▼    ▼    ▼                             ▼                        │
│ ┌──────┐ ┌──────┐ ┌────────────┐    ┌───────────┐                  │
│ │ Done │ │Failed│ │ Unresponsive│    │ Timed Out │                  │
│ └──────┘ └──────┘ └─────┬──────┘    └─────┬─────┘                  │
│                         │                  │                        │
│                         │ SIGKILL          │ SIGKILL                │
│                         ▼                  ▼                        │
│                    ┌────────────────────────────┐                   │
│                    │    Force Terminated        │                   │
│                    └────────────────────────────┘                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Timeout Handling

```swift
struct HookExecutor {
    func execute(hook: Hook, event: EventEnvelope) async -> HookResult {
        let timeout = hook.timeoutMs ?? 5000 // Default 5s

        return await withTimeout(TimeInterval(timeout) / 1000) {
            // Run hook script
            let output = try await runScript(
                path: hook.scriptPath,
                input: event.toJSON(),
                environment: hook.environment
            )
            return .success(output)

        } onTimeout: {
            // Force kill
            await killHookProcess(hook)
            return .timeout(duration: timeout)
        }
    }

    private func killHookProcess(_ hook: Hook) async {
        // Send SIGKILL
        if let pid = activeHookProcesses[hook.id] {
            kill(pid, SIGKILL)
            await errorLog.record(.hookForceKilled(hookId: hook.id))
        }
    }
}
```

### 4.3 Hook Failure Policy

| Failure Type | Blaze Behavior | User Notification |
|--------------|----------------|-------------------|
| **Timeout** | Kill hook, continue | Toast: "Hook timed out" |
| **Exit code ≠ 0** | Log error, continue | Toast: "Hook failed" |
| **Missing script** | Disable hook, continue | Alert: "Hook not found" |
| **Permission denied** | Disable hook, alert | Alert: "Hook permission error" |
| **Infinite loop** | Detect high CPU, kill | Toast: "Hook killed (runaway)" |

**Key Principle:** Hook failures should **never** block the main workflow.

---

## 5. Network Recovery

### 5.1 Retry Strategy

```swift
struct NetworkRetryPolicy {
    let maxRetries: Int = 5
    let initialDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 60.0
    let jitter: Double = 0.2 // 20% random jitter

    func execute<T>(
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch let error as NetworkError where error.isRetryable {
                lastError = error

                let delay = calculateDelay(attempt: attempt)
                await notifyRetrying(attempt: attempt, delay: delay)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw NetworkError.exhaustedRetries(underlying: lastError)
    }

    private func calculateDelay(attempt: Int) -> TimeInterval {
        let exponential = initialDelay * pow(2, Double(attempt - 1))
        let capped = min(exponential, maxDelay)
        let jitterRange = capped * jitter
        let randomJitter = Double.random(in: -jitterRange...jitterRange)
        return capped + randomJitter
    }
}
```

### 5.2 Offline Mode

When network is unavailable:

```swift
enum NetworkState {
    case online
    case offline
    case degraded(latency: TimeInterval)
}

@MainActor
class NetworkMonitor: ObservableObject {
    @Published private(set) var state: NetworkState = .online

    func handleOffline() {
        state = .offline

        // Disable features requiring network
        engineManager.pauseAllSessions()

        // Notify user
        notificationCenter.post(.networkOffline)

        // Queue pending operations for retry
        operationQueue.pauseAndQueue()
    }

    func handleOnline() {
        state = .online

        // Resume queued operations
        operationQueue.resume()

        // Notify user
        notificationCenter.post(.networkRestored)
    }
}
```

---

## 6. App Crash Recovery

### 6.1 Crash Detection

On app launch, check for incomplete sessions:

```swift
func checkForCrashRecovery() async {
    // Step 1: Find sessions marked as "active" in last run
    let incompleteSessions = await sessionStore.findIncompleteSessions()

    if incompleteSessions.isEmpty {
        return // Clean shutdown last time
    }

    // Step 2: For each incomplete session, recover from JSONL
    for session in incompleteSessions {
        do {
            try await recoverSession(session)
        } catch {
            await errorLog.record(.recoveryFailed(sessionId: session.id, error: error))
        }
    }

    // Step 3: Notify user
    if !incompleteSessions.isEmpty {
        await notifyRecoveredSessions(count: incompleteSessions.count)
    }
}

func recoverSession(_ session: Session) async throws {
    // Recover events from JSONL
    try await recoverFromJournal(sessionId: session.id)

    // Update session state
    await sessionStore.updateState(session.id, to: .idle)

    // Log recovery
    await auditLog.record(.sessionRecovered(sessionId: session.id))
}
```

### 6.2 State Persistence Checkpoints

```swift
struct StateCheckpoint {
    let timestamp: Date
    let sessionStates: [Session.ID: SessionState]
    let activeProcesses: [Session.ID: ProcessInfo]
    let pendingApprovals: [ApprovalRequest]
}

actor CheckpointManager {
    private var lastCheckpoint: StateCheckpoint?
    private let checkpointInterval: TimeInterval = 10.0 // Every 10s

    func startCheckpointing() {
        Task {
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: UInt64(checkpointInterval * 1_000_000_000))
                await saveCheckpoint()
            }
        }
    }

    func saveCheckpoint() async {
        let checkpoint = StateCheckpoint(
            timestamp: Date(),
            sessionStates: await sessionManager.getAllStates(),
            activeProcesses: await processManager.getActiveProcesses(),
            pendingApprovals: await approvalManager.getPending()
        )

        do {
            let data = try JSONEncoder().encode(checkpoint)
            try data.write(to: checkpointPath, options: .atomic)
            lastCheckpoint = checkpoint
        } catch {
            await errorLog.record(.checkpointFailed(error: error))
        }
    }

    func loadLastCheckpoint() async throws -> StateCheckpoint? {
        guard FileManager.default.fileExists(atPath: checkpointPath.path) else {
            return nil
        }

        let data = try Data(contentsOf: checkpointPath)
        return try JSONDecoder().decode(StateCheckpoint.self, from: data)
    }
}
```

### 6.3 Data Integrity Verification

```swift
func verifyDataIntegrity() async throws {
    // Verify JSONL files
    let journals = try FileManager.default.contentsOfDirectory(at: journalsPath)
    for journal in journals {
        try await verifyJournal(journal)
    }

    // Verify LanceDB
    try await lanceDB.verifyIntegrity()

    // Cross-check counts
    let journalEventCount = try await countEventsInJournals()
    let dbEventCount = try await lanceDB.countEvents()

    if journalEventCount != dbEventCount {
        await errorLog.record(.eventCountMismatch(
            journal: journalEventCount,
            database: dbEventCount
        ))

        // Trigger recovery
        try await reconcileEvents()
    }
}
```

---

## 7. User Notification Strategy

### 7.1 Notification Types

| Type | Severity | UI Element | Auto-Dismiss |
|------|----------|------------|--------------|
| **Toast** | Low | Bottom-right toast | Yes (5s) |
| **Banner** | Medium | Top banner | No |
| **Alert** | High | Modal dialog | No |
| **Critical** | Critical | Modal + sound | No |

### 7.2 Message Templates

```swift
enum ErrorNotification {
    case processTimeout(tool: String)
    case hookFailed(hookName: String)
    case networkOffline
    case networkRestored
    case recoveredSessions(count: Int)
    case databaseError(details: String)
    case authExpired(engine: String)

    var title: String {
        switch self {
        case .processTimeout: return "Process Timed Out"
        case .hookFailed: return "Hook Failed"
        case .networkOffline: return "Offline"
        case .networkRestored: return "Back Online"
        case .recoveredSessions: return "Sessions Recovered"
        case .databaseError: return "Database Error"
        case .authExpired: return "Authentication Required"
        }
    }

    var body: String {
        switch self {
        case .processTimeout(let tool):
            return "The \(tool) command took too long and was cancelled."
        case .hookFailed(let hookName):
            return "The \(hookName) hook encountered an error."
        case .networkOffline:
            return "No network connection. Some features are unavailable."
        case .networkRestored:
            return "Network connection restored."
        case .recoveredSessions(let count):
            return "\(count) session(s) recovered from last session."
        case .databaseError(let details):
            return "Database error: \(details)"
        case .authExpired(let engine):
            return "\(engine) authentication expired. Please log in again."
        }
    }

    var severity: NotificationSeverity {
        switch self {
        case .processTimeout, .hookFailed: return .low
        case .networkOffline, .recoveredSessions, .databaseError: return .medium
        case .authExpired: return .high
        case .networkRestored: return .low
        }
    }

    var actions: [NotificationAction] {
        switch self {
        case .processTimeout:
            return [.retry, .dismiss]
        case .hookFailed:
            return [.viewDetails, .disableHook, .dismiss]
        case .authExpired(let engine):
            return [.login(engine: engine), .dismiss]
        default:
            return [.dismiss]
        }
    }
}
```

### 7.3 Notification Queue

```swift
@MainActor
class NotificationManager: ObservableObject {
    @Published private(set) var activeNotifications: [ErrorNotification] = []
    @Published private(set) var toastQueue: [ErrorNotification] = []

    func notify(_ notification: ErrorNotification) {
        switch notification.severity {
        case .low:
            toastQueue.append(notification)
            scheduleAutoDismiss(notification)
        case .medium:
            activeNotifications.append(notification)
        case .high, .critical:
            // Modal handled separately
            showModal(notification)
        }
    }

    private func scheduleAutoDismiss(_ notification: ErrorNotification) {
        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            toastQueue.removeAll { $0.id == notification.id }
        }
    }
}
```

---

## 8. Implementation

### 8.1 Central Error Handler

```swift
actor ErrorCoordinator {
    private let processRunner: ProcessRunner
    private let lanceDB: LanceDBStore
    private let notificationManager: NotificationManager
    private let auditLog: AuditLog

    func handle(_ error: Error, context: ErrorContext) async {
        // Log error
        await auditLog.record(error, context: context)

        // Categorize
        let category = categorize(error)

        // Take action based on category
        switch category {
        case .transient:
            // Handled by retry policies
            break

        case .degraded:
            await notificationManager.notify(.degradedPerformance(details: error.localizedDescription))

        case .fatal:
            await notificationManager.notify(.fatalError(error))
            await gracefulShutdown()

        case .catastrophic:
            await emergencyShutdown()
        }
    }

    private func categorize(_ error: Error) -> ErrorCategory {
        switch error {
        case let networkError as NetworkError where networkError.isRetryable:
            return .transient
        case is DatabaseLockError:
            return .transient
        case is OOMError:
            return .fatal
        case is CorruptionError:
            return .catastrophic
        default:
            return .degraded
        }
    }
}
```

### 8.2 Error Types

```swift
enum ProcessError: Error {
    case spawnFailed(reason: String)
    case timeout(duration: TimeInterval)
    case exitCode(Int32)
    case interrupted
    case authFailure
    case malformedOutput(line: String)
}

enum DatabaseError: Error {
    case lockContention
    case diskFull
    case schemaMismatch(expected: Int, actual: Int)
    case corruption(details: String)
    case queryTimeout
}

enum HookError: Error {
    case timeout(hookId: Hook.ID, duration: TimeInterval)
    case scriptNotFound(path: String)
    case permissionDenied
    case executionFailed(exitCode: Int32, stderr: String)
    case runaway(cpuUsage: Double)
}

enum NetworkError: Error {
    case timeout
    case noConnection
    case dnsFailure
    case sslError
    case serverError(statusCode: Int)

    var isRetryable: Bool {
        switch self {
        case .timeout, .noConnection, .serverError(let code) where code >= 500:
            return true
        default:
            return false
        }
    }
}
```

---

## Acceptance Criteria

- [ ] Process crashes logged and recoverable
- [ ] JSONL journal always persisted before returning
- [ ] LanceDB failures don't block main workflow
- [ ] Hook timeouts enforced and logged
- [ ] Network retries with exponential backoff
- [ ] App restart recovers incomplete sessions
- [ ] User notifications for all failure types
- [ ] No data loss in any failure scenario

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
