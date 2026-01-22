# Empty States & Onboarding Visuals

> Cogit0 Blaze - First Impressions That Delight

## Overview

Empty states and onboarding are where users form their first impressions. Instead of blank screens, we turn these moments into opportunities for **guidance**, **delight**, and **education**. Every empty state should answer: "What can I do here?"

---

## 1. Design Philosophy

### 1.1 Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    EMPTY STATE PRINCIPLES                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐     │
│  │ HELPFUL    │   │ INVITING   │   │ CONTEXTUAL │   │ BEAUTIFUL  │     │
│  ├────────────┤   ├────────────┤   ├────────────┤   ├────────────┤     │
│  │ Clear next │   │ Encourage  │   │ Relevant   │   │ Visuals    │     │
│  │ action     │   │ exploration│   │ to where   │   │ that spark │     │
│  │            │   │            │   │ user is    │   │ joy        │     │
│  └────────────┘   └────────────┘   └────────────┘   └────────────┘     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Anatomy of an Empty State

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                         [Illustration/Icon]                             │
│                              64-128px                                   │
│                                                                         │
│                            Title                                        │
│                      Bold, descriptive                                  │
│                                                                         │
│              Description text explaining the state                      │
│              and what user can do about it                              │
│                                                                         │
│                     [Primary Action Button]                             │
│                                                                         │
│                       Optional secondary link                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Empty State Catalog

### 2.1 No Sessions (First Launch)

**Context:** User opens Blaze for the first time

```swift
struct WelcomeEmptyState: View {
    var body: some View {
        VStack(spacing: 24) {
            // Animated flame illustration
            AnimatedFlameIllustration()
                .frame(width: 120, height: 120)

            Text("Welcome to Blaze")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DarkText.primary)

            Text("The fastest way to work with Claude Code.\nStart a conversation to begin coding together.")
                .font(.body)
                .foregroundStyle(DarkText.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                createNewSession()
            } label: {
                Label("New Session", systemImage: "plus.bubble")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Press ⌘N anytime to start fresh")
                .font(.caption)
                .foregroundStyle(DarkText.tertiary)
        }
        .padding(40)
    }
}
```

**Illustration Concept:**
- Stylized flame icon with subtle gradient
- Gentle pulse animation (2s cycle)
- Warm glow effect behind

### 2.2 Empty Session (No Messages)

**Context:** New session created, no messages yet

```swift
struct EmptySessionView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Floating message bubbles illustration
            FloatingBubblesIllustration()
                .frame(width: 100, height: 80)

            Text("Start the Conversation")
                .font(.title2.bold())
                .foregroundStyle(DarkText.primary)

            VStack(spacing: 8) {
                SuggestionPill(text: "Help me refactor this function", icon: "wand.and.rays")
                SuggestionPill(text: "Explain this error message", icon: "exclamationmark.triangle")
                SuggestionPill(text: "Write tests for my code", icon: "checkmark.circle")
            }

            Text("Or type anything below to get started")
                .font(.caption)
                .foregroundStyle(DarkText.tertiary)
        }
        .padding(32)
    }
}

struct SuggestionPill: View {
    let text: String
    let icon: String

    var body: some View {
        Button {
            insertSuggestion(text)
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(DarkAccent.primary)
                Text(text)
                    .foregroundStyle(DarkText.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DarkBackground.raised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DarkBorder.subtle))
        }
        .buttonStyle(.plain)
    }
}
```

### 2.3 No Search Results

**Context:** Search returns zero matches

```swift
struct NoSearchResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(DarkText.tertiary)

            Text("No Results for \"\(query)\"")
                .font(.headline)
                .foregroundStyle(DarkText.primary)

            Text("Try adjusting your search terms or filters")
                .font(.body)
                .foregroundStyle(DarkText.secondary)

            HStack(spacing: 12) {
                Button("Clear Filters") {
                    clearFilters()
                }
                .buttonStyle(.bordered)

                Button("Search Tips") {
                    showSearchTips()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(32)
    }
}
```

### 2.4 No CLI Detected

**Context:** Claude Code CLI not found

```swift
struct NoCLIDetectedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal")
                .font(.system(size: 64))
                .foregroundStyle(DarkAccent.warning)

            Text("Claude Code CLI Not Found")
                .font(.title2.bold())
                .foregroundStyle(DarkText.primary)

            Text("Blaze needs the Claude Code CLI to work.\nInstall it to get started.")
                .font(.body)
                .foregroundStyle(DarkText.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    openInstallGuide()
                } label: {
                    Label("Install Claude Code", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                Button("I already have it installed") {
                    manualPathConfiguration()
                }
                .buttonStyle(.borderless)
            }

            // Terminal command preview
            HStack {
                Text("npm install -g @anthropic/claude-code")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(DarkText.secondary)

                Button {
                    copyToClipboard("npm install -g @anthropic/claude-code")
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .background(DarkBackground.raised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(40)
    }
}
```

### 2.5 Offline State

**Context:** No internet connection

```swift
struct OfflineStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundStyle(DarkText.tertiary)

            Text("You're Offline")
                .font(.title2.bold())
                .foregroundStyle(DarkText.primary)

            Text("Blaze needs an internet connection to send messages.\nYou can still browse your previous sessions.")
                .font(.body)
                .foregroundStyle(DarkText.secondary)
                .multilineTextAlignment(.center)

            Button("View Past Sessions") {
                showSessionList()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
    }
}
```

### 2.6 Error State

**Context:** Something went wrong

```swift
struct ErrorStateView: View {
    let error: AppError

    var body: some View {
        VStack(spacing: 20) {
            // Sad robot illustration
            SadRobotIllustration()
                .frame(width: 100, height: 100)

            Text(error.funTitle)  // From error taxonomy
                .font(.title2.bold())
                .foregroundStyle(DarkText.primary)

            Text(error.recoveryMessage)
                .font(.body)
                .foregroundStyle(DarkText.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 12) {
                if error.canRetry {
                    Button("Try Again") {
                        retry()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Get Help") {
                    showHelp(for: error)
                }
                .buttonStyle(.bordered)
            }

            // Error code for support
            Text("Error: \(error.code)")
                .font(.caption)
                .foregroundStyle(DarkText.disabled)
        }
        .padding(32)
    }
}
```

---

## 3. Onboarding Flow

### 3.1 Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ONBOARDING FLOW                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Step 1         Step 2          Step 3          Step 4         Done    │
│  Welcome        CLI Setup       Permissions     Quick Tour     Ready!   │
│     │              │               │               │             │      │
│     ▼              ▼               ▼               ▼             ▼      │
│  ┌──────┐      ┌──────┐       ┌──────┐        ┌──────┐      ┌──────┐   │
│  │Brand │      │Detect│       │Trust │        │Feature│     │Start │   │
│  │intro │──────│ CLI  │───────│ mode │────────│ tour  │─────│coding│   │
│  └──────┘      └──────┘       └──────┘        └──────┘      └──────┘   │
│                    │                                                    │
│                    ▼                                                    │
│              ┌──────────┐                                              │
│              │ Install  │ (if not found)                               │
│              │ helper   │                                              │
│              └──────────┘                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Step 1: Welcome

```swift
struct OnboardingWelcome: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated logo
            BlazeLogoAnimation()
                .frame(width: 120, height: 120)

            VStack(spacing: 12) {
                Text("Welcome to Blaze")
                    .font(.system(size: 32, weight: .bold))

                Text("The native macOS experience for Claude Code")
                    .font(.title3)
                    .foregroundStyle(DarkText.secondary)
            }

            // Key value props
            VStack(alignment: .leading, spacing: 16) {
                ValuePropRow(
                    icon: "bolt.fill",
                    title: "Lightning Fast",
                    description: "Native performance, instant responses"
                )
                ValuePropRow(
                    icon: "eye.fill",
                    title: "Beautiful Diffs",
                    description: "Review code changes with clarity"
                )
                ValuePropRow(
                    icon: "shield.fill",
                    title: "You're in Control",
                    description: "Approve or reject tool actions"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Get Started") {
                nextStep()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

struct ValuePropRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DarkAccent.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DarkText.secondary)
            }
        }
    }
}
```

### 3.3 Step 2: CLI Setup

```swift
struct OnboardingCLISetup: View {
    @State private var cliStatus: CLIStatus = .checking

    var body: some View {
        VStack(spacing: 32) {
            Text("Connecting to Claude Code")
                .font(.title.bold())

            // Status indicator
            CLIStatusView(status: cliStatus)
                .frame(height: 200)

            switch cliStatus {
            case .checking:
                ProgressView("Looking for Claude Code CLI...")

            case .found(let version):
                VStack(spacing: 16) {
                    Label("CLI Found!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DarkAccent.success)
                        .font(.headline)

                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(DarkText.tertiary)
                }

            case .notFound:
                VStack(spacing: 20) {
                    Text("Claude Code CLI not found")
                        .foregroundStyle(DarkAccent.warning)

                    InstallInstructions()
                }

            case .outdated(let current, let required):
                VStack(spacing: 16) {
                    Text("Update Required")
                        .foregroundStyle(DarkAccent.warning)

                    Text("Found v\(current), need v\(required)+")
                        .font(.caption)

                    Button("Update CLI") {
                        openUpdateGuide()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()

            HStack {
                Button("Back") { previousStep() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Continue") { nextStep() }
                    .buttonStyle(.borderedProminent)
                    .disabled(cliStatus != .found)
            }
        }
        .padding(40)
        .task {
            cliStatus = await checkCLI()
        }
    }
}
```

### 3.4 Step 3: Security Mode

```swift
struct OnboardingSecurityMode: View {
    @State private var selectedMode: SecurityMode = .review

    var body: some View {
        VStack(spacing: 32) {
            Text("Choose Your Security Level")
                .font(.title.bold())

            Text("How much control do you want over Claude's actions?")
                .foregroundStyle(DarkText.secondary)

            VStack(spacing: 16) {
                SecurityModeCard(
                    mode: .review,
                    title: "Review Mode",
                    description: "Approve file writes and commands before they run. Recommended for most users.",
                    icon: "eye.circle",
                    isSelected: selectedMode == .review
                ) {
                    selectedMode = .review
                }

                SecurityModeCard(
                    mode: .trusted,
                    title: "Trusted Mode",
                    description: "Claude can act freely. For experienced users who want speed.",
                    icon: "bolt.circle",
                    isSelected: selectedMode == .trusted
                ) {
                    selectedMode = .trusted
                }

                SecurityModeCard(
                    mode: .sandbox,
                    title: "Sandbox Mode",
                    description: "Read-only access. Claude can explore but not modify.",
                    icon: "lock.circle",
                    isSelected: selectedMode == .sandbox
                ) {
                    selectedMode = .sandbox
                }
            }

            Text("You can change this anytime in Settings")
                .font(.caption)
                .foregroundStyle(DarkText.tertiary)

            Spacer()

            HStack {
                Button("Back") { previousStep() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Continue") {
                    setSecurityMode(selectedMode)
                    nextStep()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
}
```

### 3.5 Step 4: Quick Tour

```swift
struct OnboardingQuickTour: View {
    @State private var tourStep = 0

    let tourSteps: [(title: String, description: String, image: String)] = [
        (
            "Chat Timeline",
            "Your conversation with Claude appears here. Messages stream in real-time.",
            "tour-chat"
        ),
        (
            "Tool Cards",
            "When Claude uses tools like Read, Write, or Bash, you'll see details here.",
            "tour-tools"
        ),
        (
            "Diff Viewer",
            "Review proposed code changes with syntax highlighting and line-by-line diffs.",
            "tour-diff"
        ),
        (
            "Session Sidebar",
            "All your conversations are saved. Search, filter, and switch between them.",
            "tour-sidebar"
        ),
        (
            "Keyboard Shortcuts",
            "Press ⌘K anytime to open the command palette. It's the fastest way to navigate.",
            "tour-keyboard"
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Quick Tour")
                .font(.title.bold())

            // Tour content
            TabView(selection: $tourStep) {
                ForEach(Array(tourSteps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Image(step.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(DarkShadow.lg)

                        Text(step.title)
                            .font(.headline)

                        Text(step.description)
                            .foregroundStyle(DarkText.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Spacer()

            HStack {
                Button("Skip Tour") {
                    completeTour()
                }
                .buttonStyle(.borderless)

                Spacer()

                if tourStep < tourSteps.count - 1 {
                    Button("Next") {
                        withAnimation { tourStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Using Blaze") {
                        completeTour()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(40)
    }
}
```

---

## 4. Illustrations

### 4.1 Illustration Style Guide

| Attribute | Specification |
|-----------|--------------|
| **Style** | Flat with subtle gradients |
| **Colors** | Primary accent + neutral grays |
| **Size** | 64-128px for empty states |
| **Animation** | Subtle, non-distracting |
| **Mood** | Friendly, professional, minimal |

### 4.2 Required Illustrations

| Name | Usage | Description |
|------|-------|-------------|
| `blaze-flame` | Welcome, branding | Stylized flame icon |
| `floating-bubbles` | Empty session | Chat bubbles floating |
| `sad-robot` | Error states | Cute robot looking apologetic |
| `rocket-launch` | First session complete | Celebration |
| `telescope` | No search results | Looking for something |
| `plugged-in` | CLI connected | Cable connecting |
| `unplugged` | CLI not found | Disconnected cable |
| `shield-check` | Security mode | Shield with checkmark |

### 4.3 Animation Examples

```swift
// AnimatedFlameIllustration.swift

struct AnimatedFlameIllustration: View {
    @State private var flicker = false

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DarkAccent.primary.opacity(0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .scaleEffect(flicker ? 1.1 : 1.0)

            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F97316"),
                            Color(hex: "#EF4444")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(flicker ? 1.05 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
    }
}
```

---

## 5. Contextual Hints

### 5.1 Tooltip System

```swift
struct ContextualHint: View {
    let title: String
    let description: String
    let shortcut: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DarkText.primary)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(DarkText.secondary)

            if let shortcut = shortcut {
                HStack(spacing: 4) {
                    Text("Shortcut:")
                        .font(.caption)
                        .foregroundStyle(DarkText.tertiary)
                    KeyboardShortcutView(shortcut: shortcut)
                }
            }
        }
        .padding(16)
        .background(DarkBackground.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(DarkShadow.lg)
    }
}
```

### 5.2 First-Time Hints

```swift
struct FirstTimeHintOverlay: View {
    @AppStorage("hasSeenHint_\(hintId)") var hasSeen = false
    let hintId: String
    let anchor: CGPoint
    let content: ContextualHint

    var body: some View {
        if !hasSeen {
            VStack {
                content

                Button("Got it!") {
                    withAnimation {
                        hasSeen = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .position(anchor)
            .transition(.opacity.combined(with: .scale))
        }
    }
}
```

---

## 6. Implementation Checklist

- [ ] All empty state components created
- [ ] Illustrations designed and exported
- [ ] Animations implemented with reduced motion support
- [ ] Onboarding flow complete (4 steps)
- [ ] CLI detection and installation helper
- [ ] Security mode selection
- [ ] Quick tour with screenshots
- [ ] Contextual hints system
- [ ] First-time user detection
- [ ] Onboarding completion tracking
- [ ] Skip and revisit options
- [ ] Accessibility testing
- [ ] Localization of all strings
