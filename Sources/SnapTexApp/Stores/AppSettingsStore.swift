import Foundation
import SnapTexCore

struct AppSettingsStore {
    private let key = "AppSettingsSnapshot"
    let defaults: UserDefaults

    var usesStandardDefaults: Bool {
        defaults === UserDefaults.standard
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettingsSnapshot {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettingsSnapshot.self, from: data) else {
            return .default
        }

        if let repairedData = try? JSONEncoder().encode(settings),
           repairedData != data {
            defaults.set(repairedData, forKey: key)
        }

        return settings
    }

    func save(_ settings: AppSettingsSnapshot) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }

}
