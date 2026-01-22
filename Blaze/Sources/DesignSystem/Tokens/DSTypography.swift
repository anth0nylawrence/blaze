import SwiftUI

// MARK: - Typography Tokens

/// Semantic typography styles for the Blaze Design System.
public enum DSTextStyle: String, CaseIterable {
    /// Large display text (32pt bold)
    case hero

    /// Section headers (20pt semibold)
    case title

    /// Subsection headers (16pt medium)
    case subtitle

    /// Standard body text (14pt regular)
    case body

    /// Small descriptive text (12pt regular)
    case caption

    /// Extra small text (11pt regular)
    case micro

    /// Monospaced code text (13pt regular)
    case mono

    /// Small monospaced text (11pt regular)
    case monoSmall

    /// Large monospaced text (15pt regular)
    case monoLarge

    // MARK: - Font Properties

    public var font: Font {
        switch self {
        case .hero:
            return .system(size: 32, weight: .bold, design: .default)
        case .title:
            return .system(size: 20, weight: .semibold, design: .default)
        case .subtitle:
            return .system(size: 16, weight: .medium, design: .default)
        case .body:
            return .system(size: 14, weight: .regular, design: .default)
        case .caption:
            return .system(size: 12, weight: .regular, design: .default)
        case .micro:
            return .system(size: 11, weight: .regular, design: .default)
        case .mono:
            return .system(size: 13, weight: .regular, design: .monospaced)
        case .monoSmall:
            return .system(size: 11, weight: .regular, design: .monospaced)
        case .monoLarge:
            return .system(size: 15, weight: .regular, design: .monospaced)
        }
    }

    /// Line height multiplier for the style
    public var lineHeight: CGFloat {
        switch self {
        case .hero:
            return 1.2
        case .title:
            return 1.3
        case .subtitle:
            return 1.35
        case .body, .caption, .micro:
            return 1.4
        case .mono, .monoSmall, .monoLarge:
            return 1.5
        }
    }

    /// Letter spacing (tracking) for the style
    public var tracking: CGFloat {
        switch self {
        case .hero:
            return -0.5
        case .title:
            return -0.3
        case .subtitle, .body:
            return 0
        case .caption, .micro:
            return 0.1
        case .mono, .monoSmall, .monoLarge:
            return 0
        }
    }
}

// MARK: - Font Weight Helpers

public enum DSFontWeight {
    case regular
    case medium
    case semibold
    case bold

    public var weight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}
