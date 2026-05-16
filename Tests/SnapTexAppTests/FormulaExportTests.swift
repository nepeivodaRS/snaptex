import AppKit
import XCTest
@testable import SnapTexApp

final class FormulaExportTests: XCTestCase {
    func testFormulaExportFormatsExposeSavePanelMetadata() {
        XCTAssertEqual(["PNG", "EPS"], FormulaExportFormat.allCases.map(\.title))
        XCTAssertEqual(["png", "eps"], FormulaExportFormat.allCases.map(\.fileExtension))
        XCTAssertEqual(["public.png", "com.adobe.encapsulated-postscript"], FormulaExportFormat.allCases.map(\.contentType.identifier))
    }

    func testFormulaExportHTMLUsesTransparentTightFormulaLayout() {
        let html = FormulaExportHTML.make(latex: " x + y ", fontSize: 24)

        XCTAssertTrue(html.contains("background: transparent"))
        XCTAssertTrue(html.contains("display: inline-block"))
        XCTAssertTrue(html.contains("overflow: hidden"))
        XCTAssertTrue(html.contains("window.snaptexFormulaBounds"))
        XCTAssertTrue(html.contains("$$x + y$$"))
    }

    @MainActor
    func testFormulaImageExporterWritesCroppedPNGAndEPSFiles() async throws {
        _ = NSApplication.shared
        let directory = try makeTemporaryDirectory()
        let pngURL = directory.appendingPathComponent("formula.png")
        let epsURL = directory.appendingPathComponent("formula.eps")

        let pngExporter = FormulaImageExporter()
        try await pngExporter.export(
            latex: #"x^2 + \frac{1}{2}"#,
            fontSize: 24,
            format: .png,
            to: pngURL
        )
        let epsExporter = FormulaImageExporter()
        try await epsExporter.export(
            latex: #"x^2 + \frac{1}{2}"#,
            fontSize: 24,
            format: .eps,
            to: epsURL
        )

        let pngData = try Data(contentsOf: pngURL)
        XCTAssertEqual([0x89, 0x50, 0x4E, 0x47], Array(pngData.prefix(4)))

        let image = try XCTUnwrap(NSImage(contentsOf: pngURL))
        XCTAssertGreaterThan(image.size.width, 10)
        XCTAssertLessThan(image.size.width, 400)
        XCTAssertGreaterThan(image.size.height, 10)
        XCTAssertLessThan(image.size.height, 200)

        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertNotEqual(CGImageAlphaInfo.none, cgImage.alphaInfo)
        XCTAssertGreaterThan(visiblePixelCount(in: image), 100)

        let epsData = try Data(contentsOf: epsURL)
        let epsHeader = String(data: epsData.prefix(256), encoding: .ascii) ?? ""
        let epsText = String(data: epsData, encoding: .ascii) ?? ""
        XCTAssertTrue(epsHeader.contains("%!PS-Adobe"))

        let boundingBox = try XCTUnwrap(epsBoundingBox(in: epsText))
        XCTAssertGreaterThan(boundingBox.width, 10)
        XCTAssertLessThan(boundingBox.width, 400)
        XCTAssertGreaterThan(boundingBox.height, 10)
        XCTAssertLessThan(boundingBox.height, 200)

        XCTAssertGreaterThan(epsText.components(separatedBy: "rectfill").count - 1, 100)

        if let rasterizedEPS = try rasterizeEPSWithGhostscript(epsURL) {
            XCTAssertGreaterThan(visiblePixelCount(in: rasterizedEPS), 100)
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func epsBoundingBox(in epsText: String) -> CGSize? {
        guard let line = epsText
            .split(whereSeparator: \.isNewline)
            .first(where: { $0.hasPrefix("%%BoundingBox:") }) else {
            return nil
        }

        let values = line
            .split(separator: " ")
            .dropFirst()
            .compactMap { Double($0) }
        guard values.count == 4 else {
            return nil
        }

        return CGSize(width: values[2] - values[0], height: values[3] - values[1])
    }

    private func visiblePixelCount(in image: NSImage) -> Int {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)

        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y) else {
                    continue
                }
                if color.alphaComponent > 0.02 &&
                    (color.redComponent < 0.96 || color.greenComponent < 0.96 || color.blueComponent < 0.96) {
                    count += 1
                }
            }
        }
        return count
    }

    private func rasterizeEPSWithGhostscript(_ epsURL: URL) throws -> NSImage? {
        guard let ghostscriptURL = ["/opt/homebrew/bin/gs", "/usr/local/bin/gs"]
            .map(URL.init(fileURLWithPath:))
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            return nil
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = ghostscriptURL
        process.arguments = [
            "-q",
            "-dSAFER",
            "-dBATCH",
            "-dNOPAUSE",
            "-dEPSCrop",
            "-sDEVICE=pngalpha",
            "-r72",
            "-sOutputFile=\(outputURL.path)",
            epsURL.path
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        return NSImage(contentsOf: outputURL)
    }
}
