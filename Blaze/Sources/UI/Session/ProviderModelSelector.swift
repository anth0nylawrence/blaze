import SwiftUI

// NOTE: ModelTier is defined in Core/ModelTier.swift
// Using that definition for consistency across the codebase.

// MARK: - Extended Model Info

/// Extended model information with tier and context window.
/// Per E005-F001-S001-T004-A001 specification.
public struct ExtendedModelInfo: Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let tier: ModelTier
    public let contextWindow: Int
    public let description: String
    public let isDefault: Bool

    public init(
        id: String,
        displayName: String,
        tier: ModelTier,
        contextWindow: Int,
        description: String = "",
        isDefault: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.tier = tier
        self.contextWindow = contextWindow
        self.description = description
        self.isDefault = isDefault
    }

    /// Formatted context window display (e.g., "200K")
    public var contextWindowDisplay: String {
        if contextWindow >= 1_000_000 {
            return "\(contextWindow / 1_000_000)M"
        } else if contextWindow >= 1_000 {
            return "\(contextWindow / 1_000)K"
        }
        return "\(contextWindow)"
    }

    /// Label for picker with tier indicator
    public var pickerLabel: String {
        isDefault ? "\(displayName) (Default)" : displayName
    }
}

// MARK: - Extended Model Registry

/// Registry of models with extended metadata (tier, context window).
/// Per E005-F001-S001-T004-A001 specification.
public enum ExtendedModelRegistry {

    /// Get all models for an engine type
    public static func models(for engine: EngineType) -> [ExtendedModelInfo] {
        switch engine {
        case .claude: return claudeModels
        case .gemini: return geminiModels
        case .codex: return codexModels
        }
    }

    /// Get the default model for an engine type
    public static func defaultModel(for engine: EngineType) -> ExtendedModelInfo {
        models(for: engine).first { $0.isDefault } ?? models(for: engine)[0]
    }

    /// Filter models by tier
    public static func models(for engine: EngineType, tier: ModelTier) -> [ExtendedModelInfo] {
        models(for: engine).filter { $0.tier == tier }
    }

    // MARK: - Model Lists

    private static let claudeModels: [ExtendedModelInfo] = [
        ExtendedModelInfo(
            id: "opus",
            displayName: "Claude Opus 4.5",
            tier: .flagship,
            contextWindow: 200_000,
            description: "Most capable model for complex tasks",
            isDefault: true
        ),
        ExtendedModelInfo(
            id: "sonnet",
            displayName: "Claude Sonnet 4.5",
            tier: .balanced,
            contextWindow: 200_000,
            description: "Balanced performance and speed"
        ),
        ExtendedModelInfo(
            id: "haiku",
            displayName: "Claude Haiku 4.5",
            tier: .fast,
            contextWindow: 200_000,
            description: "Fastest response times"
        )
    ]

    private static let geminiModels: [ExtendedModelInfo] = [
        ExtendedModelInfo(
            id: "gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro",
            tier: .flagship,
            contextWindow: 1_000_000,
            description: "Most capable with 1M context",
            isDefault: true
        ),
        ExtendedModelInfo(
            id: "gemini-2.5-flash",
            displayName: "Gemini 2.5 Flash",
            tier: .fast,
            contextWindow: 1_000_000,
            description: "Fast with large context"
        )
    ]

    private static let codexModels: [ExtendedModelInfo] = [
        ExtendedModelInfo(
            id: "gpt-5.2-extra-high",
            displayName: "GPT 5.2 Extra High",
            tier: .flagship,
            contextWindow: 128_000,
            description: "Maximum capability mode"
        ),
        ExtendedModelInfo(
            id: "gpt-5.2-high",
            displayName: "GPT 5.2 High",
            tier: .balanced,
            contextWindow: 128_000,
            description: "Balanced reasoning and speed",
            isDefault: true
        ),
        ExtendedModelInfo(
            id: "gpt-5.2-medium",
            displayName: "GPT 5.2 Medium",
            tier: .fast,
            contextWindow: 128_000,
            description: "Faster responses"
        )
    ]
}

// MARK: - Tier Badge

/// A badge displaying the model tier with icon and color.
/// Per E005-F001-S001-T004-A001 specification.
public struct TierBadge: View {
    let tier: ModelTier
    let size: TierBadgeSize

    public enum TierBadgeSize {
        case small
        case medium

        var iconSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 11
            }
        }

        var textSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 4
            }
        }
    }

    public init(tier: ModelTier, size: TierBadgeSize = .small) {
        self.tier = tier
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: tier.icon)
                .font(.system(size: size.iconSize, weight: .semibold))
            Text(tier.displayName)
                .font(.system(size: size.textSize, weight: .medium))
        }
        .foregroundStyle(tier.color)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(tier.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - CLI Status Badge

/// Badge showing CLI installation status.
/// Per E005-F001-S001-T004-A001 specification.
public struct CLIStatusBadge: View {
    let engine: EngineType
    @State private var isInstalled: Bool?

    public init(engine: EngineType) {
        self.engine = engine
    }

    public var body: some View {
        Group {
            if let installed = isInstalled {
                if installed {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("CLI Installed")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.ds.positive)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("CLI Not Found")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.ds.warning)
                    .help("Install \(engine.cliCommand) CLI for full functionality")
                }
            } else {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
        .task(id: engine) {
            await checkCLIStatus()
        }
    }

    private func checkCLIStatus() async {
        isInstalled = nil
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [engine.cliCommand]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            isInstalled = process.terminationStatus == 0
        } catch {
            isInstalled = false
        }
    }
}

// MARK: - Extended Model Row View

/// A single model row with radio button, name, tier badge, and metadata.
/// Per E005-F001-S001-T004-A001 specification.
public struct ExtendedModelRowView: View {
    let model: ExtendedModelInfo
    let engine: EngineType
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var accentColor: Color {
        switch engine {
        case .claude: return Color(red: 0.85, green: 0.55, blue: 0.35)
        case .gemini: return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .codex: return Color(red: 0.0, green: 0.65, blue: 0.52)
        }
    }

    public init(model: ExtendedModelInfo, engine: EngineType, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.model = model
        self.engine = engine
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DSSpacing.sm) {
                // Radio button
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? accentColor : Color.ds.tertiary)

                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(model.displayName)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Color.ds.foreground)

                        TierBadge(tier: model.tier)

                        if model.isDefault {
                            Text("Default")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.ds.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.ds.surface)
                                .clipShape(Capsule())
                        }
                    }

                    if !model.description.isEmpty {
                        Text(model.description)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.ds.tertiary)
                    }
                }

                Spacer()

                // Context window
                VStack(alignment: .trailing, spacing: 1) {
                    Text(model.contextWindowDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.ds.secondary)
                    Text("context")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.ds.tertiary)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(isSelected ? accentColor.opacity(0.1) :
                          (isHovered ? Color.ds.surface.opacity(0.5) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(model.displayName), \(model.tier.displayName) tier, \(model.contextWindowDisplay) context window")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Provider Model Selector

/// Combined picker for AI provider (Claude, Gemini, Codex) and model selection.
///
/// **E005-F001-S001-T004-A001 Implementation:**
/// - Segmented provider picker shows all available engine types
/// - Model list dynamically updates based on selected provider
/// - Tier badges (flagship/balanced/fast) on each model
/// - Filter models by tier
/// - Context window metadata displayed
/// - CLI availability detection with status badge
/// - Defaults to Claude with Opus model
struct ProviderModelSelector: View {
    @Binding var selectedProvider: EngineType
    @Binding var selectedModelId: String

    /// Whether to show the compact inline style or the full section style
    var isCompact: Bool = false

    /// Whether to use extended model display with tier badges and context
    var useExtendedDisplay: Bool = true

    @State private var tierFilter: ModelTier?

    // MARK: - Body

    var body: some View {
        if isCompact {
            compactLayout
        } else if useExtendedDisplay {
            extendedLayout
        } else {
            fullLayout
        }
    }

    // MARK: - Layouts

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            providerSection
            modelSection
        }
    }

    private var extendedLayout: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            extendedProviderSection
            extendedModelSection
        }
    }

    private var compactLayout: some View {
        HStack(spacing: DSSpacing.lg) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Provider")
                    .dsTextStyle(.caption, color: .ds.secondary)
                providerPicker
            }

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Model")
                    .dsTextStyle(.caption, color: .ds.secondary)
                modelPicker
            }
        }
    }

    // MARK: - Extended Sections

    private var extendedProviderSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Label("Provider", systemImage: "building.2")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                CLIStatusBadge(engine: selectedProvider)
            }

            // Segmented provider picker
            Picker("Provider", selection: $selectedProvider) {
                ForEach(EngineType.allCases, id: \.self) { engine in
                    HStack(spacing: 4) {
                        Image(systemName: engine.icon)
                        Text(engine.rawValue)
                    }
                    .tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedProvider) { _, newProvider in
                // Auto-select default model when provider changes
                let defaultModel = ExtendedModelRegistry.defaultModel(for: newProvider)
                selectedModelId = defaultModel.id
                tierFilter = nil // Reset filter
            }
        }
    }

    private var extendedModelSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Label("Select Model", systemImage: "cpu")
                    .dsTextStyle(.caption, color: .ds.secondary)

                Spacer()

                // Tier filter
                tierFilterMenu
            }

            // Model list with extended info
            VStack(spacing: 2) {
                ForEach(filteredExtendedModels) { model in
                    ExtendedModelRowView(
                        model: model,
                        engine: selectedProvider,
                        isSelected: selectedModelId == model.id,
                        onSelect: {
                            selectedModelId = model.id
                        }
                    )
                }
            }
            .padding(DSSpacing.xs)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var tierFilterMenu: some View {
        Menu {
            Button {
                tierFilter = nil
            } label: {
                HStack {
                    Text("All Tiers")
                    if tierFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(availableTiers) { tier in
                Button {
                    tierFilter = tier
                } label: {
                    HStack {
                        Image(systemName: tier.icon)
                        Text(tier.displayName)
                        if tierFilter == tier {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let filter = tierFilter {
                    Image(systemName: filter.icon)
                        .foregroundStyle(filter.color)
                    Text(filter.displayName)
                        .foregroundStyle(filter.color)
                } else {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tierFilter != nil ? tierFilter!.color : Color.ds.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.ds.surface.opacity(0.5))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Original Sections

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("AI Provider", systemImage: "cpu")
                .dsTextStyle(.caption, color: .ds.secondary)

            providerPicker
                .padding(DSSpacing.sm)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Model", systemImage: "slider.horizontal.3")
                .dsTextStyle(.caption, color: .ds.secondary)

            modelPicker
                .padding(DSSpacing.sm)
                .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none)

            // Model description
            if let model = currentModel {
                HStack(spacing: DSSpacing.xs) {
                    if model.isRecommended {
                        Badge("Recommended", variant: .info)
                    }
                    Text(model.displayName)
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
            }
        }
    }

    // MARK: - Pickers

    private var providerPicker: some View {
        Picker("", selection: $selectedProvider) {
            ForEach(EngineType.allCases, id: \.self) { engine in
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: engine.icon)
                    Text(engine.rawValue)
                }
                .tag(engine)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .onChange(of: selectedProvider) { _, newProvider in
            // Reset to default model when provider changes
            selectedModelId = ModelService.defaultModel(for: newProvider)
        }
    }

    private var modelPicker: some View {
        Picker("", selection: $selectedModelId) {
            ForEach(availableModels, id: \.id) { model in
                Text(model.pickerLabel)
                    .tag(model.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    // MARK: - Computed Properties

    private var availableModels: [ModelService.ModelInfo] {
        ModelService.models(for: selectedProvider)
    }

    private var currentModel: ModelService.ModelInfo? {
        availableModels.first { $0.id == selectedModelId }
    }

    private var extendedModels: [ExtendedModelInfo] {
        ExtendedModelRegistry.models(for: selectedProvider)
    }

    private var filteredExtendedModels: [ExtendedModelInfo] {
        if let filter = tierFilter {
            return extendedModels.filter { $0.tier == filter }
        }
        return extendedModels
    }

    private var availableTiers: [ModelTier] {
        let models = ExtendedModelRegistry.models(for: selectedProvider)
        return ModelTier.allCases.filter { tier in
            models.contains { $0.tier == tier }
        }
    }
}

// MARK: - Provider Card (Alternative Display)

/// A visual card representation of a provider for selection UIs.
struct ProviderCard: View {
    let engine: EngineType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: engine.icon)
                    .font(.system(size: DSSize.xl))
                    .foregroundStyle(isSelected ? Color.ds.accent : Color.ds.secondary)

                Text(engine.rawValue)
                    .dsTextStyle(.body)

                Text(engine.cliCommand)
                    .dsTextStyle(.monoSmall, color: .ds.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(DSSpacing.md)
            .dsGlassPanel(
                level: isSelected ? .regular : .subtle,
                cornerRadius: DSRadius.md,
                elevation: isSelected ? .low : .none,
                border: isSelected ? .standard : .subtle
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Row

/// A row displaying model information with selection indicator.
struct ModelRow: View {
    let model: ModelService.ModelInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(model.displayName)
                            .dsTextStyle(.body)

                        if model.isRecommended {
                            Badge("Recommended", variant: .info)
                        }
                    }

                    Text("ID: \(model.id)")
                        .dsTextStyle(.monoSmall, color: .ds.tertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ds.accent)
                }
            }
            .padding(DSSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Extended Provider Model Selector") {
    struct PreviewWrapper: View {
        @State private var provider: EngineType = .claude
        @State private var modelId: String = "opus"

        var body: some View {
            VStack(spacing: DSSpacing.lg) {
                // Extended layout (default - with tier badges and context)
                ProviderModelSelector(
                    selectedProvider: $provider,
                    selectedModelId: $modelId,
                    useExtendedDisplay: true
                )

                Divider()

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Selection:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Provider: \(provider.rawValue)")
                    Text("Model ID: \(modelId)")
                }
                .padding()
                .background(Color.ds.surface.opacity(0.3))
                .cornerRadius(DSRadius.md)
            }
            .padding(DSSpacing.lg)
            .frame(width: 450)
            .background(Color.ds.bg0)
        }
    }

    return PreviewWrapper()
}

#Preview("Tier Badges") {
    HStack(spacing: DSSpacing.md) {
        ForEach(ModelTier.allCases) { tier in
            TierBadge(tier: tier)
        }
    }
    .padding()
    .background(Color.ds.bg0)
}

#Preview("Extended Model Row") {
    VStack(spacing: DSSpacing.sm) {
        ExtendedModelRowView(
            model: ExtendedModelInfo(
                id: "opus",
                displayName: "Claude Opus 4.5",
                tier: .flagship,
                contextWindow: 200_000,
                description: "Most capable model",
                isDefault: true
            ),
            engine: .claude,
            isSelected: true,
            onSelect: {}
        )

        ExtendedModelRowView(
            model: ExtendedModelInfo(
                id: "sonnet",
                displayName: "Claude Sonnet 4.5",
                tier: .balanced,
                contextWindow: 200_000,
                description: "Balanced performance"
            ),
            engine: .claude,
            isSelected: false,
            onSelect: {}
        )
    }
    .padding()
    .frame(width: 400)
    .background(Color.ds.bg0)
}

#Preview("Provider Model Selector - Legacy") {
    struct PreviewWrapper: View {
        @State private var provider: EngineType = .claude
        @State private var modelId: String = "opus"

        var body: some View {
            VStack(spacing: DSSpacing.xl) {
                // Full layout (legacy)
                GroupBox("Full Layout (Legacy)") {
                    ProviderModelSelector(
                        selectedProvider: $provider,
                        selectedModelId: $modelId,
                        isCompact: false,
                        useExtendedDisplay: false
                    )
                }

                // Compact layout
                GroupBox("Compact Layout") {
                    ProviderModelSelector(
                        selectedProvider: $provider,
                        selectedModelId: $modelId,
                        isCompact: true
                    )
                }

                // Current selection
                GroupBox("Current Selection") {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Provider: \(provider.rawValue)")
                        Text("Model: \(modelId)")
                    }
                }
            }
            .padding(DSSpacing.lg)
            .background(Color.ds.bg1)
        }
    }

    return PreviewWrapper()
}

#Preview("Provider Cards") {
    struct PreviewWrapper: View {
        @State private var selectedEngine: EngineType = .claude

        var body: some View {
            HStack(spacing: DSSpacing.md) {
                ForEach(EngineType.allCases, id: \.self) { engine in
                    ProviderCard(
                        engine: engine,
                        isSelected: engine == selectedEngine,
                        onSelect: { selectedEngine = engine }
                    )
                }
            }
            .padding(DSSpacing.lg)
            .background(Color.ds.bg1)
        }
    }

    return PreviewWrapper()
}
#endif
