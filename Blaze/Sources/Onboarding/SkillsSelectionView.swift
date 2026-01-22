//
//  SkillsSelectionView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Skill Category

/// Categories for filtering registry skills.
public enum SkillCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case productivity = "Productivity"
    case git = "Git"
    case testing = "Testing"
    case documentation = "Documentation"
    case security = "Security"
    case debugging = "Debugging"
    case refactoring = "Refactoring"
    case other = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .productivity: return "bolt.fill"
        case .git: return "arrow.triangle.branch"
        case .testing: return "checkmark.seal.fill"
        case .documentation: return "doc.text.fill"
        case .security: return "lock.shield.fill"
        case .debugging: return "ant.fill"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Skills Selection View

/// Registry skills selection view for onboarding.
/// Displays skills in a searchable, filterable grid with CLI compatibility badges.
public struct SkillsSelectionView: View {
    // MARK: - State

    @State private var searchText: String = ""
    @State private var selectedCategory: SkillCategory = .all
    @Binding var selectedSkills: Set<String>

    /// Available skills from registry (passed in or fetched)
    let skills: [SkillItem]

    /// Loading state
    let isLoading: Bool

    /// Error message if fetch failed
    let errorMessage: String?

    /// Retry action for error state
    let onRetry: (() -> Void)?

    // MARK: - Layout

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 350), spacing: DSSpacing.md)
    ]

    // MARK: - Init

    public init(
        skills: [SkillItem],
        selectedSkills: Binding<Set<String>>,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.skills = skills
        self._selectedSkills = selectedSkills
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Header
            headerView
                .onboardingFadeIn(delay: 0)

            // Search and filter bar
            filterBar
                .onboardingFadeIn(delay: OnboardingAnimation.staggerDelay)

            // Content area
            contentView
                .onboardingFadeIn(delay: OnboardingAnimation.staggerDelay * 2)

            Spacer()
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("Community Skills")
                .dsTextStyle(.hero)

            Text("Extend your workflow with community-created skills. Select the ones you'd like to install.")
                .dsTextStyle(.body, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: DSSpacing.md) {
            // Search field
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.ds.secondary)
                    .font(.system(size: DSSize.sm))

                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
                    .dsTextStyle(.body)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.ds.tertiary)
                            .font(.system(size: DSSize.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(Color.ds.surface)
            .cornerRadius(DSRadius.md)
            .frame(maxWidth: 300)

            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(SkillCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Spacer()

            // Selection count
            if !selectedSkills.isEmpty {
                Text("\(selectedSkills.count) selected")
                    .dsTextStyle(.caption, color: .ds.accent)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xxs)
                    .background(Color.ds.accent.opacity(0.1))
                    .cornerRadius(DSRadius.sm)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(message: error)
        } else if filteredSkills.isEmpty {
            emptyStateView
        } else {
            skillsGridView
        }
    }

    private var loadingView: some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading community skills...")
                .dsTextStyle(.body, color: .ds.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.warning)

            Text("Failed to load skills")
                .dsTextStyle(.subtitle)

            Text(message)
                .dsTextStyle(.caption, color: .ds.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if let retry = onRetry {
                GlassButton("Retry", icon: "arrow.clockwise", style: .secondary, size: .medium) {
                    retry()
                }
                .padding(.top, DSSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    private var emptyStateView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.ds.secondary)

            Text("No skills found")
                .dsTextStyle(.subtitle)

            if !searchText.isEmpty || selectedCategory != .all {
                Text("Try adjusting your search or filters")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Button("Clear filters") {
                    searchText = ""
                    selectedCategory = .all
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ds.accent)
                .padding(.top, DSSpacing.xs)
            } else {
                Text("No community skills available yet.")
                    .dsTextStyle(.caption, color: .ds.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
    }

    private var skillsGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(filteredSkills) { skill in
                    SkillCard(
                        skill: skill,
                        isSelected: selectedSkills.contains(skill.id),
                        onToggle: { toggleSkill(skill.id) }
                    )
                }
            }
            .padding(.vertical, DSSpacing.md)
        }
    }

    // MARK: - Computed Properties

    private var filteredSkills: [SkillItem] {
        skills.filter { skill in
            // Category filter
            let categoryMatch = selectedCategory == .all ||
                skill.category.lowercased() == selectedCategory.rawValue.lowercased()

            // Search filter
            let searchMatch = searchText.isEmpty ||
                skill.name.localizedCaseInsensitiveContains(searchText) ||
                skill.description.localizedCaseInsensitiveContains(searchText) ||
                skill.author.localizedCaseInsensitiveContains(searchText)

            return categoryMatch && searchMatch
        }
    }

    // MARK: - Actions

    private func toggleSkill(_ skillId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedSkills.contains(skillId) {
                selectedSkills.remove(skillId)
            } else {
                selectedSkills.insert(skillId)
            }
        }
    }
}

// MARK: - Skill Card

/// A card displaying a registry skill with CLI compatibility badges.
private struct SkillCard: View {
    let skill: SkillItem
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                // Header row: name + checkbox
                HStack {
                    Text(skill.name)
                        .dsTextStyle(.subtitle, weight: .semibold)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: DSSize.md))
                        .foregroundStyle(isSelected ? Color.ds.positive : Color.ds.tertiary)
                }

                // Description (truncated)
                Text(skill.description)
                    .dsTextStyle(.caption, color: .ds.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .top)

                // Author
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                    Text(skill.author)
                        .lineLimit(1)
                }
                .dsTextStyle(.caption, color: .ds.tertiary)

                // CLI compatibility badges
                HStack(spacing: DSSpacing.xs) {
                    ForEach(skill.compatibleCLIs, id: \.self) { cli in
                        CLIBadge(cli: cli)
                    }
                    Spacer()
                }
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.lg,
                elevation: isSelected ? .medium : (isHovered ? .low : .none),
                border: isSelected ? .layered : .subtle,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(skill.name) by \(skill.author)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
    }
}

// MARK: - CLI Badge

/// A badge showing CLI compatibility with checkmark.
private struct CLIBadge: View {
    let cli: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
            Text(displayName)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var displayName: String {
        switch cli.lowercased() {
        case "claude": return "Claude"
        case "gemini": return "Gemini"
        case "codex": return "Codex"
        default: return cli
        }
    }

    private var badgeColor: Color {
        switch cli.lowercased() {
        case "claude": return Color.ds.accent
        case "gemini": return Color.blue
        case "codex": return Color.green
        default: return Color.ds.secondary
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Skills Selection - With Data") {
    @Previewable @State var selected: Set<String> = ["commit", "review-pr"]

    SkillsSelectionView(
        skills: [
            SkillItem(
                id: "commit",
                name: "Smart Commit",
                description: "Generate intelligent commit messages based on your staged changes with conventional commit format.",
                author: "cogit0",
                version: "1.2.0",
                category: "Git",
                compatibleCLIs: ["claude", "gemini"],
                permissions: .none
            ),
            SkillItem(
                id: "review-pr",
                name: "PR Review",
                description: "Automated pull request review with security scanning and code quality checks.",
                author: "community",
                version: "2.0.1",
                category: "Git",
                compatibleCLIs: ["claude"],
                permissions: .none
            ),
            SkillItem(
                id: "tdd",
                name: "TDD Workflow",
                description: "Test-driven development workflow with automatic test generation and validation.",
                author: "devtools",
                version: "1.0.0",
                category: "Testing",
                compatibleCLIs: ["claude", "gemini", "codex"],
                permissions: .none
            ),
            SkillItem(
                id: "docs",
                name: "Auto Documentation",
                description: "Generate and maintain documentation from code comments and structure.",
                author: "docgen",
                version: "0.9.0",
                category: "Documentation",
                compatibleCLIs: ["claude"],
                permissions: .none
            )
        ],
        selectedSkills: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Skills Selection - Loading") {
    @Previewable @State var selected: Set<String> = []

    SkillsSelectionView(
        skills: [],
        selectedSkills: $selected,
        isLoading: true
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Skills Selection - Error") {
    @Previewable @State var selected: Set<String> = []

    SkillsSelectionView(
        skills: [],
        selectedSkills: $selected,
        errorMessage: "Unable to connect to the registry. Please check your network connection.",
        onRetry: { print("Retry tapped") }
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Skills Selection - Empty") {
    @Previewable @State var selected: Set<String> = []

    SkillsSelectionView(
        skills: [],
        selectedSkills: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
}

#Preview("Skills Selection - Dark") {
    @Previewable @State var selected: Set<String> = ["commit"]

    SkillsSelectionView(
        skills: [
            SkillItem(
                id: "commit",
                name: "Smart Commit",
                description: "Generate intelligent commit messages based on your staged changes.",
                author: "cogit0",
                version: "1.2.0",
                category: "Git",
                compatibleCLIs: ["claude", "gemini"],
                permissions: .none
            )
        ],
        selectedSkills: $selected
    )
    .frame(width: 800, height: 700)
    .background(Color.ds.bg0)
    .environment(\.colorScheme, .dark)
}
#endif
