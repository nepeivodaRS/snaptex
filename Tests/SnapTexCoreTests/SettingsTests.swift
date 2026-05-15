import XCTest
@testable import SnapTexCore

final class SettingsTests: XCTestCase {
    func testDefaultSettingsUseDedicatedCondaEnvironmentAndPortableRuntimePaths() {
        let settings = AppSettingsSnapshot.default

        XCTAssertEqual("snaptex", settings.environmentName)
        XCTAssertTrue(
            settings.uniMERNetPath.hasSuffix("/Library/Application Support/snaptex/UniMERNet"),
            settings.uniMERNetPath
        )
        XCTAssertTrue(
            settings.workerScriptPath.hasSuffix("python/snaptex_worker/worker.py"),
            settings.workerScriptPath
        )
        XCTAssertEqual(.small, settings.modelVariant)
        XCTAssertEqual(.balanced, settings.recognitionMode)
        XCTAssertTrue(settings.validateRender)
        XCTAssertEqual(.defaultSnip, settings.snipShortcut)
        XCTAssertEqual("⌘⇧1", settings.snipShortcut.displayText)
        XCTAssertEqual(13, settings.historyTitleFontSize)
        XCTAssertEqual(14, settings.latexEditorFontSize)
        XCTAssertEqual(.monospaced, settings.latexEditorFontFamily)
        XCTAssertEqual("SF Mono", settings.latexEditorFontFamily.title)
        XCTAssertEqual(.normal, settings.logVerbosity)
    }

    func testDefaultUniMERNetPathUsesMacApplicationSupport() {
        let path = AppSettingsSnapshot.defaultUniMERNetPath(
            environment: [:],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        XCTAssertEqual("/Users/example/Library/Application Support/snaptex/UniMERNet", path)
    }

    func testDefaultUniMERNetPathHonorsEnvironmentOverride() {
        let path = AppSettingsSnapshot.defaultUniMERNetPath(
            environment: ["SNAPTEX_UNIMERNET_DIR": "~/snaptex/UniMERNet"],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        XCTAssertEqual("/Users/example/snaptex/UniMERNet", path)
    }

    func testDefaultUniMERNetPathHonorsLegacyEnvironmentOverride() {
        let path = AppSettingsSnapshot.defaultUniMERNetPath(
            environment: ["UNIMERNET_DIR": "~/snaptex/UniMERNet"],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        XCTAssertEqual("/Users/example/snaptex/UniMERNet", path)
    }

    func testModelVariantDetectsInstalledModelLayouts() throws {
        let root = try makeTemporaryDirectory()

        XCTAssertFalse(UniMERModelVariant.small.isInstalled(in: root.path))

        let nestedModel = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_small")
            .appendingPathComponent("pytorch_model.bin")
        try FileManager.default.createDirectory(
            at: nestedModel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: nestedModel.path, contents: Data())

        XCTAssertTrue(UniMERModelVariant.small.isInstalled(in: root.path))
    }

    func testModelVariantDetectsHuggingFacePytorchModelPTHLayout() throws {
        let root = try makeTemporaryDirectory()
        let modelFile = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_base")
            .appendingPathComponent("pytorch_model.pth")
        try FileManager.default.createDirectory(
            at: modelFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        XCTAssertTrue(UniMERModelVariant.base.isInstalled(in: root.path))
    }

    func testDefaultWorkerScriptPathPrefersBundledWorker() throws {
        let root = try makeTemporaryDirectory()
        let resourceWorker = root
            .appendingPathComponent("Resources")
            .appendingPathComponent("python/snaptex_worker/worker.py")
        try FileManager.default.createDirectory(
            at: resourceWorker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: resourceWorker.path, contents: Data())

        let path = AppSettingsSnapshot.defaultWorkerScriptPath(
            resourceDirectory: root.appendingPathComponent("Resources")
        )

        XCTAssertEqual(resourceWorker.path, path)
    }

    func testDefaultWorkerScriptPathFallsBackToSourceCheckout() throws {
        let path = AppSettingsSnapshot.defaultWorkerScriptPath(resourceDirectory: nil)

        XCTAssertEqual("python/snaptex_worker/worker.py", path)
    }

    func testDefaultCondaPathSearchesCurrentUserHome() throws {
        let root = try makeTemporaryDirectory()
        let conda = root.appendingPathComponent("miniforge3/bin/conda")
        try FileManager.default.createDirectory(
            at: conda.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: conda.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: conda.path)

        let path = AppSettingsSnapshot.defaultCondaPath(
            environment: [:],
            homeDirectory: root
        )

        XCTAssertEqual(conda.path, path)
    }

    func testDecodedSettingsAlwaysEnableValidationAndBackfillShortcut() throws {
        let json = """
        {
          "condaPath": "conda",
          "environmentName": "snaptex",
          "uniMERNetPath": "/tmp/UniMERNet",
          "modelVariant": "small",
          "recognitionMode": "balanced",
          "outputFormat": "raw",
          "validateRender": false,
          "autoCopyAfterRecognition": true,
          "historyLimit": 32,
          "workerScriptPath": "/tmp/worker.py"
        }
        """

        let settings = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data(json.utf8))

        XCTAssertTrue(settings.validateRender)
        XCTAssertTrue(settings.autoCopyAfterRecognition)
        XCTAssertEqual(32, settings.historyLimit)
        XCTAssertEqual(.defaultSnip, settings.snipShortcut)
        XCTAssertEqual(13, settings.historyTitleFontSize)
        XCTAssertEqual(14, settings.latexEditorFontSize)
        XCTAssertEqual(.monospaced, settings.latexEditorFontFamily)
        XCTAssertEqual(.normal, settings.logVerbosity)
    }

    func testSettingsPersistLogVerbosity() throws {
        var settings = AppSettingsSnapshot.default
        settings.logVerbosity = .debug

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)

        XCTAssertEqual(.debug, decoded.logVerbosity)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
