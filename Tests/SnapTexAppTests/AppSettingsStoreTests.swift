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
}
