import AppKit
import XCTest
import SnapTexCore
@testable import SnapTexApp

@MainActor
final class HistoryFolderTests: XCTestCase {
    func testHistoryStartsWithNoFoldersAndAllSnapsScope() {
        let model = AppModel()

        XCTAssertTrue(model.historyFolders.isEmpty)
        XCTAssertEqual(.all, model.selectedHistoryScope)
    }

    func testAllHistoryScopeShowsFolderAndUnfiledSnaps() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Topology")
        let folderEntry = makeEntry(title: "Euler class", folderID: folder.id)
        let unfiledEntry = makeEntry(title: "Untitled")

        model.history = [folderEntry, unfiledEntry]
        model.selectHistoryScope(.all)

        XCTAssertEqual([folderEntry.id, unfiledEntry.id], model.visibleHistory.map(\.id))
    }

    func testAllHistoryCanBeSortedByFolderThenNewestTime() {
        let model = AppModel()
        let algebra = model.createHistoryFolder(named: "Algebra")
        let topology = model.createHistoryFolder(named: "Topology")
        let unfiled = makeEntry(title: "Scratch", timestamp: Date(timeIntervalSince1970: 500))
        let topologyNewer = makeEntry(title: "Topology newer", timestamp: Date(timeIntervalSince1970: 400), folderID: topology.id)
        let algebraOlder = makeEntry(title: "Algebra older", timestamp: Date(timeIntervalSince1970: 100), folderID: algebra.id)
        let topologyOlder = makeEntry(title: "Topology older", timestamp: Date(timeIntervalSince1970: 300), folderID: topology.id)
        let algebraNewer = makeEntry(title: "Algebra newer", timestamp: Date(timeIntervalSince1970: 200), folderID: algebra.id)

        model.history = [unfiled, topologyNewer, algebraOlder, topologyOlder, algebraNewer]
        model.selectHistoryScope(.all)
        model.historySortMode = .folder

        XCTAssertEqual(
            [algebraNewer.id, algebraOlder.id, topologyNewer.id, topologyOlder.id, unfiled.id],
            model.visibleHistory.map(\.id)
        )
    }

    func testTimeSortPreservesNewestFirstHistoryOrder() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Research")
        let newest = makeEntry(title: "Newest", timestamp: Date(timeIntervalSince1970: 300))
        let folderEntry = makeEntry(title: "Folder", timestamp: Date(timeIntervalSince1970: 200), folderID: folder.id)
        let oldest = makeEntry(title: "Oldest", timestamp: Date(timeIntervalSince1970: 100))

        model.history = [newest, folderEntry, oldest]
        model.selectHistoryScope(.all)
        model.historySortMode = .time

        XCTAssertEqual([newest.id, folderEntry.id, oldest.id], model.visibleHistory.map(\.id))
    }

    func testFolderHistoryScopeShowsOnlyThatFoldersSnaps() {
        let model = AppModel()
        let topology = model.createHistoryFolder(named: "Topology")
        let algebra = model.createHistoryFolder(named: "Algebra")
        let topologyEntry = makeEntry(title: "Euler class", folderID: topology.id)
        let algebraEntry = makeEntry(title: "Spectral sequence", folderID: algebra.id)
        let unfiledEntry = makeEntry(title: "Scratch")

        model.history = [topologyEntry, algebraEntry, unfiledEntry]
        model.selectHistoryScope(.folder(topology.id))

        XCTAssertEqual([topologyEntry.id], model.visibleHistory.map(\.id))
    }

    func testNewSnapUsesSelectedFolderScope() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Combinatorics")
        model.selectHistoryScope(.folder(folder.id))

        let entryID = model.insertPendingHistoryEntry(
            image: nil,
            imageFingerprint: "folder-image",
            mode: .balanced,
            model: .small
        )

        XCTAssertEqual(folder.id, model.history.first { $0.id == entryID }?.folderID)
    }

    func testMovingHistoryEntryToFolderUpdatesVisibleHistory() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Number theory")
        let entry = makeEntry(title: "Zeta")
        model.history = [entry]

        model.moveHistoryEntry(entry, to: folder.id)
        model.selectHistoryScope(.folder(folder.id))

        XCTAssertEqual(folder.id, model.history.first?.folderID)
        XCTAssertEqual([entry.id], model.visibleHistory.map(\.id))
    }

    func testDeletingFolderKeepsSnapsAsUnfiled() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Geometry")
        let entry = makeEntry(title: "Curvature", folderID: folder.id)
        model.history = [entry]
        model.selectHistoryScope(.folder(folder.id))

        model.deleteHistoryFolderKeepingSnaps(folder)

        XCTAssertTrue(model.historyFolders.isEmpty)
        XCTAssertNil(model.history.first?.folderID)
        XCTAssertEqual(.all, model.selectedHistoryScope)
    }

    func testDeletingFolderWithSnapsRemovesThoseSnapsOnly() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Geometry")
        let folderEntry = makeEntry(title: "Curvature", folderID: folder.id)
        let unfiledEntry = makeEntry(title: "Scratch")
        model.history = [folderEntry, unfiledEntry]
        model.reopenHistoryEntry(folderEntry)

        model.deleteHistoryFolderAndSnaps(folder)

        XCTAssertTrue(model.historyFolders.isEmpty)
        XCTAssertEqual([unfiledEntry.id], model.history.map(\.id))
        XCTAssertEqual(unfiledEntry.id, model.selectedHistoryID)
    }

    func testFolderCanBeRenamedAndRecolored() {
        let model = AppModel()
        let folder = model.createHistoryFolder(named: "Old", color: .blue)

        model.renameHistoryFolder(folder, name: "New")
        model.updateHistoryFolderColor(folder, color: .orange)

        XCTAssertEqual("New", model.historyFolders.first?.name)
        XCTAssertEqual(.orange, model.historyFolders.first?.color)
    }

    func testNewFoldersUseDistinctDefaultColors() {
        let model = AppModel()

        let folders = (0..<HistoryFolderColor.automaticSequence.count).map { index in
            model.createHistoryFolder(named: "Folder \(index)")
        }

        XCTAssertEqual(
            HistoryFolderColor.automaticSequence,
            folders.map(\.color)
        )
        XCTAssertEqual(
            Set(HistoryFolderColor.automaticSequence),
            Set(folders.map(\.color))
        )
    }

    func testFoldersCanBeReorderedByDroppingBeforeOrAfterTargetFolder() {
        let model = AppModel()
        let bottom = model.createHistoryFolder(named: "Bottom")
        let middle = model.createHistoryFolder(named: "Middle")
        let top = model.createHistoryFolder(named: "Top")

        XCTAssertEqual([top.id, middle.id, bottom.id], model.historyFolders.map(\.id))

        model.moveHistoryFolder(withID: top.id, relativeTo: bottom.id, placement: .after)
        XCTAssertEqual([middle.id, bottom.id, top.id], model.historyFolders.map(\.id))

        model.moveHistoryFolder(withID: top.id, relativeTo: middle.id, placement: .before)
        XCTAssertEqual([top.id, middle.id, bottom.id], model.historyFolders.map(\.id))
        XCTAssertEqual("Moved folder", model.status)
    }

    func testDraggingFolderOntoItselfDoesNothing() {
        let model = AppModel()
        let bottom = model.createHistoryFolder(named: "Bottom")
        let top = model.createHistoryFolder(named: "Top")

        model.moveHistoryFolder(withID: top.id, relativeTo: top.id, placement: .after)

        XCTAssertEqual([top.id, bottom.id], model.historyFolders.map(\.id))
    }

    func testFoldersCanMoveUpAndDownOneStepWithBoundaryGuards() {
        let model = AppModel()
        let bottom = model.createHistoryFolder(named: "Bottom")
        let middle = model.createHistoryFolder(named: "Middle")
        let top = model.createHistoryFolder(named: "Top")

        model.moveHistoryFolderDown(top.id)
        XCTAssertEqual([middle.id, top.id, bottom.id], model.historyFolders.map(\.id))

        model.moveHistoryFolderUp(top.id)
        XCTAssertEqual([top.id, middle.id, bottom.id], model.historyFolders.map(\.id))

        model.moveHistoryFolderUp(top.id)
        XCTAssertEqual([top.id, middle.id, bottom.id], model.historyFolders.map(\.id))

        model.moveHistoryFolderDown(bottom.id)
        XCTAssertEqual([top.id, middle.id, bottom.id], model.historyFolders.map(\.id))
        XCTAssertEqual("Moved folder", model.status)
    }

    func testDefaultFolderNameUsesFolderTerminology() {
        let model = AppModel()

        let folder = model.createHistoryFolder()

        XCTAssertEqual("New Folder", folder.name)
        XCTAssertEqual("Created folder", model.status)
    }

    private func makeEntry(
        title: String,
        timestamp: Date = Date(),
        folderID: HistoryFolder.ID? = nil
    ) -> OCRHistoryEntry {
        OCRHistoryEntry(
            id: UUID(),
            title: title,
            timestamp: timestamp,
            latex: title,
            rawPrediction: title,
            alternatives: [],
            model: .small,
            mode: .balanced,
            image: NSImage(size: NSSize(width: 8, height: 8)),
            imageFingerprint: "\(title)-image",
            state: .recognized,
            folderID: folderID
        )
    }
}
