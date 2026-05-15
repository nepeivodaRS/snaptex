import XCTest
@testable import SnapTexApp

final class AppLayoutMetricsTests: XCTestCase {
    func testMinimumWindowWidthFitsCurrentToolbarLabels() {
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, 1_280)
    }

    func testToolbarLabelsReserveSingleLineWidths() {
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarModelLabelWidth, 76)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarPassesLabelWidth, 82)
    }

    func testConfidenceIsNotDisplayedWithoutModelProvidedConfidence() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceFiles = [
            "Sources/SnapTexApp/Views/CapturePreviewPane.swift",
            "Sources/SnapTexApp/Views/OutputPane.swift"
        ]

        for sourceFile in sourceFiles {
            let source = try String(
                contentsOf: sourceRoot.appendingPathComponent(sourceFile),
                encoding: .utf8
            )
            XCTAssertFalse(source.contains("Confidence:"), sourceFile)
            XCTAssertFalse(source.contains("confidencePercent"), sourceFile)
        }
    }
}
