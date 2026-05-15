import Foundation

public struct LaTeXValidationIssue: Equatable, Identifiable, Sendable {
    public var id: String { "\(location)-\(message)" }
    public let message: String
    public let location: Int
    public let length: Int
    public let excerpt: String
    public let excerptLocation: Int

    public var markedExcerpt: String {
        let caretOffset = max(0, location - excerptLocation)
        let caretCount = max(1, length)
        return excerpt + "\n" + String(repeating: " ", count: caretOffset) + String(repeating: "^", count: caretCount)
    }

    public init(message: String, location: Int, length: Int) {
        self.init(message: message, location: location, length: length, source: "")
    }

    public init(message: String, location: Int, length: Int, source: String) {
        self.message = message
        self.location = location
        self.length = length
        let fallback = source.isEmpty ? message : source
        let start = max(0, location - 18)
        let end = min(fallback.count, location + max(length, 1) + 18)
        self.excerptLocation = start
        self.excerpt = fallback.substring(fromOffset: start, toOffset: end)
    }
}

public enum LaTeXValidator {
    private static let unsupportedCommands: Set<String> = [
        "\\sl",
        "\\bf",
        "\\it",
        "\\rm",
        "\\tt"
    ]

    public static func firstIssue(in latex: String) -> LaTeXValidationIssue? {
        if let unsupported = firstUnsupportedCommand(in: latex) {
            return unsupported
        }

        return firstBraceIssue(in: latex)
    }

    private static func firstUnsupportedCommand(in source: String) -> LaTeXValidationIssue? {
        for command in unsupportedCommands {
            guard let range = source.range(of: command) else {
                continue
            }

            let after = range.upperBound
            if after < source.endIndex, source[after].isLetter {
                continue
            }

            return LaTeXValidationIssue(
                message: "Unsupported or unknown command \(command).",
                location: source.distance(from: source.startIndex, to: range.lowerBound),
                length: command.count,
                source: source
            )
        }
        return nil
    }

    private static func firstBraceIssue(in source: String) -> LaTeXValidationIssue? {
        var stack: [Int] = []
        for (offset, character) in source.enumerated() {
            if character == "{" {
                stack.append(offset)
            } else if character == "}" {
                if stack.isEmpty {
                    return LaTeXValidationIssue(
                        message: "Unexpected closing brace.",
                        location: offset,
                        length: 1,
                        source: source
                    )
                }
                stack.removeLast()
            }
        }

        if let opening = stack.last {
            return LaTeXValidationIssue(
                message: "Missing closing brace.",
                location: opening,
                length: 1,
                source: source
            )
        }

        return nil
    }
}

private extension String {
    func substring(fromOffset start: Int, toOffset end: Int) -> String {
        let safeStart = max(0, min(count, start))
        let safeEnd = max(safeStart, min(count, end))
        let startIndex = index(self.startIndex, offsetBy: safeStart)
        let endIndex = index(self.startIndex, offsetBy: safeEnd)
        return String(self[startIndex..<endIndex])
    }
}
