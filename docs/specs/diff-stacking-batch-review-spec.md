# Diff Stacking & Batch Review Spec

> "One does not simply review diffs one at a time." — Boromir, probably a code reviewer

## Overview

Diff Stacking & Batch Review transforms how developers review AI-generated changes. Instead of reviewing each file modification in isolation, Blaze presents changes as **logical stacks** — grouped by intent, dependency, or semantic relationship — enabling efficient batch approval, rejection, or selective cherry-picking.

## Core Concepts

### The Problem with Linear Diff Review

Traditional diff review suffers from:

1. **Context Fragmentation**: Related changes across files reviewed separately
2. **Approval Fatigue**: Dozens of individual confirmations per task
3. **Lost Intent**: Why these changes were made together gets lost
4. **Rollback Complexity**: Undoing one change may break dependent changes

### The Diff Stack Solution

```
┌─────────────────────────────────────────────────────────────────────┐
│  Stack: "Add user authentication"                                   │
│  ├── Layer 1: Database Schema (1 file)                             │
│  │   └── migrations/001_add_users.sql                              │
│  ├── Layer 2: Data Models (2 files)                                │
│  │   ├── models/User.swift                                         │
│  │   └── models/Session.swift                                      │
│  ├── Layer 3: API Routes (3 files)                                 │
│  │   ├── routes/auth.swift                                         │
│  │   ├── routes/login.swift                                        │
│  │   └── routes/logout.swift                                       │
│  └── Layer 4: UI Components (4 files)                              │
│      ├── views/LoginView.swift                                     │
│      ├── views/SignupView.swift                                    │
│      ├── views/ProfileView.swift                                   │
│      └── components/AuthButton.swift                               │
│                                                                     │
│  [Approve Stack] [Reject Stack] [Review Layer by Layer]            │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Model

### Diff Types

```swift
/// A single file change
struct FileDiff: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let stackId: UUID?
    let filePath: String
    let originalContent: String?
    let modifiedContent: String
    let hunks: [DiffHunk]
    let changeType: FileChangeType
    let timestamp: Date
    let metadata: DiffMetadata
}

enum FileChangeType: String, Codable {
    case created
    case modified
    case deleted
    case renamed
    case permissions
}

struct DiffHunk: Codable {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]
    let context: String? // Summary of what this hunk does
}

struct DiffLine: Codable {
    let type: LineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum LineType: String, Codable {
    case context
    case addition
    case deletion
}

struct DiffMetadata: Codable {
    let language: String?
    let symbols: [SymbolChange]    // Functions/classes affected
    let complexity: ComplexityDelta
    let testCoverage: CoverageDelta?
    let aiExplanation: String?     // Why Claude made this change
}
```

### Diff Stack Structure

```swift
/// A logical grouping of related diffs
struct DiffStack: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let name: String
    let description: String
    let layers: [DiffLayer]
    let status: StackStatus
    let createdAt: Date
    let reviewedAt: Date?
    let reviewDecision: ReviewDecision?
    let aiRationale: String        // Why these diffs are grouped
    let dependencies: [UUID]       // Other stacks this depends on
    let dependents: [UUID]         // Stacks that depend on this
}

struct DiffLayer: Identifiable, Codable {
    let id: UUID
    let name: String               // e.g., "Database Schema"
    let order: Int                 // Layer ordering (bottom-up)
    let diffs: [UUID]              // FileDiff IDs in this layer
    let category: LayerCategory
}

enum LayerCategory: String, Codable, CaseIterable {
    case schema          // Database migrations, schema changes
    case model           // Data models, entities
    case service         // Business logic, services
    case api             // Routes, controllers, endpoints
    case ui              // Views, components
    case test            // Test files
    case config          // Configuration files
    case docs            // Documentation
    case other

    var icon: String {
        switch self {
        case .schema: return "cylinder"
        case .model: return "cube"
        case .service: return "gearshape.2"
        case .api: return "network"
        case .ui: return "rectangle.on.rectangle"
        case .test: return "checkmark.seal"
        case .config: return "slider.horizontal.3"
        case .docs: return "doc.text"
        case .other: return "folder"
        }
    }
}

enum StackStatus: String, Codable {
    case pending         // Awaiting review
    case inReview        // Currently being reviewed
    case approved        // All layers approved
    case partialApproved // Some layers approved
    case rejected        // Stack rejected
    case applied         // Changes written to disk
    case reverted        // Changes rolled back
}

enum ReviewDecision: Codable {
    case approveAll
    case rejectAll
    case selective(approved: [UUID], rejected: [UUID], deferred: [UUID])
}
```

### LanceDB Schema

```python
# Diff Stacks Table
diff_stacks_schema = {
    "id": "string",
    "session_id": "string",
    "name": "string",
    "description": "string",
    "status": "string",
    "created_at": "timestamp",
    "reviewed_at": "timestamp",
    "ai_rationale": "string",
    "layer_count": "int32",
    "diff_count": "int32",
    "total_additions": "int32",
    "total_deletions": "int32",
    "embedding": "vector[1536]",  # For semantic search
}

# File Diffs Table
file_diffs_schema = {
    "id": "string",
    "session_id": "string",
    "stack_id": "string",
    "layer_id": "string",
    "file_path": "string",
    "change_type": "string",
    "additions": "int32",
    "deletions": "int32",
    "language": "string",
    "ai_explanation": "string",
    "hunk_count": "int32",
    "timestamp": "timestamp",
    "embedding": "vector[1536]",
}
```

## Stack Detection Algorithm

### Automatic Grouping

Blaze automatically groups diffs into stacks using multiple signals:

```swift
class StackDetector {

    /// Analyze diffs and create logical stacks
    func detectStacks(diffs: [FileDiff], context: SessionContext) async -> [DiffStack] {
        var stacks: [DiffStack] = []

        // 1. Group by AI-stated intent
        let intentGroups = groupByAIIntent(diffs)

        // 2. Analyze import/dependency relationships
        let dependencyGraph = buildDependencyGraph(diffs)

        // 3. Detect semantic clusters (similar changes)
        let semanticClusters = await clusterBySemantic(diffs)

        // 4. Consider temporal proximity
        let temporalGroups = groupByTimeWindow(diffs, windowSeconds: 30)

        // 5. Merge signals with weighted scoring
        let candidates = mergeGroupings(
            intent: intentGroups,
            dependency: dependencyGraph,
            semantic: semanticClusters,
            temporal: temporalGroups
        )

        // 6. Create stacks with layers
        for candidate in candidates {
            let layers = organizeIntoLayers(candidate.diffs)
            let stack = DiffStack(
                id: UUID(),
                sessionId: context.sessionId,
                name: generateStackName(candidate),
                description: generateStackDescription(candidate),
                layers: layers,
                status: .pending,
                createdAt: Date(),
                aiRationale: candidate.rationale,
                dependencies: detectDependencies(candidate, in: stacks),
                dependents: []
            )
            stacks.append(stack)
        }

        return stacks
    }

    /// Organize diffs into architectural layers
    private func organizeIntoLayers(_ diffs: [FileDiff]) -> [DiffLayer] {
        var layerMap: [LayerCategory: [FileDiff]] = [:]

        for diff in diffs {
            let category = categorizeFile(diff.filePath)
            layerMap[category, default: []].append(diff)
        }

        // Order layers by architectural dependency
        let layerOrder: [LayerCategory] = [
            .schema, .model, .service, .api, .ui, .test, .config, .docs, .other
        ]

        return layerOrder.enumerated().compactMap { index, category in
            guard let diffs = layerMap[category], !diffs.isEmpty else { return nil }
            return DiffLayer(
                id: UUID(),
                name: category.rawValue.capitalized,
                order: index,
                diffs: diffs.map(\.id),
                category: category
            )
        }
    }

    /// Categorize file based on path and content
    private func categorizeFile(_ path: String) -> LayerCategory {
        let lowercased = path.lowercased()

        if lowercased.contains("migration") || lowercased.contains("schema") {
            return .schema
        }
        if lowercased.contains("model") || lowercased.contains("entity") {
            return .model
        }
        if lowercased.contains("service") || lowercased.contains("manager") {
            return .service
        }
        if lowercased.contains("route") || lowercased.contains("controller") || lowercased.contains("api") {
            return .api
        }
        if lowercased.contains("view") || lowercased.contains("component") || lowercased.contains("screen") {
            return .ui
        }
        if lowercased.contains("test") || lowercased.contains("spec") {
            return .test
        }
        if lowercased.hasSuffix(".json") || lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml") {
            return .config
        }
        if lowercased.hasSuffix(".md") || lowercased.contains("readme") || lowercased.contains("doc") {
            return .docs
        }

        return .other
    }
}
```

### Dependency Analysis

```swift
class DependencyAnalyzer {

    /// Build a graph of file dependencies
    func buildDependencyGraph(_ diffs: [FileDiff]) -> DependencyGraph {
        var graph = DependencyGraph()

        for diff in diffs {
            let imports = extractImports(diff.modifiedContent, language: diff.metadata.language)
            let exports = extractExports(diff.modifiedContent, language: diff.metadata.language)

            graph.addNode(diff.filePath, exports: exports)

            for importPath in imports {
                if let resolvedPath = resolveImportPath(importPath, from: diff.filePath) {
                    graph.addEdge(from: diff.filePath, to: resolvedPath)
                }
            }
        }

        return graph
    }

    /// Detect circular dependencies (warning condition)
    func detectCircularDependencies(_ graph: DependencyGraph) -> [[String]] {
        // Tarjan's algorithm for SCC detection
        return graph.findStronglyConnectedComponents()
            .filter { $0.count > 1 }
    }
}
```

## Batch Review UI

### Stack Overview

```swift
struct DiffStackView: View {
    let stack: DiffStack
    @State private var expandedLayers: Set<UUID> = []
    @State private var selectedDiffs: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Stack Header
            StackHeaderView(stack: stack)

            // Layer List
            ForEach(stack.layers.sorted(by: { $0.order < $1.order })) { layer in
                LayerRowView(
                    layer: layer,
                    isExpanded: expandedLayers.contains(layer.id),
                    selectedDiffs: $selectedDiffs
                ) {
                    toggleLayer(layer.id)
                }
            }

            // Batch Actions
            BatchActionBar(
                stack: stack,
                selectedCount: selectedDiffs.count,
                onApproveAll: { approveStack() },
                onRejectAll: { rejectStack() },
                onApproveSelected: { approveSelected() },
                onRejectSelected: { rejectSelected() }
            )
        }
    }
}

struct LayerRowView: View {
    let layer: DiffLayer
    let isExpanded: Bool
    @Binding var selectedDiffs: Set<UUID>
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Layer Header
            HStack {
                Image(systemName: layer.category.icon)
                    .foregroundColor(.secondary)

                Text(layer.name)
                    .font(.headline)

                Spacer()

                // Layer Stats
                HStack(spacing: 12) {
                    StatBadge(
                        icon: "doc",
                        value: "\(layer.diffs.count)",
                        color: .blue
                    )
                    StatBadge(
                        icon: "plus",
                        value: "+\(layer.totalAdditions)",
                        color: .green
                    )
                    StatBadge(
                        icon: "minus",
                        value: "-\(layer.totalDeletions)",
                        color: .red
                    )
                }

                // Expand/Collapse
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            // Expanded Content
            if isExpanded {
                ForEach(layer.diffs) { diffId in
                    DiffSummaryRow(
                        diffId: diffId,
                        isSelected: selectedDiffs.contains(diffId),
                        onSelect: { toggleDiff(diffId) }
                    )
                }
            }
        }
    }
}
```

### Unified Diff Viewer

```swift
struct UnifiedDiffViewer: View {
    let diffs: [FileDiff]
    @State private var viewMode: DiffViewMode = .unified
    @State private var currentDiffIndex: Int = 0

    enum DiffViewMode {
        case unified      // All diffs in one scrollable view
        case sideBySide   // Original vs modified
        case sequential   // One file at a time with navigation
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("View", selection: $viewMode) {
                    Text("Unified").tag(DiffViewMode.unified)
                    Text("Side by Side").tag(DiffViewMode.sideBySide)
                    Text("Sequential").tag(DiffViewMode.sequential)
                }
                .pickerStyle(.segmented)

                Spacer()

                // Navigation (sequential mode)
                if viewMode == .sequential {
                    HStack {
                        Button(action: previousDiff) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentDiffIndex == 0)

                        Text("\(currentDiffIndex + 1) of \(diffs.count)")
                            .monospacedDigit()

                        Button(action: nextDiff) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentDiffIndex == diffs.count - 1)
                    }
                }
            }
            .padding()

            // Diff Content
            switch viewMode {
            case .unified:
                UnifiedDiffContent(diffs: diffs)
            case .sideBySide:
                SideBySideDiffContent(diffs: diffs)
            case .sequential:
                SequentialDiffContent(diff: diffs[currentDiffIndex])
            }
        }
    }
}

struct UnifiedDiffContent: View {
    let diffs: [FileDiff]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(diffs) { diff in
                    VStack(alignment: .leading, spacing: 0) {
                        // File Header
                        FileHeaderView(diff: diff)

                        // AI Explanation
                        if let explanation = diff.metadata.aiExplanation {
                            AIExplanationBanner(text: explanation)
                        }

                        // Hunks
                        ForEach(Array(diff.hunks.enumerated()), id: \.offset) { index, hunk in
                            HunkView(hunk: hunk, index: index)
                        }
                    }
                    .background(Color(.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }
}

struct HunkView: View {
    let hunk: DiffHunk
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk Header
            HStack {
                Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                if let context = hunk.context {
                    Text(context)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.purple)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))

            // Lines
            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                DiffLineView(line: line)
            }
        }
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Line Numbers
            HStack(spacing: 0) {
                Text(line.oldLineNumber.map(String.init) ?? "")
                    .frame(width: 40, alignment: .trailing)
                Text(line.newLineNumber.map(String.init) ?? "")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.trailing, 8)

            // Indicator
            Text(line.type.indicator)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(line.type.color)
                .frame(width: 16)

            // Content
            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(line.type.textColor)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(line.type.backgroundColor)
    }
}

extension LineType {
    var indicator: String {
        switch self {
        case .context: return " "
        case .addition: return "+"
        case .deletion: return "-"
        }
    }

    var color: Color {
        switch self {
        case .context: return .secondary
        case .addition: return .green
        case .deletion: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .context: return .clear
        case .addition: return Color.green.opacity(0.1)
        case .deletion: return Color.red.opacity(0.1)
        }
    }

    var textColor: Color {
        switch self {
        case .context: return .primary
        case .addition: return Color.green
        case .deletion: return Color.red
        }
    }
}
```

## Batch Actions

### Approval Workflow

```swift
class BatchReviewManager: ObservableObject {
    @Published var pendingStacks: [DiffStack] = []
    @Published var reviewQueue: [UUID] = []

    private let diffStore: DiffStore
    private let fileWriter: FileWriter

    /// Approve entire stack and apply changes
    func approveStack(_ stack: DiffStack) async throws {
        // Validate no conflicts
        try await validateNoConflicts(stack)

        // Apply in dependency order (bottom layers first)
        for layer in stack.layers.sorted(by: { $0.order < $1.order }) {
            for diffId in layer.diffs {
                guard let diff = await diffStore.getDiff(diffId) else { continue }
                try await fileWriter.applyDiff(diff)
            }
        }

        // Update stack status
        var updatedStack = stack
        updatedStack.status = .applied
        updatedStack.reviewedAt = Date()
        updatedStack.reviewDecision = .approveAll
        await diffStore.updateStack(updatedStack)

        // Notify dependents
        for dependentId in stack.dependents {
            await notifyDependencyResolved(dependentId, resolvedStack: stack.id)
        }
    }

    /// Reject entire stack
    func rejectStack(_ stack: DiffStack) async {
        var updatedStack = stack
        updatedStack.status = .rejected
        updatedStack.reviewedAt = Date()
        updatedStack.reviewDecision = .rejectAll
        await diffStore.updateStack(updatedStack)

        // Clean up any staged changes
        await cleanupStagedChanges(stack)
    }

    /// Selective approval (cherry-pick)
    func approveSelective(
        stack: DiffStack,
        approved: [UUID],
        rejected: [UUID],
        deferred: [UUID]
    ) async throws {
        // Validate approved diffs don't depend on rejected ones
        try validateDependencyIntegrity(approved: approved, rejected: rejected, in: stack)

        // Apply approved diffs
        for diffId in approved {
            guard let diff = await diffStore.getDiff(diffId) else { continue }
            try await fileWriter.applyDiff(diff)
        }

        // Update stack
        var updatedStack = stack
        updatedStack.status = .partialApproved
        updatedStack.reviewedAt = Date()
        updatedStack.reviewDecision = .selective(
            approved: approved,
            rejected: rejected,
            deferred: deferred
        )
        await diffStore.updateStack(updatedStack)

        // Create new stack for deferred items if any
        if !deferred.isEmpty {
            let deferredStack = createDeferredStack(from: stack, diffs: deferred)
            await diffStore.insertStack(deferredStack)
        }
    }

    /// Revert applied stack
    func revertStack(_ stack: DiffStack) async throws {
        guard stack.status == .applied else {
            throw ReviewError.cannotRevertUnapplied
        }

        // Revert in reverse order (top layers first)
        for layer in stack.layers.sorted(by: { $0.order > $1.order }) {
            for diffId in layer.diffs.reversed() {
                guard let diff = await diffStore.getDiff(diffId) else { continue }
                try await fileWriter.revertDiff(diff)
            }
        }

        var updatedStack = stack
        updatedStack.status = .reverted
        await diffStore.updateStack(updatedStack)
    }
}
```

### Conflict Detection

```swift
class ConflictDetector {

    /// Check for conflicts before applying diffs
    func detectConflicts(_ stack: DiffStack) async -> [DiffConflict] {
        var conflicts: [DiffConflict] = []

        for layer in stack.layers {
            for diffId in layer.diffs {
                guard let diff = await getDiff(diffId) else { continue }

                // Check if file was modified since diff was created
                if let conflict = await checkFileModified(diff) {
                    conflicts.append(conflict)
                }

                // Check for overlapping changes with other pending stacks
                if let conflict = await checkOverlappingChanges(diff) {
                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    /// Check if file on disk differs from expected state
    private func checkFileModified(_ diff: FileDiff) async -> DiffConflict? {
        guard let currentContent = try? String(contentsOfFile: diff.filePath) else {
            // File doesn't exist - only conflict if we're modifying (not creating)
            if diff.changeType == .modified {
                return DiffConflict(
                    type: .fileDeleted,
                    diff: diff,
                    message: "File was deleted since changes were proposed"
                )
            }
            return nil
        }

        if diff.changeType == .created {
            return DiffConflict(
                type: .fileAlreadyExists,
                diff: diff,
                message: "File already exists (was supposed to be created)"
            )
        }

        if currentContent != diff.originalContent {
            return DiffConflict(
                type: .contentChanged,
                diff: diff,
                message: "File was modified since changes were proposed",
                currentContent: currentContent
            )
        }

        return nil
    }
}

struct DiffConflict: Identifiable {
    let id = UUID()
    let type: ConflictType
    let diff: FileDiff
    let message: String
    let currentContent: String?

    enum ConflictType {
        case fileDeleted
        case fileAlreadyExists
        case contentChanged
        case overlappingChanges
    }
}
```

## Keyboard Shortcuts

| Action | Shortcut | Description |
|--------|----------|-------------|
| Approve Stack | ⌘ + Enter | Approve all changes in current stack |
| Reject Stack | ⌘ + Delete | Reject all changes in current stack |
| Approve Selected | ⌘ + Shift + Enter | Approve only selected diffs |
| Toggle Diff Selection | Space | Select/deselect current diff |
| Select All | ⌘ + A | Select all diffs in current stack |
| Next Stack | ⌘ + ] | Move to next pending stack |
| Previous Stack | ⌘ + [ | Move to previous stack |
| Expand Layer | → | Expand current layer |
| Collapse Layer | ← | Collapse current layer |
| Next Diff | ↓ or J | Navigate to next diff |
| Previous Diff | ↑ or K | Navigate to previous diff |
| View Diff Detail | Enter | Open detailed diff viewer |
| Toggle View Mode | ⌘ + 1/2/3 | Switch unified/side-by-side/sequential |
| Search in Diffs | ⌘ + F | Search text in all diffs |
| Jump to File | ⌘ + P | Quick jump to specific file |

## Fun Messages

### Approval Celebration
```swift
let approvalMessages = [
    // Star Wars
    "\"These are the diffs you're looking for.\" — Obi-Wan Kenobi, nodding approvingly",
    "\"Do. Or do not. You did.\" — Yoda, impressed by your code",
    "\"I find your lack of bugs... refreshing.\" — Darth Vader, unexpectedly pleased",

    // Star Trek
    "\"Make it so.\" — Captain Picard, approving your changes",
    "\"Fascinating. This code is... logical.\" — Spock, raising an eyebrow",
    "\"Shields up! Oh wait, the tests pass. Shields down.\" — Enterprise crew",

    // Marvel
    "\"I am... inevitable.\" — This merge request",
    "\"We are Groot.\" — Every approved diff in this stack",
    "\"I can do this all day.\" — You, reviewing diffs like a champ",

    // DC
    "\"It's not who I am underneath, but what my code does that defines me.\" — Batman",
    "\"In brightest day, in blackest night, no bug shall escape my sight.\" — Green Lantern Reviewer",

    // General
    "LGTM! (Looks Great To Merge)",
    "Ship it! 🚀",
    "You may fire when ready.",
]
```

### Rejection Comfort
```swift
let rejectionMessages = [
    // Star Wars
    "\"I've got a bad feeling about this.\" — Han Solo, scanning the diff",
    "\"It's a trap!\" — Admiral Ackbar, spotting the bug",
    "\"You were supposed to destroy the bugs, not join them!\" — Obi-Wan, sadly",

    // Star Trek
    "\"He's dead, Jim.\" — Dr. McCoy, checking the build status",
    "\"I'm a doctor, not a code reviewer! Wait, yes I am. This needs work.\"",
    "\"Resistance is futile. But so is this code.\" — The Borg",

    // Marvel
    "\"We don't do that here.\" — T'Challa, on spaghetti code",
    "\"That's my secret, Cap. I'm always refactoring.\" — Bruce Banner",
    "\"I've seen 14,000,605 futures. In only one does this code ship.\"",

    // DC
    "\"Why do we fall? So we can learn to write better code.\" — Alfred",
    "\"You either die a hero, or live long enough to see yourself write legacy code.\"",
]
```

### Conflict Alerts
```swift
let conflictMessages = [
    "\"I sense a disturbance in the Force... and in line 42.\" — Obi-Wan",
    "\"There can be only one!\" — Merge conflict, channeling Highlander",
    "\"Houston, we have a problem.\" — Apollo 13 reviewing your rebase",
    "\"Multiverse detected! Your timeline diverged from main.\"",
    "\"To merge, or not to merge—that is the conflict.\" — Hamlet, developer",
]
```

## Integration with CLI Events

### Mapping Claude Code Events to Stacks

```swift
extension ClaudeCodeAdapter {

    /// Process file diff events and organize into stacks
    func processFileDiffEvent(_ event: FileDiffProduced) async {
        let fileDiff = FileDiff(
            id: UUID(),
            sessionId: currentSessionId,
            stackId: nil, // Assigned after stack detection
            filePath: event.filePath,
            originalContent: event.originalContent,
            modifiedContent: event.modifiedContent,
            hunks: parseDiffHunks(event.diff),
            changeType: event.changeType,
            timestamp: Date(),
            metadata: DiffMetadata(
                language: detectLanguage(event.filePath),
                symbols: extractSymbolChanges(event.diff),
                complexity: calculateComplexityDelta(event),
                testCoverage: nil,
                aiExplanation: event.explanation
            )
        )

        // Add to pending diffs
        pendingDiffs.append(fileDiff)

        // Debounce stack detection (wait for related diffs)
        stackDetectionDebouncer.call {
            await self.detectAndCreateStacks()
        }
    }

    /// Detect stacks after debounce period
    private func detectAndCreateStacks() async {
        let detector = StackDetector()
        let stacks = await detector.detectStacks(
            diffs: pendingDiffs,
            context: sessionContext
        )

        // Assign diffs to stacks
        for stack in stacks {
            for layer in stack.layers {
                for diffId in layer.diffs {
                    if let index = pendingDiffs.firstIndex(where: { $0.id == diffId }) {
                        pendingDiffs[index].stackId = stack.id
                    }
                }
            }
        }

        // Save to store
        await diffStore.insertStacks(stacks)
        await diffStore.insertDiffs(pendingDiffs)

        // Clear pending
        pendingDiffs = []

        // Notify UI
        NotificationCenter.default.post(name: .newStacksAvailable, object: stacks)
    }
}
```

## Performance Considerations

### Large Diff Handling

```swift
class DiffOptimizer {

    /// Stream large diffs instead of loading fully
    func streamLargeDiff(_ diff: FileDiff, chunkSize: Int = 1000) -> AsyncStream<[DiffLine]> {
        AsyncStream { continuation in
            Task {
                var buffer: [DiffLine] = []

                for hunk in diff.hunks {
                    for line in hunk.lines {
                        buffer.append(line)

                        if buffer.count >= chunkSize {
                            continuation.yield(buffer)
                            buffer = []
                        }
                    }
                }

                if !buffer.isEmpty {
                    continuation.yield(buffer)
                }

                continuation.finish()
            }
        }
    }

    /// Virtualize rendering for long diffs
    func calculateVisibleRange(
        scrollOffset: CGFloat,
        viewportHeight: CGFloat,
        lineHeight: CGFloat,
        totalLines: Int
    ) -> Range<Int> {
        let buffer = 50 // Extra lines above/below viewport
        let startLine = max(0, Int(scrollOffset / lineHeight) - buffer)
        let visibleLines = Int(viewportHeight / lineHeight) + (buffer * 2)
        let endLine = min(totalLines, startLine + visibleLines)

        return startLine..<endLine
    }
}
```

## Testing

```swift
class DiffStackingTests: XCTestCase {

    func testStackDetectionGroupsRelatedDiffs() async {
        // Given
        let diffs = [
            createDiff(path: "models/User.swift", content: "struct User {}"),
            createDiff(path: "routes/users.swift", content: "import models"),
            createDiff(path: "views/UserView.swift", content: "import models"),
            createDiff(path: "README.md", content: "# Docs"), // Unrelated
        ]

        let detector = StackDetector()

        // When
        let stacks = await detector.detectStacks(diffs: diffs, context: mockContext)

        // Then
        XCTAssertEqual(stacks.count, 2) // User-related stack + Docs stack

        let userStack = stacks.first { $0.name.contains("User") }!
        XCTAssertEqual(userStack.layers.flatMap(\.diffs).count, 3)
    }

    func testLayerOrderingFollowsArchitecture() async {
        // Given
        let diffs = [
            createDiff(path: "views/Home.swift"),
            createDiff(path: "models/Data.swift"),
            createDiff(path: "migrations/001.sql"),
        ]

        let detector = StackDetector()

        // When
        let stacks = await detector.detectStacks(diffs: diffs, context: mockContext)
        let stack = stacks.first!

        // Then - layers ordered: schema -> model -> ui
        XCTAssertEqual(stack.layers[0].category, .schema)
        XCTAssertEqual(stack.layers[1].category, .model)
        XCTAssertEqual(stack.layers[2].category, .ui)
    }

    func testConflictDetection() async {
        // Given
        let diff = createDiff(
            path: "test.swift",
            original: "let x = 1",
            modified: "let x = 2"
        )

        // Simulate file changed on disk
        try! "let x = 3".write(toFile: "test.swift", atomically: true, encoding: .utf8)

        let detector = ConflictDetector()

        // When
        let conflicts = await detector.detectConflicts(createStack(diffs: [diff]))

        // Then
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].type, .contentChanged)
    }

    func testBatchApprovalAppliesInOrder() async throws {
        // Given
        let stack = createStack(layers: [
            createLayer(category: .schema, diffs: [schemaDiff]),
            createLayer(category: .model, diffs: [modelDiff]),
            createLayer(category: .api, diffs: [apiDiff]),
        ])

        var appliedOrder: [String] = []
        let mockWriter = MockFileWriter { path in
            appliedOrder.append(path)
        }

        let manager = BatchReviewManager(fileWriter: mockWriter)

        // When
        try await manager.approveStack(stack)

        // Then - applied in dependency order
        XCTAssertEqual(appliedOrder, [
            "migrations/001.sql",  // Schema first
            "models/Data.swift",   // Then models
            "routes/api.swift",    // Then API
        ])
    }
}
```

## Accessibility

- All diff content readable by VoiceOver with proper annotations
- Line changes announced: "Line 42, addition: let x = 1"
- Stack status announced: "Stack 'Add Authentication', 3 layers, 7 files, pending review"
- Keyboard navigation for all review actions
- High contrast mode for diff highlighting
- Configurable color scheme for colorblind users (deuteranopia, protanopia)

---

*"I have been, and always shall be, your merge conflict resolver." — Spock, code reviewer*
