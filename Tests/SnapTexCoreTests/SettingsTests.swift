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
            settings.paddlePaddlePath.hasSuffix("/Library/Application Support/snaptex/PaddlePaddle"),
            settings.paddlePaddlePath
        )
        XCTAssertTrue(
            settings.workerScriptPath.hasSuffix("python/snaptex_worker/worker.py"),
            settings.workerScriptPath
        )
        XCTAssertEqual(OCRModelSelection(provider: .uniMERNet, size: .medium), settings.modelVariant)
        XCTAssertEqual(.fast, settings.recognitionMode)
        XCTAssertTrue(settings.validateRender)
        XCTAssertEqual(.defaultSnip, settings.snipShortcut)
        XCTAssertEqual("⌘⇧S", settings.snipShortcut.displayText)
        XCTAssertEqual(.defaultOpenApp, settings.openAppShortcut)
        XCTAssertEqual("⌘⇧O", settings.openAppShortcut.displayText)
        XCTAssertEqual(12, settings.historyTitleFontSize)
        XCTAssertEqual(14, settings.labelFontSize)
        XCTAssertEqual(15, settings.paneTitleFontSize)
        XCTAssertEqual(12, settings.toolbarFontSize)
        XCTAssertEqual(11, settings.metadataFontSize)
        XCTAssertEqual(15, settings.latexEditorFontSize)
        XCTAssertEqual(.monospaced, settings.latexEditorFontFamily)
        XCTAssertEqual("SF Mono", settings.latexEditorFontFamily.title)
        XCTAssertEqual(.normal, settings.logVerbosity)
    }

    func testDefaultSettingsEncodeSnipButtonFontSize() throws {
        let data = try JSONEncoder().encode(AppSettingsSnapshot.default)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(20, payload["snipButtonFontSize"] as? Int)
        XCTAssertEqual(AppSettingsSnapshot.default.paddlePaddlePath, payload["paddlePaddlePath"] as? String)
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

    func testDefaultPaddlePaddlePathUsesMacApplicationSupport() {
        let path = AppSettingsSnapshot.defaultPaddlePaddlePath(
            environment: [:],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        XCTAssertEqual("/Users/example/Library/Application Support/snaptex/PaddlePaddle", path)
    }

    func testDefaultPaddlePaddlePathHonorsEnvironmentOverride() {
        let path = AppSettingsSnapshot.defaultPaddlePaddlePath(
            environment: ["SNAPTEX_PADDLEPADDLE_DIR": "~/snaptex/PaddlePaddle"],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        XCTAssertEqual("/Users/example/snaptex/PaddlePaddle", path)
    }

    func testModelVariantDetectsInstalledModelLayouts() throws {
        let root = try makeTemporaryDirectory()

        let model = OCRModelSelection(provider: .uniMERNet, size: .medium)
        XCTAssertFalse(model.isInstalled(in: root.path))

        let nestedModel = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_small")
            .appendingPathComponent("pytorch_model.bin")
        try FileManager.default.createDirectory(
            at: nestedModel.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: nestedModel.path, contents: Data())

        XCTAssertTrue(model.isInstalled(in: root.path))
    }

    func testModelVariantUsesStructuredModelDirectories() throws {
        let root = try makeTemporaryDirectory()
        let uniMERNetModel = OCRModelSelection(provider: .uniMERNet, size: .medium)
        let paddleModel = OCRModelSelection(provider: .paddlePaddle, size: .large)

        XCTAssertEqual(
            root
                .appendingPathComponent("models")
                .appendingPathComponent("unimernet")
                .appendingPathComponent("m"),
            uniMERNetModel.modelDirectory(in: root.path)
        )
        XCTAssertEqual(
            root
                .appendingPathComponent("models")
                .appendingPathComponent("paddlepaddle")
                .appendingPathComponent("official_models")
                .appendingPathComponent("PP-FormulaNet_plus-L"),
            paddleModel.modelDirectory(in: root.path)
        )
    }

    func testModelVariantDetectsStructuredInstalledModelLayout() throws {
        let root = try makeTemporaryDirectory()
        let model = OCRModelSelection(provider: .uniMERNet, size: .large)
        let modelFile = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet")
            .appendingPathComponent("l")
            .appendingPathComponent("pytorch_model.pth")
        try FileManager.default.createDirectory(
            at: modelFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        XCTAssertTrue(model.isInstalled(in: root.path))
    }

    func testModelVariantDetectsHuggingFacePytorchModelPTHLayout() throws {
        let root = try makeTemporaryDirectory()
        let model = OCRModelSelection(provider: .uniMERNet, size: .large)
        let modelFile = root
            .appendingPathComponent("models")
            .appendingPathComponent("unimernet_base")
            .appendingPathComponent("pytorch_model.pth")
        try FileManager.default.createDirectory(
            at: modelFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: modelFile.path, contents: Data())

        XCTAssertTrue(model.isInstalled(in: root.path))
    }

    func testPaddlePaddleModelsDoNotRequireManagedFiles() throws {
        let root = try makeTemporaryDirectory()
        let model = OCRModelSelection(provider: .paddlePaddle, size: .large)

        XCTAssertFalse(model.requiresManagedFiles)
        XCTAssertFalse(model.isInstalled(in: root.path))
        XCTAssertEqual("PP-FormulaNet_plus-L", model.workerModelName)
    }

    func testModelProvidersExposeRepositoryURLs() {
        XCTAssertEqual(URL(string: "https://github.com/opendatalab"), OCRModelProvider.uniMERNet.repositoryURL)
        XCTAssertEqual(URL(string: "https://github.com/PaddlePaddle"), OCRModelProvider.paddlePaddle.repositoryURL)
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
        XCTAssertTrue(settings.isHistoryLimitEnabled)
        XCTAssertEqual(32, settings.historyLimit)
        XCTAssertEqual(OCRModelSelection(provider: .uniMERNet, size: .medium), settings.modelVariant)
        XCTAssertEqual(.defaultSnip, settings.snipShortcut)
        XCTAssertEqual(.defaultOpenApp, settings.openAppShortcut)
        XCTAssertEqual(12, settings.historyTitleFontSize)
        XCTAssertEqual(14, settings.labelFontSize)
        XCTAssertEqual(15, settings.paneTitleFontSize)
        XCTAssertEqual(12, settings.toolbarFontSize)
        XCTAssertEqual(11, settings.metadataFontSize)
        XCTAssertEqual(15, settings.latexEditorFontSize)
        XCTAssertEqual(.monospaced, settings.latexEditorFontFamily)
        XCTAssertEqual(.normal, settings.logVerbosity)
        XCTAssertTrue(
            settings.paddlePaddlePath.hasSuffix("/Library/Application Support/snaptex/PaddlePaddle"),
            settings.paddlePaddlePath
        )

        let encodedData = try JSONEncoder().encode(settings)
        let encodedPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        XCTAssertEqual(20, encodedPayload["snipButtonFontSize"] as? Int)
        XCTAssertEqual(settings.paddlePaddlePath, encodedPayload["paddlePaddlePath"] as? String)
    }

    func testDecodedSettingsRepairMissingLegacyWorkerScriptPath() throws {
        let root = try makeTemporaryDirectory()
        let bundledWorker = root
            .appendingPathComponent("Resources")
            .appendingPathComponent("python/snaptex_worker/worker.py")
        try FileManager.default.createDirectory(
            at: bundledWorker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: bundledWorker.path, contents: Data())

        let repairedPath = AppSettingsSnapshot.resolvedWorkerScriptPath(
            savedPath: "/Applications/snaptex.app/Contents/Resources/python/unimer_latex_ocr/worker.py",
            fileManager: .default,
            resourceDirectory: root.appendingPathComponent("Resources")
        )

        XCTAssertEqual(bundledWorker.path, repairedPath)
    }

    func testDecodedSettingsPreserveExistingCustomWorkerScriptPath() throws {
        let root = try makeTemporaryDirectory()
        let customWorker = root.appendingPathComponent("worker.py")
        FileManager.default.createFile(atPath: customWorker.path, contents: Data())

        let repairedPath = AppSettingsSnapshot.resolvedWorkerScriptPath(
            savedPath: customWorker.path,
            fileManager: .default,
            resourceDirectory: nil
        )

        XCTAssertEqual(customWorker.path, repairedPath)
    }

    func testSettingsPersistLogVerbosity() throws {
        var settings = AppSettingsSnapshot.default
        settings.logVerbosity = .debug

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)

        XCTAssertEqual(.debug, decoded.logVerbosity)
    }

    func testSettingsPersistLabelFontSize() throws {
        var settings = AppSettingsSnapshot.default
        settings.labelFontSize = 18
        settings.paneTitleFontSize = 17
        settings.toolbarFontSize = 15
        settings.metadataFontSize = 10

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)

        XCTAssertEqual(18, decoded.labelFontSize)
        XCTAssertEqual(17, decoded.paneTitleFontSize)
        XCTAssertEqual(15, decoded.toolbarFontSize)
        XCTAssertEqual(10, decoded.metadataFontSize)
    }

    func testSettingsPersistSnipButtonFontSize() throws {
        let json = """
        {
          "condaPath": "conda",
          "environmentName": "snaptex",
          "uniMERNetPath": "/tmp/UniMERNet",
          "modelVariant": "small",
          "recognitionMode": "balanced",
          "outputFormat": "raw",
          "autoCopyAfterRecognition": false,
          "historyLimit": 32,
          "snipButtonFontSize": 19,
          "workerScriptPath": "/tmp/worker.py"
        }
        """

        let settings = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data(json.utf8))
        let data = try JSONEncoder().encode(settings)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(19, payload["snipButtonFontSize"] as? Int)
    }

    func testEncodedSettingsPreserveUnlimitedHistoryMode() throws {
        var settings = AppSettingsSnapshot.default
        settings.isHistoryLimitEnabled = false
        settings.historyLimit = 64

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettingsSnapshot.self, from: data)

        XCTAssertFalse(decoded.isHistoryLimitEnabled)
        XCTAssertEqual(64, decoded.historyLimit)
    }

    func testDecodedSettingsMigrateLegacyBaseVariantToLargeUniMERNetSelection() throws {
        let json = """
        {
          "condaPath": "conda",
          "environmentName": "snaptex",
          "uniMERNetPath": "/tmp/UniMERNet",
          "modelVariant": "base",
          "recognitionMode": "balanced",
          "outputFormat": "raw",
          "autoCopyAfterRecognition": false,
          "historyLimit": 32,
          "workerScriptPath": "/tmp/worker.py"
        }
        """

        let settings = try JSONDecoder().decode(AppSettingsSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(OCRModelSelection(provider: .uniMERNet, size: .large), settings.modelVariant)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
