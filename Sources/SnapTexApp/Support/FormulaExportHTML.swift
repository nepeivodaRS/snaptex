import Foundation

enum FormulaExportHTML {
    static func make(
        latex: String,
        fontSize: Int,
        mathJaxScriptTag: String = #"<script src="MathJax.js"></script>"#
    ) -> String {
        let body = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = body.formulaExportHTMLEscaped
        let safeFontSize = max(8, min(96, fontSize))
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <script type="text/x-mathjax-config">
            MathJax.Hub.Config({
              messageStyle: "none",
              skipStartupTypeset: true,
              tex2jax: { preview: "none" }
            });
          </script>
          <script>
            window.snaptexFormulaReady = false;

            window.snaptexFormulaBounds = function() {
              if (!window.snaptexFormulaReady) {
                return { ready: false };
              }
              var equation = document.getElementById("equation");
              if (!equation) {
                return { ready: false };
              }
              var target = equation.querySelector(".MathJax_Display") ||
                           equation.querySelector(".MathJax_SVG_Display") ||
                           equation.querySelector(".MathJax_CHTML") ||
                           equation.querySelector(".MathJax_SVG") ||
                           equation.querySelector(".MathJax") ||
                           equation;
              var rect = target.getBoundingClientRect();
              return {
                x: Math.max(0, Math.floor(rect.left)),
                y: Math.max(0, Math.floor(rect.top)),
                width: Math.ceil(rect.width),
                height: Math.ceil(rect.height),
                right: Math.ceil(rect.right),
                bottom: Math.ceil(rect.bottom),
                ready: rect.width > 0 && rect.height > 0
              };
            };
          </script>
          \(mathJaxScriptTag)
          <style>
            html,
            body {
              background: transparent;
              color: #111111;
              display: inline-block;
              font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              height: max-content;
              margin: 0;
              overflow: hidden;
              padding: 0;
              width: max-content;
            }
            #equation {
              background: transparent;
              box-sizing: border-box;
              color: #111111;
              display: inline-block;
              font-size: \(safeFontSize)px;
              line-height: 1;
              margin: 0;
              overflow: visible;
              padding: 0;
            }
            .MathJax,
            .MathJax_Display,
            .MathJax_SVG,
            .MathJax_SVG_Display {
              color: #111111 !important;
            }
            .MathJax_Display {
              display: inline-block !important;
              margin: 0 !important;
              text-align: left !important;
              width: auto !important;
            }
            .MathJax_SVG_Display {
              display: inline-block !important;
              margin: 0 !important;
              text-align: left !important;
              width: auto !important;
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
          <script>
            MathJax.Hub.Queue(
              ["Typeset", MathJax.Hub, "equation"],
              function() {
                window.snaptexFormulaReady = true;
              }
            );
          </script>
        </body>
        </html>
        """
    }
}

private extension String {
    var formulaExportHTMLEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
