import XCTest
import SnapTexCore
@testable import SnapTexApp

@MainActor
final class AppModelModelManagementTests: XCTestCase {
    func testActiveModelDownloadReportsProgressForNonSelectedModel() async throws {
        let downloader = SuspendedModelDownloader()
        let model = AppModel(modelDownloader: downloader)
        model.settings.modelVariant = .small

        model.requestModelDownload(.base)
        model.downloadPendingModel()

        try await waitFor {
            model.activeModelDownload?.variant == .base &&
            model.activeModelDownload?.progress == 0.5
        }

        XCTAssertEqual("Downloading UniMERNet L", model.status)

        downloader.finish()
    }

    func testDeletingInstalledModelRemovesModelFilesAndRefreshesState() throws {
        let root = try makeTemporaryDirectory()
        let modelFile = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_tiny")
            .appendingPathComponent("unimernet_tiny.pth")
        try FileManager.default.createDirectory(
            at: modelFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        let model = AppModel()
        model.settings.uniMERNetPath = root.path
        model.refreshModelStatuses()

        XCTAssertEqual(.installed, model.modelState(for: .tiny))

        model.requestModelDeletion(.tiny)
        model.deletePendingModel()

        XCTAssertFalse(FileManager.default.fileExists(atPath: modelFile.path))
        XCTAssertEqual(.missing, model.modelState(for: .tiny))
    }

    func testCanRevealInstalledModelFiles() throws {
        let root = try makeTemporaryDirectory()
        let modelFile = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_tiny")
            .appendingPathComponent("pytorch_model.pth")
        try FileManager.default.createDirectory(
            at: modelFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        let model = AppModel()
        model.settings.uniMERNetPath = root.path

        XCTAssertTrue(model.canRevealModelFiles(.tiny))
        XCTAssertFalse(model.canRevealModelFiles(.base))
    }

    func testCanRequestPaddlePaddleModelDeletion() {
        let model = AppModel()
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)

        XCTAssertEqual(.available, model.modelState(for: variant))

        model.requestModelDeletion(variant)

        XCTAssertEqual(PendingModelDeletion(variant: variant), model.pendingModelDeletion)

        model.deletePendingModel()

        XCTAssertNil(model.pendingModelDeletion)
        XCTAssertEqual("PaddlePaddle L model deleted", model.status)
    }

    private func waitFor(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class SuspendedModelDownloader: UniMERModelDownloading {
    private var continuation: CheckedContinuation<Void, Never>?

    func download(
        variant: UniMERModelVariant,
        configuration: OCRWorkerConfiguration,
        progressHandler: @escaping (Double?) -> Void
    ) async throws {
        progressHandler(0.5)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }
}
