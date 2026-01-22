import SwiftUI

// MARK: - VendorLogo

/// Displays a provider logo with SF Symbol fallback.
///
/// Uses asset catalog logos when available, falling back to SF Symbols
/// for light/dark theme adaptation. Designed for reuse in SessionRow sidebar.
///
/// **E005-F002-S001-T003-A001**
public struct VendorLogo: View {
    /// The AI provider to display.
    public let provider: AIProvider

    /// Logo size in points.
    public let size: CGFloat

    /// Creates a vendor logo view.
    /// - Parameters:
    ///   - provider: The AI provider whose logo to display.
    ///   - size: Size in points (default: 20).
    public init(provider: AIProvider, size: CGFloat = 20) {
        self.provider = provider
        self.size = size
    }

    public var body: some View {
        // Try asset catalog first, fall back to SF Symbol
        if let nsImage = NSImage(named: provider.logoAssetName) {
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(provider.brandColor)
        } else {
            // SF Symbol fallback
            Image(systemName: provider.fallbackSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(provider.brandColor)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("VendorLogo - All Providers") {
    HStack(spacing: 16) {
        ForEach(AIProvider.allCases, id: \.self) { provider in
            VStack(spacing: 8) {
                VendorLogo(provider: provider, size: 32)
                Text(provider.displayName)
                    .font(.caption)
            }
        }
    }
    .padding()
}

#Preview("VendorLogo - Sizes") {
    HStack(spacing: 16) {
        VendorLogo(provider: .anthropic, size: 12)
        VendorLogo(provider: .anthropic, size: 16)
        VendorLogo(provider: .anthropic, size: 20)
        VendorLogo(provider: .anthropic, size: 24)
        VendorLogo(provider: .anthropic, size: 32)
        VendorLogo(provider: .anthropic, size: 48)
    }
    .padding()
}
#endif
