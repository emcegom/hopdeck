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
    expect(manager.sessions.map(\.id) == [second.id], "close should remove only the closed session")
}

print("HopdeckNativeCoreChecks passed")

let temporaryDocumentURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("hopdeck-native-checks-\(UUID().uuidString)")
    .appendingPathComponent("hosts.json")
let store = HostDocumentStore(documentURL: temporaryDocumentURL)
let document = NativeHostDocument(hosts: [host])
try store.save(document)
let loaded = try store.load()
expect(loaded.hosts == [host], "host document should round trip through JSON store")

if ProcessInfo.processInfo.environment["HOPDECK_RUN_KEYCHAIN_CHECKS"] == "1" {
    let keychain = KeychainCredentialStore(service: "com.emcegom.hopdeck.checks")
    let account = "check:\(UUID().uuidString)"
    try keychain.setPassword("hopdeck-check-secret", account: account)
    let password = try keychain.password(account: account)
    expect(password == "hopdeck-check-secret", "keychain password should round trip")
    try keychain.delete(account: account)
}

print("HopdeckNative storage checks passed")
