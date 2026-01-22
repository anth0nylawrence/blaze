# Diff Stacking & Batch Review Spec

> Cogit0 Blaze - Review Multiple Changes with Precision

## Overview

When Claude Code produces multiple file changes in a single turn, users need a way to review them systematically rather than approving blindly. Diff Stacking provides a **stacked view** of all pending changes with **batch operations** for efficient review workflows.

---

## 1. Core Concepts

### 1.1 Terminology

| Term | Definition |
|------|------------|
| **Diff Stack** | Ordered collection of pending file changes |
| **Diff** | Single file modification (additions, deletions, modifications) |
| **Batch** | Group of diffs to operate on together |
| **Review State** | Pending, Approved, Rejected, or Skipped |
| **Changeset** | Complete set of diffs from a single Claude response |

### 1.2 Diff States

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DIFF LIFECYCLE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Received ────▶ Pending ────▶ Reviewed ────▶ Applied/Rejected           │
│                   │              │                                      │
│                   │              ├── Approved ──▶ Applied               │
│                   │              ├── Rejected ──▶ Discarded             │
│                   │              └── Skipped ──▶ Stays Pending          │
│                   │                                                     │
│                   └── Auto-approved (Trusted Mode)                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Model

### 2.1 Core Types

```swift
// DiffStackModel.swift

/// Represents a single file change
struct FileDiff: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let turnIndex: Int              // Which assistant turn
    let filePath: String
    let operation: DiffOperation
    let hunks: [DiffHunk]
    let originalContent: String?    // For reverts
    let proposedContent: String

    var reviewState: ReviewState = .pending
    var reviewedAt: Date?
    var reviewNote: String?

    enum DiffOperation: String, Codable {
        case create
        case modify
        case delete
        case rename
    }

    var additionCount: Int {
        hunks.flatMap(\.lines).filter(\.isAddition).count
    }

    var deletionCount: Int {
        hunks.flatMap(\.lines).filter(\.isDeletion).count
    }
}

/// A contiguous block of changes
struct DiffHunk: Codable {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]
    let context: String?    // @@ header
}

/// A single line in a diff
struct DiffLine: Codable {
    let type: LineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    enum LineType: String, Codable {
        case context
        case addition
        case deletion
    }

    var isAddition: Bool { type == .addition }
    var isDeletion: Bool { type == .deletion }
}

/// Review decision
enum ReviewState: String, Codable {
    case pending
    case approved
    case rejected
    case skipped
}

/// A group of diffs from one response
struct Changeset: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let turnIndex: Int
    let createdAt: Date
    var diffs: [FileDiff]

    var pendingCount: Int {
        diffs.filter { $0.reviewState == .pending }.count
    }

    var isFullyReviewed: Bool {
        diffs.allSatisfy { $0.reviewState != .pending }
    }
}

/// The complete stack of pending changes
@Observable
final class DiffStack {
    var changesets: [Changeset] = []

    var allDiffs: [FileDiff] {
        changesets.flatMap(\.diffs)
    }

    var pendingDiffs: [FileDiff] {
        allDiffs.filter { $0.reviewState == .pending }
    }

    var pendingCount: Int {
        pendingDiffs.count
    }
}
```

---

## 3. UI Components

### 3.1 Stacked Diff View

```swift
// DiffStackView.swift

struct DiffStackView: View {
    @Bindable var stack: DiffStack
    @State private var selectedDiffId: UUID?
    @State private var viewMode: ViewMode = .stacked

    enum ViewMode {
        case stacked    // Unified vertical list
        case sideBySide // Split view
        case unified    // Inline diff
    }

    var body: some View {
        HSplitView {
            // File list (left)
            DiffFileList(
                diffs: stack.allDiffs,
                selectedId: $selectedDiffId
            )
            .frame(minWidth: 200, maxWidth: 300)

            // Diff viewer (right)
            if let selectedId = selectedDiffId,
               let diff = stack.allDiffs.first(where: { $0.id == selectedId }) {
                DiffDetailView(
                    diff: diff,
                    viewMode: viewMode,
                    onApprove: { approveDiff(diff) },
                    onReject: { rejectDiff(diff) }
                )
            } else {
                DiffStackOverview(stack: stack)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("View", selection: $viewMode) {
                    Image(systemName: "rectangle.split.1x2").tag(ViewMode.stacked)
                    Image(systemName: "rectangle.split.2x1").tag(ViewMode.sideBySide)
                    Image(systemName: "text.alignleft").tag(ViewMode.unified)
                }
                .pickerStyle(.segmented)

                Spacer()

                BatchActionsToolbar(stack: stack)
            }
        }
    }
}
```

### 3.2 File List with Status

```swift
// DiffFileList.swift

struct DiffFileList: View {
    let diffs: [FileDiff]
    @Binding var selectedId: UUID?

    var body: some View {
        List(selection: $selectedId) {
            ForEach(groupedByDirectory) { group in
                Section(group.directory) {
                    ForEach(group.diffs) { diff in
                        DiffFileRow(diff: diff)
                            .tag(diff.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var groupedByDirectory: [DirectoryGroup] {
        Dictionary(grouping: diffs) { diff in
            URL(fileURLWithPath: diff.filePath).deletingLastPathComponent().path
        }
        .map { DirectoryGroup(directory: $0.key, diffs: $0.value) }
        .sorted { $0.directory < $1.directory }
    }
}

struct DiffFileRow: View {
    let diff: FileDiff

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Status icon
            statusIcon
                .frame(width: 16)

            // File icon
            Image(systemName: fileIcon)
                .foregroundStyle(DarkText.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                // Filename
                Text(URL(fileURLWithPath: diff.filePath).lastPathComponent)
                    .font(Typography.body)
                    .foregroundStyle(DarkText.primary)

                // Change summary
                HStack(spacing: Spacing.xs) {
                    Text("+\(diff.additionCount)")
                        .foregroundStyle(DarkAccent.success)
                    Text("-\(diff.deletionCount)")
                        .foregroundStyle(DarkAccent.error)
                }
                .font(Typography.caption)
            }

            Spacer()

            // Operation badge
            operationBadge
        }
        .padding(.vertical, Spacing.xxs)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch diff.reviewState {
        case .pending:
            Circle()
                .fill(DarkAccent.warning)
                .frame(width: 8, height: 8)
        case .approved:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DarkAccent.success)
        case .rejected:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(DarkAccent.error)
        case .skipped:
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(DarkText.tertiary)
        }
    }

    private var fileIcon: String {
        switch diff.operation {
        case .create: return "doc.badge.plus"
        case .modify: return "doc.badge.arrow.up"
        case .delete: return "doc.badge.minus"
        case .rename: return "arrow.triangle.swap"
        }
    }

    @ViewBuilder
    private var operationBadge: some View {
        BlazeBadge(
            text: diff.operation.rawValue.uppercased(),
            variant: badgeVariant,
            icon: nil
        )
    }

    private var badgeVariant: BlazeBadge.Variant {
        switch diff.operation {
        case .create: return .success
        case .modify: return .info
        case .delete: return .error
        case .rename: return .warning
        }
    }
}
```

### 3.3 Diff Detail View

```swift
// DiffDetailView.swift

struct DiffDetailView: View {
    let diff: FileDiff
    let viewMode: DiffStackView.ViewMode
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var showRejectDialog = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            DiffHeader(diff: diff)

            Divider()

            // Content
            ScrollView {
                switch viewMode {
                case .stacked, .unified:
                    UnifiedDiffView(hunks: diff.hunks)
                case .sideBySide:
                    SideBySideDiffView(
                        original: diff.originalContent ?? "",
                        proposed: diff.proposedContent
                    )
                }
            }

            Divider()

            // Actions
            HStack {
                // Quick actions
                Button {
                    showRejectDialog = true
                } label: {
                    Label("Reject", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                Button {
                    onApprove()
                } label: {
                    Label("Approve", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(Spacing.md)
        }
        .sheet(isPresented: $showRejectDialog) {
            RejectDiffSheet(diff: diff, onConfirm: onReject)
        }
    }
}

struct DiffHeader: View {
    let diff: FileDiff

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(diff.filePath)
                    .font(Typography.code)
                    .foregroundStyle(DarkText.primary)

                HStack(spacing: Spacing.sm) {
                    Label("+\(diff.additionCount)", systemImage: "plus")
                        .foregroundStyle(DarkAccent.success)
                    Label("-\(diff.deletionCount)", systemImage: "minus")
                        .foregroundStyle(DarkAccent.error)
                }
                .font(Typography.caption)
            }

            Spacer()

            // Copy path button
            Button {
                NSPasteboard.general.setString(diff.filePath, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)

            // Open in editor button
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: diff.filePath))
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.borderless)
        }
        .padding(Spacing.md)
        .background(DarkBackground.raised)
    }
}
```

### 3.4 Batch Actions Toolbar

```swift
// BatchActionsToolbar.swift

struct BatchActionsToolbar: View {
    @Bindable var stack: DiffStack
    @State private var showBatchConfirm = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Pending count
            if stack.pendingCount > 0 {
                BlazeBadge(
                    text: "\(stack.pendingCount) pending",
                    variant: .warning,
                    icon: "clock"
                )
            }

            Divider()
                .frame(height: 20)

            // Batch actions
            Menu {
                Button {
                    approveAllPending()
                } label: {
                    Label("Approve All Pending", systemImage: "checkmark.circle")
                }

                Button {
                    rejectAllPending()
                } label: {
                    Label("Reject All Pending", systemImage: "xmark.circle")
                }

                Divider()

                Button {
                    approveByFileType(".swift")
                } label: {
                    Label("Approve All .swift", systemImage: "swift")
                }

                Button {
                    approveByFileType(".md")
                } label: {
                    Label("Approve All .md", systemImage: "doc.text")
                }

                Divider()

                Button {
                    resetAllToTreatment()
                } label: {
                    Label("Reset All to Pending", systemImage: "arrow.uturn.backward")
                }
            } label: {
                Label("Batch Actions", systemImage: "checklist")
            }

            // Apply approved
            Button {
                showBatchConfirm = true
            } label: {
                Label("Apply Approved", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(stack.allDiffs.filter { $0.reviewState == .approved }.isEmpty)
        }
        .confirmationDialog(
            "Apply Changes?",
            isPresented: $showBatchConfirm
        ) {
            Button("Apply \(approvedCount) Files") {
                applyApproved()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will write approved changes to disk.")
        }
    }

    private var approvedCount: Int {
        stack.allDiffs.filter { $0.reviewState == .approved }.count
    }
}
```

---

## 4. Keyboard Navigation

### 4.1 Shortcuts

| Shortcut | Action |
|----------|--------|
| `↑` / `↓` | Navigate between files |
| `←` / `→` | Collapse/expand hunks |
| `Space` | Toggle current file selection |
| `A` | Approve current file |
| `R` | Reject current file |
| `S` | Skip current file |
| `⌘A` | Select all files |
| `⌘⇧A` | Approve all selected |
| `⌘⇧R` | Reject all selected |
| `⌘↵` | Apply approved changes |
| `⌘[` / `⌘]` | Previous/next hunk |
| `⌘D` | Toggle side-by-side view |

### 4.2 Implementation

```swift
// DiffStackKeyboardHandler.swift

struct DiffStackKeyboardHandler: ViewModifier {
    @Bindable var stack: DiffStack
    @Binding var selectedId: UUID?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) { selectPrevious(); return .handled }
            .onKeyPress(.downArrow) { selectNext(); return .handled }
            .onKeyPress(.space) { toggleSelection(); return .handled }
            .onKeyPress("a", modifiers: []) { approveSelected(); return .handled }
            .onKeyPress("r", modifiers: []) { rejectSelected(); return .handled }
            .onKeyPress("s", modifiers: []) { skipSelected(); return .handled }
            .onKeyPress("a", modifiers: .command) { selectAll(); return .handled }
            .onKeyPress("a", modifiers: [.command, .shift]) { approveAll(); return .handled }
            .onKeyPress(.return, modifiers: .command) { applyApproved(); return .handled }
    }

    private func selectNext() {
        guard let current = selectedId,
              let index = stack.allDiffs.firstIndex(where: { $0.id == current }),
              index < stack.allDiffs.count - 1 else { return }
        selectedId = stack.allDiffs[index + 1].id
    }

    // ... other methods
}
```

---

## 5. Review Workflows

### 5.1 Sequential Review

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SEQUENTIAL REVIEW FLOW                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐   │
│  │ File 1 │───▶│ File 2 │───▶│ File 3 │───▶│ File 4 │───▶│ Apply  │   │
│  │  ✓/✗   │    │  ✓/✗   │    │  ✓/✗   │    │  ✓/✗   │    │ All ✓  │   │
│  └────────┘    └────────┘    └────────┘    └────────┘    └────────┘   │
│                                                                         │
│  [A] Approve  [R] Reject  [S] Skip  [→] Next  [⌘↵] Apply               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Bulk Review

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       BULK REVIEW FLOW                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Select files by pattern (*.swift, src/*, etc.)                      │
│  2. Preview aggregate changes                                           │
│  3. Approve/reject entire selection                                     │
│  4. Review remaining individually                                       │
│  5. Apply all approved                                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Smart Grouping

```swift
// DiffGrouper.swift

enum DiffGroup: CaseIterable {
    case byDirectory      // Group by folder
    case byOperation      // Create, modify, delete
    case byFileType       // .swift, .md, .json
    case bySize           // Small, medium, large changes
    case byRisk           // Low, medium, high risk

    func group(_ diffs: [FileDiff]) -> [String: [FileDiff]] {
        switch self {
        case .byDirectory:
            return Dictionary(grouping: diffs) { diff in
                URL(fileURLWithPath: diff.filePath)
                    .deletingLastPathComponent().path
            }

        case .byOperation:
            return Dictionary(grouping: diffs) { $0.operation.rawValue }

        case .byFileType:
            return Dictionary(grouping: diffs) { diff in
                URL(fileURLWithPath: diff.filePath).pathExtension
            }

        case .bySize:
            return Dictionary(grouping: diffs) { diff in
                let changes = diff.additionCount + diff.deletionCount
                if changes < 10 { return "Small (<10 lines)" }
                if changes < 50 { return "Medium (10-50 lines)" }
                return "Large (>50 lines)"
            }

        case .byRisk:
            return Dictionary(grouping: diffs) { diff in
                calculateRiskLevel(for: diff)
            }
        }
    }
}
```

---

## 6. Integration with CLI

### 6.1 Capturing Diffs from Stream

```swift
// DiffCapture.swift

actor DiffCapture {
    var currentChangeset: Changeset?

    func handleEvent(_ event: NormalizedEvent) {
        switch event {
        case .toolCallStarted(let tool) where tool.name == "Write" || tool.name == "Edit":
            // Start capturing
            let diff = FileDiff(
                id: UUID(),
                sessionId: currentSession.id,
                turnIndex: currentTurn,
                filePath: tool.input["file_path"] as! String,
                operation: determineOperation(tool),
                hunks: [],
                originalContent: readOriginalFile(tool.input["file_path"] as! String),
                proposedContent: ""
            )
            pendingDiff = diff

        case .toolResult(let result) where pendingDiff != nil:
            // Complete diff capture
            var diff = pendingDiff!
            diff = parseDiffResult(result, into: diff)
            addToCurrentChangeset(diff)
            pendingDiff = nil

        case .turnEnd:
            // Finalize changeset
            if let changeset = currentChangeset, !changeset.diffs.isEmpty {
                DiffStack.shared.changesets.append(changeset)
                currentChangeset = nil
            }

        default:
            break
        }
    }
}
```

### 6.2 Applying Changes

```swift
// DiffApplier.swift

actor DiffApplier {
    func applyApproved(in stack: DiffStack) async throws {
        let approved = stack.allDiffs.filter { $0.reviewState == .approved }

        for diff in approved {
            try await applyDiff(diff)
        }

        // Update stack
        await MainActor.run {
            for diff in approved {
                if let index = stack.allDiffs.firstIndex(where: { $0.id == diff.id }) {
                    stack.allDiffs[index].reviewState = .applied
                }
            }
        }
    }

    private func applyDiff(_ diff: FileDiff) async throws {
        switch diff.operation {
        case .create, .modify:
            try diff.proposedContent.write(
                toFile: diff.filePath,
                atomically: true,
                encoding: .utf8
            )

        case .delete:
            try FileManager.default.removeItem(atPath: diff.filePath)

        case .rename:
            // Handle in DiffCapture with old/new paths
            break
        }
    }
}
```

---

## 7. Persistence

### 7.1 Saving Review State

```swift
// DiffStackStorage.swift

actor DiffStackStorage {
    func saveStack(_ stack: DiffStack, sessionId: String) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(stack.changesets)

        let url = stackStorageURL(for: sessionId)
        try data.write(to: url)
    }

    func loadStack(sessionId: String) async throws -> DiffStack {
        let url = stackStorageURL(for: sessionId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return DiffStack()
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let changesets = try decoder.decode([Changeset].self, from: data)

        let stack = DiffStack()
        stack.changesets = changesets
        return stack
    }

    private func stackStorageURL(for sessionId: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Blaze/stacks/\(sessionId).json")
    }
}
```

---

## 8. Implementation Checklist

- [ ] FileDiff data model
- [ ] Changeset collection
- [ ] DiffStack observable
- [ ] Diff file list view
- [ ] Unified diff view
- [ ] Side-by-side diff view
- [ ] Review state management
- [ ] Batch actions toolbar
- [ ] Keyboard navigation
- [ ] CLI event capture
- [ ] Diff application
- [ ] State persistence
- [ ] Undo/redo support
- [ ] Conflict detection
- [ ] Accessibility labels
