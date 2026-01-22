# Branch Conversations Spec

> Forking conversations to explore alternative paths—a killer feature for agentic coding

## Overview

Branch Conversations allows users to fork any point in a conversation to explore different approaches, undo decisions, or try alternative prompts. Since Claude Code CLI operates in headless mode without native session persistence, Blaze must implement branching entirely on the frontend by managing conversation state and context injection.

---

## 1. The Challenge: Headless CLI

### 1.1 How Claude Code CLI Works

```
Claude Code CLI (headless mode):
┌────────────────────────────────────────────────────────────────────────────┐
│                                                                            │
│  claude -p "<prompt>" --output-format stream-json                          │
│                                                                            │
│  • Each invocation is stateless                                            │
│  • No built-in session memory                                              │
│  • Context must be provided via prompt                                     │
│  • Events stream as NDJSON to stdout                                       │
│  • Process exits when complete                                             │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Implication for Branching

Since the CLI doesn't maintain conversation state, Blaze must:

1. **Store all events locally** in our database
2. **Reconstruct context** by replaying relevant history in each prompt
3. **Manage branch topology** as a data structure
4. **Synthesize conversation continuity** through smart context injection

---

## 2. Data Model

### 2.1 Branch Structure

```swift
// Branch.swift

struct ConversationBranch: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let parentBranchId: UUID?          // nil for main branch
    let forkPointEventId: UUID         // Where this branch diverged
    let createdAt: Date

    var name: String                   // User-provided or auto-generated
    var description: String?           // Optional context

    // Computed from events
    var eventIds: [UUID]               // Events in this branch
    var messageCount: Int
    var lastActivity: Date

    // Branch state
    var isActive: Bool
    var isArchived: Bool
}
```

### 2.2 Event-Branch Relationship

```swift
// Events belong to branches
struct SessionEvent: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let branchId: UUID                 // Which branch this event is on
    let parentEventId: UUID?           // For ordering
    let timestamp: Date
    let type: EventType
    let content: EventContent

    // For branch visualization
    var branchDepth: Int               // Distance from fork point
}
```

### 2.3 Database Schema (LanceDB)

```sql
-- branches table
CREATE TABLE branches (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL,
    parent_branch_id UUID,
    fork_point_event_id UUID,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_archived BOOLEAN DEFAULT false,

    FOREIGN KEY (session_id) REFERENCES sessions(id),
    FOREIGN KEY (parent_branch_id) REFERENCES branches(id),
    FOREIGN KEY (fork_point_event_id) REFERENCES events(id)
);

-- events table (add branch_id)
ALTER TABLE events ADD COLUMN branch_id UUID REFERENCES branches(id);
```

---

## 3. Branch Topology

### 3.1 Visual Representation

```
Main Branch (default)
│
├─ Message 1 (user)
├─ Message 2 (assistant)
├─ Message 3 (user)
├─ Message 4 (assistant)
│       │
│       ├─── Branch A: "Try with TypeScript" ───────────────┐
│       │    ├─ Message A1 (user)                          │
│       │    ├─ Message A2 (assistant)                     │
│       │    └─ Message A3 (user)                          │
│       │                                                   │
│       └─── Branch B: "Simpler approach" ─────────────────┐
│            ├─ Message B1 (user)                          │
│            └─ Message B2 (assistant)                     │
│                                                           │
├─ Message 5 (user)      ← Continued on main branch
├─ Message 6 (assistant)
│       │
│       └─── Branch C: "Add error handling" ───────────────┐
│            └─ Message C1 (user)                          │
│
└─ Message 7 (user)      ← Latest on main
```

### 3.2 Branch Tree Structure

```swift
// BranchTree.swift

@Observable
final class BranchTree {
    let session: Session
    private var branches: [UUID: ConversationBranch] = [:]
    private var branchEvents: [UUID: [SessionEvent]] = [:]

    var mainBranch: ConversationBranch {
        branches.values.first { $0.parentBranchId == nil }!
    }

    var activeBranch: ConversationBranch {
        branches.values.first { $0.isActive }!
    }

    // Get all branches that fork from a given event
    func branchesFrom(eventId: UUID) -> [ConversationBranch] {
        branches.values.filter { $0.forkPointEventId == eventId }
    }

    // Get the full ancestry path from root to a branch
    func ancestryPath(for branch: ConversationBranch) -> [ConversationBranch] {
        var path: [ConversationBranch] = [branch]
        var current = branch

        while let parentId = current.parentBranchId,
              let parent = branches[parentId] {
            path.insert(parent, at: 0)
            current = parent
        }

        return path
    }

    // Get all events visible on a branch (including inherited from parents)
    func visibleEvents(on branch: ConversationBranch) -> [SessionEvent] {
        var events: [SessionEvent] = []

        // Collect from ancestry
        for ancestorBranch in ancestryPath(for: branch) {
            let branchEvents = self.branchEvents[ancestorBranch.id] ?? []

            if ancestorBranch.id == branch.id {
                // Include all events on this branch
                events.append(contentsOf: branchEvents)
            } else {
                // Include events up to the fork point
                let forkPointId = findChildForkPoint(from: ancestorBranch, to: branch)
                let upToFork = branchEvents.prefix { $0.id != forkPointId }
                events.append(contentsOf: upToFork)
            }
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }
}
```

---

## 4. Context Injection Strategy

### 4.1 The Core Problem

When spawning a new Claude Code CLI process, we must inject context so Claude "remembers" the conversation history. Since we operate headlessly, this means constructing a prompt that includes:

1. **System context** (project, session metadata)
2. **Conversation history** (summarized or truncated)
3. **Branch context** (if on a branch)
4. **The actual user prompt**

### 4.2 Context Injection Template

```swift
// ContextInjector.swift

struct ContextInjector {
    let session: Session
    let branch: ConversationBranch
    let branchTree: BranchTree

    func buildPrompt(userMessage: String) -> String {
        var prompt = ""

        // 1. Session context (if needed)
        if let projectPath = session.projectPath {
            prompt += "Working in project: \(projectPath)\n\n"
        }

        // 2. Conversation history
        let history = buildConversationHistory()
        if !history.isEmpty {
            prompt += "Previous conversation:\n"
            prompt += history
            prompt += "\n---\n\n"
        }

        // 3. Branch context (if on a branch)
        if branch.parentBranchId != nil {
            prompt += "Note: This is an alternative exploration branched from the main conversation.\n"
            if let desc = branch.description {
                prompt += "Branch context: \(desc)\n"
            }
            prompt += "\n"
        }

        // 4. Current prompt
        prompt += "User: \(userMessage)"

        return prompt
    }

    private func buildConversationHistory() -> String {
        let events = branchTree.visibleEvents(on: branch)
        var history = ""

        // Summarize if too long (> 100k chars)
        let messages = extractMessages(from: events)
        let totalLength = messages.map(\.content.count).reduce(0, +)

        if totalLength > 100_000 {
            // Use summarization strategy
            return buildSummarizedHistory(messages)
        } else {
            // Use full history with truncation
            return buildFullHistory(messages)
        }
    }

    private func buildFullHistory(_ messages: [ConversationMessage]) -> String {
        messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            let content = truncateIfNeeded(msg.content, maxLength: 5000)
            return "\(role): \(content)"
        }.joined(separator: "\n\n")
    }

    private func buildSummarizedHistory(_ messages: [ConversationMessage]) -> String {
        // Keep first few and last few messages, summarize middle
        let keepFirst = 3
        let keepLast = 5

        guard messages.count > keepFirst + keepLast else {
            return buildFullHistory(messages)
        }

        var parts: [String] = []

        // First messages
        let first = messages.prefix(keepFirst)
        parts.append(contentsOf: first.map { formatMessage($0) })

        // Middle summary
        let middle = messages.dropFirst(keepFirst).dropLast(keepLast)
        let summary = generateConversationSummary(middle)
        parts.append("[...conversation continued with \(middle.count) exchanges about: \(summary)...]")

        // Last messages
        let last = messages.suffix(keepLast)
        parts.append(contentsOf: last.map { formatMessage($0) })

        return parts.joined(separator: "\n\n")
    }
}
```

### 4.3 Smart Summarization

For very long conversations, we periodically generate summaries:

```swift
// ConversationSummarizer.swift

actor ConversationSummarizer {

    /// Generate a summary of conversation segments for context injection
    func summarize(
        messages: [ConversationMessage],
        targetLength: Int = 2000
    ) async throws -> String {
        // Group by topic (heuristic: tool usage patterns, file mentions)
        let segments = segmentByTopic(messages)

        var summary = "Previous discussion covered:\n"

        for segment in segments {
            let topic = extractTopic(from: segment)
            let outcome = extractOutcome(from: segment)
            summary += "• \(topic): \(outcome)\n"
        }

        return summary
    }

    private func segmentByTopic(_ messages: [ConversationMessage]) -> [[ConversationMessage]] {
        // Heuristic: new topic when tool usage changes or explicit pivot
        var segments: [[ConversationMessage]] = []
        var current: [ConversationMessage] = []

        for message in messages {
            if shouldStartNewSegment(current: current, new: message) {
                if !current.isEmpty {
                    segments.append(current)
                }
                current = [message]
            } else {
                current.append(message)
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }

        return segments
    }

    private func extractTopic(from segment: [ConversationMessage]) -> String {
        // Extract dominant topic from segment
        // - File names mentioned
        // - Tool types used
        // - Key phrases
        let files = extractFileMentions(segment)
        let tools = extractToolTypes(segment)

        if !files.isEmpty {
            return "working on \(files.prefix(3).joined(separator: ", "))"
        } else if !tools.isEmpty {
            return "\(tools.first!) operations"
        }
        return "discussion"
    }
}
```

---

## 5. User Interface

### 5.1 Branch Visualization

```swift
// BranchTimelineView.swift

struct BranchTimelineView: View {
    @Environment(BranchTree.self) var tree
    let onBranchSelect: (ConversationBranch) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                // Main timeline
                TimelineColumn(
                    branch: tree.mainBranch,
                    events: tree.branchEvents[tree.mainBranch.id] ?? [],
                    isActive: tree.activeBranch.id == tree.mainBranch.id,
                    onSelect: { onBranchSelect(tree.mainBranch) }
                )

                // Branch columns
                ForEach(tree.allBranches.filter { $0.parentBranchId != nil }) { branch in
                    BranchColumn(
                        branch: branch,
                        forkPoint: findForkPointY(for: branch),
                        events: tree.branchEvents[branch.id] ?? [],
                        isActive: tree.activeBranch.id == branch.id,
                        onSelect: { onBranchSelect(branch) }
                    )
                }
            }
        }
    }
}

struct BranchColumn: View {
    let branch: ConversationBranch
    let forkPoint: CGFloat
    let events: [SessionEvent]
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Spacer to align with fork point
            Spacer()
                .frame(height: forkPoint)

            // Fork indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                Text(branch.name)
                    .font(.caption.bold())
            }
            .foregroundStyle(isActive ? .blue : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
            .onTapGesture(perform: onSelect)

            // Branch events
            LazyVStack(spacing: 8) {
                ForEach(events) { event in
                    CompactEventRow(event: event)
                }
            }
            .padding(.top, 8)
        }
        .frame(width: 200)
        .padding(.horizontal, 8)
    }
}
```

### 5.2 Branch Creation UI

```swift
// CreateBranchSheet.swift

struct CreateBranchSheet: View {
    let forkPoint: SessionEvent
    @State private var name = ""
    @State private var description = ""
    @State private var initialPrompt = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("Create Branch")
                        .font(.headline)
                    Text("Fork from: "\(forkPoint.summary)"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Form
            Form {
                TextField("Branch name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $description)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Text("What would you like to explore?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $initialPrompt)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
            }

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Create Branch") {
                    createBranch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || initialPrompt.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func createBranch() {
        Task {
            let branch = try await BranchManager.shared.createBranch(
                name: name,
                description: description.isEmpty ? nil : description,
                forkPoint: forkPoint
            )

            // Switch to new branch and send initial prompt
            await BranchManager.shared.switchToBranch(branch)
            await SessionManager.shared.sendMessage(initialPrompt)

            dismiss()
        }
    }
}
```

### 5.3 Context Menu Integration

```swift
// MessageContextMenu.swift

struct MessageContextMenu: View {
    let event: SessionEvent
    @Environment(BranchTree.self) var tree

    var body: some View {
        Group {
            Button {
                showBranchSheet(from: event)
            } label: {
                Label("Create Branch Here", systemImage: "arrow.triangle.branch")
            }

            if tree.branchesFrom(eventId: event.id).count > 0 {
                Menu("Branches from Here") {
                    ForEach(tree.branchesFrom(eventId: event.id)) { branch in
                        Button {
                            switchToBranch(branch)
                        } label: {
                            Label(branch.name, systemImage: branch.isActive ? "checkmark" : "arrow.right")
                        }
                    }
                }
            }

            Divider()

            Button {
                copyToClipboard(event.content)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
```

---

## 6. Branch Operations

### 6.1 Branch Manager

```swift
// BranchManager.swift

@Observable
final class BranchManager {
    static let shared = BranchManager()

    private let storage: SessionStorage
    private var currentTree: BranchTree?

    // Create a new branch
    func createBranch(
        name: String,
        description: String?,
        forkPoint: SessionEvent
    ) async throws -> ConversationBranch {
        guard let tree = currentTree else {
            throw BranchError.noActiveSession
        }

        let branch = ConversationBranch(
            id: UUID(),
            sessionId: tree.session.id,
            parentBranchId: tree.activeBranch.id,
            forkPointEventId: forkPoint.id,
            createdAt: Date(),
            name: name,
            description: description,
            eventIds: [],
            messageCount: 0,
            lastActivity: Date(),
            isActive: false,
            isArchived: false
        )

        try await storage.saveBranch(branch)
        currentTree?.addBranch(branch)

        return branch
    }

    // Switch active branch
    func switchToBranch(_ branch: ConversationBranch) async {
        guard let tree = currentTree else { return }

        // Deactivate current
        var current = tree.activeBranch
        current.isActive = false
        try? await storage.updateBranch(current)

        // Activate new
        var newActive = branch
        newActive.isActive = true
        try? await storage.updateBranch(newActive)

        tree.setActiveBranch(newActive)

        // Notify UI
        NotificationCenter.default.post(
            name: .branchDidChange,
            object: newActive
        )
    }

    // Merge branch back to parent
    func mergeBranch(_ branch: ConversationBranch, intoParent: Bool = true) async throws {
        guard let tree = currentTree,
              let parentId = branch.parentBranchId,
              let parent = tree.branches[parentId] else {
            throw BranchError.cannotMerge
        }

        if intoParent {
            // Copy branch events to parent
            let branchEvents = tree.branchEvents[branch.id] ?? []
            for var event in branchEvents {
                event.branchId = parentId
                try await storage.updateEvent(event)
            }
        }

        // Archive the branch
        var archived = branch
        archived.isArchived = true
        try await storage.updateBranch(archived)

        // Switch to parent
        await switchToBranch(parent)
    }

    // Delete branch and its events
    func deleteBranch(_ branch: ConversationBranch) async throws {
        guard branch.parentBranchId != nil else {
            throw BranchError.cannotDeleteMainBranch
        }

        // Delete all events on this branch
        if let tree = currentTree {
            for event in tree.branchEvents[branch.id] ?? [] {
                try await storage.deleteEvent(event.id)
            }
        }

        // Delete branch record
        try await storage.deleteBranch(branch.id)

        currentTree?.removeBranch(branch)
    }
}
```

### 6.2 Branch Comparison

```swift
// BranchCompareView.swift

struct BranchCompareView: View {
    let branchA: ConversationBranch
    let branchB: ConversationBranch
    @Environment(BranchTree.self) var tree

    var body: some View {
        HStack(spacing: 0) {
            // Branch A
            VStack {
                BranchHeader(branch: branchA)
                ScrollView {
                    ForEach(tree.visibleEvents(on: branchA)) { event in
                        EventRow(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Branch B
            VStack {
                BranchHeader(branch: branchB)
                ScrollView {
                    ForEach(tree.visibleEvents(on: branchB)) { event in
                        EventRow(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
```

---

## 7. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧B` | Create branch from selected message |
| `⌘[` | Switch to previous branch |
| `⌘]` | Switch to next branch |
| `⌘0` | Switch to main branch |
| `⌘⇧M` | Merge current branch to parent |
| `⌘⇧D` | Delete current branch |

---

## 8. Persistence Strategy

### 8.1 What We Store

```swift
// For each branch:
// 1. Branch metadata (name, fork point, timestamps)
// 2. Events that belong to this branch
// 3. Computed context summaries (cached)

// JSONL event log per session:
// {"type":"branch_created","branchId":"...","forkPoint":"..."}
// {"type":"branch_switched","from":"...","to":"..."}
// {"type":"event","branchId":"...","content":...}
```

### 8.2 Recovery

If app crashes mid-branch:

1. Load last known branch state from database
2. Replay JSONL log to catch up any uncommitted events
3. Restore branch tree structure
4. Resume on last active branch

---

## 9. Edge Cases

### 9.1 Circular References

**Problem**: Can a branch fork from itself?

**Solution**: Prevent by validating fork point is not on current branch.

### 9.2 Deep Nesting

**Problem**: Branches of branches of branches...

**Solution**: Allow max depth of 5. Show warning at depth 3.

### 9.3 Orphaned Branches

**Problem**: Parent branch deleted.

**Solution**: Orphaned branches become root-level (reparented to main).

### 9.4 Merge Conflicts

**Problem**: Merging branch that diverged significantly.

**Solution**: No automatic merging—user chooses which branch events to keep.

---

## 10. Performance Considerations

### 10.1 Context Size

- Track token estimates for injected context
- Auto-summarize when context exceeds 80k tokens
- Warn user when approaching limit

### 10.2 Event Count

- Index events by branch for fast retrieval
- Lazy load events for inactive branches
- Archive old branches to cold storage

### 10.3 UI Performance

- Virtualize event lists
- Cache branch visualizations
- Debounce tree recalculations

---

## 11. Future Enhancements

### 11.1 Branch Templates

Pre-defined branching patterns:
- "Try another language"
- "Simpler approach"
- "With error handling"
- "Optimized for performance"

### 11.2 Branch Sharing

Export a branch as shareable conversation:
- Markdown export
- JSON export
- Link sharing

### 11.3 AI-Suggested Branches

Blaze suggests branches when:
- Claude offers alternatives
- User seems stuck
- Approach has high uncertainty

---

## 12. Summary

### Implementation Priority

1. **P0**: Basic branch creation and switching
2. **P0**: Context injection for branch continuity
3. **P1**: Branch visualization in sidebar
4. **P1**: Merge and delete operations
5. **P2**: Branch comparison view
6. **P2**: Context summarization for long branches
7. **P3**: Templates and suggestions

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Context injection | Prompt prefixing | CLI is stateless |
| Branch storage | LanceDB + JSONL | Crash recovery, fast queries |
| Max depth | 5 levels | UX complexity limit |
| Summarization | On-demand | Save tokens, fresh context |

---

*"Every decision is a branch point. Blaze lets you explore them all."*
