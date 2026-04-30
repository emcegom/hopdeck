import Foundation

struct AppSettingsStore {
    var settingsURL: URL

    init(settingsURL: URL = AppSettingsStore.defaultSettingsURL) {
        self.settingsURL = settingsURL
    }

    func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return AppSettings()
        }

        let data = try Data(contentsOf: settingsURL)
        guard !data.isEmpty else {
            return AppSettings()
        }

        return try AppSettingsStore.decoder.decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let data = try AppSettingsStore.encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }
}

extension AppSettingsStore {
    static var defaultSettingsURL: URL {
        HostStore.defaultConfigDirectoryURL
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    private static let decoder = JSONDecoder()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
