import Foundation

struct PasswordVault {
    var vaultURL: URL

    init(vaultURL: URL = PasswordVault.defaultVaultURL) {
        self.vaultURL = vaultURL
    }

    func load() throws -> PasswordVaultDocument {
        guard FileManager.default.fileExists(atPath: vaultURL.path) else {
            return PasswordVaultDocument()
        }

        let data = try Data(contentsOf: vaultURL)
        guard !data.isEmpty else {
            return PasswordVaultDocument()
        }

        return try PasswordVault.decoder.decode(PasswordVaultDocument.self, from: data)
    }

    func save(_ document: PasswordVaultDocument) throws {
        guard document.mode == .plain else {
            throw PasswordVaultError.unsupportedMode(document.mode.rawValue)
        }

        try ensureVaultDirectory()

        let data = try PasswordVault.encoder.encode(document)
        try data.write(to: vaultURL, options: .atomic)
        try setOwnerOnlyPermissions(at: vaultURL)
    }

    func item(for passwordRef: String) throws -> PasswordVaultItem? {
        let document = try load()
        return document.items[passwordRef]
    }

    func password(for passwordRef: String) throws -> String? {
        try item(for: passwordRef)?.password
    }

    func setItem(_ item: PasswordVaultItem, for passwordRef: String) throws {
        var document = try load()
        document.items[passwordRef] = item
        try save(document)
    }

    func removeItem(for passwordRef: String) throws {
        var document = try load()
        document.items.removeValue(forKey: passwordRef)
        try save(document)
    }

    private func ensureVaultDirectory() throws {
        try FileManager.default.createDirectory(
            at: vaultURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func setOwnerOnlyPermissions(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}

extension PasswordVault {
    static var defaultVaultDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hopdeck", isDirectory: true)
    }

    static var defaultVaultURL: URL {
        defaultVaultDirectoryURL
            .appendingPathComponent("vault.json", isDirectory: false)
    }

    private static let decoder = JSONDecoder()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

enum PasswordVaultError: LocalizedError, Equatable {
    case unsupportedMode(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMode(let mode):
            return "Unsupported password vault mode: \(mode)"
        }
    }
}
