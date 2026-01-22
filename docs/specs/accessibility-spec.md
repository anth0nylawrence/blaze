# Cogit0 Blaze - Accessibility Specification

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**WCAG Target:** 2.2 Level AA
**Status:** Draft

---

## Executive Summary

Cogit0 Blaze is committed to being accessible to all users, including those who rely on assistive technologies. This specification outlines our accessibility requirements, implementation guidelines, and testing procedures to ensure compliance with WCAG 2.2 Level AA and Apple's Human Interface Guidelines for accessibility.

---

## Table of Contents

1. [Accessibility Principles](#1-accessibility-principles)
2. [VoiceOver Support](#2-voiceover-support)
3. [Text-to-Speech (TTS)](#3-text-to-speech-tts)
4. [Keyboard Navigation](#4-keyboard-navigation)
5. [Reduced Motion](#5-reduced-motion)
6. [Visual Accessibility](#6-visual-accessibility)
7. [Cognitive Accessibility](#7-cognitive-accessibility)
8. [Testing Requirements](#8-testing-requirements)
9. [Implementation Checklist](#9-implementation-checklist)

---

## 1. Accessibility Principles

### 1.1 POUR Framework

| Principle | Description | Application in Blaze |
|-----------|-------------|---------------------|
| **Perceivable** | Information must be presentable to users in ways they can perceive | All content available to screen readers, proper color contrast |
| **Operable** | UI components must be operable by all users | Full keyboard navigation, no time-dependent actions |
| **Understandable** | Information and UI operation must be understandable | Clear labels, predictable navigation, error guidance |
| **Robust** | Content must be robust enough for assistive technologies | Semantic markup, proper ARIA roles |

### 1.2 Design Philosophy

```
"Accessibility is not a feature—it's a foundation."
```

- Accessibility is considered from the start, not retrofitted
- All features must pass accessibility review before shipping
- Performance of accessible interfaces must match standard interfaces
- Accessibility settings sync across devices via iCloud

---

## 2. VoiceOver Support

### 2.1 Component Labeling

Every interactive element must have:

```swift
// Required accessibility properties
struct AccessibleComponent: View {
    var body: some View {
        Button(action: performAction) {
            Image(systemName: "play.fill")
        }
        .accessibilityLabel("Start session")           // What it is
        .accessibilityHint("Begins a new coding session with Claude")  // What it does
        .accessibilityValue(isRunning ? "Running" : "Stopped")  // Current state
        .accessibilityAddTraits(.isButton)             // Semantic role
    }
}
```

### 2.2 Accessibility Labels by Component

#### Navigation

| Component | Label | Hint | Traits |
|-----------|-------|------|--------|
| Sessions List | "Sessions sidebar" | "Browse and select previous sessions" | `.isHeader` |
| Session Item | "{name}, {date}, {turn_count} turns" | "Double-tap to open this session" | `.isButton` |
| New Session | "New session" | "Creates a new coding session" | `.isButton` |
| Engine Selector | "Engine: {current_engine}" | "Double-tap to change AI engine" | `.isButton` |

#### Chat Timeline

| Component | Label | Hint | Traits |
|-----------|-------|------|--------|
| User Message | "You said: {first_30_chars}..." | "Your message from {time}" | - |
| Assistant Message | "Claude said: {first_30_chars}..." | "Response from {time}" | - |
| Tool Card | "{tool_name} tool, {status}, {duration}" | "Double-tap to expand details" | `.isButton` |
| Diff Card | "File change: {filename}, {added} added, {removed} removed" | "Double-tap to review changes" | `.isButton` |
| Send Button | "Send message" | "Sends your message to Claude" | `.isButton` |
| Cancel Button | "Cancel" | "Stops the current operation" | `.isButton` |

#### Tool Cards (Expanded)

| Component | Label | Hint | Traits |
|-----------|-------|------|--------|
| Tool Header | "{tool} completed in {duration}" | - | `.isHeader` |
| Input Section | "Input: {truncated_input}" | "The command or input provided" | - |
| Output Section | "Output: {truncated_output}" | "The result of the operation" | - |
| Copy Input | "Copy input" | "Copies the input to clipboard" | `.isButton` |
| Copy Output | "Copy output" | "Copies the output to clipboard" | `.isButton` |
| Collapse | "Collapse tool details" | - | `.isButton` |

#### Diff Viewer

| Component | Label | Hint | Traits |
|-----------|-------|------|--------|
| File Header | "Changes to {filename}" | "{added} lines added, {removed} removed" | `.isHeader` |
| Hunk | "Change at line {start_line}" | "Shows {context} context lines" | - |
| Added Line | "Added: {content}" | "Line {number}" | - |
| Removed Line | "Removed: {content}" | "Line {number}" | - |
| Accept Button | "Accept changes" | "Applies these changes to the file" | `.isButton` |
| Reject Button | "Reject changes" | "Discards these changes" | `.isButton` |

### 2.3 Accessibility Containers

```swift
// Group related elements for VoiceOver navigation
VStack {
    // Tool card container
}
.accessibilityElement(children: .contain)
.accessibilityLabel("Bash tool execution")
.accessibilityHint("Contains command input and output")

// OR combine for simpler elements
HStack {
    Image(systemName: "checkmark.circle.fill")
    Text("Success")
}
.accessibilityElement(children: .combine)
// VoiceOver reads: "Success, checkmark"
```

### 2.4 Dynamic Content Announcements

```swift
// Announce important state changes
func announceStreamStarted() {
    AccessibilityNotification.Announcement("Claude is responding")
        .post()
}

func announceToolCompleted(tool: String, success: Bool) {
    let status = success ? "completed successfully" : "failed"
    AccessibilityNotification.Announcement("\(tool) \(status)")
        .post()
}

func announceDiffReady(filename: String) {
    AccessibilityNotification.Announcement("File changes ready for review: \(filename)")
        .post()
}
```

### 2.5 Focus Management

```swift
// Direct focus to important elements
@AccessibilityFocusState private var focusedElement: FocusableElement?

enum FocusableElement: Hashable {
    case messageInput
    case newMessage
    case errorAlert
    case diffReview
}

// After receiving response, focus on it
func onResponseReceived() {
    focusedElement = .newMessage
}

// On error, focus on the error
func onError(_ error: AppError) {
    focusedElement = .errorAlert
}
```

### 2.6 VoiceOver Rotors

```swift
// Custom rotors for quick navigation
.accessibilityRotor("Tool Calls") {
    ForEach(toolCalls) { tool in
        AccessibilityRotorEntry(tool.name, id: tool.id) {
            // Navigation action
        }
    }
}

.accessibilityRotor("File Changes") {
    ForEach(diffs) { diff in
        AccessibilityRotorEntry(diff.filename, id: diff.id) {
            // Navigation action
        }
    }
}

.accessibilityRotor("Errors") {
    ForEach(errors) { error in
        AccessibilityRotorEntry(error.title, id: error.id) {
            // Navigation action
        }
    }
}
```

---

## 3. Text-to-Speech (TTS)

### 3.1 TTS Feature Overview

Beyond VoiceOver, Blaze offers dedicated TTS for reading Claude's responses aloud:

| Feature | Description |
|---------|-------------|
| **Read Response** | Speaks the current assistant message |
| **Auto-Read** | Automatically speaks new responses as they complete |
| **Read Selection** | Speaks highlighted text |
| **Code Mode** | Specialized reading of code with syntax awareness |

### 3.2 TTS Settings

```swift
struct TTSSettings: Codable {
    var enabled: Bool = false
    var autoRead: Bool = false           // Auto-read new responses
    var voice: String = "com.apple.voice.enhanced.en-US.Samantha"
    var rate: Float = 0.5                // 0.0 (slow) to 1.0 (fast)
    var pitch: Float = 1.0               // 0.5 to 2.0
    var volume: Float = 1.0              // 0.0 to 1.0
    var codeMode: CodeReadingMode = .natural
    var pauseOnPunctuation: Bool = true
    var announceHeadings: Bool = true
    var skipCodeBlocks: Bool = false     // For non-technical users
}

enum CodeReadingMode: String, Codable {
    case natural      // "function login open paren username close paren"
    case symbolic     // "function login parenthesis username parenthesis"
    case brief        // "function login with username parameter"
}
```

### 3.3 TTS Implementation

```swift
class SpeechSynthesizer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentPosition: Int = 0  // For highlighting

    func speak(_ text: String, settings: TTSSettings) {
        let utterance = AVSpeechUtterance(string: processForTTS(text, settings))
        utterance.voice = AVSpeechSynthesisVoice(identifier: settings.voice)
        utterance.rate = settings.rate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume

        if settings.pauseOnPunctuation {
            utterance.preUtteranceDelay = 0.1
            utterance.postUtteranceDelay = 0.2
        }

        synthesizer.speak(utterance)
    }

    func processForTTS(_ text: String, _ settings: TTSSettings) -> String {
        var processed = text

        // Handle code blocks
        if settings.skipCodeBlocks {
            processed = processed.replacingCodeBlocks(with: "Code block omitted")
        } else {
            processed = processed.transformCodeForTTS(mode: settings.codeMode)
        }

        // Handle markdown
        processed = processed.strippingMarkdown()

        // Handle URLs
        processed = processed.replacingURLs(with: "link")

        return processed
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }
}
```

### 3.4 TTS Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+S` | Toggle speak current response |
| `Cmd+Shift+A` | Toggle auto-read mode |
| `Cmd+.` | Stop speaking |
| `Space` (when speaking) | Pause/resume |
| `Left/Right Arrow` (when speaking) | Skip backward/forward |

### 3.5 Code Reading Modes

**Natural Mode:**
```
// Input: function login(username: string) { return true; }
// Output: "function login, open parenthesis, username colon string, close parenthesis,
//          open brace, return true, semicolon, close brace"
```

**Symbolic Mode:**
```
// Input: function login(username: string) { return true; }
// Output: "function login parenthesis username colon string parenthesis
//          brace return true semicolon brace"
```

**Brief Mode:**
```
// Input: function login(username: string) { return true; }
// Output: "function login with username parameter, returns true"
```

---

## 4. Keyboard Navigation

### 4.1 Focus Order

The focus order follows a logical reading flow:

```
1. Menu Bar
2. Toolbar
3. Sessions List (left sidebar)
   └─ Session items (arrow keys)
4. Chat Timeline (center)
   └─ Messages (arrow keys)
   └─ Tool cards (Tab to expand, arrow keys within)
   └─ Message input (Tab)
5. Sidebar (right)
   └─ Tab buttons (Tab)
   └─ Tab content (arrow keys)
6. Command Palette (Cmd+K overlay)
```

### 4.2 Keyboard Shortcuts

#### Global Navigation

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | Open command palette |
| `Cmd+N` | New session |
| `Cmd+W` | Close current session |
| `Cmd+1/2/3` | Switch sidebar tabs |
| `Cmd+[` / `Cmd+]` | Navigate sessions |
| `Cmd+\` | Toggle left sidebar |
| `Cmd+Shift+\` | Toggle right sidebar |
| `Cmd+0` | Focus sessions list |
| `Cmd+L` | Focus message input |
| `Escape` | Close overlay/cancel |

#### Chat Navigation

| Shortcut | Action |
|----------|--------|
| `Up/Down` | Navigate messages |
| `Enter` (on message) | Expand/collapse |
| `Cmd+Enter` | Send message |
| `Cmd+.` | Cancel current operation |
| `Cmd+C` (on message) | Copy message content |
| `Cmd+Shift+C` | Copy last response |

#### Diff Viewer

| Shortcut | Action |
|----------|--------|
| `J/K` | Next/previous hunk |
| `]d` / `[d` | Next/previous file |
| `A` | Accept current hunk |
| `R` | Reject current hunk |
| `Cmd+Shift+A` | Accept all |
| `Cmd+Shift+R` | Reject all |
| `Space` | Toggle unified/split view |
| `?` | Show keyboard shortcuts |

#### Command Palette

| Shortcut | Action |
|----------|--------|
| `Up/Down` | Navigate options |
| `Enter` | Select option |
| `Tab` | Autocomplete |
| `Escape` | Close palette |
| `Cmd+Backspace` | Clear input |

### 4.3 Focus Indicators

```swift
// Custom focus indicator style
struct BlazeFocusStyle: FocusIndicatorStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(-2)
                    .opacity(configuration.isFocused ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isFocused)
    }
}

// High contrast focus for accessibility
struct HighContrastFocusStyle: FocusIndicatorStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary, lineWidth: 3)
                    .padding(-4)
                    .opacity(configuration.isFocused ? 1 : 0)
            )
            .shadow(color: configuration.isFocused ? .primary.opacity(0.3) : .clear, radius: 4)
    }
}
```

### 4.4 Focus Trapping for Modals

```swift
// Trap focus within modal dialogs
struct AccessibleModal<Content: View>: View {
    @FocusState private var focusedElement: ModalFocus?
    let content: Content

    var body: some View {
        ZStack {
            // Backdrop blocks interaction with background
            Color.black.opacity(0.5)
                .accessibilityHidden(true)
                .onTapGesture { /* dismiss */ }

            // Modal content
            content
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .focused($focusedElement, equals: .content)
                .onAppear {
                    focusedElement = .content
                }
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
    }
}
```

### 4.5 Skip Links

```swift
// Skip to main content for keyboard users
struct ContentView: View {
    @FocusState private var focus: ContentFocus?

    var body: some View {
        VStack {
            // Invisible skip link (visible on focus)
            Button("Skip to main content") {
                focus = .mainContent
            }
            .opacity(focus == .skipLink ? 1 : 0)
            .focused($focus, equals: .skipLink)
            .accessibilityAddTraits(.isLink)

            NavigationSplitView {
                SessionsSidebar()
            } content: {
                ChatTimeline()
                    .focused($focus, equals: .mainContent)
            } detail: {
                DetailSidebar()
            }
        }
    }
}
```

---

## 5. Reduced Motion

### 5.1 Motion Preferences

```swift
struct MotionSettings {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var animationDuration: Double {
        reduceMotion ? 0 : 0.3
    }

    var animation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.3)
    }

    var transition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }
}
```

### 5.2 Respecting User Preferences

```swift
// Streaming text animation
struct StreamingText: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if reduceMotion {
            // Show complete text immediately
            Text(text)
        } else {
            // Animate text appearing
            TypewriterText(text: text, speed: 0.02)
        }
    }
}

// Tool card expansion
struct ToolCard: View {
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack {
            header
            if isExpanded {
                details
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3), value: isExpanded)
    }
}
```

### 5.3 Motion Categories

| Category | Default Behavior | Reduced Motion Behavior |
|----------|------------------|------------------------|
| Streaming text | Typewriter effect | Instant display |
| Panel transitions | Slide + fade | Fade only |
| Tool card expand | Spring animation | Instant toggle |
| Loading spinners | Rotation | Static progress bar |
| Success checkmark | Draw animation | Instant appear |
| Error shake | Horizontal shake | Red flash |
| Scroll to bottom | Smooth scroll | Jump scroll |

### 5.4 Essential vs. Decorative Motion

```swift
// Essential motion (always plays, but simplified)
func scrollToNewMessage() {
    withAnimation(reduceMotion ? nil : .easeOut) {
        scrollProxy.scrollTo(lastMessageId, anchor: .bottom)
    }
}

// Decorative motion (disabled when reduce motion on)
struct ParticleEffect: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()  // Skip entirely
        } else {
            ParticleSystem()
        }
    }
}
```

---

## 6. Visual Accessibility

### 6.1 Color Contrast

All text and interactive elements must meet WCAG AA contrast requirements:

| Element Type | Minimum Ratio | Target Ratio |
|--------------|---------------|--------------|
| Body text | 4.5:1 | 7:1 |
| Large text (18pt+) | 3:1 | 4.5:1 |
| UI components | 3:1 | 4.5:1 |
| Focus indicators | 3:1 | 4.5:1 |
| Disabled elements | 3:1 (informational only) | - |

### 6.2 Color Independence

Never rely on color alone to convey information:

```swift
// Bad: Only color indicates status
Circle()
    .fill(success ? .green : .red)

// Good: Color + icon + label
HStack {
    Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(success ? .green : .red)
    Text(success ? "Success" : "Failed")
}
.accessibilityElement(children: .combine)
```

### 6.3 High Contrast Mode

```swift
struct AdaptiveColors {
    @Environment(\.accessibilityHighContrast) var highContrast
    @Environment(\.colorScheme) var colorScheme

    var cardBackground: Color {
        if highContrast {
            return colorScheme == .dark ? .black : .white
        }
        return Color("CardBackground")  // Semi-transparent
    }

    var borderColor: Color {
        highContrast ? .primary : Color("Separator")
    }

    var borderWidth: CGFloat {
        highContrast ? 2 : 1
    }
}
```

### 6.4 Dynamic Type

```swift
// All text must support Dynamic Type
struct MessageView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body)  // Uses Dynamic Type automatically
            .lineLimit(nil)  // Don't truncate when text is large
    }
}

// Custom fonts must also scale
extension Font {
    static var blazeMonospace: Font {
        .system(.body, design: .monospaced)
    }

    static func blazeHeadline(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
            .leading(.tight)
    }
}

// Test at all Dynamic Type sizes
@available(iOS 15.0, macOS 12.0, *)
struct DynamicTypePreviews: PreviewProvider {
    static var previews: some View {
        ForEach(DynamicTypeSize.allCases, id: \.self) { size in
            MessageView(message: "Sample text")
                .dynamicTypeSize(size)
                .previewDisplayName(String(describing: size))
        }
    }
}
```

### 6.5 Differentiate Without Color

```swift
// Diff viewer with patterns, not just colors
struct DiffLine: View {
    let type: DiffLineType
    let content: String
    @Environment(\.accessibilityDifferentiateWithoutColor) var diffWithoutColor

    var body: some View {
        HStack(spacing: 8) {
            // Type indicator
            Group {
                switch type {
                case .added:
                    if diffWithoutColor {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text("+")
                case .removed:
                    if diffWithoutColor {
                        Image(systemName: "minus.circle.fill")
                    }
                    Text("-")
                case .unchanged:
                    Text(" ")
                }
            }
            .foregroundColor(type.color)
            .frame(width: 20)

            // Content with background pattern
            Text(content)
                .background(
                    diffWithoutColor ? type.pattern : type.color.opacity(0.2)
                )
        }
    }
}

extension DiffLineType {
    var pattern: some View {
        switch self {
        case .added:
            return DiagonalPattern(direction: .forward, color: .green)
        case .removed:
            return DiagonalPattern(direction: .backward, color: .red)
        case .unchanged:
            return Color.clear
        }
    }
}
```

---

## 7. Cognitive Accessibility

### 7.1 Clear Language

- Use simple, direct language in UI text
- Avoid jargon when possible; explain when necessary
- Provide context for technical terms

### 7.2 Predictable Navigation

- Consistent layout across all views
- Same actions in same locations
- Clear visual hierarchy

### 7.3 Error Prevention

```swift
// Confirmation for destructive actions
struct DestructiveAction {
    func deleteSession(_ session: Session) {
        showConfirmation(
            title: "Delete Session?",
            message: "This will permanently delete '\(session.name)' and all its messages. This cannot be undone.",
            confirmLabel: "Delete",
            confirmRole: .destructive,
            onConfirm: { performDeletion(session) }
        )
    }
}
```

### 7.4 Status Visibility

```swift
// Always show what's happening
struct SessionStatusIndicator: View {
    let status: SessionStatus

    var body: some View {
        HStack {
            statusIcon
            Text(status.description)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session status: \(status.description)")
    }

    @ViewBuilder
    var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        case .thinking:
            ProgressView()
                .controlSize(.small)
        case .responding:
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .pulsingAnimation()  // Respects reduce motion
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}
```

### 7.5 Time Limits

- No time-based automatic actions that can't be extended
- Auto-save prevents data loss
- Timeouts have warnings and can be extended

---

## 8. Testing Requirements

### 8.1 Automated Testing

```swift
// XCTest accessibility assertions
func testMessageAccessibility() throws {
    let app = XCUIApplication()
    app.launch()

    let message = app.staticTexts["Claude said:"].firstMatch
    XCTAssertTrue(message.exists)
    XCTAssertNotNil(message.label)
    XCTAssertTrue(message.isAccessibilityElement)
}

// Accessibility audit (iOS 17+)
func testAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()

    try app.performAccessibilityAudit()
}

// Custom audit rules
func testColorContrast() throws {
    let app = XCUIApplication()
    app.launch()

    try app.performAccessibilityAudit(for: [.contrast])
}
```

### 8.2 Manual Testing Checklist

**VoiceOver Testing:**
- [ ] All interactive elements have labels
- [ ] Focus order is logical
- [ ] State changes are announced
- [ ] No unlabeled images
- [ ] Tables and lists navigable
- [ ] Custom rotors work correctly

**Keyboard Testing:**
- [ ] All features accessible via keyboard
- [ ] Focus visible at all times
- [ ] No keyboard traps
- [ ] Shortcuts don't conflict with system
- [ ] Modal focus is trapped correctly

**Visual Testing:**
- [ ] Works at all Dynamic Type sizes
- [ ] High contrast mode works
- [ ] Reduce transparency works
- [ ] No color-only information
- [ ] Focus indicators visible

**Motion Testing:**
- [ ] Reduce motion respected
- [ ] No vestibular triggers
- [ ] Essential animations simplified

### 8.3 Assistive Technology Testing Matrix

| AT | macOS Version | Test Frequency |
|----|---------------|----------------|
| VoiceOver | 14.0+ | Every release |
| Voice Control | 14.0+ | Every release |
| Switch Control | 14.0+ | Major releases |
| Full Keyboard Access | 14.0+ | Every release |
| Zoom | 14.0+ | Major releases |

---

## 9. Implementation Checklist

### 9.1 Per-Component Checklist

- [ ] Accessibility label defined
- [ ] Accessibility hint defined (if needed)
- [ ] Accessibility traits set correctly
- [ ] Focus indicator visible
- [ ] Keyboard navigable
- [ ] VoiceOver tested
- [ ] Dynamic Type tested
- [ ] High contrast tested
- [ ] Reduced motion tested

### 9.2 Per-Feature Checklist

- [ ] All new components pass component checklist
- [ ] Feature accessible via keyboard only
- [ ] Feature works with VoiceOver only
- [ ] Error states are accessible
- [ ] Loading states are announced
- [ ] Success states are announced
- [ ] Documentation updated

### 9.3 Per-Release Checklist

- [ ] Accessibility audit passes
- [ ] Manual VoiceOver testing complete
- [ ] Keyboard navigation testing complete
- [ ] Automated tests pass
- [ ] Release notes include accessibility changes
- [ ] Known issues documented

---

## Appendix A: Accessibility Settings Panel

```swift
struct AccessibilitySettingsView: View {
    @AppStorage("tts.enabled") var ttsEnabled = false
    @AppStorage("tts.autoRead") var ttsAutoRead = false
    @AppStorage("tts.rate") var ttsRate: Double = 0.5
    @AppStorage("tts.voice") var ttsVoice = "com.apple.voice.enhanced.en-US.Samantha"
    @AppStorage("a11y.announceToolResults") var announceToolResults = true
    @AppStorage("a11y.highContrastFocus") var highContrastFocus = false

    var body: some View {
        Form {
            Section("Text-to-Speech") {
                Toggle("Enable TTS", isOn: $ttsEnabled)
                Toggle("Auto-read responses", isOn: $ttsAutoRead)
                    .disabled(!ttsEnabled)

                Slider(value: $ttsRate, in: 0...1) {
                    Text("Speaking rate")
                }
                .disabled(!ttsEnabled)

                Picker("Voice", selection: $ttsVoice) {
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text(voice.name).tag(voice.identifier)
                    }
                }
                .disabled(!ttsEnabled)
            }

            Section("VoiceOver") {
                Toggle("Announce tool completions", isOn: $announceToolResults)
                Toggle("High contrast focus ring", isOn: $highContrastFocus)
            }

            Section("Keyboard") {
                NavigationLink("Customize shortcuts") {
                    KeyboardShortcutSettings()
                }
            }
        }
        .navigationTitle("Accessibility")
    }
}
```

---

## Appendix B: WCAG 2.2 Compliance Matrix

| Criterion | Level | Status | Notes |
|-----------|-------|--------|-------|
| 1.1.1 Non-text Content | A | Compliant | All images have alt text |
| 1.3.1 Info and Relationships | A | Compliant | Semantic structure used |
| 1.3.2 Meaningful Sequence | A | Compliant | Logical reading order |
| 1.4.1 Use of Color | A | Compliant | Never color-only |
| 1.4.3 Contrast (Minimum) | AA | Compliant | 4.5:1 minimum |
| 1.4.4 Resize Text | AA | Compliant | Dynamic Type supported |
| 1.4.10 Reflow | AA | Compliant | Responsive layout |
| 1.4.11 Non-text Contrast | AA | Compliant | 3:1 for UI components |
| 2.1.1 Keyboard | A | Compliant | Full keyboard support |
| 2.1.2 No Keyboard Trap | A | Compliant | Focus management |
| 2.1.4 Character Key Shortcuts | A | Compliant | All require modifier |
| 2.4.3 Focus Order | A | Compliant | Logical focus order |
| 2.4.7 Focus Visible | AA | Compliant | Custom focus rings |
| 2.5.1 Pointer Gestures | A | Compliant | Single pointer alternatives |
| 3.2.1 On Focus | A | Compliant | No context change on focus |
| 3.3.1 Error Identification | A | Compliant | Clear error messages |
| 4.1.2 Name, Role, Value | A | Compliant | Proper accessibility API |

---

**End of Document**
