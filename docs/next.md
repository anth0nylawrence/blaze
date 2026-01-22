# Blaze Next Features: Deep Dive Research

**Date:** 2026-01-22
**Source:** Auto-Claude analysis + SwiftUI patterns research
**Decision:** Add Kanban + Memory + AI Merge to roadmap

---

## Confirmed Decisions

| Feature | Decision | Rationale |
|---------|----------|-----------|
| **Kanban** | 4 columns, separate terminal | Cleaner UX, terminal in main view not cards |
| **Memory** | Project-local (`<project>/.blaze/memory/`) | Portable, git-trackable, project-scoped |
| **AI Merge** | Regex-first (not tree-sitter) | Ship fast, Auto-Claude proves it works at 90% accuracy |

---

## Executive Summary

Three features from Auto-Claude have been identified for Blaze integration:

| Feature | Complexity | MVP Timeline | Competitive Value |
|---------|------------|--------------|-------------------|
| **Kanban Board** | Medium | 11-13 days | HIGH - immediate UX win |
| **Memory Layer** | Medium-High | 7-14 days | MEDIUM - better returning UX |
| **AI-Powered Merge** | High | 2-4 weeks | HIGH - unique differentiator |

**Key Insight:** Git worktrees are already implemented in Blaze (`GitWorktreeManager.swift`, 510 lines), so the foundation for parallel work is ready.

---

## Feature 1: Kanban Board

### What It Does

Visual task management showing sessions moving through workflow columns:
- **Queued** → **Running** → **Review** → **Done**
- Drag-and-drop reordering
- Live progress indicators
- Engine badges (Claude/Gemini/Codex)

### Auto-Claude Implementation

**Location:** `/apps/frontend/src/renderer/components/KanbanBoard.tsx` (965 lines)

**Technology:** React + @dnd-kit/core for drag-drop

**Columns (5-stage):**
```
Backlog → In Progress → AI Review → Human Review → Done
```

**Key Patterns:**
- `DndContext` wrapper with collision detection
- `SortableContext` per column for reordering
- `useSortable` hook for drag handles
- `DragOverlay` for visual feedback during drag

### Recommended Blaze Implementation

**Columns (Simplified to 4):**
```
┌─────────┬──────────┬─────────┬──────┐
│ Queued  │ Running  │ Review  │ Done │
└─────────┴──────────┴─────────┴──────┘
```

**Why 4 instead of 5:**
- Collapse AI Review + Human Review into single "Review"
- Simpler mental model
- Matches existing `Session.status` enum
- Can expand to 5 columns later if needed

**SwiftUI Approach:**
- iOS 16+ `.draggable()` and `.dropDestination()` modifiers
- `LazyVStack` per column for performance (50+ sessions)
- Optimistic UI updates with rollback on error

**Data Model:**
```swift
struct SessionCard {
  let id: UUID
  var name: String
  var status: SessionStatus      // queued | running | review | done
  var engineType: EngineType     // claude | gemini | codex
  var progress: ExecutionProgress?
  var metadata: SessionMetadata  // tokens, cost, turnCount
  var updatedAt: Date
}

struct ExecutionProgress {
  var phase: String              // "planning" | "coding" | "review"
  var phaseProgress: Double      // 0.0-1.0
  var currentTool: String?
  var message: String?
}
```

**Layout Integration:**
```
Toolbar: [List View] [Kanban View]

Kanban Mode:
┌─────────────────────────────────────┬──────────┐
│          Kanban Board               │ Sidebar  │
│   (full width, 4 columns)           │ (right)  │
└─────────────────────────────────────┴──────────┘
```

**State Transitions:**

| Trigger | From → To |
|---------|-----------|
| Start button | Queued → Running |
| CLI exit (success) | Running → Review |
| CLI exit (error) | Running → Review (with error badge) |
| Merge button | Review → Done |
| Drag-drop | Any → Any (with validation) |

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SwiftUI drag perf | `LazyVStack` + Instruments profiling |
| State sync | Single source of truth (SessionStore) + `@Published` |
| Complex drag logic | Phase 1: cross-column only, Phase 2: reordering |
| Running session drag | Block drag or show confirmation dialog |

### Open Questions

1. **Archived sessions in Done?** → Recommend: toggleable "Show Archived" (off by default)
2. **Multi-selection for batch ops?** → Shift+Click to multi-select for bulk merge
3. **Column widths?** → Fixed initially, resize handles in Phase 2
4. **Turn count display?** → Badge showing "12 turns" on card

### Implementation Phases

**Phase 1 (MVP): 11-13 days**
1. Prototype layout (2-3 days)
2. Drag-drop mechanics (3-4 days)
3. Progress visualization (2 days)
4. Persistence (2 days)
5. Polish & testing (2 days)

---

## Feature 2: Memory Layer

### What It Does

Persists learnings between sessions:
- What worked / what failed
- Codebase patterns discovered
- Gotchas to avoid
- Cross-session context retrieval

### Auto-Claude Implementation

**Location:** `/apps/backend/memory/`, `/apps/backend/agents/memory_manager.py`

**Dual-Layer Architecture:**
1. **Primary:** File-based (JSONL + Markdown) - always works, zero deps
2. **Secondary:** Graphiti/LadybugDB - semantic search with embeddings

**7 Memory Types:**
- Session insights (what worked/failed)
- File discoveries (path → purpose mappings)
- Code patterns (conventions to follow)
- Gotchas (pitfalls to avoid)
- Tool outcomes (success/failure learnings)
- Task outcomes
- Historical context

**Retrieval Pattern:**
- Semantic search via embeddings (0.4-0.6 similarity scores)
- Injected as markdown at session start + subtask boundaries
- Agent tools for explicit memory queries

### Recommended Blaze Implementation

**Storage Location:**
```
~/.blaze/memory/              # Global memories
<project>/.blaze/memory/      # Project-specific memories
```

**Storage Format (Phase 1 - File-Based):**
```
memories/
├── insights.jsonl            # Append-only session learnings
├── patterns/                 # Markdown files per pattern
│   ├── error-handling.md
│   └── testing-conventions.md
├── gotchas/                  # Things to avoid
│   └── async-pitfalls.md
└── index.sqlite              # SQLite for fast search
```

**Memory Entry Schema:**
```swift
struct MemoryEntry: Codable {
  let id: UUID
  let type: MemoryType         // insight | pattern | gotcha | discovery
  let content: String
  let context: String          // Where it applies
  let projectPath: String?     // nil = global
  let sessionId: UUID?
  let createdAt: Date
  let confidence: Double       // 0.0-1.0
  let tags: [String]
}

enum MemoryType: String, Codable {
  case insight     // What worked/failed
  case pattern     // Code convention
  case gotcha      // Pitfall to avoid
  case discovery   // File/API mapping
}
```

**Injection Points:**
1. **Session start:** Inject relevant memories as system context
2. **Tool call:** Look up gotchas for specific tools
3. **Error recovery:** Recall past solutions for similar errors

**Format for CLI Injection:**
```markdown
## Relevant Memories

### What worked before
- Using `async let` for parallel API calls improved performance 3x (2026-01-15)

### Gotchas to avoid
- Don't use `DispatchQueue.main.sync` from main thread - deadlock risk

### Patterns in this codebase
- All API calls go through `NetworkService.shared`
- Errors use `BlazeError` enum with associated values
```

### Semantic Search Options

| Phase | Approach | Pros | Cons |
|-------|----------|------|------|
| 1 | CoreML NaturalLanguage | Native, offline, free | Lower quality embeddings |
| 2 | Python bridge (sentence-transformers) | High quality, local | Requires Python runtime |
| 3 | API embeddings (OpenAI/Anthropic) | Best quality | Cost, requires network |

**Recommendation:** Start with CoreML NaturalLanguage for MVP, add better embeddings later.

### Privacy Considerations

- **Default:** Session-scoped memories (not shared across projects)
- **Opt-in:** Project-wide and global memories
- **Secret filtering:** Regex scan before storing (API keys, passwords)
- **Local only:** No cloud sync in Phase 1

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Storage bloat | Auto-archive memories older than 90 days |
| Stale memories | Confidence decay over time |
| Irrelevant injection | Only inject high-confidence (>0.7) matches |
| Secret leakage | Regex filter + manual review option |

### Open Questions

1. **Memory lifetime?** → Recommend: decay confidence over time, archive at 0.3
2. **Conflict resolution?** → Newer memory wins, keep both if different context
3. **Export format?** → JSONL for portability
4. **Memory UI?** → Sidebar panel showing recent memories + search

### Implementation Phases

**Phase 1 (MVP): 7 days**
1. JSONL storage layer (2 days)
2. SQLite index for search (1 day)
3. Session injection (2 days)
4. Basic UI panel (2 days)

**Phase 2 (Enhanced): +7 days**
1. CoreML embeddings
2. Semantic search
3. Confidence decay
4. Export/import

---

## Feature 3: AI-Powered Merge

### What It Does

Automatically resolves git merge conflicts when integrating worktree changes to main:
1. Tracks file evolution with baselines
2. Analyzes semantic changes (not just text diffs)
3. Applies deterministic merges where possible
4. Calls AI only for ambiguous conflicts

### Auto-Claude Implementation

**Location:** `/apps/backend/merge/` (~52 Python files)

**Key Components:**
- `orchestrator.py` (755 lines) - Main coordinator
- `semantic_analyzer.py` - Extracts semantic changes
- `conflict_detector.py` - Identifies overlapping changes
- `auto_merger.py` - Deterministic merge rules
- `ai_resolver/resolver.py` (418 lines) - AI fallback

**3-Layer Pipeline:**

```
1. Semantic Analysis (Regex-based)
   ↓
2. Conflict Detection (Rule-based compatibility)
   ↓
3. Resolution (AutoMerger → AI fallback)
```

**Critical Insight: Regex, Not Tree-sitter**

Auto-Claude uses **regex patterns**, not tree-sitter AST parsing:
- No dependencies
- Fast startup (~10ms per file)
- Good enough for merge detection
- 77 change types covering Python, JS/TS, React

**Semantic Change Types (examples):**
```python
ADD_IMPORT
MODIFY_FUNCTION
ADD_CLASS
RENAME_VARIABLE
ADD_HOOK_CALL      # React-specific
MODIFY_STATE       # React-specific
ADD_TEST_CASE
```

**Deterministic Merge Strategies (9 total):**

| Strategy | When Used | Logic |
|----------|-----------|-------|
| `COMBINE_IMPORTS` | Both tasks add imports | Merge + dedupe |
| `APPEND_FUNCTIONS` | Both tasks add functions | Add to end of file |
| `HOOKS_THEN_WRAP` | React hook + JSX change | Hooks first, then wrap |
| `PRESERVE_ORDER` | Non-conflicting changes | Apply in original order |

**AI Fallback Triggers:**
- Same function modified by both tasks
- Conflicting control flow changes
- Semantic analyzer can't determine compatibility

**Minimal Context Approach:**
- Only send conflict region (not entire file)
- Include task intents (from specs)
- <4000 tokens per AI call
- Cost: <$0.01 per merge

### Recommended Blaze Implementation

**Architecture:**
```swift
// 1. Orchestrator
class MergeOrchestrator {
  let analyzer: SemanticAnalyzer
  let detector: ConflictDetector
  let autoMerger: AutoMerger
  let aiResolver: AIResolver

  func merge(worktree: WorktreeInfo, into branch: String) async throws -> MergeResult
}

// 2. Semantic Analyzer (regex-based)
class SemanticAnalyzer {
  func analyze(diff: GitDiff) -> [SemanticChange]
}

// 3. Conflict Detector
class ConflictDetector {
  func detectConflicts(_ changes: [SemanticChange]) -> [Conflict]
  func canAutoMerge(_ conflict: Conflict) -> Bool
}

// 4. Auto Merger
class AutoMerger {
  func resolve(_ conflict: Conflict, strategy: MergeStrategy) -> Resolution
}

// 5. AI Resolver (via EngineAdapter)
class AIResolver {
  func resolve(_ conflict: Conflict, using engine: EngineAdapter) async throws -> Resolution
}
```

**Semantic Change Model:**
```swift
struct SemanticChange {
  let type: ChangeType
  let file: String
  let startLine: Int
  let endLine: Int
  let content: String
  let metadata: [String: Any]  // Function name, class name, etc.
}

enum ChangeType: String {
  case addImport
  case modifyFunction
  case addClass
  case addHookCall
  // ... 77 total types
}
```

**AI Resolver Prompt (minimal context):**
```
You are resolving a git merge conflict.

## Conflict Context
File: {filename}
Lines: {start_line}-{end_line}

## Task A Intent
{task_a_description}

## Task A Changes
```{language}
{task_a_diff}
```

## Task B Intent
{task_b_description}

## Task B Changes
```{language}
{task_b_diff}
```

## Instructions
Produce the merged code that:
1. Preserves functionality from both tasks
2. Follows the codebase style
3. Resolves any naming conflicts

Output ONLY the merged code, no explanation.
```

**Provider-Agnostic via EngineAdapter:**
```swift
protocol EngineAdapter {
  func resolveConflict(_ conflict: Conflict, context: MergeContext) async throws -> String
}

// Claude implementation
class ClaudeAdapter: EngineAdapter {
  func resolveConflict(_ conflict: Conflict, context: MergeContext) async throws -> String {
    // Call Claude API directly (not via CLI for speed)
  }
}
```

### UI Design

**Merge Preview (4-pane diff viewer):**
```
┌─────────────┬─────────────┐
│   Task A    │   Task B    │
│   Changes   │   Changes   │
├─────────────┴─────────────┤
│        Merged Result       │
│    (editable by user)      │
└───────────────────────────┘
[Auto-Resolve] [Accept] [Cancel]
```

**Merge Status Badges:**
- 🟢 "Auto-merged" - deterministic rules applied
- 🟡 "AI-resolved" - AI produced merge
- 🔴 "Manual needed" - user must resolve

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Wrong merge | Always show preview, require user approval |
| Token costs | Minimal context approach (<$0.01/merge) |
| Language gaps | Start with Swift/TS/Python, expand later |
| Complex conflicts | Graceful fallback to manual merge |

### Open Questions

1. **Tree-sitter or regex?** → Recommend: regex for MVP (Auto-Claude proves it works)
2. **Which languages first?** → Swift, TypeScript, Python (Blaze's stack)
3. **Merge history?** → SQLite table tracking all merges for audit
4. **Undo merge?** → Git reflog + UI "Revert Merge" button

### Implementation Phases

**Phase 1 (MVP): 2 weeks**
1. Port types + semantic analyzer (3 days)
2. Implement 3 core strategies: COMBINE_IMPORTS, APPEND_FUNCTIONS, PRESERVE_ORDER (4 days)
3. AI resolver via EngineAdapter (3 days)
4. Basic merge UI (4 days)

**Phase 2 (Full): +2 weeks**
1. All 9 merge strategies
2. Multi-file batch merging
3. Merge history + audit
4. Conflict prediction (warn before work starts)

---

## Implementation Priority

**Recommended Order:**

```
1. Kanban Board (11-13 days)
   └─ Immediate UX improvement
   └─ No dependencies
   └─ User-visible value

2. Memory Layer (7-14 days)
   └─ Better returning user experience
   └─ Builds on session data
   └─ Can start file-based, enhance later

3. AI-Powered Merge (2-4 weeks)
   └─ Most complex
   └─ Depends on worktrees (already done)
   └─ Competitive differentiator
```

**Total Timeline: 5-7 weeks** for all three features (MVP versions)

---

## UI/UX Design Excellence

### Design Philosophy: Not AI Slop

Blaze must feel **premium** - like Arc Browser, Raycast, Things 3. Not generic Bootstrap-looking garbage.

### Color Specifications

**Session State Colors:**
```swift
enum SessionStateColor {
    static let idle = Color(hex: "#6B7280")     // Gray - waiting
    static let running = Color(hex: "#60A5FA")  // Blue - active pulse
    static let review = Color(hex: "#FBBF24")   // Amber - needs attention
    static let done = Color(hex: "#34D399")     // Green - success
    static let errored = Color(hex: "#F87171")  // Red - failed
}
```

**Engine Badge Colors (Brand-Accurate):**
```swift
enum EngineBrandColor {
    static let claude = Color(hex: "#D97757")   // Anthropic orange
    static let gemini = Color(hex: "#4285F4")   // Google blue
    static let codex = Color(hex: "#10A37F")    // OpenAI green
}
```

### Animation Constants (SwiftUI Springs)

```swift
enum DSAnimation {
    // Fast interactions (button press, hover)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.75)

    // Most UI transitions (card move, panel slide)
    static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.8)

    // Success states (completion, checkmark)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    // Large content (sheet present, overlay)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.9)
}
```

### Card Design (ASCII Sketch)

```
┌────────────────────────────────────────────┐
│ ┌──────┐  Add OAuth to login flow          │
│ │Claude│  ───────────────────────────      │
│ └──────┘  Planning • 45%                   │
│                                            │
│  ████████████░░░░░░░░░  2m ago            │
│                                            │
│  🧠 3 memories   📝 12 turns   ⏱ 4:32     │
└────────────────────────────────────────────┘
```

**Visual Elements:**
- Engine badge: 12×16px with brand color, 0.5pt border
- Progress bar: Gradient from blue to green as progress increases
- Memory indicator: Brain icon + count (shows agent remembers context)
- Subtle pulse animation when running

### Drag-Drop Feedback

1. **On drag start:** Card lifts (scale 1.02), shadow increases
2. **Over valid column:** Column background highlights (#3B82F6 at 10% opacity)
3. **On drop:** Card snaps with `bouncy` spring, brief scale overshoot (1.05 → 1.0)

### Premium Touches

- **Glass panels:** `ultraThinMaterial` with layered borders
- **Hover reveals:** Actions appear on hover, fade on leave
- **Keyboard shortcuts:** All actions have shortcuts, hints shown on hover
- **Reduced motion:** Respect `accessibilityReduceMotion` with linear 0.1s fallback

---

## Multi-CLI Connectivity

### Unified Adapter Pattern

Blaze normalizes heterogeneous CLI outputs into a single event stream:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Claude Code    │     │   Gemini CLI    │     │   Codex CLI     │
│  (NDJSON)       │     │   (NDJSON)      │     │   (JSON-RPC)    │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │    NormalizedEvent    │
                     │    (35+ event types)  │
                     └───────────┬───────────┘
                                 │
                     ┌───────────▼───────────┐
                     │    Kanban / Memory    │
                     │    / Timeline UI      │
                     └───────────────────────┘
```

### Event Comparison Table

| Event Type | Claude Code | Gemini CLI | Codex CLI |
|------------|-------------|------------|-----------|
| **Stream format** | NDJSON | NDJSON | JSON-RPC notifications |
| **Session resume** | Blaze-managed | Native `--resume` | Native `resume` |
| **Tool approval** | PTY stdin | CLI auto-deny | `--full-auto` flag |
| **Progress tracking** | toolCallStarted/Complete | Similar | turnPlanUpdated |
| **Cost reporting** | tokenUsage event | aggregatedStats | costUpdate |

### EngineAdapter Protocol

```swift
@MainActor
protocol EngineAdapter: AnyObject, Sendable {
    var engineType: EngineType { get }

    /// Start a turn and return event stream
    func startTurn(prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent>

    /// Validate CLI installation
    func validateInstallation() async throws -> CLIInfo

    /// Cancel running turn
    func cancelTurn() async

    /// Feature detection
    func supports(feature: EngineFeature) -> Bool
}
```

### Session Isolation Pattern

Each session gets its own adapter instance to prevent PTY bleeding:

```swift
let adapter = engineManager.adapter(for: .claude, sessionId: session.id)
```

### Progressive Feature Disclosure

If an engine doesn't support a feature, hide it:

```swift
if adapter.supports(.toolApproval) {
    showToolApprovalUI()
} else {
    autoApproveTools()  // Gemini doesn't support interactive approval
}
```

---

## Implementation Architecture

### State Management: @Observable

Migrate from `@ObservableObject` to Swift 5.9 `@Observable`:

```swift
@Observable
@MainActor
final class ObservableSessionStore {
    private(set) var sessions: [Session] = []
    var currentSessionId: UUID?

    var currentSession: Session? {
        sessions.first { $0.id == currentSessionId }
    }
}
```

**Benefits:**
- Only accessed properties trigger view updates (not all `@Published`)
- Simpler syntax (no `@Published` wrappers)
- Better performance

### Split AppState (Currently 700+ Lines)

```
Before:                          After:
┌──────────────────┐            ┌──────────────────┐
│    AppState      │            │ SessionStore     │
│  - sessions      │            └──────────────────┘
│  - events        │   →        ┌──────────────────┐
│  - fileTabs      │            │ EventStore       │
│  - toolPrompts   │            └──────────────────┘
│  - subagents     │            ┌──────────────────┐
│  - terminalState │            │ FileTabStore     │
└──────────────────┘            └──────────────────┘
                                ┌──────────────────┐
                                │ AppCoordinator   │ (mediates)
                                └──────────────────┘
```

### Error Handling with Recovery

```swift
enum BlazeError: Error, LocalizedError {
    case cliNotInstalled(EngineType)
    case cliAuthRequired(EngineType)
    case turnTimeout(sessionId: UUID)

    var recoveryAction: RecoveryAction? {
        switch self {
        case .cliNotInstalled(let type):
            return .openURL(type.installURL)
        case .cliAuthRequired(let type):
            return .runCommand("Run: \(type.authCommand)")
        default: return nil
        }
    }
}
```

### Performance Targets

- **60fps** with 50+ animated Kanban cards
- **<100ms** memory semantic search
- **<16ms** frame time (verified with Instruments)
- **<200MB** memory with large sessions (1000+ events)

---

## Files to Reference

### Auto-Claude (analyzed)

**Kanban:**
- `/apps/frontend/src/renderer/components/KanbanBoard.tsx` (965 lines)
- `/apps/frontend/src/renderer/components/TaskCard.tsx` (675 lines)
- `/apps/frontend/src/shared/types/task.ts` (493 lines)

**Memory:**
- `/apps/backend/memory/__init__.py`
- `/apps/backend/agents/memory_manager.py`
- `/apps/backend/integrations/graphiti/`

**Merge:**
- `/apps/backend/merge/orchestrator.py` (755 lines)
- `/apps/backend/merge/ai_resolver/resolver.py` (418 lines)
- `/apps/backend/merge/conflict_detector.py` (184 lines)
- `/apps/backend/merge/semantic_analyzer.py` (150 lines)

### Blaze (current)

**Relevant existing code:**
- `/Blaze/Sources/Core/GitWorktreeManager.swift` (510 lines) - worktrees ready
- `/Blaze/Sources/Data/SessionStore.swift` - session persistence
- `/Blaze/Sources/Core/Models.swift` - Session model
- `/Blaze/Sources/Engine/EngineAdapter.swift` - provider abstraction

---

## Next Steps

1. **Review this document** - Discuss refinements
2. **Create atoms** - Add to `docs/atoms/atoms.jsonl` with verification steps
3. **Prioritize** - Confirm Kanban → Memory → Merge order
4. **Start Kanban** - Begin with layout prototype
