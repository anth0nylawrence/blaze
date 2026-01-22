import SwiftUI

// MARK: - Tutorial Step Content Router

/// Routes to the appropriate content view for each tutorial step.
public struct TutorialStepContent: View {
    let step: TutorialStep

    public init(step: TutorialStep) {
        self.step = step
    }

    public var body: some View {
        switch step {
        case .welcome:
            WelcomeTutorialContent()
        case .sessionList:
            SessionListTutorialContent()
        case .chatInput:
            ChatInputTutorialContent()
        case .fileTree:
            FileTreeTutorialContent()
        case .settings:
            SettingsTutorialContent()
        case .complete:
            CompleteTutorialContent()
        }
    }
}

// MARK: - Welcome Content

/// Welcome step: Overview of what users will learn in the tutorial.
struct WelcomeTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Hero icon
            TutorialIconBadge(
                icon: "sparkles",
                color: Color.ds.accent
            )
            .onboardingFadeIn(delay: 0.05)

            // What you'll learn
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "sidebar.left",
                    text: "Organize your AI coding sessions"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "text.bubble",
                    text: "Chat with your coding assistant"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "folder",
                    text: "Explore files in your workspace"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            // Estimated time
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.ds.tertiary)
                Text("Takes about 1 minute")
                    .dsTextStyle(.caption, color: Color.ds.tertiary)
            }
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - Session List Content

/// Session list step: Explains session management.
struct SessionListTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TutorialIconBadge(
                icon: "sidebar.left",
                color: .blue
            )
            .onboardingFadeIn(delay: 0.05)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "plus.circle",
                    text: "Create new sessions for different projects"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "arrow.left.arrow.right",
                    text: "Switch between sessions instantly"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "magnifyingglass",
                    text: "Search through your session history"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            // Tip callout
            TutorialTip(
                text: "Each session remembers your conversation context"
            )
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - Chat Input Content

/// Chat input step: Explains prompt interaction.
struct ChatInputTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TutorialIconBadge(
                icon: "text.bubble",
                color: .green
            )
            .onboardingFadeIn(delay: 0.05)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "character.cursor.ibeam",
                    text: "Type natural language prompts"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "at",
                    text: "Use @file to reference specific files"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "command",
                    text: "Press Return to send, Shift+Return for newlines"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            // Keyboard shortcuts hint
            TutorialKeyboardHint(
                keys: ["Return"],
                action: "Send message"
            )
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - File Tree Content

/// File tree step: Explains workspace file navigation.
struct FileTreeTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TutorialIconBadge(
                icon: "folder",
                color: .orange
            )
            .onboardingFadeIn(delay: 0.05)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "eye",
                    text: "Browse files in your project"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "cursorarrow.and.square.on.square.dashed",
                    text: "Drag files into chat to reference them"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "doc.text.magnifyingglass",
                    text: "Click to preview, double-click to open"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            TutorialTip(
                text: "Modified files show a badge indicator"
            )
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - Settings Content

/// Settings step: Explains configuration options.
struct SettingsTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TutorialIconBadge(
                icon: "gear",
                color: .purple
            )
            .onboardingFadeIn(delay: 0.05)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "terminal",
                    text: "Configure your preferred CLI"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "shield.checkered",
                    text: "Set security mode and permissions"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "paintpalette",
                    text: "Customize themes and appearance"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            TutorialKeyboardHint(
                keys: ["Cmd", ","],
                action: "Open Settings"
            )
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - Completion Content

/// Completion step: Congratulates user and provides next steps.
struct CompleteTutorialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Celebration icon
            TutorialIconBadge(
                icon: "checkmark.seal.fill",
                color: Color.ds.positive
            )
            .onboardingFadeIn(delay: 0.05)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TutorialBullet(
                    icon: "arrow.right.circle",
                    text: "Start your first coding session"
                )
                .onboardingFadeIn(delay: 0.1)

                TutorialBullet(
                    icon: "book",
                    text: "Check Help menu for documentation"
                )
                .onboardingFadeIn(delay: 0.15)

                TutorialBullet(
                    icon: "arrow.counterclockwise",
                    text: "Replay this tutorial from Settings"
                )
                .onboardingFadeIn(delay: 0.2)
            }

            // Fun encouragement
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(Color.ds.accent)
                Text("Happy coding!")
                    .dsTextStyle(.caption, color: Color.ds.secondary)
                    .italic()
            }
            .onboardingFadeIn(delay: 0.25)
        }
    }
}

// MARK: - Reusable Components

/// A prominent icon badge for tutorial step headers.
struct TutorialIconBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: DSSize.lg, weight: .medium))
            .foregroundStyle(color)
            .frame(width: DSSize.xxl, height: DSSize.xxl)
            .background(
                Circle()
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Circle()
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
    }
}

/// A bullet point with icon and text for tutorial content.
struct TutorialBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DSSize.xs))
                .foregroundStyle(Color.ds.accent)
                .frame(width: DSSize.sm)

            Text(text)
                .dsTextStyle(.body, color: Color.ds.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A tip callout box for extra context.
struct TutorialTip: View {
    let text: String

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "lightbulb")
                .font(.system(size: DSSize.xs))
                .foregroundStyle(Color.ds.warning)

            Text(text)
                .dsTextStyle(.caption, color: Color.ds.secondary)
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .fill(Color.ds.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(Color.ds.warning.opacity(0.2), lineWidth: 1)
        )
    }
}

/// A keyboard shortcut hint display.
struct TutorialKeyboardHint: View {
    let keys: [String]
    let action: String

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xxs) {
                ForEach(keys, id: \.self) { key in
                    KeyCapView(key: key)
                }
            }

            Text(action)
                .dsTextStyle(.caption, color: Color.ds.secondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// A single keyboard key cap representation.
struct KeyCapView: View {
    let key: String

    var body: some View {
        Text(key)
            .dsTextStyle(.caption, weight: .medium)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .fill(Color.ds.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
                    .strokeBorder(Color.ds.border, lineWidth: 1)
            )
    }
}

// MARK: - Previews

#if DEBUG
struct TutorialStepViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DSSpacing.xl) {
            Group {
                Text("Welcome")
                    .dsTextStyle(.title)
                WelcomeTutorialContent()
            }

            Divider()

            Group {
                Text("Session List")
                    .dsTextStyle(.title)
                SessionListTutorialContent()
            }
        }
        .padding(DSSpacing.lg)
        .frame(width: 360)
        .background(Color.ds.bg0)
    }
}

struct TutorialStepViews_AllSteps_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xxl) {
                ForEach(TutorialStep.allCases) { step in
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text(step.title)
                            .dsTextStyle(.title)

                        TutorialStepContent(step: step)
                    }
                    .padding(DSSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DSRadius.lg)
                            .fill(Color.ds.panel)
                    )
                }
            }
            .padding(DSSpacing.lg)
        }
        .frame(width: 400, height: 800)
        .background(Color.ds.bg0)
    }
}
#endif
