import AppKit
import Foundation
import SnapTexCore

enum LaTeXSyntaxHighlighter {
    static let commandColor = NSColor(calibratedRed: 0.88, green: 0.93, blue: 1.00, alpha: 1)
    static let braceColor = NSColor(calibratedWhite: 0.52, alpha: 1)
    static let variableColor = NSColor(calibratedWhite: 0.78, alpha: 1)
    static let errorUnderlineColor = NSColor.systemRed

    static func highlightedString(
        for source: String,
        font: NSFont,
        validationIssue: LaTeXValidationIssue?
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: font,
                .foregroundColor: variableColor
            ]
        )
        guard attributed.length > 0 else {
            return attributed
        }

        highlightCommands(in: source, attributed: attributed)
        highlightBraces(in: source, attributed: attributed)
        highlightError(in: source, issue: validationIssue, attributed: attributed)

        return attributed
    }

    private static func highlightCommands(in source: String, attributed: NSMutableAttributedString) {
        let pattern = #"\\[A-Za-z]+|\\."#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in expression.matches(in: source, range: range) {
            attributed.addAttribute(.foregroundColor, value: commandColor, range: match.range)
        }
    }

    private static func highlightBraces(in source: String, attributed: NSMutableAttributedString) {
        for (index, character) in source.enumerated() where character == "{" || character == "}" {
            if let range = nsRange(characterLocation: index, characterLength: 1, in: source) {
                attributed.addAttribute(.foregroundColor, value: braceColor, range: range)
            }
        }
    }

    private static func highlightError(
        in source: String,
        issue: LaTeXValidationIssue?,
        attributed: NSMutableAttributedString
    ) {
        guard let issue,
              let range = nsRange(
                characterLocation: issue.location,
                characterLength: max(issue.length, 1),
                in: source
              ) else {
            return
        }

        attributed.addAttributes(
            [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: errorUnderlineColor
            ],
            range: range
        )
    }

    private static func nsRange(
        characterLocation: Int,
        characterLength: Int,
        in source: String
    ) -> NSRange? {
        guard characterLocation >= 0,
              characterLocation < source.count,
              characterLength > 0 else {
            return nil
        }

        let startOffset = min(characterLocation, source.count)
        let endOffset = min(startOffset + characterLength, source.count)
        let start = source.index(source.startIndex, offsetBy: startOffset)
        let end = source.index(source.startIndex, offsetBy: endOffset)
        return NSRange(start..<end, in: source)
    }
}
