import XCTest
@testable import SnapTexApp

final class PreviewZoomTests: XCTestCase {
    func testZoomAdjustsByStepAndClampsToBounds() {
        XCTAssertEqual(20, RenderedPreviewZoom.zoomIn(from: 18))
        XCTAssertEqual(16, RenderedPreviewZoom.zoomOut(from: 18))
        XCTAssertEqual(RenderedPreviewZoom.maximumFontSize, RenderedPreviewZoom.zoomIn(from: 99))
        XCTAssertEqual(RenderedPreviewZoom.minimumFontSize, RenderedPreviewZoom.zoomOut(from: 1))
    }

    func testZoomPercentUsesDefaultSizeAsOneHundredPercent() {
        XCTAssertEqual(100, RenderedPreviewZoom.percent(for: RenderedPreviewZoom.defaultFontSize))
        XCTAssertEqual(200, RenderedPreviewZoom.percent(for: RenderedPreviewZoom.defaultFontSize * 2))
    }
}
