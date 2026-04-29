import Foundation

struct HostStore {
    var configURL: URL

    init(configURL: URL = HostStore.defaultConfigURL) {
        self.configURL = configURL
    }

    func loadHosts() throws -> [SSHHost] {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return SSHHost.samples
        }

        let data = try Data(contentsOf: configURL)
        guard !data.isEmpty else {
            return []
        }

        if let config = try? HostStore.decoder.decode(HopdeckConfig.self, from: data) {
            return config.hosts
        }

        return try HostStore.decoder.decode([SSHHost].self, from: data)
    }

    func saveHosts(_ hosts: [SSHHost]) throws {
        try ensureConfigDirectory()

        let config = HopdeckConfig(hosts: hosts)
        let data = try HostStore.encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func upsertHost(_ host: SSHHost) throws -> [SSHHost] {
        var hosts = try loadHosts()

        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }

        try saveHosts(hosts)
        return hosts
    }

    func deleteHost(id: SSHHost.ID) throws -> [SSHHost] {
        var hosts = try loadHosts()
        hosts.removeAll { $0.id == id }
        try saveHosts(hosts)
        return hosts
    }

    private func ensureConfigDirectory() throws {
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}

extension HostStore {
    static var defaultConfigDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hopdeck", isDirectory: true)
    }

    static var defaultConfigURL: URL {
        defaultConfigDirectoryURL
            .appendingPathComponent("hosts.json", isDirectory: false)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
