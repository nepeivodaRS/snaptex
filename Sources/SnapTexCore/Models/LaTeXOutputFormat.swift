import Foundation

public enum LaTeXOutputFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case raw
    case inlineMath
    case displayMath
    case equation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .raw:
            return "Raw"
        case .inlineMath:
            return "$"
        case .displayMath:
            return "$$"
        case .equation:
            return "Equation"
        }
    }

    public func apply(to latex: String) -> String {
        let body = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .raw:
            return body
        case .inlineMath:
            return "$\(body)$"
        case .displayMath:
            return "$$\(body)$$"
        case .equation:
            return "\\begin{equation}\n\(body)\n\\end{equation}"
        }
    }
}
