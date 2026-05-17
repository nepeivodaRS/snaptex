import Foundation

enum MathJaxResource {
    // Preview and export WebViews use the bundled MathJax file so rendering is
    // deterministic and does not require network access.
    static let inlineScriptTag: String = {
        guard let url = scriptURL,
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            return #"<script src="MathJax.js"></script>"#
        }

        return "<script>\(script.inlineScriptEscaped)</script>"
    }()

    static var baseURL: URL? {
        scriptURL?.deletingLastPathComponent()
    }

    private static var scriptURL: URL? {
        Bundle.module.url(forResource: "MathJax", withExtension: "js")
            ?? Bundle.main.url(forResource: "MathJax", withExtension: "js")
    }
}

private extension String {
    var inlineScriptEscaped: String {
        replacingOccurrences(of: "</script", with: #"<\/script"#, options: .caseInsensitive)
    }
}
