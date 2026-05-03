import Foundation

public struct HostFolder: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var hostIDs: [UUID]

    public init(id: UUID, name: String, hostIDs: [UUID]) {
        self.id = id
        self.name = name
        self.hostIDs = hostIDs
    }
}

public struct NativeHostDocument: Codable, Equatable, Sendable {
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
        NativeDocumentPaths.documentURL(filename: "hosts.json")
    }

    public func load() throws -> NativeHostDocument {
        try NativeJSONDocumentStore.load(from: documentURL, defaultDocument: NativeHostDocument())
    }

    public func save(_ document: NativeHostDocument) throws {
        try NativeJSONDocumentStore.save(document, to: documentURL)
    }
}

public enum LegacyHopdeckImport {
    public static func defaultLegacyDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hopdeck", isDirectory: true)
    }

    public static func importHostDocument(from url: URL) throws -> NativeHostDocument {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            return NativeHostDocument()
        }

        let hosts = try importHosts(from: url)
        let folders = legacyFolders(from: root, hosts: hosts)
        return NativeHostDocument(version: 1, folders: folders, hosts: hosts)
    }

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

    public static func importSettings(from url: URL) throws -> NativeSettingsDocument {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            return NativeSettingsDocument()
        }

        var document = NativeSettingsDocument()
        if let version = int(root["version"]) {
            document.version = version
        }
        if let theme = string(root["theme"]), let mode = NativeThemeMode(rawValue: theme) {
            document.theme = mode
        }

        if let terminal = root["terminal"] as? [String: Any] {
            document.terminal.fontFamily = string(terminal["fontFamily"]) ?? document.terminal.fontFamily
            document.terminal.fontSize = int(terminal["fontSize"]) ?? document.terminal.fontSize
            document.terminal.fontWeight = string(terminal["fontWeight"]) ?? document.terminal.fontWeight
            document.terminal.fontWeightBold = string(terminal["fontWeightBold"]) ?? document.terminal.fontWeightBold
            document.terminal.lineHeight = double(terminal["lineHeight"]) ?? document.terminal.lineHeight
            document.terminal.letterSpacing = double(terminal["letterSpacing"]) ?? document.terminal.letterSpacing
            document.terminal.minimumContrastRatio = double(terminal["minimumContrastRatio"]) ?? document.terminal.minimumContrastRatio
            document.terminal.drawBoldTextInBrightColors = bool(terminal["drawBoldTextInBrightColors"]) ?? document.terminal.drawBoldTextInBrightColors
            document.terminal.cursorStyle = string(terminal["cursorStyle"]) ?? document.terminal.cursorStyle
            document.terminal.backgroundBlur = int(terminal["backgroundBlur"]) ?? document.terminal.backgroundBlur
            document.terminal.backgroundOpacity = int(terminal["backgroundOpacity"]) ?? document.terminal.backgroundOpacity
            document.terminal.autoCopySelection = bool(terminal["autoCopySelection"]) ?? document.terminal.autoCopySelection

            if let colors = terminal["colors"] as? [String: Any] {
                document.terminal.colors.background = string(colors["background"]) ?? document.terminal.colors.background
                document.terminal.colors.foreground = string(colors["foreground"]) ?? document.terminal.colors.foreground
                document.terminal.colors.cursor = string(colors["cursor"]) ?? document.terminal.colors.cursor
                document.terminal.colors.selection = string(colors["selection"]) ?? document.terminal.colors.selection
                let ansi = stringArray(colors["ansi"])
                if ansi.count == 16 {
                    document.terminal.colors.ansi = ansi
                }
            }
        }

        if let vault = root["vault"] as? [String: Any] {
            document.vault.mode = string(vault["mode"]) ?? document.vault.mode
            document.vault.clearClipboardAfterSeconds = int(vault["clearClipboardAfterSeconds"]) ?? document.vault.clearClipboardAfterSeconds
        }

        if let connection = root["connection"] as? [String: Any] {
            document.connection.defaultOpenMode = string(connection["defaultOpenMode"]) ?? document.connection.defaultOpenMode
            document.connection.autoLogin = bool(connection["autoLogin"]) ?? document.connection.autoLogin
            document.connection.closeTabOnDisconnect = bool(connection["closeTabOnDisconnect"]) ?? document.connection.closeTabOnDisconnect
        }

        return document
    }

    public static func importWorkspace(fromHostDocument document: NativeHostDocument) -> NativeWorkspaceDocument {
        NativeWorkspaceDocument(
            folders: document.folders.map { folder in
                WorkspaceFolder(id: folder.id, name: folder.name, hostIDs: folder.hostIDs)
            },
            smartViews: [
                SmartView(id: UUID(), name: "Favorites", predicate: .favorites),
                SmartView(id: UUID(), name: "Recent", predicate: .recent)
            ],
            connectionProfiles: [
                ConnectionProfile(id: UUID(), name: "Default SSH")
            ]
        )
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

    private static func legacyFolders(from root: [String: Any], hosts: [SSHHost]) -> [HostFolder] {
        guard let rawHosts = root["hosts"] as? [[String: Any]] else {
            return hosts.isEmpty ? [] : [HostFolder(id: UUID(), name: "Hosts", hostIDs: hosts.map(\.id))]
        }

        var hostsByAlias: [String: UUID] = [:]
        for host in hosts {
            hostsByAlias[host.alias] = host.id
        }
        let grouped = Dictionary(grouping: rawHosts) { rawHost in
            string(rawHost["group"])?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Hosts"
        }

        return grouped.keys.sorted().map { group in
            let ids = grouped[group, default: []].compactMap { rawHost -> UUID? in
                guard let alias = string(rawHost["alias"]) ?? string(rawHost["name"]) ?? string(rawHost["label"]) else {
                    return nil
                }
                return hostsByAlias[alias]
            }
            return HostFolder(id: UUID(), name: group, hostIDs: ids)
        }
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

    private static func double(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let stringValue = value as? String {
            return Double(stringValue)
        }
        return nil
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let stringValue = value as? String {
            return Bool(stringValue)
        }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        value as? [String] ?? []
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
