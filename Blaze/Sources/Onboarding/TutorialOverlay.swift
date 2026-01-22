import SwiftUI
import Observation

// MARK: - Tutorial Step

/// Represents each step in the interactive tutorial flow.
public enum TutorialStep: Int, CaseIterable, Identifiable, Sendable {
    case welcome = 0
    case sessionList = 1
    case chatInput = 2
    case fileTree = 3
    case settings = 4
    case complete = 5

    public var id: Int { rawValue }

    /// Human-readable title for the step
    public var title: String {
        switch self {
        case .welcome:
            return "Welcome to Blaze"
        case .sessionList:
            return "Session List"
        case .chatInput:
            return "Chat Input"
        case .fileTree:
            return "File Explorer"
        case .settings:
            return "Settings"
        case .complete:
            return "You're Ready!"
        }
    }

    /// Detailed description for the step
    public var description: String {
        switch self {
        case .welcome:
            return "Blaze gives you a polished desktop experience for agentic coding CLIs. Let's take a quick tour of the interface."
        case .sessionList:
            return "This sidebar shows all your coding sessions. Create new sessions, switch between them, or search through your history."
        case .chatInput:
            return "Type your prompts here to interact with your AI coding assistant. Use natural language to describe what you want to build."
        case .fileTree:
            return "Browse and manage files in your workspace. See what files the AI has created or modified during your session."
        case .settings:
            return "Access settings to configure your CLI preferences, security modes, and customize the interface."
        case .complete:
            return "You're all set to start coding with AI assistance. Have fun building!"
        }
    }

    /// The UI area to highlight for this step
    public var highlightArea: HighlightArea {
        switch self {
        case .welcome:
            return .none
        case .sessionList:
            return .sidebar
        case .chatInput:
            return .inputField
        case .fileTree:
            return .fileTree
        case .settings:
            return .settingsButton
        case .complete:
            return .none
        }
    }

    /// The next step in the sequence, or nil if this is the last step
    public var next: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }

    /// The previous step in the sequence, or nil if this is the first step
    public var previous: TutorialStep? {
        TutorialStep(rawValue: rawValue - 1)
    }

    /// Whether this is the last step
    public var isLast: Bool {
        self == .complete
    }

    /// Step number for display (1-indexed)
    public var stepNumber: Int {
        rawValue + 1
    }

    /// Total number of steps
    public static var totalSteps: Int {
        allCases.count
    }
}

// MARK: - Highlight Area

/// Defines which UI region to highlight during a tutorial step.
public enum HighlightArea: String, CaseIterable, Sendable {
    case none
    case sidebar
    case chatArea
    case inputField
    case fileTree
    case settingsButton

    /// Default frame when no actual frame is captured
    public var defaultFrame: CGRect {
        // These are fallback values; actual frames are captured via PreferenceKey
        switch self {
        case .none:
            return .zero
        case .sidebar:
            return CGRect(x: 0, y: 0, width: 280, height: 600)
        case .chatArea:
            return CGRect(x: 280, y: 0, width: 500, height: 500)
        case .inputField:
            return CGRect(x: 280, y: 520, width: 500, height: 80)
        case .fileTree:
            return CGRect(x: 780, y: 0, width: 280, height: 600)
        case .settingsButton:
            return CGRect(x: 20, y: 560, width: 44, height: 44)
        }
    }
}

// MARK: - Highlight Area Preference Key

/// PreferenceKey for capturing UI element frames for tutorial highlighting.
public struct HighlightAreaPreferenceKey: PreferenceKey {
    public static var defaultValue: [HighlightArea: CGRect] = [:]

    public static func reduce(value: inout [HighlightArea: CGRect], nextValue: () -> [HighlightArea: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Highlight Area Modifier

/// A modifier that reports the frame of a view for tutorial highlighting.
public struct HighlightAreaModifier: ViewModifier {
    let area: HighlightArea
    let coordinateSpace: CoordinateSpace

    public init(area: HighlightArea, coordinateSpace: CoordinateSpace = .global) {
        self.area = area
        self.coordinateSpace = coordinateSpace
    }

    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: HighlightAreaPreferenceKey.self,
                            value: [area: geometry.frame(in: coordinateSpace)]
                        )
                }
            )
    }
}

public extension View {
    /// Mark this view as a highlight area for the tutorial overlay.
    func tutorialHighlight(_ area: HighlightArea, coordinateSpace: CoordinateSpace = .global) -> some View {
        modifier(HighlightAreaModifier(area: area, coordinateSpace: coordinateSpace))
    }
}

// MARK: - Tutorial View Model

/// Observable view model managing tutorial state and navigation.
///
/// Use via `@Environment(TutorialViewModel.self)` in views.
@Observable
public final class TutorialViewModel {
    // MARK: - Persisted State

    /// Whether the user has completed the tutorial.
    @ObservationIgnored
    @AppStorage("hasCompletedTutorial") public var hasCompletedTutorial: Bool = false

    // MARK: - Tutorial State

    /// Current step in the tutorial, or nil if not running.
    public var currentStep: TutorialStep?

    /// Whether the tutorial is currently active.
    public var isActive: Bool {
        currentStep != nil
    }

    /// Captured frames for highlight areas.
    public var highlightFrames: [HighlightArea: CGRect] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation

    /// Start the tutorial from the beginning.
    public func startTutorial() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .welcome
        }
    }

    /// Advance to the next step.
    public func nextStep() {
        guard let current = currentStep else { return }

        if let next = current.next {
            withAnimation(.spring(response: OnboardingAnimation.springResponse, dampingFraction: OnboardingAnimation.springDamping)) {
                currentStep = next
            }
        } else {
            completeTutorial()
        }
    }

    /// Go back to the previous step.
    public func previousStep() {
        guard let current = currentStep, let previous = current.previous else { return }

        withAnimation(.spring(response: OnboardingAnimation.springResponse, dampingFraction: OnboardingAnimation.springDamping)) {
            currentStep = previous
        }
    }

    /// Skip the tutorial entirely.
    public func skipTutorial() {
        hasCompletedTutorial = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nil
        }
    }

    /// Complete the tutorial.
    public func completeTutorial() {
        hasCompletedTutorial = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nil
        }
    }

    /// Reset the tutorial state (for testing or re-running).
    public func reset() {
        hasCompletedTutorial = false
        currentStep = nil
        highlightFrames = [:]
    }

    /// Update captured highlight frame.
    public func updateHighlightFrame(_ area: HighlightArea, frame: CGRect) {
        highlightFrames[area] = frame
    }

    /// Get the frame for the current step's highlight area.
    public var currentHighlightFrame: CGRect {
        guard let step = currentStep else { return .zero }
        let area = step.highlightArea
        return highlightFrames[area] ?? area.defaultFrame
    }
}

// MARK: - Environment Support

public extension EnvironmentValues {
    @Entry var tutorialViewModel: TutorialViewModel = TutorialViewModel()
}

// MARK: - Tutorial Animation Tokens

/// Animation parameters specific to tutorial overlay.
private enum TutorialAnimation {
    static let overlayFadeDuration: Double = 0.25
    static let spotlightDuration: Double = 0.35
    static let tooltipDuration: Double = 0.3
    static let springResponse: Double = 0.4
    static let springDamping: Double = 0.75
    static let spotlightPadding: CGFloat = 12
    static let spotlightCornerRadius: CGFloat = DSRadius.lg
}

// MARK: - Tutorial Overlay View

/// The main tutorial overlay that displays a spotlight and tooltip.
public struct TutorialOverlayView: View {
    @Environment(\.tutorialViewModel) private var viewModel

    public init() {}

    public var body: some View {
        if let step = viewModel.currentStep {
            ZStack {
                // Dark overlay with spotlight cutout
                spotlightOverlay(for: step)

                // Tooltip card
                tooltipCard(for: step)
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: TutorialAnimation.overlayFadeDuration), value: viewModel.isActive)
        }
    }

    // MARK: - Spotlight Overlay

    @ViewBuilder
    private func spotlightOverlay(for step: TutorialStep) -> some View {
        let frame = viewModel.currentHighlightFrame

        GeometryReader { geometry in
            Color.black.opacity(0.7)
                .mask(
                    SpotlightMask(
                        spotlightFrame: frame,
                        containerSize: geometry.size
                    )
                )
                .animation(
                    .spring(response: TutorialAnimation.springResponse, dampingFraction: TutorialAnimation.springDamping),
                    value: frame
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Tooltip Card

    @ViewBuilder
    private func tooltipCard(for step: TutorialStep) -> some View {
        let frame = viewModel.currentHighlightFrame

        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    // Step indicator
                    HStack {
                        Text("Step \(step.stepNumber) of \(TutorialStep.totalSteps)")
                            .dsTextStyle(.caption, color: Color.ds.secondary)

                        Spacer()

                        // Progress dots
                        StepProgressIndicator(
                            currentStep: step.rawValue,
                            totalSteps: TutorialStep.totalSteps
                        )
                    }

                    // Title
                    Text(step.title)
                        .dsTextStyle(.title)

                    // Description
                    Text(step.description)
                        .dsTextStyle(.body, color: Color.ds.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DSSpacing.lg)

                Divider()
                    .background(Color.ds.border)

                // Actions
                HStack(spacing: DSSpacing.md) {
                    // Skip button
                    GlassButton("Skip", style: .ghost, size: .medium) {
                        viewModel.skipTutorial()
                    }

                    Spacer()

                    // Back button (if not first step)
                    if step.previous != nil {
                        GlassButton("Back", style: .secondary, size: .medium) {
                            viewModel.previousStep()
                        }
                    }

                    // Next/Finish button
                    GlassButton(
                        step.isLast ? "Get Started" : "Next",
                        icon: step.isLast ? "checkmark" : "arrow.right",
                        style: .primary,
                        size: .medium
                    ) {
                        viewModel.nextStep()
                    }
                }
                .padding(DSSpacing.md)
            }
            .frame(width: 360)
            .dsGlassPanel(level: .prominent, cornerRadius: DSRadius.xl, elevation: .high)
            .position(tooltipPosition(for: step, highlightFrame: frame, containerSize: geometry.size))
            .animation(
                .spring(response: TutorialAnimation.springResponse, dampingFraction: TutorialAnimation.springDamping),
                value: step
            )
        }
    }

    // MARK: - Tooltip Positioning

    private func tooltipPosition(for step: TutorialStep, highlightFrame: CGRect, containerSize: CGSize) -> CGPoint {
        let tooltipWidth: CGFloat = 360
        let tooltipHeight: CGFloat = 220 // Estimated height
        let margin: CGFloat = DSSpacing.lg

        // For welcome/complete steps (no highlight), center the tooltip
        if step.highlightArea == .none {
            return CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        }

        // Calculate available space around the highlight area
        let spaceRight = containerSize.width - highlightFrame.maxX
        let spaceLeft = highlightFrame.minX
        let spaceBottom = containerSize.height - highlightFrame.maxY
        let spaceTop = highlightFrame.minY

        var x: CGFloat
        var y: CGFloat

        // Prefer positioning to the right of the highlight
        if spaceRight >= tooltipWidth + margin * 2 {
            x = highlightFrame.maxX + margin + tooltipWidth / 2
            y = highlightFrame.midY
        }
        // Try left
        else if spaceLeft >= tooltipWidth + margin * 2 {
            x = highlightFrame.minX - margin - tooltipWidth / 2
            y = highlightFrame.midY
        }
        // Try below
        else if spaceBottom >= tooltipHeight + margin * 2 {
            x = highlightFrame.midX
            y = highlightFrame.maxY + margin + tooltipHeight / 2
        }
        // Try above
        else if spaceTop >= tooltipHeight + margin * 2 {
            x = highlightFrame.midX
            y = highlightFrame.minY - margin - tooltipHeight / 2
        }
        // Fallback: center on screen
        else {
            x = containerSize.width / 2
            y = containerSize.height / 2
        }

        // Clamp to screen bounds
        x = max(tooltipWidth / 2 + margin, min(x, containerSize.width - tooltipWidth / 2 - margin))
        y = max(tooltipHeight / 2 + margin, min(y, containerSize.height - tooltipHeight / 2 - margin))

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Spotlight Mask Shape

/// A shape that creates a "spotlight" cutout effect.
/// Uses CGRect's built-in Animatable conformance for smooth spotlight transitions.
private struct SpotlightMask: Shape {
    var spotlightFrame: CGRect
    let containerSize: CGSize

    // CGRect already conforms to Animatable, so we use its AnimatableData directly
    var animatableData: CGRect.AnimatableData {
        get { spotlightFrame.animatableData }
        set { spotlightFrame.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Full rectangle
        path.addRect(rect)

        // Subtract spotlight area (if valid frame)
        if spotlightFrame.width > 0 && spotlightFrame.height > 0 {
            let paddedFrame = spotlightFrame.insetBy(
                dx: -TutorialAnimation.spotlightPadding,
                dy: -TutorialAnimation.spotlightPadding
            )
            let spotlightPath = RoundedRectangle(
                cornerRadius: TutorialAnimation.spotlightCornerRadius,
                style: .continuous
            )
            .path(in: paddedFrame)

            path.addPath(spotlightPath)
        }

        return path
            .applying(CGAffineTransform.identity)
    }
}

// MARK: - Tutorial Overlay Modifier

/// A modifier that adds the tutorial overlay to a view and captures highlight frames.
public struct TutorialOverlayModifier: ViewModifier {
    @Environment(\.tutorialViewModel) private var viewModel

    public init() {}

    public func body(content: Content) -> some View {
        content
            .overlay {
                TutorialOverlayView()
            }
            .onPreferenceChange(HighlightAreaPreferenceKey.self) { frames in
                for (area, frame) in frames {
                    viewModel.updateHighlightFrame(area, frame: frame)
                }
            }
    }
}

public extension View {
    /// Apply the tutorial overlay to this view.
    func tutorialOverlay() -> some View {
        modifier(TutorialOverlayModifier())
    }
}

// MARK: - Previews

#if DEBUG
struct TutorialOverlay_Previews: PreviewProvider {
    static var previews: some View {
        TutorialPreviewContainer()
            .frame(width: 1200, height: 800)
    }
}

private struct TutorialPreviewContainer: View {
    @State private var tutorialVM = TutorialViewModel()

    var body: some View {
        ZStack {
            // Mock app layout
            HStack(spacing: 0) {
                // Sidebar
                VStack {
                    Text("Sessions")
                        .dsTextStyle(.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    ForEach(1...5, id: \.self) { i in
                        HStack {
                            Circle()
                                .fill(Color.ds.accent)
                                .frame(width: 8, height: 8)
                            Text("Session \(i)")
                                .dsTextStyle(.body)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, DSSpacing.xs)
                    }

                    Spacer()

                    // Settings button
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .dsTextStyle(.body)
                    .padding()
                    .tutorialHighlight(.settingsButton)
                }
                .frame(width: 280)
                .background(Color.ds.bg1)
                .tutorialHighlight(.sidebar)

                Divider()

                // Main content
                VStack {
                    // Chat area
                    ScrollView {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            ForEach(1...3, id: \.self) { _ in
                                Text("Chat message...")
                                    .dsTextStyle(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.ds.surface)
                                    .cornerRadius(DSRadius.md)
                            }
                        }
                        .padding()
                    }
                    .tutorialHighlight(.chatArea)

                    Divider()

                    // Input field
                    HStack {
                        TextField("Type a prompt...", text: .constant(""))
                            .textFieldStyle(.plain)
                            .padding()

                        GlassButton("Send", icon: "arrow.up", action: {})
                            .padding(.trailing)
                    }
                    .background(Color.ds.bg1)
                    .tutorialHighlight(.inputField)
                }
                .frame(maxWidth: .infinity)

                Divider()

                // File tree
                VStack(alignment: .leading) {
                    Text("Files")
                        .dsTextStyle(.title)
                        .padding()

                    ForEach(["src/", "lib/", "tests/"], id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                            Text(folder)
                        }
                        .dsTextStyle(.body)
                        .padding(.horizontal)
                        .padding(.vertical, DSSpacing.xs)
                    }

                    Spacer()
                }
                .frame(width: 280)
                .background(Color.ds.bg1)
                .tutorialHighlight(.fileTree)
            }
            .background(Color.ds.bg0)
        }
        .environment(tutorialVM)
        .tutorialOverlay()
        .onAppear {
            tutorialVM.startTutorial()
        }
    }
}
#endif
