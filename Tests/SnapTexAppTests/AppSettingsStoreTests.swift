import XCTest
import SnapTexCore
@testable import SnapTexApp

final class AppSettingsStoreTests: XCTestCase {
    func testLoadPreservesSnaptexEnvironmentName() throws {
        let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var settings = AppSettingsSnapshot.default
        settings.environmentName = "snaptex"
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: "AppSettingsSnapshot")

        let loaded = AppSettingsStore(defaults: defaults).load()

        XCTAssertEqual("snaptex", loaded.environmentName)
    }

    func testLoadPersistsRepairedWorkerScriptPath() throws {
        let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let json = """
        {
          "condaPath": "conda",
          "environmentName": "snaptex",
          "uniMERNetPath": "/tmp/UniMERNet",
          "modelVariant": "small",
          "recognitionMode": "balanced",
          "outputFormat": "raw",
          "validateRender": true,
          "autoCopyAfterRecognition": false,
          "historyLimit": 40,
          "historyTitleFontSize": 13,
          "latexEditorFontSize": 14,
          "latexEditorFontFamily": "monospaced",
          "logVerbosity": "normal",
          "workerScriptPath": "/Applications/snaptex.app/Contents/Resources/python/unimer_latex_ocr/worker.py"
        }
        """
        defaults.set(Data(json.utf8), forKey: "AppSettingsSnapshot")

        let loaded = AppSettingsStore(defaults: defaults).load()
        let savedData = try XCTUnwrap(defaults.data(forKey: "AppSettingsSnapshot"))
        let savedPayload = try XCTUnwrap(String(data: savedData, encoding: .utf8))

        XCTAssertTrue(loaded.workerScriptPath.hasSuffix("python/snaptex_worker/worker.py"))
        XCTAssertTrue(savedPayload.contains("python\\/snaptex_worker\\/worker.py"), savedPayload)
        XCTAssertFalse(savedPayload.contains("python\\/unimer_latex_ocr\\/worker.py"), savedPayload)
    }
}
