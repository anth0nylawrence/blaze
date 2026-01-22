# Session State Machine Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines the formal state machine for Blaze sessions. A session represents a conversation with an AI engine, and its state determines what actions are valid, how the UI renders, and how errors are handled.

**Why This Matters:** Without clear state definitions, the UI will be inconsistent, actions will be allowed at wrong times, and debugging will be difficult.

---

## Table of Contents

1. [Session States](#1-session-states)
2. [State Transitions](#2-state-transitions)
3. [Actions & Permissions](#3-actions--permissions)
4. [UI Implications](#4-ui-implications)
5. [Persistence](#5-persistence)
6. [Implementation](#6-implementation)

---

## 1. Session States

### 1.1 State Definitions

| State | Description | UI Indicator |
|-------|-------------|--------------|
| `idle` | Session created, no active conversation | Gray indicator |
| `starting` | CLI process spawning | Spinner |
| `active` | CLI running, waiting for input/output | Green indicator |
| `streaming` | Receiving streamed response | Pulsing green + typing indicator |
| `waiting` | Waiting for user action (approval, input) | Yellow indicator |
| `error` | Recoverable error occurred | Red indicator |
| `closing` | Session ending, cleanup in progress | Fading indicator |
| `closed` | Session ended, read-only | No indicator |

### 1.2 State Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SESSION STATE MACHINE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                              ┌──────────┐                                   │
│                              │  closed  │◀─────────────────────────┐        │
│                              └──────────┘                          │        │
│                                   ▲                                │        │
│                                   │ cleanup complete               │        │
│                                   │                                │        │
│                              ┌──────────┐                          │        │
│                        ┌────▶│ closing  │◀────────────────────┐    │        │
│                        │     └──────────┘                     │    │        │
│                        │          ▲                           │    │        │
│                        │          │ close()                   │    │        │
│                        │          │                           │    │        │
│     ┌──────────┐   spawn()   ┌──────────┐    receive()   ┌──────────┐      │
│     │   idle   │────────────▶│ starting │───────────────▶│  active  │      │
│     └──────────┘             └──────────┘                └────┬─────┘      │
│          ▲                        │                           │     │      │
│          │                        │ error                     │     │      │
│          │                        ▼                           │     │      │
│          │                   ┌──────────┐◀────────────────────┼─────┘      │
│          │                   │  error   │                     │ error      │
│          │                   └────┬─────┘                     │            │
│          │                        │                           │            │
│          │                   retry│                           │            │
│          └────────────────────────┘                           │            │
│                                                               │            │
│                                                          stream│            │
│                                                               │            │
│                                                               ▼            │
│                                                         ┌──────────┐       │
│                                            ┌───────────▶│streaming │       │
│                                            │            └────┬─────┘       │
│                                            │                 │             │
│                                       input│            done │             │
│                                            │                 │             │
│                                       ┌────┴─────┐           │             │
│                                       │ waiting  │◀──────────┘             │
│                                       └────┬─────┘                         │
│                                            │                               │
│                                       response                             │
│                                            │                               │
│                                            └───────────────▶ active        │
│                                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 State Properties

```swift
enum SessionState: String, Codable {
    case idle
    case starting
    case active
    case streaming
    case waiting
    case error
    case closing
    case closed

    var isTerminal: Bool {
        self == .closed
    }

    var allowsInput: Bool {
        switch self {
        case .idle, .active, .waiting:
            return true
        default:
            return false
        }
    }

    var allowsCancel: Bool {
        switch self {
        case .starting, .active, .streaming:
            return true
        default:
            return false
        }
    }

    var isActive: Bool {
        switch self {
        case .starting, .active, .streaming, .waiting:
            return true
        default:
            return false
        }
    }

    var showsSpinner: Bool {
        switch self {
        case .starting, .streaming:
            return true
        default:
            return false
        }
    }
}
```

---

## 2. State Transitions

### 2.1 Valid Transitions

| From State | To State | Trigger | Side Effects |
|------------|----------|---------|--------------|
| `idle` | `starting` | User sends message | Spawn CLI process |
| `starting` | `active` | CLI process started | Begin event stream |
| `starting` | `error` | Spawn failed | Log error |
| `active` | `streaming` | First token received | Show typing indicator |
| `active` | `waiting` | Approval required | Show approval dialog |
| `active` | `error` | CLI error | Log error, show UI |
| `active` | `closing` | User closes session | Begin cleanup |
| `streaming` | `active` | Stream complete | Update last message |
| `streaming` | `waiting` | Approval required | Pause stream, show dialog |
| `streaming` | `error` | Stream error | Log partial, show error |
| `waiting` | `active` | User responds | Resume/reject action |
| `waiting` | `closing` | User closes | Cancel pending action |
| `error` | `idle` | User retries | Reset state |
| `error` | `closing` | User closes | Begin cleanup |
| `closing` | `closed` | Cleanup complete | Archive session |

### 2.2 Invalid Transitions

These transitions are **never allowed**:

| From | To | Reason |
|------|-----|--------|
| `closed` | Any | Terminal state |
| `idle` | `streaming` | Must go through `starting` |
| `streaming` | `idle` | Must complete or error |
| `waiting` | `streaming` | Must go through `active` |

### 2.3 Transition Validation

```swift
struct SessionStateMachine {
    private(set) var currentState: SessionState

    mutating func transition(to newState: SessionState) throws {
        guard isValidTransition(from: currentState, to: newState) else {
            throw SessionError.invalidTransition(from: currentState, to: newState)
        }

        currentState = newState
    }

    private func isValidTransition(from: SessionState, to: SessionState) -> Bool {
        let validTransitions: [SessionState: Set<SessionState>] = [
            .idle: [.starting],
            .starting: [.active, .error],
            .active: [.streaming, .waiting, .error, .closing],
            .streaming: [.active, .waiting, .error],
            .waiting: [.active, .closing],
            .error: [.idle, .closing],
            .closing: [.closed],
            .closed: []
        ]

        return validTransitions[from]?.contains(to) ?? false
    }
}
```

---

## 3. Actions & Permissions

### 3.1 Action Matrix

| Action | idle | starting | active | streaming | waiting | error | closing | closed |
|--------|------|----------|--------|-----------|---------|-------|---------|--------|
| Send message | Yes | No | Yes | No | Depends | No | No | No |
| Cancel | No | Yes | Yes | Yes | Yes | No | No | No |
| Retry | No | No | No | No | No | Yes | No | No |
| Close | Yes | Yes | Yes | Yes | Yes | Yes | No | No |
| Fork | Yes | No | Yes | No | No | No | No | Yes |
| Export | Yes | No | Yes | No | No | No | No | Yes |
| View history | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |

### 3.2 Action Handlers

```swift
@MainActor
class SessionController: ObservableObject {
    @Published private(set) var session: Session
    private var stateMachine: SessionStateMachine

    func sendMessage(_ content: String) async throws {
        guard stateMachine.currentState.allowsInput else {
            throw SessionError.actionNotAllowed("sendMessage", in: stateMachine.currentState)
        }

        if stateMachine.currentState == .idle {
            try stateMachine.transition(to: .starting)
            try await startEngine()
        }

        try await engineAdapter.send(message: content)
        try stateMachine.transition(to: .streaming)
    }

    func cancel() async throws {
        guard stateMachine.currentState.allowsCancel else {
            throw SessionError.actionNotAllowed("cancel", in: stateMachine.currentState)
        }

        try await engineAdapter.cancel()
        try stateMachine.transition(to: .active)
    }

    func retry() async throws {
        guard stateMachine.currentState == .error else {
            throw SessionError.actionNotAllowed("retry", in: stateMachine.currentState)
        }

        try stateMachine.transition(to: .idle)
        // Re-attempt last action
        if let lastMessage = session.lastUserMessage {
            try await sendMessage(lastMessage.content)
        }
    }

    func close() async throws {
        guard !stateMachine.currentState.isTerminal else {
            return // Already closed
        }

        try stateMachine.transition(to: .closing)
        await performCleanup()
        try stateMachine.transition(to: .closed)
    }
}
```

---

## 4. UI Implications

### 4.1 Visual States

```swift
struct SessionIndicator: View {
    let state: SessionState

    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 8, height: 8)
            .overlay(spinnerOverlay)
    }

    private var indicatorColor: Color {
        switch state {
        case .idle, .closing, .closed:
            return .secondary
        case .starting:
            return .blue
        case .active:
            return .green
        case .streaming:
            return .green
        case .waiting:
            return .yellow
        case .error:
            return .red
        }
    }

    @ViewBuilder
    private var spinnerOverlay: some View {
        if state.showsSpinner {
            ProgressView()
                .scaleEffect(0.5)
        }
    }
}
```

### 4.2 Input Field States

```swift
struct MessageInputField: View {
    @ObservedObject var controller: SessionController

    var body: some View {
        TextField("Message...", text: $inputText)
            .disabled(!controller.session.state.allowsInput)
            .onSubmit { sendMessage() }
            .overlay(alignment: .trailing) {
                submitButton
            }
    }

    @ViewBuilder
    private var submitButton: some View {
        switch controller.session.state {
        case .streaming:
            Button(action: { controller.cancel() }) {
                Image(systemName: "stop.circle.fill")
            }
        case .idle, .active:
            Button(action: { sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
            }
        default:
            EmptyView()
        }
    }
}
```

### 4.3 Session List Item

```swift
struct SessionListRow: View {
    let session: Session

    var body: some View {
        HStack {
            SessionIndicator(state: session.state)

            VStack(alignment: .leading) {
                Text(session.name)
                    .fontWeight(session.state.isActive ? .semibold : .regular)

                Text(stateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.state == .streaming {
                typingIndicator
            }
        }
    }

    private var stateDescription: String {
        switch session.state {
        case .idle:
            return "Ready"
        case .starting:
            return "Starting..."
        case .active:
            return "Active"
        case .streaming:
            return "Responding..."
        case .waiting:
            return "Waiting for approval"
        case .error:
            return "Error occurred"
        case .closing:
            return "Closing..."
        case .closed:
            return "Closed"
        }
    }
}
```

---

## 5. Persistence

### 5.1 State Storage

Session state is persisted in LanceDB with JSONL journaling:

```swift
struct SessionRecord: Codable {
    let id: UUID
    var name: String
    let projectId: UUID
    let engineType: EngineType
    var state: SessionState
    let createdAt: Date
    var lastActivityAt: Date
    var eventCount: Int
    var metadata: [String: String]
}
```

### 5.2 State Recovery

On app startup, recover session states:

```swift
func recoverSessionStates() async {
    let sessions = await sessionStore.getAll()

    for session in sessions {
        switch session.state {
        case .starting, .streaming, .active:
            // These states indicate crash during activity
            await sessionStore.updateState(session.id, to: .error)
            await notifyRecoveredSession(session)

        case .waiting:
            // Approval was pending - need to re-request
            await sessionStore.updateState(session.id, to: .error)

        case .closing:
            // Cleanup was interrupted
            await performCleanup(session)
            await sessionStore.updateState(session.id, to: .closed)

        case .idle, .error, .closed:
            // These are valid recovery states
            break
        }
    }
}
```

### 5.3 State Change Logging

Every state transition is logged:

```swift
struct StateChangeEvent: Codable {
    let sessionId: UUID
    let timestamp: Date
    let fromState: SessionState
    let toState: SessionState
    let trigger: String
    let metadata: [String: String]?
}

func logStateChange(
    session: Session,
    from: SessionState,
    to: SessionState,
    trigger: String
) async {
    let event = StateChangeEvent(
        sessionId: session.id,
        timestamp: Date(),
        fromState: from,
        toState: to,
        trigger: trigger,
        metadata: nil
    )

    await eventLog.append(event)
}
```

---

## 6. Implementation

### 6.1 SessionManager Integration

```swift
@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var activeSessionId: Session.ID?

    private var stateMachines: [Session.ID: SessionStateMachine] = [:]

    func createSession(
        project: Project,
        engine: EngineType,
        name: String? = nil
    ) async throws -> Session {
        let session = Session(
            id: UUID(),
            name: name ?? "New Session",
            projectId: project.id,
            engineType: engine,
            state: .idle,
            createdAt: Date(),
            lastActivityAt: Date()
        )

        sessions.append(session)
        stateMachines[session.id] = SessionStateMachine(currentState: .idle)

        await sessionStore.insert(session)

        return session
    }

    func transition(
        _ sessionId: Session.ID,
        to newState: SessionState,
        trigger: String = "unknown"
    ) async throws {
        guard var stateMachine = stateMachines[sessionId] else {
            throw SessionError.sessionNotFound(sessionId)
        }

        let fromState = stateMachine.currentState
        try stateMachine.transition(to: newState)
        stateMachines[sessionId] = stateMachine

        // Update session object
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].state = newState
            sessions[index].lastActivityAt = Date()
        }

        // Persist state
        await sessionStore.updateState(sessionId, to: newState)

        // Log transition
        await logStateChange(
            session: sessions.first { $0.id == sessionId }!,
            from: fromState,
            to: newState,
            trigger: trigger
        )
    }
}
```

### 6.2 Concurrency Safety

```swift
// State machine is value type for thread safety
struct SessionStateMachine {
    private(set) var currentState: SessionState

    // Transitions are atomic via actor isolation
}

// SessionManager is MainActor-isolated
@MainActor
final class SessionManager: ObservableObject {
    // All mutations happen on main thread
}
```

### 6.3 Testing

```swift
final class SessionStateMachineTests: XCTestCase {
    func testValidTransitions() {
        var sm = SessionStateMachine(currentState: .idle)

        XCTAssertNoThrow(try sm.transition(to: .starting))
        XCTAssertEqual(sm.currentState, .starting)

        XCTAssertNoThrow(try sm.transition(to: .active))
        XCTAssertEqual(sm.currentState, .active)

        XCTAssertNoThrow(try sm.transition(to: .streaming))
        XCTAssertEqual(sm.currentState, .streaming)
    }

    func testInvalidTransitions() {
        var sm = SessionStateMachine(currentState: .closed)

        XCTAssertThrowsError(try sm.transition(to: .idle))
        XCTAssertThrowsError(try sm.transition(to: .active))
    }

    func testActionPermissions() {
        XCTAssertTrue(SessionState.idle.allowsInput)
        XCTAssertTrue(SessionState.active.allowsInput)
        XCTAssertFalse(SessionState.streaming.allowsInput)
        XCTAssertFalse(SessionState.closed.allowsInput)
    }
}
```

---

## Acceptance Criteria

- [ ] All 8 states implemented with correct properties
- [ ] State transitions validated before execution
- [ ] Invalid transitions throw descriptive errors
- [ ] UI reflects current state correctly
- [ ] State persists across app restarts
- [ ] Crash recovery handles interrupted states
- [ ] State changes logged for debugging
- [ ] Concurrent access is safe

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
