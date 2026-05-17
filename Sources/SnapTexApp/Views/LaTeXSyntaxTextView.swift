import AppKit
import SwiftUI
import SnapTexCore

struct LaTeXSyntaxTextView: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let validationIssue: LaTeXValidationIssue?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        RigidScrollBehavior.configure(scrollView)

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 9, height: 9)
        textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.insertionPointColor = NSColor.white.withAlphaComponent(0.86)

        scrollView.documentView = textView
        context.coordinator.configure(font: font, validationIssue: validationIssue)
        context.coordinator.apply(text: text, to: textView, force: true)
        context.coordinator.installRigidScrollBehavior(on: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        RigidScrollBehavior.configure(scrollView)
        context.coordinator.text = $text
        context.coordinator.configure(font: font, validationIssue: validationIssue)

        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        context.coordinator.apply(text: text, to: textView)
        context.coordinator.installRigidScrollBehavior(on: scrollView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        private let rigidScrollBehavior = RigidScrollBehavior.Controller()
        private var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        private var validationIssue: LaTeXValidationIssue?
        private var renderedText = ""
        private var renderedFontName = ""
        private var renderedFontSize: CGFloat = 0
        private var renderedValidationIssue: LaTeXValidationIssue?
        private var isApplying = false

        init(text: Binding<String>) {
            self.text = text
        }

        func configure(font: NSFont, validationIssue: LaTeXValidationIssue?) {
            self.font = font
            self.validationIssue = validationIssue
        }

        func installRigidScrollBehavior(on scrollView: NSScrollView) {
            rigidScrollBehavior.install(on: scrollView)
        }

        func apply(text: String, to textView: NSTextView, force: Bool = false) {
            guard force || needsRender(text: text, textView: textView) else {
                return
            }

            isApplying = true
            let selectedRanges = textView.selectedRanges
            let highlighted = LaTeXSyntaxHighlighter.highlightedString(
                for: text,
                font: font,
                validationIssue: validationIssue
            )
            textView.textStorage?.setAttributedString(highlighted)
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: LaTeXSyntaxHighlighter.variableColor
            ]
            textView.selectedRanges = selectedRanges.clamped(to: highlighted.length)

            renderedText = text
            renderedFontName = font.fontName
            renderedFontSize = font.pointSize
            renderedValidationIssue = validationIssue
            isApplying = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying,
                  let textView = notification.object as? NSTextView else {
                return
            }

            let updatedText = textView.string
            text.wrappedValue = updatedText
            apply(text: updatedText, to: textView, force: true)
        }

        private func needsRender(text: String, textView: NSTextView) -> Bool {
            textView.string != text ||
                renderedText != text ||
                renderedFontName != font.fontName ||
                renderedFontSize != font.pointSize ||
                renderedValidationIssue != validationIssue
        }
    }
}

private extension Array where Element == NSValue {
    func clamped(to length: Int) -> [NSValue] {
        map { value in
            let range = value.rangeValue
            let location = Swift.min(range.location, length)
            let clampedLength = Swift.min(range.length, Swift.max(0, length - location))
            return NSValue(range: NSRange(location: location, length: clampedLength))
        }
    }
}
