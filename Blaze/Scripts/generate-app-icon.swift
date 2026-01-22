#!/usr/bin/env swift
//
// generate-app-icon.swift
// Renders the Blaze flame icon to PNG at all required macOS app icon sizes.
// Uses the exact same SF Symbol and gradient as WelcomeView for consistency.
//
// Usage: swift generate-app-icon.swift [output-directory]
//

import AppKit
import SwiftUI

// MARK: - Icon View (matches WelcomeView exactly)

struct BlazeIconView: View {
    let size: CGFloat

    // Background: Dark navy blue gradient (matches the design)
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(nsColor: NSColor(red: 0.12, green: 0.18, blue: 0.28, alpha: 1.0)),  // #1e2d47
            Color(nsColor: NSColor(red: 0.08, green: 0.12, blue: 0.20, alpha: 1.0))   // #141f33
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Background with rounded corners (macOS icon style)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundGradient)

            // Flame icon (exact match to WelcomeView.BlazeLogo)
            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Renderer

func renderIcon(size: CGFloat) -> NSImage? {
    let view = BlazeIconView(size: size)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)

    // Force layout
    hostingView.layoutSubtreeIfNeeded()

    // Create bitmap representation
    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        print("Failed to create bitmap for size \(size)")
        return nil
    }

    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(bitmapRep)
    return image
}

func saveAsPNG(_ image: NSImage, to path: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to convert image to PNG")
        return false
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Failed to write PNG: \(error)")
        return false
    }
}

// MARK: - Main

let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

// Determine output directory
let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    // Default to current directory
    outputDir = FileManager.default.currentDirectoryPath
}

print("Generating Blaze app icons to: \(outputDir)")

var success = true
for (name, size) in sizes {
    let path = (outputDir as NSString).appendingPathComponent(name)

    if let image = renderIcon(size: size) {
        if saveAsPNG(image, to: path) {
            print("✓ Generated \(name) (\(Int(size))x\(Int(size)))")
        } else {
            print("✗ Failed to save \(name)")
            success = false
        }
    } else {
        print("✗ Failed to render \(name)")
        success = false
    }
}

if success {
    print("\n✅ All icons generated successfully!")
} else {
    print("\n⚠️ Some icons failed to generate")
    exit(1)
}
