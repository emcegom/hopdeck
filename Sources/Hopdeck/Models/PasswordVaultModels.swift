import Foundation

enum PasswordVaultMode: String, Codable, Hashable {
    case plain
}

struct PasswordVaultItem: Codable, Hashable {
    var username: String
    var password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

struct PasswordVaultDocument: Codable, Hashable {
    var version: Int
    var mode: PasswordVaultMode
    var items: [String: PasswordVaultItem]

    init(version: Int = 1, mode: PasswordVaultMode = .plain, items: [String: PasswordVaultItem] = [:]) {
        self.version = version
        self.mode = mode
        self.items = items
    }
}
