import AppKit
import XCTest
import SnapTexCore
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

    @MainActor
    func testRenderedPreviewZoomUsesGlobalSizeUntilSelectedEntryIsFixed() {
        let model = AppModel()
        let first = makeEntry(title: "First")
        let second = makeEntry(title: "Second")
        model.history = [first, second]

        model.reopenHistoryEntry(first)
        model.zoomRenderedPreviewIn()
        XCTAssertEqual(20, model.renderedPreviewFontSize)

        model.reopenHistoryEntry(second)
        XCTAssertEqual(20, model.renderedPreviewFontSize)

        model.toggleFixedRenderedPreviewZoom()
        XCTAssertTrue(model.isRenderedPreviewZoomFixed)
        model.zoomRenderedPreviewIn()
        XCTAssertEqual(22, model.renderedPreviewFontSize)

        model.reopenHistoryEntry(first)
        XCTAssertEqual(20, model.renderedPreviewFontSize)

        model.zoomRenderedPreviewOut()
        XCTAssertEqual(18, model.renderedPreviewFontSize)

        model.reopenHistoryEntry(second)
        XCTAssertEqual(22, model.renderedPreviewFontSize)
    }

    @MainActor
    func testUnfixingSelectedRenderedPreviewZoomReturnsToGlobalSize() {
        let model = AppModel()
        let entry = makeEntry(title: "Pinned")
        model.history = [entry]

        model.zoomRenderedPreviewIn()
        model.reopenHistoryEntry(entry)
        model.toggleFixedRenderedPreviewZoom()
        model.zoomRenderedPreviewIn()
        XCTAssertEqual(22, model.renderedPreviewFontSize)

        model.toggleFixedRenderedPreviewZoom()
        XCTAssertFalse(model.isRenderedPreviewZoomFixed)
        XCTAssertEqual(20, model.renderedPreviewFontSize)
    }

    private func makeEntry(title: String) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: UUID(),
            title: title,
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "\(title)-image",
            state: .recognized
        )
    }
}
