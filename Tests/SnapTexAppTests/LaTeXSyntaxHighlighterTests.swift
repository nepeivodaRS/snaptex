import AppKit
import XCTest
import SnapTexCore
@testable import SnapTexApp

final class LaTeXSyntaxHighlighterTests: XCTestCase {
    func testHighlightsCommandsBracesVariablesAndValidationIssue() {
        let source = #"\frac{x}{y}"#
        let issue = LaTeXValidationIssue(
            message: "Unsupported command",
            location: 0,
            length: 5,
            source: source
        )

        let highlighted = LaTeXSyntaxHighlighter.highlightedString(
            for: source,
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            validationIssue: issue
        )

        XCTAssertEqual(
            highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor,
            LaTeXSyntaxHighlighter.commandColor
        )
        XCTAssertEqual(
            highlighted.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor,
            LaTeXSyntaxHighlighter.braceColor
        )
        XCTAssertEqual(
            highlighted.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor,
            LaTeXSyntaxHighlighter.variableColor
        )
        XCTAssertEqual(
            highlighted.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
        XCTAssertEqual(
            highlighted.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor,
            LaTeXSyntaxHighlighter.errorUnderlineColor
        )
        XCTAssertNil(highlighted.attribute(.underlineStyle, at: 6, effectiveRange: nil))
    }
}
