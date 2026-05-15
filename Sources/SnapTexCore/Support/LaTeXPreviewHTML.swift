import Foundation

public enum LaTeXPreviewHTML {
    public static func make(latex: String, fontSize: Int = 18) -> String {
        let body = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = body.htmlEscaped
        let safeFontSize = max(8, min(48, fontSize))
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <script src="MathJax.js"></script>
          <script>
            MathJax.Hub.Config({
              messageStyle: "none",
              tex2jax: { preview: "none" }
            });
          </script>
          <style>
            html, body {
              background: transparent;
              color: #ffffff;
              font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              height: 100%;
              margin: 0;
              overflow: auto;
              padding: 0;
              width: 100%;
            }
            #equation {
              align-items: center;
              box-sizing: border-box;
              color: #ffffff;
              display: flex;
              font-size: \(safeFontSize)px;
              justify-content: center;
              min-height: 100vh;
              min-width: 100vw;
              overflow: visible;
              padding: 12px;
              width: max-content;
            }
            .MathJax,
            .MathJax_Display,
            .MathJax_SVG,
            .MathJax_SVG_Display {
              color: #ffffff !important;
            }
            .MathJax_Display {
              margin: 0 !important;
            }
            #equation svg,
            #equation svg * {
              fill: currentColor !important;
              stroke: currentColor !important;
            }
          </style>
        </head>
        <body>
          <div id="equation">$$\(escaped)$$</div>
        </body>
        </html>
        """
    }
}

private extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
