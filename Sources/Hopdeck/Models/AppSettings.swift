import Foundation

struct AppSettings: Codable, Hashable {
    var version: Int
    var defaultTerminal: TerminalBackend
    var customTerminalTemplate: String
    var clipboardClearSeconds: Int
    var passwordStorageMode: PasswordVaultMode
    var autoLoginEnabled: Bool

    init(
        version: Int = 1,
        defaultTerminal: TerminalBackend = .terminalApp,
        customTerminalTemplate: String = "{{command}}",
        clipboardClearSeconds: Int = 30,
        passwordStorageMode: PasswordVaultMode = .plain,
        autoLoginEnabled: Bool = true
    ) {
        self.version = version
        self.defaultTerminal = defaultTerminal
        self.customTerminalTemplate = customTerminalTemplate
        self.clipboardClearSeconds = clipboardClearSeconds
        self.passwordStorageMode = passwordStorageMode
        self.autoLoginEnabled = autoLoginEnabled
    }
}
