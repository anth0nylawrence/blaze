# Branch Conversations Research

> Cogit0 Blaze - Implementing Conversation Branching as a Frontend Harness

## Executive Summary

This document explores how to implement conversation branching/forking in Cogit0 Blaze as a **frontend-only** feature that works with the unmodified Claude Code CLI. Since Claude Code stores conversations in JSONL files and supports `--fork-session` and `/rewind` commands, we can build a sophisticated branching UI that leverages these capabilities while adding visualization, navigation, and management layers.

---

## 1. Current Claude Code Capabilities

### 1.1 Native Session Features

Based on research of Claude Code's current implementation:

| Feature | CLI Support | Blaze Leverage |
|---------|-------------|----------------|
| Session storage | JSONL files at `~/.claude/projects/[hash]/[session].jsonl` | Read and visualize |
| Fork session | `--fork-session` flag | Trigger via CLI |
| Rewind | `/rewind` command | Trigger via CLI |
| Resume | `--resume`, `--continue` | Session picker |
| Grouped display | Forks shown under root in `/resume` | Build tree structure |

### 1.2 Current Limitations (from GitHub Issues)

**GitHub Issue #10370 - Chat Branching:**
- Context pollution from side tasks
- Loss of focus as chat becomes cluttered
- No isolation for exploration
- Expensive compaction loses side-task details

**GitHub Issue #150 - Conversation Forks === Git Branches:**
- Requests rapid iteration capability
- Wants easy rollback/forward across forks
- Proposes git-like branch metaphor

### 1.3 Opportunity for Blaze

Blaze can solve these problems at the UI layer:
1. **Visualize** the conversation tree that CLI creates
2. **Navigate** between branches easily
3. **Manage** branch lifecycle (archive, delete, merge)
4. **Preview** branch differences before switching

---

## 2. Data Model

### 2.1 Conversation Tree Structure

```swift
// BranchModel.swift

/// Represents a node in the conversation tree
struct ConversationNode: Identifiable, Codable {
    let id: UUID
    let sessionId: String           // Maps to CLI session
    let parentNodeId: UUID?         // nil for root
    let branchPoint: Int            // Message index where branched
    let createdAt: Date
    var title: String
    var isArchived: Bool

    // Computed from JSONL
    var messageCount: Int
    var lastActivity: Date
}

/// The full conversation tree
struct ConversationTree: Codable {
    let rootSessionId: String
    var nodes: [UUID: ConversationNode]
    var edges: [(parent: UUID, child: UUID)]

    var root: ConversationNode? {
        nodes.values.first { $0.parentNodeId == nil }
    }

    func children(of nodeId: UUID) -> [ConversationNode] {
        edges
            .filter { $0.parent == nodeId }
            .compactMap { nodes[$0.child] }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func path(to nodeId: UUID) -> [ConversationNode] {
        var path: [ConversationNode] = []
        var current = nodes[nodeId]

        while let node = current {
            path.insert(node, at: 0)
            current = node.parentNodeId.flatMap { nodes[$0] }
        }

        return path
    }
}
```

### 2.2 Storage Schema (LanceDB)

```sql
-- Conversation tree metadata
CREATE TABLE conversation_trees (
    root_session_id TEXT PRIMARY KEY,
    tree_json TEXT NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Branch navigation history
CREATE TABLE branch_visits (
    id INTEGER PRIMARY KEY,
    tree_id TEXT,
    node_id TEXT,
    visited_at TIMESTAMP,
    FOREIGN KEY (tree_id) REFERENCES conversation_trees(root_session_id)
);
```

---

## 3. UI Design

### 3.1 Tree Visualization Options

**Option A: Horizontal Timeline (Recommended)**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                     CONVERSATION TREE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  main ●───────●───────●───────●───────●───────●──────→ (current)       │
│                       │                                                 │
│                       └──●───────●───────● feature-exploration          │
│                                  │                                      │
│                                  └──● dead-end (archived)               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Option B: Sidebar Tree View**
```
┌──────────────────────┐
│ 📁 Session: Auth Fix │
├──────────────────────┤
│ ├── main (12 msgs)   │
│ │   └── 🌿 try-jwt   │
│ │       └── 🌿 retry │
│ └── 🗄️ archived      │
│     └── old-approach │
└──────────────────────┘
```

**Option C: Command Palette Branch Picker**
```
┌────────────────────────────────────────────────────────────────────┐
│ 🔍 Switch branch...                                                │
├────────────────────────────────────────────────────────────────────┤
│ ● main                                    12 messages   2m ago     │
│   └─ feature-exploration                   8 messages   5m ago     │
│      └─ dead-end                           3 messages   10m ago    │
│ [↵ Select]  [⌘⏎ Preview]  [⌘D Diff]                               │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 Branch Visualization Component

```swift
// ConversationTreeView.swift

struct ConversationTreeView: View {
    let tree: ConversationTree
    @Binding var selectedNodeId: UUID?

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Canvas { context, size in
                    drawTree(context: context, size: size)
                }
                .frame(width: treeWidth, height: treeHeight)
            }
        }
    }

    private func drawTree(context: GraphicsContext, size: CGSize) {
        // Draw edges
        for edge in tree.edges {
            guard let parent = tree.nodes[edge.parent],
                  let child = tree.nodes[edge.child] else { continue }

            let parentPos = position(for: parent)
            let childPos = position(for: child)

            var path = Path()
            path.move(to: parentPos)
            path.addCurve(
                to: childPos,
                control1: CGPoint(x: parentPos.x + 50, y: parentPos.y),
                control2: CGPoint(x: childPos.x - 50, y: childPos.y)
            )

            context.stroke(path, with: .color(.secondary), lineWidth: 2)
        }

        // Draw nodes
        for node in tree.nodes.values {
            let pos = position(for: node)
            let isSelected = node.id == selectedNodeId

            // Node circle
            context.fill(
                Circle().path(in: CGRect(x: pos.x - 8, y: pos.y - 8, width: 16, height: 16)),
                with: .color(isSelected ? .accentColor : .secondary)
            )

            // Label
            context.draw(
                Text(node.title).font(.caption),
                at: CGPoint(x: pos.x, y: pos.y + 20)
            )
        }
    }

    private func position(for node: ConversationNode) -> CGPoint {
        // Calculate position based on depth and sibling index
        let depth = tree.path(to: node.id).count
        let siblings = node.parentNodeId.map { tree.children(of: $0) } ?? [node]
        let siblingIndex = siblings.firstIndex(where: { $0.id == node.id }) ?? 0

        return CGPoint(
            x: CGFloat(depth) * 120 + 60,
            y: CGFloat(siblingIndex) * 60 + 40
        )
    }
}
```

### 3.3 Branch Creation UI

```swift
// CreateBranchSheet.swift

struct CreateBranchSheet: View {
    let atMessage: Message
    @State private var branchName = ""
    @State private var keepContext = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 40))
                    .foregroundStyle(DarkAccent.primary)

                Text("Create Branch")
                    .font(Typography.h2)

                Text("Fork the conversation from this point")
                    .font(Typography.body)
                    .foregroundStyle(DarkText.secondary)
            }

            // Branch point preview
            BlazeCard {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Branching from:")
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.tertiary)

                    Text(atMessage.content.prefix(100) + "...")
                        .font(Typography.body)
                        .lineLimit(2)
                }
            }

            // Branch name
            BlazeTextField(
                text: $branchName,
                placeholder: "Branch name (optional)",
                icon: "tag"
            )

            // Options
            Toggle("Include messages after this point", isOn: $keepContext)
                .toggleStyle(.switch)

            // Actions
            HStack {
                BlazeButton(title: "Cancel", style: .secondary, size: .medium) {
                    dismiss()
                }

                BlazeButton(title: "Create Branch", icon: "plus", style: .primary, size: .medium) {
                    createBranch()
                }
            }
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }

    private func createBranch() {
        // 1. Determine branch point
        let branchPoint = atMessage.index

        // 2. Create forked session via CLI
        Task {
            let session = try await CLIRunner.fork(
                fromSession: currentSession.id,
                atPoint: branchPoint,
                name: branchName.isEmpty ? nil : branchName
            )

            // 3. Update conversation tree
            await ConversationTreeStore.shared.addBranch(
                parentNodeId: currentNode.id,
                newSession: session,
                branchPoint: branchPoint
            )

            dismiss()
        }
    }
}
```

---

## 4. Implementation Strategy

### 4.1 Phase 1: Read-Only Visualization (Week 1-2)

**Goal:** Display existing conversation structure from CLI session files

1. **Scan session directory** at `~/.claude/projects/`
2. **Parse JSONL files** to extract message counts, timestamps
3. **Detect forks** by analyzing session metadata
4. **Build tree structure** from fork relationships
5. **Render basic tree view** in sidebar

```swift
// SessionScanner.swift

actor SessionScanner {
    func scanForTrees() async throws -> [ConversationTree] {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        var trees: [ConversationTree] = []

        for projectDir in try FileManager.default.contentsOfDirectory(at: projectsDir) {
            let sessions = try await scanProject(at: projectDir)
            let tree = buildTree(from: sessions)
            trees.append(tree)
        }

        return trees
    }

    private func buildTree(from sessions: [SessionMetadata]) -> ConversationTree {
        // Group by root session
        // Detect parent-child relationships from fork metadata
        // Build node and edge lists
        // Return tree
    }
}
```

### 4.2 Phase 2: Branch Navigation (Week 2-3)

**Goal:** Switch between branches seamlessly

1. **Branch switcher UI** (command palette style)
2. **Load target session** via CLI `--continue`
3. **Update chat view** with new conversation
4. **Breadcrumb navigation** showing current branch path

```swift
// BranchNavigator.swift

actor BranchNavigator {
    func switchToBranch(_ nodeId: UUID) async throws {
        let node = try await getNode(nodeId)

        // Update CLI session
        try await CLIRunner.resume(sessionId: node.sessionId)

        // Update UI
        await MainActor.run {
            SessionStore.shared.currentSession = node.sessionId
            SessionStore.shared.currentBranch = nodeId
        }

        // Record visit
        try await recordVisit(nodeId: nodeId)
    }
}
```

### 4.3 Phase 3: Branch Creation (Week 3-4)

**Goal:** Create new branches from any message

1. **Context menu on messages** with "Branch from here"
2. **Create branch sheet** with naming and options
3. **CLI fork invocation** with correct parameters
4. **Tree update** to include new branch
5. **Auto-switch** to new branch

### 4.4 Phase 4: Branch Management (Week 4-5)

**Goal:** Full lifecycle management

1. **Rename branches** - update metadata
2. **Archive branches** - mark as inactive
3. **Delete branches** - remove session files (with confirmation)
4. **Compare branches** - side-by-side diff view
5. **Merge branches** - selective message copying (advanced)

---

## 5. CLI Integration

### 5.1 Fork Session Implementation

```swift
// CLIBranchCommands.swift

extension CLIRunner {
    /// Fork a session at a specific message
    static func fork(
        fromSession: String,
        atPoint: Int,
        name: String?
    ) async throws -> SessionMetadata {
        // Use /rewind to go back to the branch point
        // Then start new session which creates implicit fork

        var args = [
            "--continue", fromSession,
            "--output-format", "stream-json"
        ]

        // Spawn CLI process
        let process = try await spawn(arguments: args)

        // Send rewind command
        try await process.sendInput("/rewind \(atPoint)")

        // Capture new session ID from init event
        let initEvent = try await process.waitForEvent(ofType: .init)

        return SessionMetadata(
            id: initEvent.sessionId,
            forkedFrom: fromSession,
            branchPoint: atPoint,
            name: name
        )
    }
}
```

### 5.2 Session File Watching

```swift
// SessionFileWatcher.swift

actor SessionFileWatcher {
    private var watchers: [DispatchSourceFileSystemObject] = []

    func startWatching(directory: URL) {
        let descriptor = open(directory.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            Task {
                await self?.handleChange()
            }
        }

        source.resume()
        watchers.append(source)
    }

    private func handleChange() async {
        // Rescan session files
        // Update conversation trees
        // Notify UI of changes
    }
}
```

---

## 6. UX Considerations

### 6.1 Branch Indicators in Chat

```swift
// ChatBranchIndicator.swift

struct ChatBranchIndicator: View {
    let currentBranch: ConversationNode
    let tree: ConversationTree

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: IconSize.sm))
                .foregroundStyle(DarkText.tertiary)

            // Breadcrumb path
            ForEach(tree.path(to: currentBranch.id)) { node in
                if node.id != currentBranch.id {
                    Text(node.title)
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.tertiary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(DarkText.disabled)
                }
            }

            Text(currentBranch.title)
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(DarkText.secondary)

            // Branch count badge
            if tree.children(of: currentBranch.id).count > 0 {
                BlazeBadge(
                    text: "\(tree.children(of: currentBranch.id).count)",
                    variant: .neutral,
                    icon: "arrow.triangle.branch"
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(DarkBackground.raised)
        .clipShape(Capsule())
    }
}
```

### 6.2 Branch Point Markers

```swift
// BranchPointMarker.swift

struct BranchPointMarker: View {
    let message: Message
    let branches: [ConversationNode]

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Capsule()
                .fill(DarkAccent.primary.opacity(0.2))
                .frame(width: 4, height: 20)

            Menu {
                ForEach(branches) { branch in
                    Button {
                        switchToBranch(branch.id)
                    } label: {
                        Label(branch.title, systemImage: "arrow.triangle.branch")
                    }
                }

                Divider()

                Button {
                    createNewBranch(at: message)
                } label: {
                    Label("New Branch", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.triangle.branch")
                    Text("\(branches.count)")
                }
                .font(Typography.caption)
                .foregroundStyle(DarkAccent.primary)
            }
        }
    }
}
```

---

## 7. Edge Cases

### 7.1 Orphaned Branches

When CLI session is deleted outside Blaze:
1. Detect missing files during scan
2. Mark branch as "orphaned" in tree
3. Show warning indicator
4. Allow user to remove from tree

### 7.2 Concurrent Modifications

When CLI modifies session while Blaze is viewing:
1. File watcher detects change
2. Reload session data
3. Update UI without losing scroll position
4. Show toast: "Session updated"

### 7.3 Very Deep Trees

For trees with many levels:
1. Collapse distant branches by default
2. Allow expand/collapse per level
3. Provide "focus on subtree" option
4. Implement virtual scrolling for large trees

---

## 8. References

- [GitHub Issue #10370: Chat Branching](https://github.com/anthropics/claude-code/issues/10370)
- [GitHub Issue #150: Conversation Forks === Git Branches](https://github.com/anthropics/claude-code/issues/150)
- [Claude Code Conversation History](https://kentgigger.com/posts/claude-code-conversation-history)
- [tldraw Branching Chat Starter Kit](https://tldraw.dev/starter-kits/branching-chat)
- [flow-chat: Chat UI in Graph](https://github.com/lemonnekogh/flow-chat)
- [forky: Git-style LLM Chats](https://github.com/ishandhanani/forky)
