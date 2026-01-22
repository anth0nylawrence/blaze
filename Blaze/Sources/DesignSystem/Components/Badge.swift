import SwiftUI

// MARK: - Badge Variant

/// Visual variants for badges.
public enum BadgeVariant {
    case `default`   // Subtle, secondary style
    case primary     // Accent colored
    case success     // Green/positive
    case warning     // Orange/caution
    case error       // Red/negative
    case info        // Blue/informational

    var backgroundColor: Color {
        switch self {
        case .default: return Color.ds.foreground.opacity(0.1)
        case .primary: return Color.accentColor.opacity(0.15)
        case .success: return Color.ds.positive.opacity(0.15)
        case .warning: return Color.ds.warning.opacity(0.15)
        case .error: return Color.ds.negative.opacity(0.15)
        case .info: return Color.ds.info.opacity(0.15)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .default: return Color.ds.secondary
        case .primary: return Color.accentColor
        case .success: return Color.ds.positive
        case .warning: return Color.ds.warning
        case .error: return Color.ds.negative
        case .info: return Color.ds.info
        }
    }

    var borderColor: Color {
        switch self {
        case .default: return Color.ds.border
        case .primary: return Color.accentColor.opacity(0.3)
        case .success: return Color.ds.positive.opacity(0.3)
        case .warning: return Color.ds.warning.opacity(0.3)
        case .error: return Color.ds.negative.opacity(0.3)
        case .info: return Color.ds.info.opacity(0.3)
        }
    }
}

// MARK: - Badge Size

/// Size variants for badges.
public enum BadgeSize {
    case small
    case medium
    case large

    var textStyle: DSTextStyle {
        switch self {
        case .small: return .micro
        case .medium: return .caption
        case .large: return .body
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return DSSpacing.xs
        case .medium: return DSSpacing.sm
        case .large: return DSSpacing.md
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return DSSpacing.xxs
        case .large: return DSSpacing.xs
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        }
    }
}

// MARK: - Badge

/// A small status indicator or label chip.
public struct Badge: View {
    let text: String
    let icon: String?
    let variant: BadgeVariant
    let size: BadgeSize
    let showBorder: Bool

    public init(
        _ text: String,
        icon: String? = nil,
        variant: BadgeVariant = .default,
        size: BadgeSize = .medium,
        showBorder: Bool = false
    ) {
        self.text = text
        self.icon = icon
        self.variant = variant
        self.size = size
        self.showBorder = showBorder
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
            }

            Text(text)
                .font(size.textStyle.font)
                .fontWeight(.medium)
        }
        .foregroundStyle(variant.foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(variant.backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(showBorder ? variant.borderColor : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Count Badge

/// A numeric badge for showing counts.
public struct CountBadge: View {
    let count: Int
    let variant: BadgeVariant
    let maxDisplay: Int

    public init(
        _ count: Int,
        variant: BadgeVariant = .primary,
        maxDisplay: Int = 99
    ) {
        self.count = count
        self.variant = variant
        self.maxDisplay = maxDisplay
    }

    public var body: some View {
        if count > 0 {
            Text(displayText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(badgeColor)
                .clipShape(Capsule())
        }
    }

    private var displayText: String {
        count > maxDisplay ? "\(maxDisplay)+" : "\(count)"
    }

    private var badgeColor: Color {
        switch variant {
        case .default, .primary: return .accentColor
        case .success: return Color.ds.positive
        case .warning: return Color.ds.warning
        case .error: return Color.ds.negative
        case .info: return Color.ds.info
        }
    }
}

// MARK: - Dot Indicator

/// A simple colored dot indicator.
public struct DotIndicator: View {
    let color: Color
    let size: CGFloat
    let isPulsing: Bool

    @State private var isAnimating = false

    public init(
        color: Color = .accentColor,
        size: CGFloat = 8,
        isPulsing: Bool = false
    ) {
        self.color = color
        self.size = size
        self.isPulsing = isPulsing
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing && isAnimating ? 1.2 : 1.0)
            .opacity(isPulsing && isAnimating ? 0.7 : 1.0)
            .animation(
                isPulsing ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )
            .onAppear {
                isAnimating = isPulsing
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Badges") {
    VStack(spacing: DSSpacing.lg) {
        // Variants
        HStack(spacing: DSSpacing.sm) {
            Badge("Default")
            Badge("Primary", variant: .primary)
            Badge("Success", icon: "checkmark", variant: .success)
            Badge("Warning", variant: .warning)
            Badge("Error", variant: .error)
            Badge("Info", variant: .info)
        }

        // Sizes
        HStack(spacing: DSSpacing.sm) {
            Badge("Small", size: .small)
            Badge("Medium", size: .medium)
            Badge("Large", size: .large)
        }

        // With borders
        HStack(spacing: DSSpacing.sm) {
            Badge("Bordered", variant: .primary, showBorder: true)
            Badge("With Icon", icon: "star.fill", variant: .warning, showBorder: true)
        }

        // Count badges
        HStack(spacing: DSSpacing.sm) {
            CountBadge(3)
            CountBadge(42)
            CountBadge(150)
            CountBadge(5, variant: .error)
        }

        // Dot indicators
        HStack(spacing: DSSpacing.md) {
            DotIndicator(color: .green)
            DotIndicator(color: .orange)
            DotIndicator(color: .red, isPulsing: true)
        }
    }
    .padding(DSSpacing.xl)
    .background(Color.ds.bg0)
}
#endif
