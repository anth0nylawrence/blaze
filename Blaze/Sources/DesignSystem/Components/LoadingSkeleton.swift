import SwiftUI

// MARK: - Skeleton Shape

/// Shape variants for skeleton placeholders.
public enum SkeletonShape {
    case rectangle(cornerRadius: CGFloat = DSRadius.sm)
    case circle
    case capsule
}

// MARK: - Loading Skeleton

/// An animated placeholder for loading states.
public struct LoadingSkeleton: View {
    let width: CGFloat?
    let height: CGFloat
    let shape: SkeletonShape

    @State private var isAnimating = false

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        shape: SkeletonShape = .rectangle()
    ) {
        self.width = width
        self.height = height
        self.shape = shape
    }

    public var body: some View {
        skeletonView
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }

    @ViewBuilder
    private var skeletonView: some View {
        switch shape {
        case .rectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(shimmerGradient)
        case .circle:
            Circle()
                .fill(shimmerGradient)
        case .capsule:
            Capsule()
                .fill(shimmerGradient)
        }
    }

    private var shimmerGradient: LinearGradient {
        let baseColor = Color.ds.foreground.opacity(0.08)
        let highlightColor = Color.ds.foreground.opacity(0.15)

        return LinearGradient(
            colors: [baseColor, highlightColor, baseColor],
            startPoint: isAnimating ? .trailing : .leading,
            endPoint: isAnimating ? .leading : .trailing
        )
    }
}

// MARK: - Text Skeleton

/// A skeleton that mimics text lines.
public struct TextSkeleton: View {
    let lines: Int
    let lastLineWidth: CGFloat

    public init(lines: Int = 3, lastLineWidth: CGFloat = 0.6) {
        self.lines = lines
        self.lastLineWidth = lastLineWidth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            ForEach(0..<lines, id: \.self) { index in
                LoadingSkeleton(
                    height: 14,
                    shape: .rectangle(cornerRadius: DSRadius.sm)
                )
                .frame(maxWidth: index == lines - 1 ? .infinity : .infinity)
                .scaleEffect(x: index == lines - 1 ? lastLineWidth : 1.0, anchor: .leading)
            }
        }
    }
}

// MARK: - Card Skeleton

/// A skeleton that mimics a card with avatar and text.
public struct CardSkeleton: View {
    let showAvatar: Bool
    let textLines: Int

    public init(showAvatar: Bool = true, textLines: Int = 2) {
        self.showAvatar = showAvatar
        self.textLines = textLines
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            if showAvatar {
                LoadingSkeleton(
                    width: DSSize.xl,
                    height: DSSize.xl,
                    shape: .circle
                )
            }

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                LoadingSkeleton(width: 120, height: 16)

                TextSkeleton(lines: textLines, lastLineWidth: 0.7)
            }
        }
        .padding(DSSpacing.md)
        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)
    }
}

// MARK: - List Skeleton

/// A skeleton for a list of items.
public struct ListSkeleton: View {
    let itemCount: Int
    let itemHeight: CGFloat

    public init(itemCount: Int = 5, itemHeight: CGFloat = 56) {
        self.itemCount = itemCount
        self.itemHeight = itemHeight
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            ForEach(0..<itemCount, id: \.self) { _ in
                HStack(spacing: DSSpacing.md) {
                    LoadingSkeleton(
                        width: 24,
                        height: 24,
                        shape: .rectangle(cornerRadius: DSRadius.sm)
                    )

                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        LoadingSkeleton(width: 140, height: 14)
                        LoadingSkeleton(width: 80, height: 12)
                    }

                    Spacer()
                }
                .padding(.horizontal, DSSpacing.md)
                .frame(height: itemHeight)
            }
        }
    }
}

// MARK: - Message Skeleton

/// A skeleton mimicking a chat message bubble.
public struct MessageSkeleton: View {
    let isUser: Bool
    let lines: Int

    public init(isUser: Bool = false, lines: Int = 2) {
        self.isUser = isUser
        self.lines = lines
    }

    public var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: DSSpacing.xs) {
                ForEach(0..<lines, id: \.self) { index in
                    LoadingSkeleton(
                        width: index == 0 ? 200 : (index == lines - 1 ? 120 : 180),
                        height: 14,
                        shape: .rectangle(cornerRadius: DSRadius.sm)
                    )
                }
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(
                level: .subtle,
                cornerRadius: DSRadius.lg,
                elevation: .none
            )

            if !isUser { Spacer() }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Loading Skeletons") {
    ScrollView {
        VStack(spacing: DSSpacing.xl) {
            // Basic shapes
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Shapes").dsTextStyle(.subtitle)
                HStack(spacing: DSSpacing.md) {
                    LoadingSkeleton(width: 100, height: 20)
                    LoadingSkeleton(width: 40, height: 40, shape: .circle)
                    LoadingSkeleton(width: 80, height: 24, shape: .capsule)
                }
            }

            Divider()

            // Text skeleton
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Text").dsTextStyle(.subtitle)
                TextSkeleton(lines: 4)
            }

            Divider()

            // Card skeleton
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Cards").dsTextStyle(.subtitle)
                CardSkeleton()
                CardSkeleton(showAvatar: false, textLines: 3)
            }

            Divider()

            // List skeleton
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("List").dsTextStyle(.subtitle)
                ListSkeleton(itemCount: 3)
            }

            Divider()

            // Message skeletons
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("Messages").dsTextStyle(.subtitle)
                MessageSkeleton(isUser: false, lines: 3)
                MessageSkeleton(isUser: true, lines: 1)
            }
        }
        .padding(DSSpacing.lg)
    }
    .background(Color.ds.bg0)
}
#endif
