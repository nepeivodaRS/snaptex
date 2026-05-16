import SwiftUI
import SnapTexCore
import WebKit

struct LaTeXPreviewView: NSViewRepresentable {
    let latex: String
    let fontSize: Int

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(
            LaTeXPreviewHTML.make(
                latex: latex,
                fontSize: fontSize,
                mathJaxScriptTag: MathJaxResource.inlineScriptTag
            ),
            baseURL: MathJaxResource.baseURL
        )
    }
}
