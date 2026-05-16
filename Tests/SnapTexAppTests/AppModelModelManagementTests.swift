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

    func testPaddlePaddleDownloadReportsProgress() async throws {
        let downloader = SuspendedModelDownloader()
        let model = AppModel(modelDownloader: downloader)
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)
        model.settings.modelVariant = .tiny

        model.requestModelDownload(variant)
        model.downloadPendingModel()

        try await waitFor {
            model.modelState(for: variant) == .downloading(progress: 0.5)
        }

        XCTAssertEqual("Downloading PaddlePaddle L", model.status)

        downloader.finish()
    }

    func testRequestingDownloadWhileAnotherModelDownloadsIsIgnored() async throws {
        let downloader = SuspendedModelDownloader()
        let model = AppModel(modelDownloader: downloader)
        model.settings.modelVariant = .small

        model.requestModelDownload(.base)
        model.downloadPendingModel()

        try await waitFor {
            model.activeModelDownload?.variant == .base
        }

        model.requestModelDownload(.tiny)

        XCTAssertNil(model.pendingModelDownload)
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

    func testRefreshMigratesLegacyUniMERNetProviderFolderToSizeFolder() throws {
        let root = try makeTemporaryDirectory()
        let legacyDirectory = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet")
            .appendingPathComponent("small")
        let canonicalDirectory = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet")
            .appendingPathComponent("m")
        let modelFile = legacyDirectory.appendingPathComponent("unimernet_small.pth")
        try FileManager.default.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        let model = AppModel()
        model.settings.uniMERNetPath = root.path
        model.refreshModelStatuses()

        XCTAssertTrue(FileManager.default.fileExists(atPath: canonicalDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyDirectory.path))
        XCTAssertEqual(.installed, model.modelState(for: .small))
        XCTAssertTrue(model.canRevealModelFiles(.small))
    }

    func testWorkerConfigurationUsesRuntimeInsideUniMERNetModelRoot() throws {
        let root = try makeTemporaryDirectory()
        let runtime = root.appendingPathComponent("runtime")
        try makeUniMERNetRuntime(at: runtime)

        var settings = AppSettingsSnapshot.default
        settings.uniMERNetPath = root.path

        let configuration = AppModel.workerConfiguration(for: settings)

        XCTAssertEqual(root.path, configuration.uniMERNetPath)
        XCTAssertEqual(runtime.path, configuration.uniMERNetRuntimePath)
    }

    func testUniMERNetRuntimeResolverFindsSiblingCheckoutForBundledWorker() throws {
        let root = try makeTemporaryDirectory()
        let snaptexRoot = root.appendingPathComponent("snaptex")
        let worker = snaptexRoot
            .appendingPathComponent("python")
            .appendingPathComponent("snaptex_worker")
            .appendingPathComponent("worker.py")
        let runtime = root.appendingPathComponent("UniMERNet")
        try FileManager.default.createDirectory(
            at: worker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: worker.path, contents: Data())
        try makeUniMERNetRuntime(at: runtime)

        var settings = AppSettingsSnapshot.default
        settings.uniMERNetPath = root.appendingPathComponent("model-storage").path
        settings.workerScriptPath = worker.path

        let resolved = AppModel.uniMERNetRuntimePath(
            for: settings,
            environment: [:],
            resourceDirectory: nil,
            homeDirectory: root
        )

        XCTAssertEqual(runtime.path, resolved)
    }

    func testPaddlePaddleModelWithoutLocalFilesRequestsExplicitDownload() throws {
        let paddlePaddleRoot = try makeTemporaryDirectory()
        let model = AppModel()
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)
        model.settings.modelVariant = .tiny
        model.settings.paddlePaddlePath = paddlePaddleRoot.path

        model.selectModelVariant(variant)

        XCTAssertEqual(.missing, model.modelState(for: variant))
        XCTAssertNotEqual(variant, model.settings.modelVariant)
        XCTAssertEqual(PendingModelDownload(variant: variant), model.pendingModelDownload)
        XCTAssertFalse(model.canRevealModelFiles(variant))

        model.requestModelDeletion(variant)

        XCTAssertNil(model.pendingModelDeletion)
    }

    func testCanRevealInstalledPaddlePaddleModelLocation() throws {
        let paddlePaddleRoot = try makeTemporaryDirectory()
        let model = AppModel()
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)
        let modelDirectory = variant.modelDirectory(in: paddlePaddleRoot.path)
        let modelFile = modelDirectory.appendingPathComponent("inference.yml")
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())
        model.settings.paddlePaddlePath = paddlePaddleRoot.path

        XCTAssertEqual(.installed, model.modelState(for: variant))
        XCTAssertTrue(model.canRevealModelFiles(variant))
    }

    func testPaddlePaddleModelWithoutConfigIsMissing() throws {
        let paddlePaddleRoot = try makeTemporaryDirectory()
        let model = AppModel()
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)
        let modelDirectory = variant.modelDirectory(in: paddlePaddleRoot.path)
        let partialFile = modelDirectory.appendingPathComponent("inference.json")
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: partialFile.path, contents: Data())
        model.settings.paddlePaddlePath = paddlePaddleRoot.path

        XCTAssertEqual(.missing, model.modelState(for: variant))
        XCTAssertFalse(model.canRevealModelFiles(variant))
    }

    func testCanRequestPaddlePaddleModelDeletion() throws {
        let uniMERNetRoot = try makeTemporaryDirectory()
        let paddlePaddleRoot = try makeTemporaryDirectory()
        let model = AppModel()
        let variant = OCRModelSelection(provider: .paddlePaddle, size: .large)
        let modelDirectory = variant.modelDirectory(in: paddlePaddleRoot.path)
        let wrongProviderDirectory = variant.modelDirectory(in: uniMERNetRoot.path)
        let modelFile = modelDirectory.appendingPathComponent("inference.yml")
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())
        try FileManager.default.createDirectory(
            at: wrongProviderDirectory,
            withIntermediateDirectories: true
        )
        model.settings.uniMERNetPath = uniMERNetRoot.path
        model.settings.paddlePaddlePath = paddlePaddleRoot.path

        XCTAssertEqual(.installed, model.modelState(for: variant))

        model.requestModelDeletion(variant)

        XCTAssertEqual(PendingModelDeletion(variant: variant), model.pendingModelDeletion)

        model.deletePendingModel()

        XCTAssertNil(model.pendingModelDeletion)
        XCTAssertEqual("PaddlePaddle L model deleted", model.status)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: wrongProviderDirectory.path))
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

    private func makeUniMERNetRuntime(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url
                .appendingPathComponent("unimernet"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: url
                .appendingPathComponent("configs")
                .appendingPathComponent("val"),
            withIntermediateDirectories: true
        )
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
