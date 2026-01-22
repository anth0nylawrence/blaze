import XCTest
import SwiftUI
@testable import Blaze

/// Tests for VendorLogo SwiftUI component.
/// Follows E005-F002-S001-T003-A001 atom spec.
final class VendorLogoTests: XCTestCase {

    // MARK: - Initialization Tests

    func testVendorLogoInitWithProvider() {
        let logo = VendorLogo(provider: .anthropic)
        XCTAssertEqual(logo.provider, .anthropic)
        XCTAssertEqual(logo.size, 20) // Default size
    }

    func testVendorLogoInitWithCustomSize() {
        let logo = VendorLogo(provider: .openai, size: 32)
        XCTAssertEqual(logo.provider, .openai)
        XCTAssertEqual(logo.size, 32)
    }

    // MARK: - Provider Coverage Tests

    func testVendorLogoForAllProviders() {
        for provider in AIProvider.allCases {
            let logo = VendorLogo(provider: provider)
            XCTAssertEqual(logo.provider, provider)
            // Verify fallback symbol is accessible
            XCTAssertFalse(provider.fallbackSymbol.isEmpty)
        }
    }

    func testVendorLogoFallbackSymbols() {
        // Verify each provider has a valid SF Symbol fallback
        XCTAssertEqual(AIProvider.anthropic.fallbackSymbol, "brain")
        XCTAssertEqual(AIProvider.openai.fallbackSymbol, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(AIProvider.google.fallbackSymbol, "sparkles")
        XCTAssertEqual(AIProvider.community.fallbackSymbol, "person.3.fill")
    }

    // MARK: - Size Tests

    func testVendorLogoSizeVariants() {
        let sizes: [CGFloat] = [12, 16, 20, 24, 32, 48]
        for size in sizes {
            let logo = VendorLogo(provider: .anthropic, size: size)
            XCTAssertEqual(logo.size, size)
        }
    }

    // MARK: - View Creation Tests

    func testVendorLogoCreatesView() {
        let logo = VendorLogo(provider: .google)
        // View type check - ensures body can be evaluated
        XCTAssertTrue(type(of: logo.body) is any View.Type)
    }
}
