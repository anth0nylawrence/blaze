//
//  UserProfileView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - User Profile View

/// Onboarding step for collecting user profile information.
/// Displays name field, experience level selection, and primary use case selection.
public struct UserProfileView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    public init() {}

    public var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.sm) {
                Text("Tell us about yourself")
                    .dsTextStyle(.hero)

                Text("This helps us personalize your experience")
                    .dsTextStyle(.body, color: .ds.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, DSSpacing.lg)

            // Form content
            VStack(spacing: DSSpacing.lg) {
                // Display name field
                FormSection(title: "Display Name") {
                    GlassTextField(
                        "What should we call you?",
                        text: $vm.displayName,
                        icon: "person.fill"
                    )
                }

                // Experience level selection
                FormSection(
                    title: "Experience Level",
                    description: "How familiar are you with AI coding assistants?"
                ) {
                    VStack(spacing: DSSpacing.sm) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            ExperienceLevelRow(
                                level: level,
                                isSelected: vm.experienceLevel == level
                            ) {
                                vm.experienceLevel = level
                            }
                        }
                    }
                }

                // Primary use case selection
                FormSection(
                    title: "Primary Use Case",
                    description: "What will you mainly use Blaze for?"
                ) {
                    UseCaseGrid(
                        selection: $vm.primaryUseCase
                    )
                }
            }
            .frame(maxWidth: 480)

            Spacer()

            // Navigation buttons
            HStack(spacing: DSSpacing.md) {
                GlassButton("Back", icon: "chevron.left", style: .ghost, size: .medium) {
                    viewModel.goBack()
                }

                Spacer()

                GlassButton("Continue", icon: "arrow.right", style: .primary, size: .large) {
                    viewModel.goForward()
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)
        }
        .padding(.horizontal, DSSpacing.xl)
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.ds.bg0)
    }
}

// MARK: - Experience Level Row

/// A selectable row displaying an experience level option.
private struct ExperienceLevelRow: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var icon: String {
        switch level {
        case .beginner: return "leaf.fill"
        case .intermediate: return "gearshape.2.fill"
        case .advanced: return "bolt.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DSSize.md))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.ds.secondary)
                    .frame(width: DSSize.lg, height: DSSize.lg)
                    .dsGlassPanel(
                        level: .subtle,
                        cornerRadius: DSRadius.sm,
                        elevation: isSelected ? .low : .none
                    )

                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(level.displayName)
                        .dsTextStyle(.subtitle, color: isSelected ? .ds.foreground : .ds.secondary)

                    Text(level.description)
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DSSize.md))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.lg,
                elevation: isSelected ? .medium : (isHovered ? .low : .none),
                border: isSelected ? .layered : .subtle,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Use Case Grid

/// A grid of selectable use case options.
private struct UseCaseGrid: View {
    @Binding var selection: PrimaryUseCase

    let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
            ForEach(PrimaryUseCase.allCases, id: \.self) { useCase in
                UseCaseCard(
                    useCase: useCase,
                    isSelected: selection == useCase
                ) {
                    selection = useCase
                }
            }
        }
    }
}

// MARK: - Use Case Card

/// A card displaying a single use case option.
private struct UseCaseCard: View {
    let useCase: PrimaryUseCase
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var icon: String {
        switch useCase {
        case .personal: return "house.fill"
        case .professional: return "briefcase.fill"
        case .learning: return "book.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DSSize.lg))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.ds.secondary)

                Text(useCase.displayName)
                    .dsTextStyle(.caption, color: isSelected ? .ds.foreground : .ds.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .padding(.horizontal, DSSpacing.sm)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.lg,
                elevation: isSelected ? .medium : (isHovered ? .low : .none),
                border: isSelected ? .layered : .subtle,
                isInteractive: true
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DSSize.sm))
                        .foregroundStyle(Color.accentColor)
                        .padding(DSSpacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("User Profile View") {
    UserProfileView()
        .environment(OnboardingViewModel())
        .frame(width: 700, height: 600)
}
#endif
