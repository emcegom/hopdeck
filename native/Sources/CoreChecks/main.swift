import Foundation
import HopdeckNativeCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("check failed: \(message)\n", stderr)
        exit(1)
    }
}

let shell = OpenSSHCommandBuilder().build(target: .localShell)
expect(!shell.executable.isEmpty, "local shell executable should not be empty")
expect(shell.arguments.isEmpty, "local shell should use execName instead of -l argv")
expect(shell.execName?.hasPrefix("-") == true, "local shell execName should request login shell")
expect(!shell.currentDirectory.isEmpty, "local shell should have a working directory")

let host = SSHHost(
    id: UUID(),
    alias: "prod",
    address: "10.0.1.20",
    user: "app",
    port: 2222,
    jumpChain: [],
    tags: []
)

let ssh = OpenSSHCommandBuilder().build(target: .ssh(host))
expect(ssh.executable == "/usr/bin/ssh", "ssh executable should be system OpenSSH")
expect(
    ssh.arguments == [
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=10",
        "-tt",
        "-p", "2222",
        "app@10.0.1.20"
    ],
    "ssh argv should be structured and shell-free"
)
expect(ssh.execName == nil, "ssh should not override execName")
let credentialService = CredentialService(keychain: KeychainCredentialStore(service: "com.emcegom.hopdeck.checks"))
expect(
    credentialService.hostPasswordAccount(hostID: host.id) == "host:\(host.id.uuidString):password",
    "credential service should derive stable host password accounts"
)
let diagnostics = ConnectionDiagnosticsService().staticReport(for: host)
expect(diagnostics.hostID == host.id, "diagnostics should target the selected host")
expect(diagnostics.diagnostics.contains(where: { $0.title == "Command" }), "diagnostics should include command preview")
let releaseReport = UpdateService().localSpikeReport()
expect(!releaseReport.isReleaseReady, "local spike should not claim release readiness")

await MainActor.run {
    let manager = SessionManager()
    let first = manager.createSession(target: .localShell)
    let second = manager.createSession(target: .ssh(host))
    expect(manager.activeSessionID == second.id, "new sessions should become active")
    manager.activate(sessionID: first.id)
    expect(manager.activeSessionID == first.id, "activate should update active session")
    let closePlan = manager.closeActiveSession()
    expect(closePlan?.closedSessionID == first.id, "close should target the active session")
    expect(closePlan?.nextActiveSessionID == second.id, "close should select the remaining session")
    expect(closePlan?.shouldCloseWindow == false, "closing a session should not close the window")
    expect(manager.sessions.map(\.id) == [second.id], "close should remove only the closed session")
    let lastClosePlan = manager.closeActiveSession()
    expect(lastClosePlan?.closedSessionID == second.id, "last close should close the last session")
    expect(lastClosePlan?.nextActiveSessionID == nil, "last close should leave no active session")
    expect(lastClosePlan?.shouldCloseWindow == false, "closing the last session should keep the app open")
    expect(manager.sessions.isEmpty, "last close should leave an empty session list")
}

print("HopdeckNativeCoreChecks passed")

let temporaryDocumentURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("hopdeck-native-checks-\(UUID().uuidString)")
    .appendingPathComponent("hosts.json")
let temporaryDirectoryURL = temporaryDocumentURL.deletingLastPathComponent()
let store = HostDocumentStore(documentURL: temporaryDocumentURL)
let document = NativeHostDocument(hosts: [host])
try store.save(document)
let loaded = try store.load()
expect(loaded.hosts == [host], "host document should round trip through JSON store")

let inventoryStore = HostDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("inventory-hosts.json"))
let inventory = HostInventoryService(store: inventoryStore)
try inventory.upsert(host)
expect(inventory.hosts.contains(host), "inventory should upsert hosts")
try inventory.delete(hostID: host.id)
expect(!inventory.hosts.contains(where: { $0.id == host.id }), "inventory should delete hosts")

let settingsStore = SettingsDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("settings.json"))
var settings = NativeSettingsDocument()
settings.theme = .dark
settings.terminal.fontSize = 15
try settingsStore.save(settings)
let loadedSettings = try settingsStore.load()
expect(loadedSettings == settings, "settings document should round trip through JSON store")

let workspaceStore = WorkspaceDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("workspaces.json"))
let folderID = UUID()
let workspace = NativeWorkspaceDocument(
    layout: WorkspaceLayout(selectedHostID: host.id),
    folders: [WorkspaceFolder(id: folderID, name: "Production", hostIDs: [host.id])],
    smartViews: [SmartView(id: UUID(), name: "Favorites", predicate: .favorites)],
    connectionProfiles: [ConnectionProfile(id: UUID(), name: "Default SSH", defaultUser: "app")]
)
try workspaceStore.save(workspace)
let loadedWorkspace = try workspaceStore.load()
expect(loadedWorkspace == workspace, "workspace document should round trip through JSON store")

let legacyDirectoryURL = temporaryDirectoryURL.appendingPathComponent("legacy", isDirectory: true)
try FileManager.default.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
let legacyHostsURL = legacyDirectoryURL.appendingPathComponent("hosts.json")
let legacySettingsURL = legacyDirectoryURL.appendingPathComponent("settings.json")
let legacyHostsJSON = """
{
  "hosts": [
    {
      "id": "\(host.id.uuidString)",
      "alias": "prod",
      "host": "10.0.1.20",
      "user": "app",
      "port": 2222,
      "group": "Production",
      "tags": ["prod"]
    }
  ]
}
"""
try legacyHostsJSON.data(using: .utf8)!.write(to: legacyHostsURL)
let legacySettingsJSON = """
{
  "theme": "light",
  "terminal": {
    "fontSize": 16,
    "colors": {
      "background": "#000000",
      "ansi": ["#000000", "#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777", "#888888", "#999999", "#AAAAAA", "#BBBBBB", "#CCCCCC", "#DDDDDD", "#EEEEEE", "#FFFFFF"]
    }
  },
  "connection": {
    "autoLogin": false
  }
}
"""
try legacySettingsJSON.data(using: .utf8)!.write(to: legacySettingsURL)

let migration = MigrationService(
    hostStore: HostDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("migrated-hosts.json")),
    settingsStore: SettingsDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("migrated-settings.json")),
    workspaceStore: WorkspaceDocumentStore(documentURL: temporaryDirectoryURL.appendingPathComponent("migrated-workspaces.json"))
)
let migrationResult = try migration.importLegacyData(from: legacyDirectoryURL)
expect(migrationResult.importedHosts == 1, "migration should import legacy hosts")
expect(migrationResult.importedFolders == 1, "migration should preserve legacy host groups as folders")
expect(migrationResult.wroteSettings, "migration should write imported settings")
expect(migrationResult.wroteWorkspaces, "migration should write derived workspaces")
let migratedSettings = try migration.settingsStore.load()
expect(migratedSettings.theme == .light, "migration should import legacy settings values")

if ProcessInfo.processInfo.environment["HOPDECK_RUN_KEYCHAIN_CHECKS"] == "1" {
    let keychain = KeychainCredentialStore(service: "com.emcegom.hopdeck.checks")
    let account = "check:\(UUID().uuidString)"
    try keychain.setPassword("hopdeck-check-secret", account: account)
    let password = try keychain.password(account: account)
    expect(password == "hopdeck-check-secret", "keychain password should round trip")
    try keychain.delete(account: account)
}

print("HopdeckNative storage checks passed")
