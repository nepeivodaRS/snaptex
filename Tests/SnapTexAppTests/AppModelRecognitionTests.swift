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

    func testChangingOutputFormatForHistoryEntryPersistsWhenReopened() throws {
        let model = AppModel()
        let defaultOutputFormat = model.settings.outputFormat
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
        model.setCurrentOutputFormat(.displayMath)

        XCTAssertEqual(.displayMath, try XCTUnwrap(model.history.first).outputFormat)
        model.reopenHistoryEntry(entry)

        XCTAssertEqual("$$x + y$$", model.latexOutput)
        XCTAssertEqual(.displayMath, model.currentOutputFormat)
        XCTAssertEqual(defaultOutputFormat, model.settings.outputFormat)
    }

    func testOutputFormatCanChangeForRecognizedHistoryWhileAnotherItemRecognizes() {
        let model = AppModel()
        let recognized = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognized-image",
            state: .recognized
        )
        let recognizing = OCRHistoryEntry(
            id: UUID(),
            title: "Recognizing...",
            timestamp: Date(),
            latex: "",
            rawPrediction: "",
            alternatives: [],
            model: .small,
            mode: .accurate,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognizing-image",
            state: .recognizing
        )

        model.history = [recognizing, recognized]
        model.isProcessing = true
        model.reopenHistoryEntry(recognized)

        XCTAssertTrue(model.canChangeOutputFormat)

        model.setCurrentOutputFormat(.displayMath)

        XCTAssertEqual("$$x + y$$", model.latexOutput)
        XCTAssertEqual(.displayMath, model.currentOutputFormat)
    }

    func testRecognizedHistoryCanBeRetriedWhileAnotherItemRecognizes() {
        let model = AppModel()
        let recognized = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognized-image",
            state: .recognized
        )
        let recognizing = OCRHistoryEntry(
            id: UUID(),
            title: "Recognizing...",
            timestamp: Date(),
            latex: "",
            rawPrediction: "",
            alternatives: [],
            model: .small,
            mode: .accurate,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognizing-image",
            state: .recognizing
        )

        model.history = [recognizing, recognized]
        model.isProcessing = true
        model.reopenHistoryEntry(recognized)

        XCTAssertTrue(model.canRetry)
        XCTAssertTrue(model.canChangeRecognitionSettings)
        XCTAssertFalse(model.isCurrentItemRecognizing)
    }

    func testFormulaExportRequiresRenderedPreview() {
        let model = AppModel()
        model.latexOutput = "x + y"

        XCTAssertFalse(model.canExportFormula)

        model.previewLatex = "x + y"

        XCTAssertTrue(model.canExportFormula)

        model.previewIssue = LaTeXValidationIssue(message: "Invalid", location: 0, length: 1)

        XCTAssertFalse(model.canExportFormula)
    }

    func testManualLatexEditRefreshesValidationIssueForSyntaxEditor() {
        let model = AppModel()

        model.latexOutput = #"d^{5}x = (\beta^{4}\ {}d beta\\))\times(\operatorname{sin}3\gamma d\gamma d\Omega)"#

        XCTAssertEqual("Unexpected line break command \\\\.", model.validationIssue?.message)
    }

    func testManualLatexEditShowsPreviewIssueForUnexpectedLineBreak() async {
        let model = AppModel()

        model.latexOutput = #"d^{5}x = (\beta^{4}\ {}d beta\\))\times(\operatorname{sin}3\gamma d\gamma d\Omega)"#

        try? await Task.sleep(nanoseconds: 320_000_000)
        XCTAssertEqual("", model.previewLatex)
        XCTAssertEqual("Unexpected line break command \\\\.", model.previewIssue?.message)
    }

    func testRecognizingHistoryItemLocksOnlyTheCurrentItem() {
        let model = AppModel()
        let recognized = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognized-image",
            state: .recognized
        )
        let recognizing = OCRHistoryEntry(
            id: UUID(),
            title: "Recognizing...",
            timestamp: Date(),
            latex: "",
            rawPrediction: "",
            alternatives: [],
            model: .small,
            mode: .accurate,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "recognizing-image",
            state: .recognizing
        )

        model.history = [recognizing, recognized]
        model.isProcessing = true

        model.reopenHistoryEntry(recognizing)
        XCTAssertFalse(model.canRetry)
        XCTAssertFalse(model.canChangeRecognitionSettings)
        XCTAssertTrue(model.isCurrentItemRecognizing)
        XCTAssertEqual("Recognizing", model.toolbarStatusText)

        model.reopenHistoryEntry(recognized)
        XCTAssertTrue(model.canRetry)
        XCTAssertTrue(model.canChangeRecognitionSettings)
        XCTAssertFalse(model.isCurrentItemRecognizing)
        XCTAssertEqual("Reopened history item", model.toolbarStatusText)
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

    func testFinderAddCanStartUnlessRegionSelectionIsActive() {
        let model = AppModel()

        XCTAssertTrue(model.canAddFromFinder)

        model.isProcessing = true
        XCTAssertTrue(model.canAddFromFinder)

        model.isSnipping = true
        XCTAssertFalse(model.canAddFromFinder)
    }

    func testOCRPassChangesDoNotChangeWorkerConfiguration() {
        var settings = AppSettingsSnapshot.default
        let workerConfiguration = AppModel.workerConfiguration(for: settings)

        settings.recognitionMode = .accurate

        XCTAssertEqual(workerConfiguration, AppModel.workerConfiguration(for: settings))
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

    func testRetryIsAvailableForSelectedHistoryEntryWithStoredImageURL() throws {
        let model = AppModel()
        let imageURL = try makeTemporaryImageFile()
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: nil,
            imageURL: imageURL,
            imageFingerprint: "selected-image",
            state: .recognized
        )

        model.history = [entry]
        model.reopenHistoryEntry(entry)

        XCTAssertTrue(model.canRetry)
    }

    func testReplacingRenamedHistoryEntryPreservesUserTitle() {
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
        model.renameHistoryEntry(entry, title: "Euler class")
        let id = model.insertPendingHistoryEntry(
            image: nil,
            imageFingerprint: "selected-image",
            mode: .accurate,
            model: .base
        )

        XCTAssertEqual(id, model.history.first?.id)
        XCTAssertEqual("Euler class", model.history.first?.title)
        XCTAssertEqual(.recognizing, model.history.first?.state)
    }

    func testReopeningHistoryEntryTracksDisplayedModel() {
        let model = AppModel()
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .base,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "selected-image",
            state: .recognized
        )

        model.history = [entry]
        model.reopenHistoryEntry(entry)

        XCTAssertEqual(.base, model.currentResultModel)
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
        XCTAssertNil(model.currentResultModel)
    }

    func testDeletingHistoryEntryRemovesOwnedImageFile() throws {
        let model = AppModel()
        let imageURL = try makeTemporaryImageFile()
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: nil,
            imageURL: imageURL,
            ownsImageFile: true,
            imageFingerprint: "owned-image",
            state: .recognized
        )

        model.history = [entry]
        model.deleteHistoryEntry(entry)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testDeletingHistoryEntryLeavesExternalImageFile() throws {
        let model = AppModel()
        let imageURL = try makeTemporaryImageFile()
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "x + y",
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: nil,
            imageURL: imageURL,
            ownsImageFile: false,
            imageFingerprint: "external-image",
            state: .recognized
        )
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        model.history = [entry]
        model.deleteHistoryEntry(entry)

        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testReplacingHistoryEntryRemovesOldOwnedImageFile() throws {
        let model = AppModel()
        let oldImageURL = try makeTemporaryImageFile()
        let newImageURL = try makeTemporaryImageFile()
        defer {
            try? FileManager.default.removeItem(at: oldImageURL)
            try? FileManager.default.removeItem(at: newImageURL)
        }
        model.history = [
            OCRHistoryEntry(
                id: UUID(),
                title: "x + y",
                timestamp: Date(),
                latex: "x + y",
                rawPrediction: "x + y",
                alternatives: [],
                model: .small,
                mode: .balanced,
                image: nil,
                imageURL: oldImageURL,
                ownsImageFile: true,
                imageFingerprint: "same-image",
                state: .recognized
            )
        ]

        model.insertPendingHistoryEntry(
            image: nil,
            imageURL: newImageURL,
            ownsImageFile: true,
            imageFingerprint: "same-image",
            mode: .balanced,
            model: .base
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldImageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newImageURL.path))
    }

    func testTrimmingHistoryRemovesOwnedImageFiles() throws {
        let model = AppModel()
        model.settings.historyLimit = 4
        let oldestImageURL = try makeTemporaryImageFile()
        var imageURLs = [oldestImageURL]
        defer {
            for imageURL in imageURLs {
                try? FileManager.default.removeItem(at: imageURL)
            }
        }

        model.insertPendingHistoryEntry(
            image: nil,
            imageURL: oldestImageURL,
            ownsImageFile: true,
            imageFingerprint: "image-0",
            mode: .balanced,
            model: .small
        )
        for index in 1...4 {
            let imageURL = try makeTemporaryImageFile()
            imageURLs.append(imageURL)
            model.insertPendingHistoryEntry(
                image: nil,
                imageURL: imageURL,
                ownsImageFile: true,
                imageFingerprint: "image-\(index)",
                mode: .balanced,
                model: .small
            )
        }

        XCTAssertEqual(4, model.history.count)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldestImageURL.path))
    }

    func testReducingLimitedHistoryLimitRemovesOldestSnapsImmediately() {
        let model = AppModel()
        model.settings.isHistoryLimitEnabled = true
        model.settings.historyLimit = 40
        model.history = [
            makeHistoryEntry(title: "Newest", imageFingerprint: "image-0"),
            makeHistoryEntry(title: "Recent", imageFingerprint: "image-1"),
            makeHistoryEntry(title: "Middle", imageFingerprint: "image-2"),
            makeHistoryEntry(title: "Older", imageFingerprint: "image-3"),
            makeHistoryEntry(title: "Oldest", imageFingerprint: "image-4")
        ]

        model.settings.historyLimit = 4

        XCTAssertEqual(["Newest", "Recent", "Middle", "Older"], model.history.map(\.title))
    }

    func testUnlimitedHistoryKeepsSnapsBeyondNumericLimit() {
        let model = AppModel()
        model.settings.isHistoryLimitEnabled = false
        model.settings.historyLimit = 4

        for index in 0..<6 {
            model.insertPendingHistoryEntry(
                image: nil,
                imageFingerprint: "image-\(index)",
                mode: .balanced,
                model: .small
            )
        }

        XCTAssertEqual(6, model.history.count)
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

    private func makeTemporaryImageFile() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snaptex-test-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try Data("image".utf8).write(to: url)
        return url
    }

    private func makeHistoryEntry(title: String, imageFingerprint: String) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: UUID(),
            title: title,
            timestamp: Date(),
            latex: "x + y",
            rawPrediction: "x + y",
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: nil,
            imageFingerprint: imageFingerprint,
            state: .recognized
        )
    }
}
