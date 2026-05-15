import XCTest
import SnapTexCore
@testable import SnapTexApp

@MainActor
final class AppModelRecognitionTests: XCTestCase {
    func testRecognitionPredictionsAreSanitizedBeforeDisplay() {
        let model = AppModel()

        model.applyRecognitionPredictions([#"\lambda - 3 / _ { 2 }"#])

        XCTAssertEqual(#"\lambda - \frac{3}{2}"#, model.rawPrediction)
        XCTAssertEqual(#"\lambda - \frac{3}{2}"#, model.latexOutput)
        XCTAssertEqual(1, model.alternatives.count)
        XCTAssertEqual(#"\lambda - \frac{3}{2}"#, model.alternatives.first?.latex)
    }

    func testChangingOutputFormatDoesNotStackWrappers() {
        let model = AppModel()
        model.applyRecognitionPredictions(["x + y"])

        model.settings.outputFormat = .inlineMath
        XCTAssertEqual("$x + y$", model.latexOutput)

        model.settings.outputFormat = .displayMath
        XCTAssertEqual("$$x + y$$", model.latexOutput)

        model.settings.outputFormat = .equation
        XCTAssertEqual("\\begin{equation}\nx + y\n\\end{equation}", model.latexOutput)

        model.settings.outputFormat = .raw
        XCTAssertEqual("x + y", model.latexOutput)
    }

    func testPendingHistoryEntryIsInsertedBeforeRecognitionFinishes() {
        let model = AppModel()

        let id = model.insertPendingHistoryEntry(
            image: nil,
            imageFingerprint: "pending-image",
            mode: .balanced,
            model: .small
        )

        XCTAssertEqual(id, model.history.first?.id)
        XCTAssertEqual(id, model.selectedHistoryID)
        XCTAssertEqual(.recognizing, model.history.first?.state)
        XCTAssertEqual("", model.history.first?.latex)
    }

    func testSnipCanStartWhileRecognitionIsRunning() {
        let model = AppModel()

        model.isProcessing = true
        model.isSnipping = false

        XCTAssertTrue(model.canStartSnip)
    }

    func testRetryIsAvailableForSelectedHistoryEntryWithoutLastCaptureURL() {
        let model = AppModel()
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "selected-image",
            state: .recognized
        )

        model.history = [entry]
        model.reopenHistoryEntry(entry)

        XCTAssertTrue(model.canRetry)
    }

    func testDeletingOnlySelectedHistoryEntryClearsDetailPanes() {
        let model = AppModel()
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [LaTeXAlternative(title: "Preferred", latex: "x + y", rank: 0)],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "selected-image",
            state: .recognized
        )

        model.history = [entry]
        model.reopenHistoryEntry(entry)

        model.deleteHistoryEntry(entry)

        XCTAssertNil(model.selectedHistoryID)
        XCTAssertNil(model.capturedImage)
        XCTAssertEqual("", model.rawPrediction)
        XCTAssertEqual("", model.latexOutput)
        XCTAssertEqual([], model.alternatives)
        XCTAssertEqual("", model.previewLatex)
        XCTAssertNil(model.previewIssue)
        XCTAssertNil(model.validationIssue)
    }

    func testSelectingMissingModelPromptsForDownload() throws {
        let root = try makeTemporaryDirectory()
        let model = AppModel()
        model.settings.uniMERNetPath = root.path
        model.settings.modelVariant = .small
        model.refreshModelStatuses()

        model.selectModelVariant(.base)

        XCTAssertEqual(.small, model.settings.modelVariant)
        XCTAssertEqual(.base, model.pendingModelDownload?.variant)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
