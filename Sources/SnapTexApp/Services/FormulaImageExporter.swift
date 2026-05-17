import AppKit
import WebKit

@MainActor
final class FormulaImageExporter {
    func export(
        latex: String,
        fontSize: Int,
        format: FormulaExportFormat,
        to url: URL
    ) async throws {
        let webView = makeWebView()
        let hostWindow = makeHostWindow(for: webView)
        let html = FormulaExportHTML.make(
            latex: latex,
            fontSize: fontSize,
            mathJaxScriptTag: MathJaxResource.inlineScriptTag
        )
        defer {
            hostWindow.contentView = nil
            hostWindow.close()
        }

        try await load(html: html, in: webView)
        let cropRect = try await waitForFormulaCropRect(in: webView)
        webView.setFrameSize(NSSize(width: max(cropRect.maxX, 1), height: max(cropRect.maxY, 1)))
        try await Task.sleep(nanoseconds: 50_000_000)
        let image = try await visibleSnapshotImage(from: webView, cropRect: cropRect)

        switch format {
        case .png:
            let data = try pngData(from: image)
            try data.write(to: url)
        case .eps:
            let data = try epsData(from: image)
            guard !data.isEmpty else {
                throw FormulaExportError.renderFailed
            }
            try data.write(to: url)
        }
    }

    private func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 2_400, height: 1_200))
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        return webView
    }

    private func makeHostWindow(for webView: WKWebView) -> NSWindow {
        // WKWebView snapshots are more reliable after the view is attached to a
        // window, even when the window is borderless and never shown.
        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView
        return window
    }

    private func load(html: String, in webView: WKWebView) async throws {
        webView.loadHTMLString(html, baseURL: MathJaxResource.baseURL)
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    private func waitForFormulaCropRect(in webView: WKWebView) async throws -> CGRect {
        for _ in 0..<80 {
            if let rect = try? await formulaCropRect(in: webView) {
                return rect
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw FormulaExportError.renderTimedOut
    }

    private func formulaCropRect(in webView: WKWebView) async throws -> CGRect? {
        let script = """
        (function() {
          if (typeof window.snaptexFormulaBounds !== "function") {
            return null;
          }
          return window.snaptexFormulaBounds();
        })();
        """
        guard let result = try await evaluateJavaScript(script, in: webView) as? [String: Any],
              result["ready"] as? Bool == true,
              let x = result["x"] as? Double,
              let y = result["y"] as? Double,
              let width = result["width"] as? Double,
              let height = result["height"] as? Double,
              width > 0,
              height > 0 else {
            return nil
        }

        return integralRect(CGRect(x: x, y: y, width: width, height: height))
    }

    private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func visibleSnapshotImage(from webView: WKWebView, cropRect: CGRect) async throws -> NSImage {
        // MathJax can report layout before WebKit has painted the SVG/HTML
        // content. Retry snapshots until the bitmap contains visible pixels.
        for _ in 0..<12 {
            let image = try await snapshotImage(from: webView, cropRect: cropRect)
            if imageHasVisibleContent(image) {
                return image
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw FormulaExportError.renderFailed
    }

    private func snapshotImage(from webView: WKWebView, cropRect: CGRect) async throws -> NSImage {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = cropRect

        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? FormulaExportError.renderFailed)
                }
            }
        }
    }

    private func imageHasVisibleContent(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y) else {
                    continue
                }
                if color.alphaComponent > 0.02 &&
                    (color.redComponent < 0.96 || color.greenComponent < 0.96 || color.blueComponent < 0.96) {
                    return true
                }
            }
        }
        return false
    }

    private func pngData(from image: NSImage) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            throw FormulaExportError.renderFailed
        }
        return data
    }

    private func epsData(from image: NSImage) throws -> Data {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw FormulaExportError.renderFailed
        }

        // Export EPS without an external vector pipeline by rasterizing the
        // rendered formula and compacting same-gray horizontal pixel runs.
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        var body = ""

        for y in 0..<height {
            var x = 0
            while x < width {
                guard let color = bitmap.colorAt(x: x, y: y),
                      let gray = epsGray(for: color) else {
                    x += 1
                    continue
                }

                let startX = x
                x += 1
                while x < width,
                      let nextColor = bitmap.colorAt(x: x, y: y),
                      epsGray(for: nextColor) == gray {
                    x += 1
                }

                body += "\(format(gray)) setgray \(startX) \(height - y - 1) \(x - startX) 1 rectfill\n"
            }
        }

        guard !body.isEmpty else {
            throw FormulaExportError.renderFailed
        }

        let eps = """
        %!PS-Adobe-3.0 EPSF-3.0
        %%Creator: SnapTex
        %%BoundingBox: 0 0 \(width) \(height)
        %%LanguageLevel: 2
        %%Pages: 1
        %%EndComments
        gsave
        \(body)grestore
        showpage
        %%EOF
        """
        return Data(eps.utf8)
    }

    private func epsGray(for color: NSColor) -> Double? {
        let converted = color.usingColorSpace(.deviceRGB) ?? color
        let alpha = converted.alphaComponent
        guard alpha > 0.02 else {
            return nil
        }

        let luminance = 0.2126 * converted.redComponent +
            0.7152 * converted.greenComponent +
            0.0722 * converted.blueComponent
        let gray = 1 - alpha * (1 - luminance)
        guard gray < 0.98 else {
            return nil
        }
        return Double((gray * 255).rounded()) / 255
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func integralRect(_ rect: CGRect) -> CGRect {
        let minX = floor(rect.minX)
        let minY = floor(rect.minY)
        let maxX = ceil(rect.maxX)
        let maxY = ceil(rect.maxY)
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }
}

enum FormulaExportError: LocalizedError {
    case renderFailed
    case renderTimedOut

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Could not render the formula export."
        case .renderTimedOut:
            return "Timed out while rendering the formula export."
        }
    }
}
