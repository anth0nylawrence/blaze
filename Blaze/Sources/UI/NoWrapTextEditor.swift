import SwiftUI
import AppKit

/// A text editor that disables word wrapping, allowing horizontal scrolling.
/// This ensures line numbers align 1:1 with source lines regardless of viewport width.
/// Returns a raw NSTextView (not in NSScrollView) so SwiftUI ScrollView can handle scrolling.
struct NoWrapTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    var lineHeight: CGFloat
    var onFocusChange: ((Bool) -> Void)?

    /// Optional EditorSession for syntax highlighting and diagnostics
    var editorSession: EditorSession?

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Configure text container for no wrapping
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true

        // Auto-resize to fit content
        textView.autoresizingMask = [.width, .height]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Styling
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false

        // Match line height with gutter
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        // Padding
        textView.textContainerInset = NSSize(width: 4, height: 8)

        textView.delegate = context.coordinator
        textView.string = text

        // Attach EditorSession for syntax highlighting and diagnostics
        editorSession?.attachToTextView(textView)
        // Detect language from content (shebang/modeline) after initial load
        editorSession?.detectLanguageFromContent()

        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        // Only update text if it differs (prevents cursor jumping)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update font if changed
        if textView.font != font {
            textView.font = font
        }

        // Update colors
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor

        // Update typing attributes with line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        // Force layout update to ensure proper sizing
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoWrapTextEditor

        init(_ parent: NoWrapTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange?(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange?(false)
        }
    }
}

// MARK: - Convenience Initializer

extension NoWrapTextEditor {
    init(
        text: Binding<String>,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        textColor: Color = Color.ds.foreground,
        backgroundColor: Color = .clear,
        onFocusChange: ((Bool) -> Void)? = nil,
        editorSession: EditorSession? = nil
    ) {
        self._text = text
        self.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        self.lineHeight = lineHeight
        self.textColor = NSColor(textColor)
        self.backgroundColor = NSColor(backgroundColor)
        self.onFocusChange = onFocusChange
        self.editorSession = editorSession
    }
}
