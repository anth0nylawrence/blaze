# Keyboard Shortcut Conflict Resolution Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines how Blaze handles keyboard shortcut conflicts between system shortcuts, app shortcuts, and user customizations. It covers detection, resolution, customization, and accessibility considerations.

**Why This Matters:** Power users rely heavily on keyboard shortcuts. Conflicts with system or other app shortcuts lead to frustration and broken workflows.

---

## Table of Contents

1. [Shortcut Categories](#1-shortcut-categories)
2. [Conflict Detection](#2-conflict-detection)
3. [Resolution Strategy](#3-resolution-strategy)
4. [Customization System](#4-customization-system)
5. [Accessibility](#5-accessibility)
6. [Implementation](#6-implementation)

---

## 1. Shortcut Categories

### 1.1 Priority Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                  SHORTCUT PRIORITY (HIGH → LOW)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. System Reserved (NEVER override)                                │
│     ├─ Cmd+Tab         (App switcher)                              │
│     ├─ Cmd+Space       (Spotlight)                                  │
│     ├─ Cmd+Q           (Quit app)                                   │
│     ├─ Cmd+H           (Hide app)                                   │
│     ├─ Cmd+M           (Minimize)                                   │
│     └─ Ctrl+arrows     (Mission Control)                           │
│                                                                      │
│  2. macOS Standard (Override with warning)                         │
│     ├─ Cmd+,           (Preferences)                               │
│     ├─ Cmd+N           (New document)                              │
│     ├─ Cmd+O           (Open)                                      │
│     ├─ Cmd+S           (Save)                                      │
│     └─ Cmd+P           (Print)                                      │
│                                                                      │
│  3. Blaze Core (App-specific, high priority)                       │
│     ├─ Cmd+K           (Command palette)                           │
│     ├─ Cmd+Enter       (Send message)                              │
│     ├─ Cmd+.           (Cancel)                                     │
│     └─ Cmd+D           (Diff viewer)                                │
│                                                                      │
│  4. Blaze Secondary (Customizable)                                 │
│     ├─ Cmd+1/2/3       (Switch tabs)                               │
│     ├─ Cmd+T           (New tab)                                    │
│     ├─ Cmd+W           (Close tab)                                  │
│     └─ Cmd+Shift+E     (Export)                                     │
│                                                                      │
│  5. User Custom (Lowest priority, fully customizable)              │
│     └─ User-defined shortcuts                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Default Shortcut Map

| Category | Shortcut | Action | Customizable |
|----------|----------|--------|--------------|
| **Navigation** | `Cmd+K` | Open command palette | No |
| | `Cmd+1` - `Cmd+9` | Switch to tab 1-9 | Yes |
| | `Cmd+[` | Previous session | Yes |
| | `Cmd+]` | Next session | Yes |
| | `Cmd+\` | Toggle sidebar | Yes |
| **Session** | `Cmd+N` | New session | Yes |
| | `Cmd+T` | New tab | Yes |
| | `Cmd+W` | Close tab | Yes |
| | `Cmd+Shift+N` | New window | Yes |
| **Messages** | `Cmd+Enter` | Send message | No |
| | `Cmd+.` | Cancel generation | No |
| | `Cmd+Shift+C` | Copy last response | Yes |
| | `Up Arrow` | Previous message (in input) | Yes |
| **Diff** | `Cmd+D` | Toggle diff viewer | Yes |
| | `Cmd+Shift+A` | Accept all | Yes |
| | `Cmd+Shift+R` | Reject all | Yes |
| | `Space` | Accept current hunk | Yes |
| **Timeline** | `Cmd+T` | Toggle timeline | Yes |
| | `Cmd+J` | Jump to event | Yes |
| **Context** | `Cmd+Shift+K` | Compact context | Yes |
| | `Cmd+Shift+S` | Summarize history | Yes |

### 1.3 Reserved Shortcuts

These shortcuts are **NEVER** overridable:

```swift
let systemReservedShortcuts: Set<KeyboardShortcut> = [
    // App lifecycle
    KeyboardShortcut(.q, modifiers: .command),           // Quit
    KeyboardShortcut(.h, modifiers: .command),           // Hide
    KeyboardShortcut(.m, modifiers: .command),           // Minimize
    KeyboardShortcut(.w, modifiers: [.command, .option]), // Close all windows

    // System functions
    KeyboardShortcut(.tab, modifiers: .command),         // App switcher
    KeyboardShortcut(.space, modifiers: .command),       // Spotlight
    KeyboardShortcut(.space, modifiers: .control),       // Input sources

    // Accessibility
    KeyboardShortcut(.f5, modifiers: .command),          // VoiceOver
]
```

---

## 2. Conflict Detection

### 2.1 Detection Algorithm

```swift
struct ShortcutConflictDetector {
    private let systemShortcuts: [KeyboardShortcut: String]
    private let blazeShortcuts: [KeyboardShortcut: ShortcutAction]
    private let userShortcuts: [KeyboardShortcut: ShortcutAction]

    func detectConflicts() -> [ShortcutConflict] {
        var conflicts: [ShortcutConflict] = []

        // Check user shortcuts against system
        for (shortcut, action) in userShortcuts {
            if let systemAction = systemShortcuts[shortcut] {
                conflicts.append(ShortcutConflict(
                    shortcut: shortcut,
                    existingAction: systemAction,
                    newAction: action.name,
                    severity: .system,
                    resolution: .cannotOverride
                ))
            }
        }

        // Check user shortcuts against Blaze core
        for (shortcut, action) in userShortcuts {
            if let blazeAction = blazeShortcuts[shortcut], !blazeAction.isCustomizable {
                conflicts.append(ShortcutConflict(
                    shortcut: shortcut,
                    existingAction: blazeAction.name,
                    newAction: action.name,
                    severity: .blazeCore,
                    resolution: .requiresConfirmation
                ))
            }
        }

        // Check for duplicate user shortcuts
        var seenShortcuts: [KeyboardShortcut: ShortcutAction] = [:]
        for (shortcut, action) in userShortcuts {
            if let existing = seenShortcuts[shortcut] {
                conflicts.append(ShortcutConflict(
                    shortcut: shortcut,
                    existingAction: existing.name,
                    newAction: action.name,
                    severity: .duplicate,
                    resolution: .mustResolve
                ))
            }
            seenShortcuts[shortcut] = action
        }

        return conflicts
    }
}

struct ShortcutConflict {
    let shortcut: KeyboardShortcut
    let existingAction: String
    let newAction: String
    let severity: ConflictSeverity
    let resolution: ResolutionType
}

enum ConflictSeverity: Comparable {
    case duplicate      // Same shortcut assigned twice
    case blazeSecondary // Conflicts with customizable Blaze shortcut
    case blazeCore      // Conflicts with core Blaze shortcut
    case macosStandard  // Conflicts with macOS convention
    case system         // Conflicts with system shortcut
}

enum ResolutionType {
    case cannotOverride      // System shortcuts
    case requiresConfirmation // Core shortcuts
    case autoResolve         // Secondary shortcuts (new wins)
    case mustResolve         // User must choose
}
```

### 2.2 Real-Time Validation

```swift
class ShortcutValidator: ObservableObject {
    @Published var currentConflicts: [ShortcutConflict] = []

    func validate(shortcut: KeyboardShortcut, for action: ShortcutAction) -> ValidationResult {
        // Check system reserved
        if systemReservedShortcuts.contains(shortcut) {
            return .invalid(reason: "This shortcut is reserved by macOS")
        }

        // Check Blaze core
        if let coreAction = blazeCoreShortcuts[shortcut] {
            return .warning(
                reason: "This will override '\(coreAction.name)'",
                canProceed: true
            )
        }

        // Check existing user shortcuts
        if let existingAction = userShortcuts[shortcut] {
            return .conflict(
                existing: existingAction,
                resolution: .mustResolve
            )
        }

        return .valid
    }
}

enum ValidationResult {
    case valid
    case warning(reason: String, canProceed: Bool)
    case conflict(existing: ShortcutAction, resolution: ResolutionType)
    case invalid(reason: String)
}
```

---

## 3. Resolution Strategy

### 3.1 Automatic Resolution

```swift
func resolveConflict(_ conflict: ShortcutConflict) -> ResolvedShortcut? {
    switch conflict.resolution {
    case .cannotOverride:
        // System shortcuts cannot be overridden
        return nil

    case .requiresConfirmation:
        // Show confirmation dialog
        return nil // Handled by UI

    case .autoResolve:
        // New shortcut wins, old is unassigned
        return ResolvedShortcut(
            shortcut: conflict.shortcut,
            action: conflict.newAction,
            previousAction: conflict.existingAction,
            wasAutoResolved: true
        )

    case .mustResolve:
        // User must choose
        return nil // Handled by UI
    }
}
```

### 3.2 Conflict Resolution UI

```swift
struct ShortcutConflictSheet: View {
    let conflict: ShortcutConflict
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                Text("Keyboard Shortcut Conflict")
                    .font(.headline)
            }

            Text("The shortcut \(conflict.shortcut.displayName) is already assigned to '\(conflict.existingAction)'.")

            Divider()

            Text("Choose an action:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Button {
                    onResolve(.replaceExisting)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Use for '\(conflict.newAction)'")
                                .fontWeight(.medium)
                            Text("'\(conflict.existingAction)' will be unassigned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    onResolve(.keepExisting)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Keep for '\(conflict.existingAction)'")
                                .fontWeight(.medium)
                            Text("Choose a different shortcut for '\(conflict.newAction)'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                if conflict.severity < .blazeCore {
                    Button {
                        onResolve(.assignBoth)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Use context-aware switching")
                                    .fontWeight(.medium)
                                Text("Shortcut behavior depends on current focus")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}

enum ConflictResolution {
    case replaceExisting    // New action gets the shortcut
    case keepExisting       // Old action keeps the shortcut
    case assignBoth         // Context-aware (if supported)
    case cancel             // Don't make changes
}
```

### 3.3 Context-Aware Shortcuts

Some shortcuts can have different actions based on focus:

```swift
struct ContextualShortcut {
    let shortcut: KeyboardShortcut
    let contexts: [FocusContext: ShortcutAction]

    func action(for context: FocusContext) -> ShortcutAction? {
        contexts[context]
    }
}

enum FocusContext {
    case messageInput    // Typing in message field
    case diffViewer      // Viewing diffs
    case timeline        // Timeline sidebar
    case commandPalette  // Command palette open
    case fileViewer      // Viewing file contents
    case sessionList     // Session sidebar
    case general         // Anywhere else
}

// Example: Cmd+Enter
let cmdEnter = ContextualShortcut(
    shortcut: KeyboardShortcut(.return, modifiers: .command),
    contexts: [
        .messageInput: .sendMessage,
        .diffViewer: .acceptCurrentHunk,
        .commandPalette: .executeSelected,
        .general: .sendMessage
    ]
)
```

---

## 4. Customization System

### 4.1 Settings UI

```swift
struct KeyboardShortcutsSettingsView: View {
    @StateObject private var shortcutManager = ShortcutManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ShortcutCategory?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                ForEach(ShortcutCategory.allCases, id: \.self) { category in
                    Label(category.name, systemImage: category.icon)
                }
            }
            .navigationTitle("Shortcuts")
        } detail: {
            if let category = selectedCategory {
                ShortcutCategoryView(category: category)
            } else {
                Text("Select a category")
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(text: $searchText, prompt: "Search shortcuts")
        .toolbar {
            ToolbarItem {
                Button("Reset All") {
                    shortcutManager.resetToDefaults()
                }
            }
        }
    }
}

struct ShortcutCategoryView: View {
    let category: ShortcutCategory
    @StateObject private var shortcutManager = ShortcutManager.shared

    var body: some View {
        List {
            ForEach(category.actions, id: \.id) { action in
                ShortcutRow(action: action)
            }
        }
        .navigationTitle(category.name)
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    @State private var isRecording = false
    @State private var pendingShortcut: KeyboardShortcut?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(action.name)
                if let description = action.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            ShortcutRecorder(
                shortcut: action.currentShortcut,
                isRecording: $isRecording,
                onRecord: { newShortcut in
                    validateAndAssign(newShortcut)
                }
            )
            .frame(width: 120)

            if action.isCustomizable {
                Button {
                    resetToDefault()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .disabled(action.currentShortcut == action.defaultShortcut)
            }
        }
    }
}
```

### 4.2 Shortcut Recorder

```swift
struct ShortcutRecorder: View {
    let shortcut: KeyboardShortcut?
    @Binding var isRecording: Bool
    let onRecord: (KeyboardShortcut) -> Void

    var body: some View {
        Button {
            isRecording = true
        } label: {
            if isRecording {
                Text("Press shortcut...")
                    .foregroundStyle(.blue)
            } else if let shortcut = shortcut {
                Text(shortcut.displayName)
                    .monospaced()
            } else {
                Text("None")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .onKeyPress(phases: .down) { keyPress in
            guard isRecording else { return .ignored }

            // Ignore modifier-only presses
            guard !keyPress.key.isModifier else { return .ignored }

            let newShortcut = KeyboardShortcut(
                keyPress.key,
                modifiers: keyPress.modifiers
            )

            isRecording = false
            onRecord(newShortcut)
            return .handled
        }
    }
}
```

### 4.3 Import/Export

```swift
struct ShortcutProfile: Codable {
    let name: String
    let version: String
    let shortcuts: [String: String]  // action ID -> shortcut string
}

extension ShortcutManager {
    func exportProfile(name: String) throws -> Data {
        let profile = ShortcutProfile(
            name: name,
            version: "1.0",
            shortcuts: customShortcuts.mapValues { $0.exportString }
        )
        return try JSONEncoder().encode(profile)
    }

    func importProfile(_ data: Data) throws -> [ShortcutConflict] {
        let profile = try JSONDecoder().decode(ShortcutProfile.self, from: data)

        var conflicts: [ShortcutConflict] = []

        for (actionId, shortcutString) in profile.shortcuts {
            guard let action = actions[actionId],
                  let shortcut = KeyboardShortcut(from: shortcutString) else {
                continue
            }

            let result = validator.validate(shortcut: shortcut, for: action)
            if case .conflict(let existing, _) = result {
                conflicts.append(ShortcutConflict(
                    shortcut: shortcut,
                    existingAction: existing.name,
                    newAction: action.name,
                    severity: .duplicate,
                    resolution: .mustResolve
                ))
            }
        }

        return conflicts
    }
}
```

---

## 5. Accessibility

### 5.1 VoiceOver Compatibility

```swift
struct AccessibleShortcutLabel: View {
    let shortcut: KeyboardShortcut

    var body: some View {
        Text(shortcut.displayName)
            .accessibilityLabel(voiceOverLabel)
    }

    private var voiceOverLabel: String {
        var parts: [String] = []

        if shortcut.modifiers.contains(.command) {
            parts.append("Command")
        }
        if shortcut.modifiers.contains(.shift) {
            parts.append("Shift")
        }
        if shortcut.modifiers.contains(.option) {
            parts.append("Option")
        }
        if shortcut.modifiers.contains(.control) {
            parts.append("Control")
        }

        parts.append(shortcut.key.voiceOverName)

        return parts.joined(separator: " ")
    }
}

extension KeyEquivalent {
    var voiceOverName: String {
        switch self {
        case .return: return "Return"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .space: return "Space"
        case .tab: return "Tab"
        case .upArrow: return "Up Arrow"
        case .downArrow: return "Down Arrow"
        case .leftArrow: return "Left Arrow"
        case .rightArrow: return "Right Arrow"
        default: return String(character).uppercased()
        }
    }
}
```

### 5.2 Reduced Motion Support

```swift
@MainActor
class ShortcutFeedbackManager {
    @AppStorage("reduceMotion") private var reduceMotion = false

    func provideFeedback(for action: ShortcutAction) {
        if reduceMotion {
            // Use sound/haptic feedback instead of animation
            NSSound.beep()
        } else {
            // Visual feedback animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                // Highlight activated element
            }
        }
    }
}
```

### 5.3 Alternative Input Methods

```swift
// Support for sticky keys (pressing modifiers sequentially)
struct StickyKeySupport {
    var activeModifiers: EventModifiers = []
    var stickyModifiers: EventModifiers = []

    mutating func handleModifierPress(_ modifier: EventModifiers) {
        if activeModifiers.contains(modifier) {
            // Double-tap to lock
            stickyModifiers.insert(modifier)
        } else {
            activeModifiers.insert(modifier)
        }
    }

    mutating func handleKeyPress(_ key: KeyEquivalent) -> KeyboardShortcut {
        let allModifiers = activeModifiers.union(stickyModifiers)
        let shortcut = KeyboardShortcut(key, modifiers: allModifiers)

        // Clear non-sticky modifiers
        activeModifiers = []

        return shortcut
    }
}
```

---

## 6. Implementation

### 6.1 ShortcutManager

```swift
@MainActor
@Observable
final class ShortcutManager {
    static let shared = ShortcutManager()

    private(set) var actions: [String: ShortcutAction] = [:]
    private(set) var customShortcuts: [String: KeyboardShortcut] = [:]
    private(set) var conflicts: [ShortcutConflict] = []

    private let detector = ShortcutConflictDetector()
    private let validator = ShortcutValidator()

    init() {
        loadDefaults()
        loadCustomizations()
        detectConflicts()
    }

    func assign(
        _ shortcut: KeyboardShortcut,
        to actionId: String
    ) throws {
        guard let action = actions[actionId] else {
            throw ShortcutError.actionNotFound(actionId)
        }

        guard action.isCustomizable else {
            throw ShortcutError.notCustomizable(actionId)
        }

        let result = validator.validate(shortcut: shortcut, for: action)

        switch result {
        case .valid:
            customShortcuts[actionId] = shortcut
            saveCustomizations()

        case .warning(_, let canProceed) where canProceed:
            customShortcuts[actionId] = shortcut
            saveCustomizations()

        case .conflict, .warning, .invalid:
            throw ShortcutError.conflict(result)
        }

        detectConflicts()
    }

    func resetToDefaults() {
        customShortcuts.removeAll()
        saveCustomizations()
        detectConflicts()
    }

    func shortcut(for actionId: String) -> KeyboardShortcut? {
        customShortcuts[actionId] ?? actions[actionId]?.defaultShortcut
    }

    private func detectConflicts() {
        conflicts = detector.detectConflicts()
    }
}
```

### 6.2 Global Keyboard Handler

```swift
struct GlobalKeyboardHandler: ViewModifier {
    @Environment(\.focusedValue) var focusContext

    func body(content: Content) -> some View {
        content
            .onKeyPress { keyPress in
                let shortcut = KeyboardShortcut(
                    keyPress.key,
                    modifiers: keyPress.modifiers
                )

                if let action = ShortcutManager.shared.action(
                    for: shortcut,
                    context: focusContext
                ) {
                    action.execute()
                    return .handled
                }

                return .ignored
            }
    }
}

extension View {
    func handleGlobalShortcuts() -> some View {
        modifier(GlobalKeyboardHandler())
    }
}
```

### 6.3 Persistence

```swift
extension ShortcutManager {
    private func saveCustomizations() {
        let data = try? JSONEncoder().encode(customShortcuts)
        UserDefaults.standard.set(data, forKey: "customShortcuts")
    }

    private func loadCustomizations() {
        guard let data = UserDefaults.standard.data(forKey: "customShortcuts"),
              let shortcuts = try? JSONDecoder().decode(
                [String: KeyboardShortcut].self,
                from: data
              ) else {
            return
        }
        customShortcuts = shortcuts
    }
}
```

---

## Acceptance Criteria

- [ ] All default shortcuts work out of the box
- [ ] System reserved shortcuts cannot be overridden
- [ ] Conflicts detected and shown to user
- [ ] Resolution options presented clearly
- [ ] Custom shortcuts persist across restarts
- [ ] Import/export works correctly
- [ ] VoiceOver announces shortcuts correctly
- [ ] Reduced motion alternative feedback works

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |
