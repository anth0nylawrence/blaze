# Context Window Management Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines how Blaze tracks, displays, and manages the context window (token budget) for AI sessions. It covers token counting, budget visualization, automatic summarization, and context compaction strategies.

**Why This Matters:** AI models have finite context windows. Without proactive management, conversations will hit limits unexpectedly, lose important context, or incur unnecessary costs.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Token Counting](#2-token-counting)
3. [Budget Visualization](#3-budget-visualization)
4. [Context Breakdown](#4-context-breakdown)
5. [Compaction Strategies](#5-compaction-strategies)
6. [Auto-Summarization](#6-auto-summarization)
7. [User Controls](#7-user-controls)
8. [Implementation](#8-implementation)

---

## 1. Core Concepts

### 1.1 What is Context Window?

The **context window** is the total number of tokens a model can process in a single request. It includes:

- **System prompt** (Blaze instructions, policies)
- **Conversation history** (messages, tool calls, responses)
- **File contents** (attached files, code snippets)
- **Tool outputs** (command results, diffs)

### 1.2 Token Budget Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CONTEXT WINDOW BUDGET                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Total Context Window: 200,000 tokens (Claude 3.5)                  │
│  ═══════════════════════════════════════════════════════════════    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ System Prompt        │ 2,000 tokens (1%)                    │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Policy Context       │ 500 tokens (0.25%)                   │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Conversation History │ 45,000 tokens (22.5%)                │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Attached Files       │ 80,000 tokens (40%)                  │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Tool Outputs         │ 30,000 tokens (15%)                  │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Reserve (Output)     │ 16,000 tokens (8%)                   │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ Available            │ 26,500 tokens (13.25%)               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Used: 173,500 / 200,000 (86.75%)                                   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 Model Context Limits

| Model | Context Window | Output Reserve | Usable |
|-------|---------------|----------------|--------|
| Claude 3.5 Sonnet | 200,000 | 8,192 | 191,808 |
| Claude 3 Opus | 200,000 | 4,096 | 195,904 |
| Claude 3 Haiku | 200,000 | 4,096 | 195,904 |
| GPT-4 Turbo | 128,000 | 4,096 | 123,904 |
| Gemini 1.5 Pro | 1,000,000 | 8,192 | 991,808 |

---

## 2. Token Counting

### 2.1 Counting Strategy

Since exact tokenization requires model-specific tokenizers, we use approximation:

```swift
struct TokenCounter {
    /// Approximate tokens using character-based heuristic
    /// Claude uses ~4 characters per token on average for English
    static func approximateTokens(_ text: String) -> Int {
        let charCount = text.count
        // Add overhead for special tokens, formatting
        let baseTokens = Int(Double(charCount) / 3.5)
        let overhead = max(10, baseTokens / 20) // 5% overhead minimum
        return baseTokens + overhead
    }

    /// Count tokens for a message with role
    static func countMessage(_ message: Message) -> Int {
        var tokens = 0

        // Role tokens (assistant, user, system)
        tokens += 4

        // Content tokens
        tokens += approximateTokens(message.content)

        // Tool use tokens (if applicable)
        if let toolUse = message.toolUse {
            tokens += approximateTokens(toolUse.name)
            tokens += approximateTokens(toolUse.inputJSON)
        }

        return tokens
    }

    /// Count tokens for file content
    static func countFile(_ content: String, language: String?) -> Int {
        // Code typically has higher token density
        let multiplier: Double = language != nil ? 0.9 : 1.0
        return Int(Double(approximateTokens(content)) * multiplier)
    }
}
```

### 2.2 Real-Time Tracking

```swift
@Observable
class ContextBudgetTracker {
    private(set) var breakdown: ContextBreakdown = .empty
    private(set) var totalUsed: Int = 0
    private(set) var totalLimit: Int = 200_000
    private(set) var percentageUsed: Double = 0

    func recalculate(session: Session, model: ModelInfo) async {
        totalLimit = model.contextWindow

        var newBreakdown = ContextBreakdown()

        // Count system prompt
        newBreakdown.systemPrompt = TokenCounter.approximateTokens(
            session.systemPrompt ?? ""
        )

        // Count policy context
        newBreakdown.policyContext = TokenCounter.approximateTokens(
            session.policyContext ?? ""
        )

        // Count conversation history
        for message in session.messages {
            newBreakdown.conversationHistory += TokenCounter.countMessage(message)
        }

        // Count attached files
        for file in session.attachedFiles {
            newBreakdown.attachedFiles += TokenCounter.countFile(
                file.content,
                language: file.language
            )
        }

        // Count recent tool outputs
        for output in session.recentToolOutputs {
            newBreakdown.toolOutputs += TokenCounter.approximateTokens(output)
        }

        // Reserve for output
        newBreakdown.outputReserve = model.maxOutputTokens

        breakdown = newBreakdown
        totalUsed = newBreakdown.total
        percentageUsed = Double(totalUsed) / Double(totalLimit) * 100
    }
}

struct ContextBreakdown {
    var systemPrompt: Int = 0
    var policyContext: Int = 0
    var conversationHistory: Int = 0
    var attachedFiles: Int = 0
    var toolOutputs: Int = 0
    var outputReserve: Int = 0

    var total: Int {
        systemPrompt + policyContext + conversationHistory +
        attachedFiles + toolOutputs + outputReserve
    }

    static let empty = ContextBreakdown()
}
```

---

## 3. Budget Visualization

### 3.1 Progress Bar Component

```swift
struct ContextBudgetBar: View {
    let tracker: ContextBudgetTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatTokens(tracker.totalUsed)) / \(formatTokens(tracker.totalLimit))")
                    .font(.caption.monospacedDigit())
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * fillPercentage)
                }
            }
            .frame(height: 8)
        }
    }

    private var fillPercentage: Double {
        min(1.0, tracker.percentageUsed / 100)
    }

    private var barColor: Color {
        switch tracker.percentageUsed {
        case 0..<60:
            return .green
        case 60..<80:
            return .yellow
        case 80..<95:
            return .orange
        default:
            return .red
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
```

### 3.2 Detailed Breakdown View

```swift
struct ContextBreakdownView: View {
    let breakdown: ContextBreakdown
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context Breakdown")
                .font(.headline)

            ForEach(categories, id: \.name) { category in
                HStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    Text(category.name)
                        .font(.caption)
                    Spacer()
                    Text("\(formatTokens(category.tokens))")
                        .font(.caption.monospacedDigit())
                    Text("(\(formatPercent(category.tokens)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Available")
                    .fontWeight(.medium)
                Spacer()
                Text("\(formatTokens(available))")
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
    }

    private var categories: [(name: String, tokens: Int, color: Color)] {
        [
            ("System Prompt", breakdown.systemPrompt, .blue),
            ("Policies", breakdown.policyContext, .purple),
            ("Conversation", breakdown.conversationHistory, .green),
            ("Files", breakdown.attachedFiles, .orange),
            ("Tool Outputs", breakdown.toolOutputs, .yellow),
            ("Output Reserve", breakdown.outputReserve, .gray)
        ]
    }

    private var available: Int {
        max(0, limit - breakdown.total)
    }
}
```

### 3.3 Warning Thresholds

| Threshold | Indicator | User Action |
|-----------|-----------|-------------|
| < 60% | Green bar | Normal operation |
| 60-80% | Yellow bar + icon | Consider summarizing |
| 80-95% | Orange bar + warning | Prompt to compact |
| > 95% | Red bar + alert | Force compaction or block |

---

## 4. Context Breakdown

### 4.1 Category Definitions

| Category | What It Includes | Optimization Options |
|----------|------------------|---------------------|
| **System Prompt** | Blaze instructions, CLAUDE.md | Compress, remove optional parts |
| **Policy Context** | Active policies, rules | Lazy load only relevant |
| **Conversation** | Messages, tool calls, results | Summarize old messages |
| **Attached Files** | User-attached files | Detach, chunk, or summarize |
| **Tool Outputs** | Command results, file contents | Truncate, summarize |
| **Output Reserve** | Space for model response | Fixed per model |

### 4.2 Top Consumers View

```swift
struct TopContextConsumersView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Context Consumers")
                .font(.headline)

            ForEach(topItems.prefix(5), id: \.id) { item in
                HStack {
                    Image(systemName: item.icon)
                        .frame(width: 20)
                    Text(item.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(formatTokens(item.tokens))")
                        .font(.caption.monospacedDigit())
                    Button(action: { removeItem(item) }) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var topItems: [ContextItem] {
        var items: [ContextItem] = []

        // Add attached files
        for file in session.attachedFiles {
            items.append(ContextItem(
                id: file.id,
                name: file.name,
                tokens: TokenCounter.countFile(file.content, language: file.language),
                icon: "doc.text",
                type: .file
            ))
        }

        // Add large tool outputs
        for (index, output) in session.recentToolOutputs.enumerated() {
            let tokens = TokenCounter.approximateTokens(output)
            if tokens > 1000 {
                items.append(ContextItem(
                    id: "tool-\(index)",
                    name: "Tool output #\(index + 1)",
                    tokens: tokens,
                    icon: "terminal",
                    type: .toolOutput
                ))
            }
        }

        return items.sorted { $0.tokens > $1.tokens }
    }
}
```

---

## 5. Compaction Strategies

### 5.1 Strategy Options

| Strategy | Description | Token Savings | Information Loss |
|----------|-------------|---------------|------------------|
| **Summarize History** | Replace old messages with summary | 60-80% | Medium |
| **Truncate Outputs** | Keep first/last N lines of tool outputs | 40-60% | Low |
| **Detach Files** | Remove file contents, keep references | 90%+ | High |
| **Chunk Files** | Keep only relevant file sections | 50-70% | Low-Medium |
| **Drop Old Messages** | Remove messages beyond N turns | 70-90% | High |

### 5.2 Automatic Compaction

```swift
struct CompactionPolicy {
    let triggerThreshold: Double = 0.85  // 85% usage
    let targetThreshold: Double = 0.60   // Compact to 60%
    let preserveRecentMessages: Int = 10
    let preserveRecentToolOutputs: Int = 5

    func shouldCompact(tracker: ContextBudgetTracker) -> Bool {
        tracker.percentageUsed >= triggerThreshold * 100
    }

    func computeCompactionPlan(
        session: Session,
        tracker: ContextBudgetTracker
    ) -> CompactionPlan {
        let targetTokens = Int(Double(tracker.totalLimit) * targetThreshold)
        let tokensToFree = tracker.totalUsed - targetTokens

        var plan = CompactionPlan()

        // Strategy 1: Truncate tool outputs first
        let toolOutputSavings = estimateTruncationSavings(session.recentToolOutputs)
        if toolOutputSavings >= tokensToFree {
            plan.truncateToolOutputs = true
            return plan
        }

        // Strategy 2: Summarize old messages
        let oldMessages = session.messages.dropLast(preserveRecentMessages)
        let messageSavings = estimateSummarizationSavings(Array(oldMessages))
        if toolOutputSavings + messageSavings >= tokensToFree {
            plan.truncateToolOutputs = true
            plan.summarizeMessages = true
            plan.messagesToSummarize = Array(oldMessages)
            return plan
        }

        // Strategy 3: Detach large files
        let sortedFiles = session.attachedFiles.sorted {
            $0.tokenCount > $1.tokenCount
        }
        var filesToDetach: [AttachedFile] = []
        var fileSavings = 0
        for file in sortedFiles {
            if toolOutputSavings + messageSavings + fileSavings >= tokensToFree {
                break
            }
            filesToDetach.append(file)
            fileSavings += file.tokenCount
        }

        plan.truncateToolOutputs = true
        plan.summarizeMessages = true
        plan.messagesToSummarize = Array(oldMessages)
        plan.detachFiles = filesToDetach

        return plan
    }
}

struct CompactionPlan {
    var truncateToolOutputs: Bool = false
    var summarizeMessages: Bool = false
    var messagesToSummarize: [Message] = []
    var detachFiles: [AttachedFile] = []

    var isEmpty: Bool {
        !truncateToolOutputs && !summarizeMessages && detachFiles.isEmpty
    }
}
```

### 5.3 User Confirmation

```swift
struct CompactionConfirmationView: View {
    let plan: CompactionPlan
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Context Compaction Needed")
                .font(.headline)

            Text("Your conversation is approaching the context limit. Blaze will:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                if plan.truncateToolOutputs {
                    Label("Truncate large tool outputs", systemImage: "scissors")
                }
                if plan.summarizeMessages {
                    Label("Summarize \(plan.messagesToSummarize.count) old messages",
                          systemImage: "doc.text.magnifyingglass")
                }
                if !plan.detachFiles.isEmpty {
                    Label("Detach \(plan.detachFiles.count) files (kept as references)",
                          systemImage: "paperclip")
                }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                Button("Compact Now", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

---

## 6. Auto-Summarization

### 6.1 Summarization Trigger

```swift
class AutoSummarizer {
    private let summarizationThreshold = 50  // Messages before summarizing
    private let keepRecentCount = 10

    func shouldSummarize(session: Session) -> Bool {
        session.messages.count > summarizationThreshold
    }

    func createSummaryPrompt(messages: [Message]) -> String {
        """
        Summarize the following conversation history, preserving:
        1. Key decisions made
        2. Important code changes or files discussed
        3. Unresolved issues or next steps
        4. Critical context for continuing the work

        Keep the summary concise (under 500 words) but complete.

        Conversation:
        \(formatMessages(messages))
        """
    }

    func applySummary(session: inout Session, summary: String) {
        let oldMessages = session.messages.dropLast(keepRecentCount)

        // Replace old messages with summary message
        let summaryMessage = Message(
            role: .system,
            content: """
            [CONVERSATION SUMMARY]
            The following summarizes \(oldMessages.count) previous messages:

            \(summary)

            [END SUMMARY]
            """,
            metadata: ["type": "summary", "messageCount": "\(oldMessages.count)"]
        )

        session.messages = [summaryMessage] + Array(session.messages.suffix(keepRecentCount))
    }
}
```

### 6.2 Summary Quality

| Aspect | Requirement |
|--------|-------------|
| **Completeness** | All key decisions preserved |
| **Accuracy** | No hallucinated details |
| **Conciseness** | < 500 words typically |
| **Structure** | Organized by topic/file |
| **Actionability** | Clear next steps if applicable |

---

## 7. User Controls

### 7.1 Manual Controls

| Control | Action | Location |
|---------|--------|----------|
| **Detach File** | Remove file from context | File attachment menu |
| **Clear History** | Remove all but recent N messages | Session menu |
| **Summarize Now** | Trigger manual summarization | Context budget popover |
| **Pin Message** | Preserve message from summarization | Message context menu |
| **Compact** | Run compaction with preview | Context budget popover |

### 7.2 Settings

```swift
struct ContextManagementSettings: Codable {
    var autoCompactEnabled: Bool = true
    var compactThreshold: Double = 0.85
    var preserveRecentMessages: Int = 10
    var autoSummarizeEnabled: Bool = true
    var summarizeAfterMessages: Int = 50
    var showBudgetBar: Bool = true
    var warnAtPercentage: Double = 80
}
```

### 7.3 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+C` | Show context breakdown |
| `Cmd+Shift+K` | Compact context |
| `Cmd+Shift+S` | Summarize history |

---

## 8. Implementation

### 8.1 Integration Points

```swift
// In SessionController
func sendMessage(_ content: String) async throws {
    // Check context budget before sending
    await contextTracker.recalculate(session: session, model: currentModel)

    if contextTracker.percentageUsed > 95 {
        throw ContextError.budgetExceeded
    }

    if contextTracker.percentageUsed > 85 && settings.autoCompactEnabled {
        let plan = compactionPolicy.computeCompactionPlan(
            session: session,
            tracker: contextTracker
        )

        if await confirmCompaction(plan) {
            await executeCompaction(plan)
        }
    }

    // Proceed with message
    try await engineAdapter.send(message: content)
}
```

### 8.2 LanceDB Storage

```swift
// Store context snapshots for analytics
struct ContextSnapshot: Codable {
    let sessionId: UUID
    let timestamp: Date
    let totalUsed: Int
    let totalLimit: Int
    let breakdown: ContextBreakdown
    let messageCount: Int
    let fileCount: Int
}

// Query for trends
func getContextTrend(sessionId: UUID) async -> [ContextSnapshot] {
    await lanceDB.query(
        table: "context_snapshots",
        filter: "session_id = '\(sessionId)'",
        orderBy: "timestamp DESC",
        limit: 100
    )
}
```

---

## Acceptance Criteria

- [ ] Token counting within 20% of actual
- [ ] Budget bar updates in real-time during streaming
- [ ] Breakdown shows accurate category distribution
- [ ] Auto-compaction triggers at configured threshold
- [ ] Summarization preserves key context
- [ ] User can manually trigger compaction
- [ ] Settings persist across sessions
- [ ] No context-related crashes or data loss

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
