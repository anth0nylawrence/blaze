# SwiftUI Native Features Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Overview

This specification defines platform-native SwiftUI features that differentiate Blaze from web-based alternatives. These features leverage macOS system integration to provide a premium, native experience that feels like it belongs alongside Xcode, Finder, and other Apple apps.

**Why This Matters:** Native features create switching costs, improve discoverability, and establish Blaze as a first-class macOS citizen rather than a cross-platform compromise.

---

## Table of Contents

1. [Feature Summary](#1-feature-summary)
2. [Menu Bar Companion](#2-menu-bar-companion)
3. [Spotlight Integration](#3-spotlight-integration)
4. [Drag and Drop](#4-drag-and-drop)
5. [Matched Geometry Transitions](#5-matched-geometry-transitions)
6. [Scroll Transitions](#6-scroll-transitions)
7. [Undo/Redo Stack](#7-undoredo-stack)
8. [Quick Look Provider](#8-quick-look-provider)
9. [Implementation Phases](#9-implementation-phases)
10. [Acceptance Criteria](#10-acceptance-criteria)

---

## 1. Feature Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SWIFTUI NATIVE FEATURES MATRIX                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1 (Days 1-14) - Low effort, high polish                              │
│  ├─ Matched Geometry Transitions     Tool card expansion morphs             │
│  └─ Scroll Transitions               Messages fade/scale on scroll          │
│                                                                             │
│  PHASE 2 (Days 15-45) - Needs core features working                         │
│  ├─ Menu Bar Companion               Status bar with quick actions          │
│  ├─ Drag and Drop                    Export sessions, attach files          │
│  └─ Undo/Redo Stack                  Cmd+Z for diff operations              │
│                                                                             │
│  PHASE 3 (Days 46+) - Nice to have, stable schema required                  │
│  ├─ Spotlight Integration            System-wide session search             │
│  └─ Quick Look Provider              Spacebar preview in Finder             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Feature | Effort | Impact | Dependencies | Phase |
|---------|--------|--------|--------------|-------|
| Matched Geometry Transitions | Low | High | Basic UI | 1 |
| Scroll Transitions | Low | Medium | Message list | 1 |
| Menu Bar Companion | Medium | High | SessionManager | 2 |
| Drag and Drop | Medium | High | Export, SessionStore | 2 |
| Undo/Redo Stack | Medium | High | Diff operations | 2 |
| Spotlight Integration | Medium | High | Stable session schema | 3 |
| Quick Look Provider | Medium | Medium | Export format finalized | 3 |

---

## 2. Menu Bar Companion

### 2.1 Purpose

Always-visible status indicator and quick action hub accessible without activating the main app window.

### 2.2 Architecture

```swift
// MenuBarManager.swift

@Observable
final class MenuBarManager {
    private var statusItem: NSStatusItem?

    var activeSession: Session?
    var tokenBudget: TokenBudget?
    var pendingApprovals: [ApprovalRequest] = []

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Blaze")
            button.image?.isTemplate = true  // Adapts to menu bar appearance
        }
    }
}
```

### 2.3 Menu Structure

```
┌─────────────────────────────────────────┐
│ ⚡ Blaze                                │
├─────────────────────────────────────────┤
│ ● Active: "Fix auth bug"          3m 42s│
│   └─ Running: git status                │
│   └─ Tokens: 45,231 / 200,000     [███░]│
├─────────────────────────────────────────┤
│ ⚠️ 2 Approvals Pending                  │
│   └─ bash: rm -rf ./build               │
│   └─ Write: src/config.ts               │
├─────────────────────────────────────────┤
│ Recent Sessions                         │
│   ├─ Refactor API endpoints             │
│   ├─ Add dark mode                      │
│   └─ Debug memory leak                  │
├─────────────────────────────────────────┤
│ ⌘N  New Session                         │
│ ⌘,  Preferences...                      │
│ ──────────────────────────────          │
│ ⌘Q  Quit Blaze                          │
└─────────────────────────────────────────┘
```

### 2.4 SwiftUI Implementation

```swift
// BlazeApp.swift

@main
struct BlazeApp: App {
    @State private var menuBarManager = MenuBarManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        // Menu bar companion
        MenuBarExtra {
            MenuBarContentView()
                .environment(menuBarManager)
        } label: {
            MenuBarLabel()
                .environment(menuBarManager)
        }
        .menuBarExtraStyle(.window)  // Allows rich SwiftUI content
    }
}

struct MenuBarLabel: View {
    @Environment(MenuBarManager.self) private var manager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(statusColor, .secondary)

            if manager.pendingApprovals.count > 0 {
                Text("\(manager.pendingApprovals.count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .background(.red, in: Capsule())
            }
        }
    }

    private var statusIcon: String {
        if manager.activeSession != nil {
            return "bolt.fill"
        }
        return "bolt"
    }

    private var statusColor: Color {
        if manager.pendingApprovals.count > 0 { return .orange }
        if manager.activeSession != nil { return .green }
        return .secondary
    }
}

struct MenuBarContentView: View {
    @Environment(MenuBarManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Active session status
            if let session = manager.activeSession {
                ActiveSessionSection(session: session)
                Divider()
            }

            // Pending approvals
            if !manager.pendingApprovals.isEmpty {
                ApprovalsSection(approvals: manager.pendingApprovals)
                Divider()
            }

            // Recent sessions
            RecentSessionsSection()

            Divider()

            // Quick actions
            Button("New Session") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Preferences...") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Blaze") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 300)
        .padding(.vertical, 8)
    }
}
```

### 2.5 Status Indicators

| State | Icon | Color | Badge |
|-------|------|-------|-------|
| Idle | `bolt` | Secondary | - |
| Active session | `bolt.fill` | Green | - |
| Streaming | `bolt.fill` | Green (pulsing) | - |
| Approval pending | `bolt.fill` | Orange | Count |
| Error | `bolt.trianglebadge.exclamationmark` | Red | - |

### 2.6 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Show active session status | P0 | Name, duration, current tool visible |
| Token budget display | P0 | Progress bar with percentage |
| Pending approvals badge | P0 | Count badge on menu bar icon |
| Quick approve/deny | P1 | One-click approval from menu |
| Recent sessions list | P1 | Last 5 sessions, click to open |
| New session shortcut | P0 | Cmd+N creates new session |
| Dark/light mode adaptation | P0 | Template image adapts automatically |

---

## 3. Spotlight Integration

### 3.1 Purpose

Enable system-wide search for Blaze sessions, making them discoverable from anywhere in macOS.

### 3.2 Core Spotlight Indexing

```swift
// SpotlightIndexer.swift

import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightIndexer {
    private let index = CSSearchableIndex.default()

    /// Index a session for Spotlight search
    func indexSession(_ session: Session) async throws {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Primary metadata
        attributeSet.title = session.name
        attributeSet.contentDescription = session.lastAssistantMessage?.text.prefix(500).description
        attributeSet.displayName = session.name

        // Dates
        attributeSet.contentCreationDate = session.createdAt
        attributeSet.contentModificationDate = session.updatedAt

        // Custom metadata
        attributeSet.keywords = extractKeywords(from: session)
        attributeSet.creator = "Cogit0 Blaze"
        attributeSet.contentType = UTType.blazeSession.identifier

        // Thumbnail (optional)
        if let thumbnail = await generateSessionThumbnail(session) {
            attributeSet.thumbnailData = thumbnail
        }

        // Project context
        if let project = session.project {
            attributeSet.containerTitle = project.name
            attributeSet.containerDisplayName = project.name
        }

        let item = CSSearchableItem(
            uniqueIdentifier: "session:\(session.id)",
            domainIdentifier: "com.cogit0.blaze.sessions",
            attributeSet: attributeSet
        )

        // Set expiration (optional - sessions don't expire)
        item.expirationDate = .distantFuture

        try await index.indexSearchableItems([item])
    }

    /// Remove session from Spotlight
    func deindexSession(_ sessionId: String) async throws {
        try await index.deleteSearchableItems(withIdentifiers: ["session:\(sessionId)"])
    }

    /// Reindex all sessions
    func reindexAll(sessions: [Session]) async throws {
        // Delete existing items
        try await index.deleteSearchableItems(withDomainIdentifiers: ["com.cogit0.blaze.sessions"])

        // Reindex all
        for session in sessions {
            try await indexSession(session)
        }
    }

    private func extractKeywords(from session: Session) -> [String] {
        var keywords: [String] = []

        // Extract from session name
        keywords.append(contentsOf: session.name.split(separator: " ").map(String.init))

        // Extract tool names used
        keywords.append(contentsOf: session.toolsUsed.map(\.name))

        // Extract file paths mentioned
        keywords.append(contentsOf: session.filesModified.map { $0.lastPathComponent })

        // Engine name
        keywords.append(session.engineId.rawValue)

        return keywords
    }
}
```

### 3.3 Deep Link Handling

```swift
// BlazeApp.swift

@main
struct BlazeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightSelection(activity)
                }
        }
    }

    private func handleSpotlightSelection(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              identifier.hasPrefix("session:") else {
            return
        }

        let sessionId = String(identifier.dropFirst("session:".count))

        // Navigate to session
        Task {
            await SessionManager.shared.openSession(id: sessionId)
        }
    }
}
```

### 3.4 Custom UTType Registration

```swift
// UTType+Blaze.swift

import UniformTypeIdentifiers

extension UTType {
    static let blazeSession = UTType(exportedAs: "com.cogit0.blaze.session")
    static let blazePolicy = UTType(exportedAs: "com.cogit0.blaze.policy")
    static let blazeRecipe = UTType(exportedAs: "com.cogit0.blaze.recipe")
}
```

Info.plist registration:

```xml
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.cogit0.blaze.session</string>
        <key>UTTypeDescription</key>
        <string>Blaze Session</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.content</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>blaze</string>
            </array>
        </dict>
    </dict>
</array>
```

### 3.5 Search Result Appearance

```
┌─────────────────────────────────────────────────────────────────┐
│ 🔍 "auth bug"                                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚡ Fix auth bug in login flow                    Blaze Session │
│     Last modified: Today at 2:34 PM                             │
│     "The authentication middleware was checking..."             │
│                                                                 │
│  ⚡ Debug OAuth token refresh                     Blaze Session │
│     Last modified: Yesterday                                    │
│     "Found the issue - the refresh token was..."                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.6 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Index sessions on create/update | P0 | Sessions appear in Spotlight within 5s |
| Deindex on session delete | P0 | Deleted sessions removed from Spotlight |
| Deep link opens session | P0 | Clicking result opens Blaze to that session |
| Search session name | P0 | Name is searchable |
| Search session content | P1 | Assistant messages are searchable |
| Search by project | P1 | Filter by project name |
| Thumbnail in results | P2 | Session preview image shown |

---

## 4. Drag and Drop

### 4.1 Purpose

Enable intuitive file management through native macOS drag and drop gestures.

### 4.2 Supported Operations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DRAG AND DROP OPERATIONS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DRAG FROM BLAZE (Export)                                                   │
│  ├─ Session row → Desktop         Creates .blaze export file                │
│  ├─ Session row → Finder          Creates .blaze export file                │
│  ├─ Session row → Mail            Attaches .blaze file                      │
│  ├─ Diff hunk → Editor            Pastes diff text                          │
│  └─ Tool output → Terminal        Pastes command/output                     │
│                                                                             │
│  DROP INTO BLAZE (Import)                                                   │
│  ├─ Files → Chat input            Attaches as context                       │
│  ├─ Images → Chat input           Attaches for vision analysis              │
│  ├─ .blaze file → Session list    Imports session                           │
│  ├─ URLs → Chat input             Fetches and attaches content              │
│  └─ Text → Chat input             Pastes as message                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Drag Implementation

```swift
// SessionRow.swift

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            SessionIcon(session: session)
            VStack(alignment: .leading) {
                Text(session.name)
                    .font(.headline)
                Text(session.updatedAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .draggable(session) {
            // Custom drag preview
            SessionDragPreview(session: session)
        }
    }
}

struct SessionDragPreview: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(session.messageCount) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }
}

// Session must conform to Transferable
extension Session: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // Primary: Export as .blaze file
        FileRepresentation(exportedContentType: .blazeSession) { session in
            let url = try await SessionExporter.export(session)
            return SentTransferredFile(url)
        }

        // Fallback: Plain text summary
        ProxyRepresentation(exporting: \.exportSummary)
    }

    var exportSummary: String {
        """
        Session: \(name)
        Created: \(createdAt.formatted())
        Messages: \(messageCount)
        Engine: \(engineId.rawValue)
        """
    }
}
```

### 4.4 Drop Implementation

```swift
// ChatInputView.swift

struct ChatInputView: View {
    @Binding var messageText: String
    @State private var attachments: [Attachment] = []
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            // Attachment preview bar
            if !attachments.isEmpty {
                AttachmentBar(attachments: $attachments)
            }

            // Input field with drop target
            HStack {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)

                SendButton(action: send)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.accent, lineWidth: 2)
                        .background(.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .dropDestination(for: DropItem.self) { items, location in
            handleDrop(items)
            return true
        } isTargeted: { isTargeted in
            withAnimation(.easeOut(duration: 0.15)) {
                isDragTargeted = isTargeted
            }
        }
    }

    private func handleDrop(_ items: [DropItem]) {
        for item in items {
            switch item {
            case .file(let url):
                attachments.append(Attachment(type: .file, url: url))

            case .image(let image):
                attachments.append(Attachment(type: .image, image: image))

            case .url(let url):
                attachments.append(Attachment(type: .url, url: url))

            case .text(let text):
                messageText += text
            }
        }
    }
}

// Unified drop item type
enum DropItem: Transferable {
    case file(URL)
    case image(NSImage)
    case url(URL)
    case text(String)

    static var transferRepresentation: some TransferRepresentation {
        // Files
        FileRepresentation(importedContentType: .item) { received in
            .file(received.file)
        }

        // Images
        DataRepresentation(importedContentType: .image) { data in
            guard let image = NSImage(data: data) else {
                throw TransferError.importFailed
            }
            return .image(image)
        }

        // URLs
        ProxyRepresentation { (url: URL) in
            .url(url)
        }

        // Plain text
        ProxyRepresentation { (text: String) in
            .text(text)
        }
    }
}
```

### 4.5 Drag Feedback

```swift
// Visual feedback during drag operations

struct DropZoneModifier: ViewModifier {
    let isTargeted: Bool
    let acceptedTypes: [String]

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    VStack {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.largeTitle)
                        Text("Drop to attach")
                            .font(.headline)
                        Text(acceptedTypes.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .animation(.easeOut(duration: 0.2), value: isTargeted)
    }
}
```

### 4.6 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Drag session to export | P0 | Creates .blaze file on drop |
| Drop files to attach | P0 | Files appear as attachments |
| Drop images for vision | P0 | Images sent to model for analysis |
| Custom drag preview | P1 | Rich preview shows session info |
| Drop zone visual feedback | P1 | Clear highlight when drag over |
| Drag diff hunks | P2 | Diff text copied on drop |
| Drop URLs | P2 | URL content fetched and attached |

---

## 5. Matched Geometry Transitions

### 5.1 Purpose

Create fluid, context-preserving animations when UI elements transform between states.

### 5.2 Tool Card Expansion

```swift
// ToolCardView.swift

struct ToolCardContainer: View {
    let tool: ToolCall
    @State private var isExpanded = false
    @Namespace private var animation

    var body: some View {
        ZStack {
            if !isExpanded {
                // Compact card
                ToolCardCompact(tool: tool)
                    .matchedGeometryEffect(id: "card-\(tool.id)", in: animation)
                    .matchedGeometryEffect(id: "icon-\(tool.id)", in: animation, properties: .position)
                    .matchedGeometryEffect(id: "title-\(tool.id)", in: animation, properties: .position)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded = true
                        }
                    }
            } else {
                // Expanded card (overlays everything)
                ToolCardExpanded(tool: tool, isExpanded: $isExpanded)
                    .matchedGeometryEffect(id: "card-\(tool.id)", in: animation)
                    .matchedGeometryEffect(id: "icon-\(tool.id)", in: animation, properties: .position)
                    .matchedGeometryEffect(id: "title-\(tool.id)", in: animation, properties: .position)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

struct ToolCardCompact: View {
    let tool: ToolCall

    var body: some View {
        HStack(spacing: 12) {
            // Icon (matched)
            Image(systemName: tool.icon)
                .font(.title3)
                .foregroundStyle(tool.statusColor)
                .frame(width: 32, height: 32)

            // Title (matched)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.headline)
                Text(tool.inputPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(tool.duration.formatted())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            // Expand indicator
            Image(systemName: "chevron.down")
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ToolCardExpanded: View {
    let tool: ToolCall
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header (elements match compact positions)
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundStyle(tool.statusColor)
                    .frame(width: 32, height: 32)

                Text(tool.name)
                    .font(.title3.bold())

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Full input
            GroupBox("Input") {
                Text(tool.input)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }

            // Full output
            if let output = tool.output {
                GroupBox("Output") {
                    ScrollView {
                        Text(output)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                }
            }

            // Actions
            HStack {
                Button("Copy Input") { /* ... */ }
                Button("Copy Output") { /* ... */ }
                Spacer()
                Button("Rerun") { /* ... */ }
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}
```

### 5.3 Session Switching

```swift
// SessionTransition.swift

struct SessionSwitchView: View {
    @Binding var currentSession: Session?
    let sessions: [Session]
    @Namespace private var sessionAnimation

    var body: some View {
        HStack(spacing: 0) {
            // Session list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sessions) { session in
                        SessionTab(session: session, isSelected: session.id == currentSession?.id)
                            .matchedGeometryEffect(
                                id: "session-\(session.id)",
                                in: sessionAnimation,
                                isSource: session.id != currentSession?.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    currentSession = session
                                }
                            }
                    }
                }
            }
            .frame(width: 250)

            // Current session content
            if let session = currentSession {
                SessionContentView(session: session)
                    .matchedGeometryEffect(
                        id: "session-\(session.id)",
                        in: sessionAnimation,
                        isSource: true
                    )
            }
        }
    }
}
```

### 5.4 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Tool card compact ↔ expanded | P0 | Smooth morph with spring physics |
| Preserve element positions | P0 | Icon, title maintain position continuity |
| Session tab ↔ content | P1 | Transition feels connected |
| Diff card expansion | P1 | Same pattern as tool cards |
| No jank during transition | P0 | 60fps maintained throughout |

---

## 6. Scroll Transitions

### 6.1 Purpose

Add depth and focus to scrolling content through subtle visual effects.

### 6.2 Message List Transitions

```swift
// MessageListView.swift

struct MessageListView: View {
    let messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .scrollTransition(.animated(.spring())) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.85)
                                .scaleEffect(phase.isIdentity ? 1 : 0.98)
                                .blur(radius: phase.isIdentity ? 0 : 1)
                        }
                }
            }
            .padding()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .automatic))
    }
}
```

### 6.3 Tool Timeline Scroll Effects

```swift
// TimelineView.swift

struct TimelineView: View {
    let events: [TimelineEvent]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(events) { event in
                    TimelineEventCard(event: event)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.7)
                                .scaleEffect(
                                    x: phase.isIdentity ? 1 : 0.95,
                                    y: phase.isIdentity ? 1 : 0.95
                                )
                                .offset(y: phase.value * 5)
                        }
                        .containerRelativeFrame(.horizontal, count: 4, spacing: 12)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(16)
    }
}
```

### 6.4 Parallax Header

```swift
// SessionDetailView.swift

struct SessionDetailHeader: View {
    let session: Session

    var body: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .named("scroll")).minY
            let height = max(200, 200 + minY)

            VStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)
                    .scaleEffect(1 + (minY / 500).clamped(to: 0...0.3))

                Text(session.name)
                    .font(.largeTitle.bold())

                Text(session.project?.name ?? "No project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: geometry.size.width, height: height)
            .background(.ultraThinMaterial)
            .offset(y: -minY)
        }
        .frame(height: 200)
    }
}
```

### 6.5 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Message fade on scroll | P1 | Messages at edges slightly faded |
| Scale effect on scroll | P2 | Subtle scale reduction at edges |
| Snap to message boundaries | P2 | Optional snap behavior |
| Parallax session header | P2 | Header stretches when overscrolled |
| Respect reduced motion | P0 | Effects disabled when preference set |

---

## 7. Undo/Redo Stack

### 7.1 Purpose

Enable Cmd+Z/Cmd+Shift+Z for reversible diff operations, integrated with macOS undo system.

### 7.2 Architecture

```swift
// DiffUndoManager.swift

@Observable
final class DiffUndoManager {
    private var undoManager: UndoManager

    init(undoManager: UndoManager = .init()) {
        self.undoManager = undoManager
    }

    /// Accept a diff with undo support
    func acceptDiff(_ diff: Diff, in session: Session) async throws {
        // Store state for undo
        let originalContent = try await FileManager.read(diff.filePath)

        // Apply the diff
        try await DiffApplier.apply(diff, to: diff.filePath)

        // Register undo
        undoManager.registerUndo(withTarget: self) { [weak self] manager in
            Task {
                try await self?.revertDiff(diff, originalContent: originalContent, in: session)
            }
        }
        undoManager.setActionName("Accept Diff: \(diff.filePath.lastPathComponent)")

        // Log the action
        await session.logEvent(.diffAccepted(diff))
    }

    /// Revert a previously accepted diff
    func revertDiff(_ diff: Diff, originalContent: String, in session: Session) async throws {
        // Store current state for redo
        let currentContent = try await FileManager.read(diff.filePath)

        // Restore original
        try await FileManager.write(originalContent, to: diff.filePath)

        // Register redo
        undoManager.registerUndo(withTarget: self) { [weak self] manager in
            Task {
                try await self?.reapplyDiff(diff, content: currentContent, in: session)
            }
        }
        undoManager.setActionName("Revert Diff: \(diff.filePath.lastPathComponent)")

        // Log the revert
        await session.logEvent(.diffReverted(diff))
    }
}
```

### 7.3 SwiftUI Integration

```swift
// DiffViewer.swift

struct DiffViewer: View {
    let diff: Diff
    let session: Session
    @Environment(\.undoManager) private var undoManager
    @State private var diffManager: DiffUndoManager?

    var body: some View {
        VStack {
            DiffContentView(diff: diff)

            HStack {
                Button("Reject") {
                    rejectDiff()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Accept") {
                    acceptDiff()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            if let undoManager {
                diffManager = DiffUndoManager(undoManager: undoManager)
            }
        }
    }

    private func acceptDiff() {
        Task {
            try await diffManager?.acceptDiff(diff, in: session)
        }
    }

    private func rejectDiff() {
        // Rejection doesn't need undo - the diff just stays unaccepted
        Task {
            await session.logEvent(.diffRejected(diff))
        }
    }
}
```

### 7.4 Batch Operations

```swift
// BatchDiffOperations.swift

extension DiffUndoManager {
    /// Accept multiple diffs as a single undoable group
    func acceptDiffs(_ diffs: [Diff], in session: Session) async throws {
        undoManager.beginUndoGrouping()

        for diff in diffs {
            try await acceptDiff(diff, in: session)
        }

        undoManager.endUndoGrouping()
        undoManager.setActionName("Accept \(diffs.count) Diffs")
    }
}
```

### 7.5 Visual Feedback

```swift
// UndoToast.swift

struct UndoToast: View {
    let actionName: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(actionName)

            Button("Undo") {
                onUndo()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("z", modifiers: .command)
        }
        .padding(12)
        .background(.regularMaterial, in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

### 7.6 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Cmd+Z reverts accepted diff | P0 | File restored to pre-accept state |
| Cmd+Shift+Z reapplies diff | P0 | Redo restores accepted state |
| Undo batch operations | P1 | Group of diffs undone together |
| Undo action name in menu | P1 | Edit menu shows "Undo Accept Diff" |
| Visual undo confirmation | P1 | Toast shows undo option after accept |
| Persist undo across session | P2 | Undo stack survives app restart |

---

## 8. Quick Look Provider

### 8.1 Purpose

Enable Spacebar preview of .blaze session files in Finder without opening the full app.

### 8.2 Extension Architecture

```
Blaze.app/
└── Contents/
    └── PlugIns/
        └── BlazeQuickLook.appex/    # Quick Look extension
```

### 8.3 Quick Look Extension

```swift
// BlazeQuickLookPreview.swift (in extension target)

import QuickLookUI
import SwiftUI

class PreviewProvider: QLPreviewProvider {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL

        // Parse .blaze file
        let sessionExport = try SessionExport.load(from: fileURL)

        // Create SwiftUI preview
        let preview = SessionPreviewView(export: sessionExport)

        return QLPreviewReply(
            contextSize: CGSize(width: 600, height: 800),
            isBitmap: false
        ) { context in
            // Render SwiftUI view into context
            let renderer = ImageRenderer(content: preview)
            renderer.render { size, render in
                render(context.cgContext)
            }
        }
    }
}

struct SessionPreviewView: View {
    let export: SessionExport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.accent)

                VStack(alignment: .leading) {
                    Text(export.session.name)
                        .font(.title.bold())

                    Text("Created \(export.session.createdAt.formatted())")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Stats
            HStack(spacing: 24) {
                StatItem(label: "Messages", value: "\(export.session.messageCount)")
                StatItem(label: "Tool Calls", value: "\(export.session.toolCallCount)")
                StatItem(label: "Files Changed", value: "\(export.session.filesModified.count)")
            }

            Divider()

            // Message preview
            Text("Recent Messages")
                .font(.headline)

            ForEach(export.session.messages.suffix(5)) { message in
                MessagePreviewRow(message: message)
            }

            Spacer()

            // Footer
            HStack {
                Image(systemName: "bolt.circle")
                Text("Cogit0 Blaze Session")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(24)
        .frame(width: 600, height: 800)
        .background(.background)
    }
}
```

### 8.4 Thumbnail Provider

```swift
// BlazeThumbnailProvider.swift

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize

        // Create thumbnail image
        let thumbnail = ThumbnailView(fileURL: request.fileURL)

        let reply = QLThumbnailReply(contextSize: size) { context in
            let renderer = ImageRenderer(content: thumbnail.frame(width: size.width, height: size.height))
            if let cgImage = renderer.cgImage {
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
            return true
        }

        handler(reply, nil)
    }
}

struct ThumbnailView: View {
    let fileURL: URL

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)

            VStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.accent)

                Text(".blaze")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### 8.5 Info.plist Configuration

```xml
<!-- BlazeQuickLook extension Info.plist -->
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>QLSupportedContentTypes</key>
        <array>
            <string>com.cogit0.blaze.session</string>
        </array>
        <key>QLSupportsSearchableItems</key>
        <true/>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.quicklook.preview</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).PreviewProvider</string>
</dict>
```

### 8.6 Requirements

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Spacebar shows preview | P0 | .blaze files preview in Finder |
| Session name visible | P0 | Title shown in preview |
| Message count visible | P0 | Stats displayed |
| Recent messages shown | P1 | Last 5 messages previewed |
| Custom thumbnail icon | P1 | .blaze files have distinctive icon |
| Tool call summary | P2 | Tools used shown in preview |

---

## 9. Implementation Phases

### Phase 1: Days 1-14 (Polish During MVP)

| Feature | Day | Effort | Notes |
|---------|-----|--------|-------|
| Matched Geometry Transitions | 5-6 | 4h | Add to tool cards during initial implementation |
| Scroll Transitions | 6-7 | 2h | Add to message list during initial implementation |

**Rationale:** These are low-effort, high-impact polish items that can be added during initial UI implementation with minimal overhead.

### Phase 2: Days 15-45 (Daily Driver Features)

| Feature | Week | Effort | Dependencies |
|---------|------|--------|--------------|
| Menu Bar Companion | 3 | 8h | SessionManager, basic UI |
| Drag and Drop | 4 | 6h | Session export, file handling |
| Undo/Redo Stack | 5 | 8h | Diff accept/reject working |

**Rationale:** These features need core functionality working first (sessions, diffs, export) but add significant UX value for daily driver usage.

### Phase 3: Days 46+ (Platform Integration)

| Feature | Week | Effort | Dependencies |
|---------|------|--------|--------------|
| Spotlight Integration | 8-9 | 8h | Stable session schema |
| Quick Look Provider | 10 | 6h | Export format finalized |

**Rationale:** These features require stable data schemas and export formats. Implementing too early risks rework when schemas change.

---

## 10. Acceptance Criteria

### Overall

- [ ] All features respect `accessibilityReduceMotion` preference
- [ ] All features work in both light and dark modes
- [ ] All features maintain 60fps performance
- [ ] All features have unit tests
- [ ] Documentation updated for each feature

### Phase 1 Checklist

- [ ] Tool cards expand/collapse with matched geometry
- [ ] Messages have subtle scroll transitions
- [ ] Animations disabled when reduced motion enabled

### Phase 2 Checklist

- [ ] Menu bar shows active session status
- [ ] Menu bar shows pending approvals badge
- [ ] Sessions can be dragged to export
- [ ] Files can be dropped to attach
- [ ] Cmd+Z reverts accepted diffs
- [ ] Cmd+Shift+Z reapplies diffs

### Phase 3 Checklist

- [ ] Sessions appear in Spotlight search
- [ ] Clicking Spotlight result opens Blaze
- [ ] Spacebar previews .blaze files in Finder
- [ ] Custom thumbnail for .blaze files

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-30 | Claude | Initial specification |

---

**End of Document**
