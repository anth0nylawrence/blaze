# Animation & Motion Spec

> Cogit0 Blaze - Movement, Timing, and Choreography

## Overview

Motion in Blaze isn't decoration—it's information. Every animation serves a purpose: guiding attention, showing relationships, or providing feedback. Our motion language is **purposeful**, **swift**, and **delightful**.

---

## 1. Motion Philosophy

### 1.1 Core Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MOTION PRINCIPLES                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐     │
│  │ PURPOSEFUL │   │   SWIFT    │   │  NATURAL   │   │ DELIGHTFUL │     │
│  ├────────────┤   ├────────────┤   ├────────────┤   ├────────────┤     │
│  │ Every move │   │ Fast but   │   │ Physics-   │   │ Subtle joy │     │
│  │ has intent │   │ not jarring│   │ informed   │   │ in details │     │
│  └────────────┘   └────────────┘   └────────────┘   └────────────┘     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 When to Animate

| ✅ Animate | ❌ Don't Animate |
|-----------|-----------------|
| State changes (loading → loaded) | Every hover state |
| Navigation transitions | Repeated micro-interactions |
| Revealing new content | Distracting from content |
| User action feedback | When user prefers reduced motion |
| Error/success states | Blocking user interaction |

---

## 2. Timing & Easing

### 2.1 Duration Scale

```swift
// MotionTokens.swift

enum MotionDuration {
    /// Instant feedback (button press, toggle)
    static let instant: Double = 0.1      // 100ms

    /// Quick transitions (expand, collapse)
    static let fast: Double = 0.2         // 200ms

    /// Standard transitions (panel slide, modal)
    static let normal: Double = 0.3       // 300ms

    /// Deliberate movements (page transition)
    static let slow: Double = 0.5         // 500ms

    /// Orchestrated sequences (onboarding)
    static let deliberate: Double = 0.8   // 800ms
}
```

### 2.2 Easing Curves

```swift
// MotionCurves.swift

enum MotionCurve {
    /// Standard easing - use for most transitions
    /// Fast start, gentle land
    static let standard = Animation.timingCurve(0.2, 0.0, 0.0, 1.0)

    /// Emphasized - for important state changes
    /// Snappy with satisfying settle
    static let emphasized = Animation.timingCurve(0.2, 0.0, 0.0, 1.0)

    /// Decelerate - entering elements
    /// Slides in and settles
    static let decelerate = Animation.timingCurve(0.0, 0.0, 0.0, 1.0)

    /// Accelerate - exiting elements
    /// Quick departure
    static let accelerate = Animation.timingCurve(0.3, 0.0, 1.0, 1.0)

    /// Spring - playful, bouncy
    /// For success states, toggles
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)

    /// Gentle spring - subtle bounce
    static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)
}
```

### 2.3 Visual Easing Reference

```
Standard Curve (0.2, 0.0, 0.0, 1.0)
         ┌────────────────────────────────────────┐
    100% │                          ●●●●●●●●●●●●●│
         │                    ●●●●●               │
         │               ●●●●                     │
         │          ●●●●                          │
         │       ●●●                              │
         │    ●●●                                 │
         │  ●●                                    │
      0% │●●                                      │
         └────────────────────────────────────────┘
          0%                                    100%
                         Time →

Spring Curve (response: 0.4, damping: 0.7)
         ┌────────────────────────────────────────┐
    110% │          ●●●                           │
    100% │       ●●●   ●●●●●●●●●●●●●●●●●●●●●●●●●●│
         │     ●●                                 │
         │   ●●                                   │
         │  ●                                     │
         │ ●                                      │
         │●                                       │
      0% │●                                       │
         └────────────────────────────────────────┘
```

---

## 3. Component Animations

### 3.1 Message Bubbles

**Appearance:**
- Duration: `fast` (200ms)
- Easing: `decelerate`
- Effect: Fade in + slide up from 8px

```swift
struct MessageBubble: View {
    @State private var isVisible = false

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
    }
}
```

**Streaming Text:**
- Each character: `instant` (100ms) fade-in
- Cursor blink: 530ms on, 530ms off
- No movement, just opacity

```swift
struct StreamingText: View {
    let text: String
    @State private var visibleCount = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .opacity(index < visibleCount ? 1 : 0)
            }

            // Blinking cursor
            Rectangle()
                .fill(.primary)
                .frame(width: 2, height: 16)
                .opacity(cursorVisible ? 1 : 0)
        }
        .onAppear {
            animateText()
        }
    }
}
```

### 3.2 Tool Cards

**Expand/Collapse:**
- Duration: `normal` (300ms)
- Easing: `gentleSpring`
- Effect: Height change with content fade

```swift
struct ToolCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            header
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}
```

**Status Indicator:**
- Pending: Gentle pulse (2s cycle)
- In Progress: Spinning loader
- Complete: Checkmark with spring bounce
- Error: Shake (3 oscillations, 50ms each)

```swift
struct StatusIndicator: View {
    let status: ToolStatus

    var body: some View {
        switch status {
        case .pending:
            Circle()
                .fill(.secondary)
                .modifier(PulseModifier())

        case .inProgress:
            ProgressView()
                .progressViewStyle(.circular)

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .modifier(BounceModifier())

        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .modifier(ShakeModifier())
        }
    }
}

struct ShakeModifier: ViewModifier {
    @State private var shake = false

    func body(content: Content) -> some View {
        content
            .offset(x: shake ? -5 : 0)
            .animation(
                .easeInOut(duration: 0.05)
                .repeatCount(6, autoreverses: true),
                value: shake
            )
            .onAppear { shake = true }
    }
}
```

### 3.3 Diff Viewer

**Line Reveal:**
- Staggered appearance: 20ms delay per line
- Duration: `fast` (200ms) per line
- Effect: Fade in from left

```swift
struct DiffLine: View {
    let line: DiffLineDelta
    let index: Int

    @State private var isVisible = false

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : -10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2).delay(Double(index) * 0.02)) {
                    isVisible = true
                }
            }
    }
}
```

**Highlight on Hover:**
- Duration: `instant` (100ms)
- Effect: Background color fade

### 3.4 Navigation

**Panel Transitions:**
- Duration: `normal` (300ms)
- Easing: `standard`
- Effect: Slide + fade

```swift
NavigationSplitView {
    SessionList()
        .transition(.move(edge: .leading).combined(with: .opacity))
} content: {
    ChatView()
        .transition(.opacity)
} detail: {
    DetailView()
        .transition(.move(edge: .trailing).combined(with: .opacity))
}
.animation(.easeInOut(duration: 0.3), value: selectedSession)
```

**Session Switch:**
- Duration: `fast` (200ms)
- Effect: Cross-dissolve

---

## 4. Micro-interactions

### 4.1 Button States

```swift
struct PrimaryButton: View {
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Text("Send")
            .padding()
            .background(backgroundColor)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }

    var backgroundColor: Color {
        if isPressed { return .accentColor.opacity(0.8) }
        if isHovered { return .accentColor.opacity(0.9) }
        return .accentColor
    }
}
```

### 4.2 Toggle Switch

```swift
struct CustomToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isOn ? Color.green : Color.secondary.opacity(0.3))
            .frame(width: 44, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .padding(2)
                    .shadow(radius: 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            .onTapGesture { isOn.toggle() }
    }
}
```

### 4.3 Loading States

**Skeleton Shimmer:**
```swift
struct SkeletonView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: shimmerOffset * 200)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1
                }
            }
    }
}
```

**Typing Indicator:**
```swift
struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.4)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}
```

---

## 5. Page Transitions

### 5.1 Modal Presentation

```swift
struct ModalPresentation: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            if isPresented {
                // Backdrop
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // Modal
                content
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.95))
                                .combined(with: .offset(y: 20)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.95))
                        )
                    )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
    }
}
```

### 5.2 Command Palette

```swift
struct CommandPalette: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            searchField
            resultsList
        }
        .frame(width: 600)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .scaleEffect(isPresented ? 1 : 0.9)
        .opacity(isPresented ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPresented)
    }
}
```

### 5.3 Onboarding Flow

```swift
struct OnboardingView: View {
    @State private var currentStep = 0

    var body: some View {
        TabView(selection: $currentStep) {
            ForEach(0..<steps.count, id: \.self) { index in
                OnboardingStep(step: steps[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
    }
}
```

---

## 6. Choreography

### 6.1 Staggered Reveals

```swift
struct StaggeredList<Content: View>: View {
    let items: [Any]
    let content: (Int) -> Content

    var body: some View {
        VStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                content(index)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 20)),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8)
                        .delay(Double(index) * 0.05),
                        value: items.count
                    )
            }
        }
    }
}
```

### 6.2 Orchestrated Sequences

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SESSION LOAD CHOREOGRAPHY                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  0ms        100ms       200ms       300ms       400ms       500ms      │
│   │           │           │           │           │           │        │
│   ▼           ▼           ▼           ▼           ▼           ▼        │
│  ┌───┐                                                                  │
│  │ 1 │ Header slides in                                                 │
│  └───┘────────────────────────────────►                                 │
│              ┌───┐                                                      │
│              │ 2 │ Messages fade in (staggered)                         │
│              └───┘────────────────────────────────────►                 │
│                          ┌───┐                                          │
│                          │ 3 │ Tool cards expand                        │
│                          └───┘────────────────────────►                 │
│                                      ┌───┐                              │
│                                      │ 4 │ Input field appears          │
│                                      └───┘────────────►                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Accessibility

### 7.1 Reduced Motion

```swift
struct MotionAwareView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animated: Content
    let reduced: Content

    var body: some View {
        if reduceMotion {
            reduced
        } else {
            animated
        }
    }
}

// Usage
MotionAwareView(
    animated: AnimatedTransition(),
    reduced: InstantTransition()
)
```

### 7.2 Motion Preferences

```swift
struct MotionSettings: View {
    @AppStorage("motionLevel") var motionLevel = MotionLevel.full

    enum MotionLevel: String, CaseIterable {
        case full = "Full Motion"
        case reduced = "Reduced Motion"
        case minimal = "Minimal Motion"
    }

    var body: some View {
        Picker("Motion", selection: $motionLevel) {
            ForEach(MotionLevel.allCases, id: \.self) { level in
                Text(level.rawValue).tag(level)
            }
        }
    }
}
```

---

## 8. Performance

### 8.1 Animation Best Practices

**Do:**
- Use `drawingGroup()` for complex animations
- Prefer `opacity` and `transform` (GPU-accelerated)
- Use `GeometryEffect` for custom transforms
- Keep animations to 60fps (16.67ms per frame)

**Don't:**
- Animate `frame` or `position` directly
- Use complex shadows during animation
- Chain too many animations together
- Block the main thread during animation

### 8.2 Performance Monitoring

```swift
struct AnimationProfiler: ViewModifier {
    @State private var frameCount = 0
    @State private var startTime: Date?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { _ in
                    Color.clear
                        .preference(key: FrameKey.self, value: Date())
                }
            )
            .onPreferenceChange(FrameKey.self) { date in
                frameCount += 1
                if startTime == nil { startTime = date }

                if let start = startTime {
                    let elapsed = date.timeIntervalSince(start)
                    if elapsed >= 1.0 {
                        let fps = Double(frameCount) / elapsed
                        print("Animation FPS: \(Int(fps))")
                        frameCount = 0
                        startTime = date
                    }
                }
            }
    }
}
```

---

## 9. Implementation Checklist

- [ ] Motion tokens defined in design system
- [ ] All animations use system preference for reduced motion
- [ ] Page transitions implemented
- [ ] Micro-interactions for buttons, toggles, inputs
- [ ] Loading states with skeleton/shimmer
- [ ] Tool card expand/collapse animations
- [ ] Message bubble entrance animations
- [ ] Streaming text with cursor
- [ ] Staggered list reveals
- [ ] Modal presentation/dismissal
- [ ] Command palette animation
- [ ] Error shake feedback
- [ ] Success bounce feedback
- [ ] Performance profiling enabled
