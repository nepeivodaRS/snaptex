import AppKit
import XCTest
import SnapTexCore
@testable import SnapTexApp

@MainActor
final class AppHistoryPersistenceTests: XCTestCase {
    func testHistoryAndSnapSettingsPersistAcrossModelInstances() throws {
        let suiteName = "AppHistoryPersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let settingsStore = AppSettingsStore(defaults: defaults)
        let firstModel = AppModel(settingsStore: settingsStore)
        let folder = firstModel.createHistoryFolder(named: "Topology", color: .blue)
        let entry = OCRHistoryEntry(
            id: UUID(),
            title: "Euler class",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            latex: "$$e(TM)$$",
            rawPrediction: "e(TM)",
            alternatives: [
                LaTeXAlternative(title: "Preferred", latex: "e(TM)", rank: 0),
                LaTeXAlternative(title: "Option 2", latex: "e(TN)", rank: 1)
            ],
            outputFormat: .displayMath,
            model: .base,
            mode: .accurate,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageURL: URL(fileURLWithPath: "/tmp/snaptex-history-image.png"),
            ownsImageFile: true,
            imageFingerprint: "snap-image",
            state: .recognized,
            folderID: folder.id,
            fixedRenderedPreviewFontSize: 22
        )

        firstModel.history = [entry]
        firstModel.historySortMode = .folder
        firstModel.reopenHistoryEntry(entry)

        let reopenedModel = AppModel(settingsStore: settingsStore)

        XCTAssertEqual([folder], reopenedModel.historyFolders)
        XCTAssertEqual(.folder(folder.id), reopenedModel.selectedHistoryScope)
        XCTAssertEqual(.folder, reopenedModel.historySortMode)
        XCTAssertEqual(entry.id, reopenedModel.selectedHistoryID)
        XCTAssertEqual("$$e(TM)$$", reopenedModel.latexOutput)
        XCTAssertEqual(22, reopenedModel.renderedPreviewFontSize)

        let reopenedEntry = try XCTUnwrap(reopenedModel.history.first)
        XCTAssertEqual(entry.id, reopenedEntry.id)
        XCTAssertEqual("Euler class", reopenedEntry.title)
        XCTAssertEqual(Date(timeIntervalSince1970: 1_700_000_000), reopenedEntry.timestamp)
        XCTAssertEqual("$$e(TM)$$", reopenedEntry.latex)
        XCTAssertEqual("e(TM)", reopenedEntry.rawPrediction)
        XCTAssertEqual(entry.alternatives, reopenedEntry.alternatives)
        XCTAssertEqual(.displayMath, reopenedEntry.outputFormat)
        XCTAssertEqual(.base, reopenedEntry.model)
        XCTAssertEqual(.accurate, reopenedEntry.mode)
        XCTAssertEqual(URL(fileURLWithPath: "/tmp/snaptex-history-image.png"), reopenedEntry.imageURL)
        XCTAssertTrue(reopenedEntry.ownsImageFile)
        XCTAssertEqual("snap-image", reopenedEntry.imageFingerprint)
        XCTAssertEqual(.recognized, reopenedEntry.state)
        XCTAssertEqual(folder.id, reopenedEntry.folderID)
        XCTAssertEqual(22, reopenedEntry.fixedRenderedPreviewFontSize)
        XCTAssertNil(reopenedEntry.image)
    }
}
