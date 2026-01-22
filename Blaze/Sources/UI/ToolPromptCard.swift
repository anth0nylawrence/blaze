import SwiftUI

// MARK: - Tool Prompt Card

/// A card view for interactive tool prompts (e.g., AskUserQuestion).
/// Displays options for selection or free-text input based on the prompt type.
public struct ToolPromptCard: View {
    let prompt: ToolPromptEvent
    let submissionState: SubmissionState
    let pendingCount: Int
    let onSubmit: (ToolPromptResponse) -> Void
    let onRetry: () -> Void

    // Selection state (for option-based prompts)
    @State private var selectedOptionIds: Set<String> = []

    // Free-text state (for text input prompts)
    @State private var freeTextInput: String = ""

    public init(
        prompt: ToolPromptEvent,
        submissionState: SubmissionState,
        pendingCount: Int = 0,
        onSubmit: @escaping (ToolPromptResponse) -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.submissionState = submissionState
        self.pendingCount = pendingCount
        self.onSubmit = onSubmit
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Header: Title + tool name badge
            headerView

            // Body text
            if let body = prompt.body {
                Text(body)
                    .dsTextStyle(.body, color: .ds.secondary)
            }

            // Content: Options OR Free-text input
            if prompt.requiresFreeText {
                FreeTextInputView(
                    text: $freeTextInput,
                    placeholder: "Enter your response...",
                    isDisabled: isSubmitting || isSubmitted
                )
            } else {
                Text(prompt.responseType == .multiSelect ? "Select one or more." : "Select one.")
                    .dsTextStyle(.caption, color: .ds.tertiary)
                optionsView
            }

            // Footer: Submit / Retry / Status
            footerView

            // Debug expander (developer mode)
            debugDisclosure
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(
            level: .light,
            cornerRadius: DSRadius.lg,
            elevation: .medium,
            border: .subtle
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(Color.ds.info.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: DSSize.md))
                .foregroundStyle(Color.ds.info)

            if let title = prompt.title {
                Text(title)
                    .dsTextStyle(.subtitle)
            }

            Spacer()

            if let index = prompt.promptIndex,
               let count = prompt.promptCount,
               count > 1 {
                Text("Question \(index) of \(count)")
                    .dsTextStyle(.micro, color: .ds.tertiary)
                    .padding(.horizontal, DSSpacing.xs)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(Color.ds.bg1.opacity(0.5))
                    .clipShape(Capsule())
            }

            // Tool name badge
            Text(prompt.toolName)
                .dsTextStyle(.micro, color: .ds.tertiary)
                .padding(.horizontal, DSSpacing.xs)
                .padding(.vertical, DSSpacing.xxs)
                .background(Color.ds.bg1.opacity(0.5))
                .clipShape(Capsule())
        }
    }

    // MARK: - Options

    private var optionsView: some View {
        VStack(spacing: DSSpacing.xs) {
            ForEach(prompt.options) { option in
                OptionRow(
                    option: option,
                    isSelected: selectedOptionIds.contains(option.id),
                    isMultiSelect: prompt.responseType == .multiSelect,
                    isDisabled: isSubmitting || isSubmitted,
                    onToggle: { toggleOption(option) }
                )
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Queue indicator
            if pendingCount > 1 {
                Text("\(pendingCount - 1) more pending")
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }

            Spacer()

            switch submissionState {
            case .idle:
                GlassButton("Submit", icon: "paperplane.fill", style: .primary, size: .small) {
                    submit()
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1.0 : 0.5)

            case .submitting:
                HStack(spacing: DSSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Sending...")
                        .dsTextStyle(.caption, color: .ds.secondary)
                }

            case .submitted:
                Label("Submitted", systemImage: "checkmark.circle.fill")
                    .dsTextStyle(.caption, color: .ds.positive)

            case .failed(let message):
                VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                    GlassButton("Retry", icon: "arrow.clockwise", style: .secondary, size: .small) {
                        onRetry()
                    }
                    Text(message)
                        .dsTextStyle(.micro, color: .ds.negative)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Debug Disclosure

    private var debugDisclosure: some View {
        DisclosureGroup {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(prompt.rawInput)
                    .dsTextStyle(.monoSmall, color: .ds.tertiary)
                    .textSelection(.enabled)
                    .padding(DSSpacing.xs)
            }
            .frame(maxHeight: 100)
            .background(Color.ds.bg0.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        } label: {
            Label("Raw Input", systemImage: "chevron.left.forwardslash.chevron.right")
                .dsTextStyle(.caption, color: .ds.tertiary)
        }
        .tint(Color.ds.tertiary)
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        if prompt.requiresFreeText {
            return !freeTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !selectedOptionIds.isEmpty
        }
    }

    private var isSubmitting: Bool {
        if case .submitting = submissionState { return true }
        return false
    }

    private var isSubmitted: Bool {
        if case .submitted = submissionState { return true }
        return false
    }

    private func toggleOption(_ option: ToolPromptOption) {
        guard !isSubmitting && !isSubmitted else { return }

        if prompt.responseType == .multiSelect {
            if selectedOptionIds.contains(option.id) {
                selectedOptionIds.remove(option.id)
            } else {
                selectedOptionIds.insert(option.id)
            }
        } else {
            // Single select - clear others
            selectedOptionIds = [option.id]
        }
    }

    private func submit() {
        let response: ToolPromptResponse
        if prompt.requiresFreeText {
            response = .freeText(freeTextInput.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            let selections = prompt.options
                .filter { selectedOptionIds.contains($0.id) }
                .map { ToolPromptSelection(id: $0.id, label: $0.label) }
            response = .selections(selections)
        }
        onSubmit(response)
    }
}

// MARK: - Option Row

/// A single option row with radio button or checkbox styling.
struct OptionRow: View {
    let option: ToolPromptOption
    let isSelected: Bool
    let isMultiSelect: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DSSpacing.sm) {
                // Selection indicator
                Image(systemName: selectionIcon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(isSelected ? Color.ds.accent : Color.ds.secondary)

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(option.label)
                        .dsTextStyle(.body)

                    if let desc = option.description {
                        Text(desc)
                            .dsTextStyle(.caption, color: .ds.tertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(isSelected ? Color.ds.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .onHover { isHovered = $0 }
    }

    private var selectionIcon: String {
        if isMultiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        } else {
            return isSelected ? "largecircle.fill.circle" : "circle"
        }
    }

    private var background: Color {
        if isSelected {
            return Color.ds.accent.opacity(0.12)
        } else if isHovered && !isDisabled {
            return Color.ds.foreground.opacity(0.05)
        }
        return Color.clear
    }
}

// MARK: - Free Text Input View

/// A text editor for free-text responses (used for unknown tools or empty options).
struct FreeTextInputView: View {
    @Binding var text: String
    let placeholder: String
    let isDisabled: Bool

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Enter your response...",
        isDisabled: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isDisabled = isDisabled
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .dsTextStyle(.mono)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .disabled(isDisabled)

            // Placeholder
            if text.isEmpty && !isFocused {
                Text(placeholder)
                    .dsTextStyle(.body, color: .ds.placeholder)
                    .padding(.leading, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 80, maxHeight: 200)
        .padding(DSSpacing.xs)
        .background(Color.ds.bg0.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(isFocused ? Color.ds.accent.opacity(0.5) : Color.ds.border.opacity(0.5), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tool Prompt Card - Single Select") {
    let prompt = ToolPromptEvent(
        toolUseId: "toolu_123",
        toolName: "AskUserQuestion",
        title: "Which approach do you prefer?",
        body: "Please select one option to continue with the implementation.",
        options: [
            ToolPromptOption(id: "option_a", label: "Quick Implementation", description: "Fast but minimal features"),
            ToolPromptOption(id: "option_b", label: "Thorough Implementation", description: "Complete features with full test coverage"),
            ToolPromptOption(id: "option_c", label: "Iterative Approach", description: "Start simple and expand over time")
        ],
        responseType: .singleSelect,
        rawInput: "{\"questions\":[{\"question\":\"Which approach?\",\"options\":[...]}]}",
        timestamp: Date()
    )

    VStack(spacing: DSSpacing.lg) {
        ToolPromptCard(
            prompt: prompt,
            submissionState: .idle,
            pendingCount: 3,
            onSubmit: { response in
                print("Submitted: \(response)")
            },
            onRetry: {}
        )
        .frame(width: 500)
    }
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}

#Preview("Tool Prompt Card - Multi Select") {
    let prompt = ToolPromptEvent(
        toolUseId: "toolu_456",
        toolName: "AskUserQuestion",
        title: "Which features should we include?",
        body: "Select all that apply.",
        options: [
            ToolPromptOption(id: "feat_auth", label: "Authentication", description: "User login and session management"),
            ToolPromptOption(id: "feat_api", label: "REST API", description: "RESTful endpoints for data access"),
            ToolPromptOption(id: "feat_ws", label: "WebSocket", description: "Real-time bidirectional communication")
        ],
        responseType: .multiSelect,
        rawInput: "{}",
        timestamp: Date()
    )

    ToolPromptCard(
        prompt: prompt,
        submissionState: .idle,
        onSubmit: { _ in },
        onRetry: {}
    )
    .frame(width: 500)
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}

#Preview("Tool Prompt Card - Free Text") {
    let prompt = ToolPromptEvent(
        toolUseId: "toolu_789",
        toolName: "UnknownTool",
        title: "Provide your input",
        body: "This tool requires free-text input.",
        options: [],
        responseType: .freeText,
        rawInput: "{\"prompt\":\"Enter something\"}",
        timestamp: Date()
    )

    ToolPromptCard(
        prompt: prompt,
        submissionState: .idle,
        onSubmit: { _ in },
        onRetry: {}
    )
    .frame(width: 500)
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}

#Preview("Tool Prompt Card - States") {
    let prompt = ToolPromptEvent(
        toolUseId: "toolu_states",
        toolName: "AskUserQuestion",
        title: "Test state",
        body: nil,
        options: [
            ToolPromptOption(id: "yes", label: "Yes", description: nil),
            ToolPromptOption(id: "no", label: "No", description: nil)
        ],
        responseType: .singleSelect,
        rawInput: "{}",
        timestamp: Date()
    )

    VStack(spacing: DSSpacing.lg) {
        // Submitting state
        ToolPromptCard(
            prompt: prompt,
            submissionState: .submitting,
            onSubmit: { _ in },
            onRetry: {}
        )

        // Submitted state
        ToolPromptCard(
            prompt: prompt,
            submissionState: .submitted,
            onSubmit: { _ in },
            onRetry: {}
        )

        // Failed state
        ToolPromptCard(
            prompt: prompt,
            submissionState: .failed("Connection timeout after 30s"),
            onSubmit: { _ in },
            onRetry: {}
        )
    }
    .frame(width: 500)
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}
#endif
