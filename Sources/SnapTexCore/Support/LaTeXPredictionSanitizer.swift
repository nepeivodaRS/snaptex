import Foundation

public enum LaTeXPredictionSanitizer {
    public static func sanitize(_ prediction: String) -> String {
        var result = prediction.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("```") {
            result = result
                .replacingRegex(#"^```[A-Za-z]*\s*"#) { _ in "" }
                .replacingRegex(#"\s*```$"#) { _ in "" }
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        result = LaTeXSource.mathBody(from: result)

        result = result.replacingRegex(#"([0-9]+)\s*/\s*_\s*\{\s*([0-9]+)\s*\}"#) { groups in
            #"\frac{\#(groups[1])}{\#(groups[2])}"#
        }

        return LaTeXSpacingNormalizer.normalize(result)
    }
}

private enum LaTeXSpacingNormalizer {
    static func normalize(_ latex: String) -> String {
        var result = latex
            .replacingRegex(#"\s+"#) { _ in " " }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        result = result.replacingRegex(#"\\([A-Za-z]+)\s+\{"#) { groups in
            "\\\(groups[1]){"
        }
        result = result.replacingRegex(#"\{\s+"#) { _ in "{" }
        result = result.replacingRegex(#"\s+\}"#) { _ in "}" }
        result = result.replacingRegex(#"\}\s+\{"#) { _ in "}{" }
        result = result.replacingRegex(#"\s*([_^])\s*"#) { groups in groups[1] }
        result = compactSingleLetterRuns(in: result)

        result = result.replacingRegex(#"\s+([)\],.])"#) { groups in groups[1] }
        result = result.replacingRegex(#"([(\[])\s+"#) { groups in groups[1] }
        result = result.replacingRegex(#",\s*"#) { _ in ", " }

        result = result.replacingRegex(#"\s*([=+])\s*"#) { groups in
            " \(groups[1]) "
        }
        result = result.replacingRegex(#"(?<=[A-Za-z0-9}\)])\s*-\s*(?=[A-Za-z\\(0-9{])"#) { _ in
            " - "
        }
        result = result.replacingRegex(#"\s*/\s*"#) { _ in "/" }

        result = result.replacingRegex(#"(\\[A-Za-z]+)\s+([(\[])"#) { groups in
            "\(groups[1])\(groups[2])"
        }
        result = result.replacingRegex(#"([A-Za-z0-9}])\s+([(\[])"#) { groups in
            "\(groups[1])\(groups[2])"
        }

        return result
            .replacingRegex(#"\s+"#) { _ in " " }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compactSingleLetterRuns(in latex: String) -> String {
        latex.replacingRegex(#"(\\(?:mathrm|mathbf|mathit|mathsf|mathtt|operatorname)\{)([^{}]+)(\})"#) { groups in
            let body = groups[2]
            guard body.range(of: #"^[A-Za-z](?:\s+[A-Za-z])+$"#, options: .regularExpression) != nil else {
                return groups[0]
            }

            return "\(groups[1])\(body.filter { !$0.isWhitespace })\(groups[3])"
        }
    }
}

public enum LaTeXSource {
    public static func mathBody(from latex: String) -> String {
        let body = latex.trimmingCharacters(in: .whitespacesAndNewlines)

        if body.hasPrefix("$$"), body.hasSuffix("$$"), body.count >= 4 {
            return body.droppingPrefix(2).droppingSuffix(2).trimmed
        }

        if body.hasPrefix("$"), body.hasSuffix("$"), body.count >= 2 {
            return body.droppingPrefix(1).droppingSuffix(1).trimmed
        }

        let equationOpen = #"\begin{equation}"#
        let equationClose = #"\end{equation}"#
        if body.hasPrefix(equationOpen), body.hasSuffix(equationClose) {
            return body.droppingPrefix(equationOpen.count).droppingSuffix(equationClose.count).trimmed
        }

        for (open, close) in [
            (#"\["#, #"\]"#),
            (#"\\["#, #"\\]"#),
            (#"\("#, #"\)"#),
            (#"\\("#, #"\\)"#)
        ] where body.hasPrefix(open) && body.hasSuffix(close) {
            return body.droppingPrefix(open.count).droppingSuffix(close.count).trimmed
        }

        return body
    }
}

public struct LaTeXAlternative: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let latex: String

    public init(title: String, latex: String, rank: Int) {
        self.id = "\(rank)-\(latex)"
        self.title = title
        self.latex = latex
    }
}

public enum LaTeXAlternativeGenerator {
    public static func makeAlternatives(predictions: [String], limit: Int = 3) -> [LaTeXAlternative] {
        var seen = Set<String>()
        let unique = predictions.compactMap { prediction -> String? in
            let sanitized = LaTeXPredictionSanitizer.sanitize(prediction)
            guard !sanitized.isEmpty,
                  LaTeXValidator.firstIssue(in: sanitized) == nil,
                  seen.insert(sanitized).inserted else {
                return nil
            }
            return sanitized
        }

        return unique.prefix(max(1, limit)).enumerated().map { rank, latex in
            LaTeXAlternative(title: rank == 0 ? "Preferred" : "Option \(rank + 1)", latex: latex, rank: rank)
        }
    }
}

private struct RegexMatch {
    let location: Int
    let length: Int
    let groups: [String]
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func droppingPrefix(_ count: Int) -> String {
        String(dropFirst(count))
    }

    func droppingSuffix(_ count: Int) -> String {
        String(dropLast(count))
    }

    func replacingRegex(_ pattern: String, with replacement: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let nsString = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else {
            return self
        }

        var result = self
        for match in matches.reversed() {
            let groups = (0..<match.numberOfRanges).map { groupIndex -> String in
                let range = match.range(at: groupIndex)
                guard range.location != NSNotFound else {
                    return ""
                }
                return nsString.substring(with: range)
            }

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement(groups))
            }
        }
        return result
    }
}
