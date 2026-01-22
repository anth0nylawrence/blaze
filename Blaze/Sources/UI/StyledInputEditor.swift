import SwiftUI
import AppKit

/// NSTextView-based input that styles @file: and @folder: tokens with background highlighting.
/// Key design: Text content stays as-is (e.g., "@folder:migrations"), only visual styling is applied.
/// This avoids feedback loops that occur when replacing text content.
struct StyledInputEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Ask anything..."
    var onSubmit: () -> Void
    var onTextChange: (String, String) -> Void  // (oldValue, newValue)

    // Keyboard callbacks for mention handling
    var onEscape: () -> Void = {}
    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}
    var onTab: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = StyledNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Text container setup
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 0, height: 2)

        // Store callbacks
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape
        textView.onArrowUp = onArrowUp
        textView.onArrowDown = onArrowDown
        textView.onTab = onTab
        textView.placeholder = placeholder

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? StyledNSTextView else { return }

        // Update callbacks
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape
        textView.onArrowUp = onArrowUp
        textView.onArrowDown = onArrowDown
        textView.onTab = onTab

        // Only update text if binding changed externally (not from typing)
        let currentText = textView.string
        if currentText != text && !context.coordinator.isUpdatingFromTextView {
            context.coordinator.isUpdatingFromBinding = true
            textView.string = text
            applyTokenStyling(to: textView)
            // Move cursor to end after external change (e.g., token insertion)
            let newLength = textView.string.count
            textView.setSelectedRange(NSRange(location: newLength, length: 0))
            context.coordinator.isUpdatingFromBinding = false
        }

        // Update vertical centering
        updateVerticalCentering(scrollView: scrollView, textView: textView)
    }

    /// Center text vertically in scroll view for single-line inputs
    private func updateVerticalCentering(scrollView: NSScrollView, textView: NSTextView) {
        let scrollHeight = scrollView.frame.height
        guard scrollHeight > 0 else { return }

        // Calculate text height
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let textHeight = layoutManager.usedRect(for: textContainer).height

            // Center vertically if text fits in view
            if textHeight < scrollHeight {
                let verticalInset = max(0, (scrollHeight - textHeight) / 2)
                textView.textContainerInset = NSSize(width: 0, height: verticalInset)
            } else {
                textView.textContainerInset = NSSize(width: 0, height: 4)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Token Styling

    /// Apply visual styling to @file: and @folder: tokens without changing text content
    private func applyTokenStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string

        // Reset to base attributes
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]
        textStorage.setAttributes(baseAttrs, range: fullRange)

        // Find and style tokens
        let pattern = #"@(file|folder):([^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        for match in matches {
            let tokenRange = match.range

            // Apply pill-like styling
            let pillAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.systemBlue
            ]
            textStorage.addAttributes(pillAttrs, range: tokenRange)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: StyledInputEditor
        weak var textView: StyledNSTextView?
        var isUpdatingFromTextView = false
        var isUpdatingFromBinding = false
        private var previousText = ""

        init(_ parent: StyledInputEditor) {
            self.parent = parent
            self.previousText = parent.text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isUpdatingFromBinding else { return }

            isUpdatingFromTextView = true
            let newText = textView.string
            let oldText = previousText

            // Update binding
            parent.text = newText

            // Notify about change (for mention detection)
            parent.onTextChange(oldText, newText)

            // Re-apply styling after text change
            parent.applyTokenStyling(to: textView)

            previousText = newText
            isUpdatingFromTextView = false
        }
    }
}

// MARK: - Custom NSTextView

class StyledNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onTab: (() -> Void)?
    var placeholder: String = "Ask anything..."

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: // Return
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)  // Shift+Return = newline
            } else {
                onSubmit?()
            }
        case 53: // Escape
            onEscape?()
        case 126: // Up arrow
            onArrowUp?()
        case 125: // Down arrow
            onArrowDown?()
        case 48: // Tab
            onTab?()
        default:
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw placeholder when empty - vertically centered
        if string.isEmpty {
            let placeholderFont = font ?? NSFont.systemFont(ofSize: 13)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: placeholderFont,
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let textHeight = placeholderFont.ascender - placeholderFont.descender
            let yOffset = (bounds.height - textHeight) / 2 - placeholderFont.descender - 4
            let rect = NSRect(
                x: textContainerInset.width + 5,
                y: yOffset,
                width: bounds.width - textContainerInset.width * 2 - 10,
                height: textHeight
            )
            placeholder.draw(in: rect, withAttributes: attrs)
        }
    }

    // Trigger redraw when inset changes so placeholder repositions
    override var textContainerInset: NSSize {
        didSet {
            needsDisplay = true
        }
    }
}
