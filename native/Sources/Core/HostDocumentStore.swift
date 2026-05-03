import Foundation

public struct HostFolder: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var hostIDs: [UUID]

    public init(id: UUID, name: String, hostIDs: [UUID]) {
        self.id = id
        self.name = name
        self.hostIDs = hostIDs
    }
}

public struct NativeHostDocument: Codable, Equatable {
    public var version: Int
    public var folders: [HostFolder]
    public var hosts: [SSHHost]

    public init(version: Int = 1, folders: [HostFolder] = [], hosts: [SSHHost] = []) {
        self.version = version
        self.folders = folders
        self.hosts = hosts
    }
}

public final class HostDocumentStore {
    public let documentURL: URL

    public init(documentURL: URL = HostDocumentStore.defaultDocumentURL()) {
        self.documentURL = documentURL
    }

    public static func defaultDocumentURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hopdeck", isDirectory: true).appendingPathComponent("hosts.json")
    }

    public func load() throws -> NativeHostDocument {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return NativeHostDocument()
        }

        let data = try Data(contentsOf: documentURL)
        return try JSONDecoder().decode(NativeHostDocument.self, from: data)
    }

    public func save(_ document: NativeHostDocument) throws {
        let directory = documentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: documentURL, options: .atomic)
    }
}

public enum LegacyHopdeckImport {
    public static func importHosts(from url: URL) throws -> [SSHHost] {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            return []
        }

        if let hosts = root["hosts"] as? [[String: Any]] {
            return hosts.compactMap(parseHost)
        }

        if let hostMap = root["hosts"] as? [String: Any] {
            return hostMap.compactMap { _, value in
                guard let host = value as? [String: Any] else {
                    return nil
                }
                return parseHost(host)
            }
        }

        return []
    }

    private static func parseHost(_ raw: [String: Any]) -> SSHHost? {
        let alias = string(raw["alias"]) ?? string(raw["name"]) ?? string(raw["label"])
        let address = string(raw["address"]) ?? string(raw["host"]) ?? string(raw["hostname"])
        let user = string(raw["user"]) ?? string(raw["username"]) ?? NSUserName()
        let port = int(raw["port"]) ?? 22

        guard let alias, let address, !alias.isEmpty, !address.isEmpty else {
            return nil
        }

        return SSHHost(
            id: UUID(uuidString: string(raw["id"]) ?? "") ?? UUID(),
            alias: alias,
            address: address,
            user: user,
            port: port,
            jumpChain: [],
            tags: stringArray(raw["tags"])
        )
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func int(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        value as? [String] ?? []
    }
}
