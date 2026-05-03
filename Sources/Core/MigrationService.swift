import Foundation

public struct NativeMigrationResult: Equatable {
    public var importedHosts: Int
    public var importedFolders: Int
    public var importedSmartViews: Int
    public var wroteSettings: Bool
    public var wroteWorkspaces: Bool

    public init(
        importedHosts: Int = 0,
        importedFolders: Int = 0,
        importedSmartViews: Int = 0,
        wroteSettings: Bool = false,
        wroteWorkspaces: Bool = false
    ) {
        self.importedHosts = importedHosts
        self.importedFolders = importedFolders
        self.importedSmartViews = importedSmartViews
        self.wroteSettings = wroteSettings
        self.wroteWorkspaces = wroteWorkspaces
    }
}

public final class MigrationService {
    public let hostStore: HostDocumentStore
    public let settingsStore: SettingsDocumentStore
    public let workspaceStore: WorkspaceDocumentStore

    public init(
        hostStore: HostDocumentStore = HostDocumentStore(),
        settingsStore: SettingsDocumentStore = SettingsDocumentStore(),
        workspaceStore: WorkspaceDocumentStore = WorkspaceDocumentStore()
    ) {
        self.hostStore = hostStore
        self.settingsStore = settingsStore
        self.workspaceStore = workspaceStore
    }

    public func importLegacyData(from legacyDirectory: URL = LegacyHopdeckImport.defaultLegacyDirectory()) throws -> NativeMigrationResult {
        var result = NativeMigrationResult()
        let fileManager = FileManager.default

        let legacyHostsURL = legacyDirectory.appendingPathComponent("hosts.json")
        if fileManager.fileExists(atPath: legacyHostsURL.path) {
            let hostDocument = try LegacyHopdeckImport.importHostDocument(from: legacyHostsURL)
            try hostStore.save(hostDocument)
            result.importedHosts = hostDocument.hosts.count
            result.importedFolders = hostDocument.folders.count

            let workspaceDocument = LegacyHopdeckImport.importWorkspace(fromHostDocument: hostDocument)
            try workspaceStore.save(workspaceDocument)
            result.importedSmartViews = workspaceDocument.smartViews.count
            result.wroteWorkspaces = true
        }

        let legacySettingsURL = legacyDirectory.appendingPathComponent("settings.json")
        if fileManager.fileExists(atPath: legacySettingsURL.path) {
            let settingsDocument = try LegacyHopdeckImport.importSettings(from: legacySettingsURL)
            try settingsStore.save(settingsDocument)
            result.wroteSettings = true
        }

        return result
    }
}
