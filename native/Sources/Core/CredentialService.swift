import Foundation

public final class CredentialService {
    private let keychain: KeychainCredentialStore

    public init(keychain: KeychainCredentialStore = KeychainCredentialStore()) {
        self.keychain = keychain
    }

    public func hostPasswordAccount(hostID: UUID) -> String {
        keychain.accountForHostPassword(hostID: hostID)
    }

    public func hostWithStoredPassword(_ host: SSHHost, password: String) throws -> SSHHost {
        let account = hostPasswordAccount(hostID: host.id)
        try keychain.setPassword(password, account: account)
        var updatedHost = host
        updatedHost.credential = CredentialRef(kind: .password, account: account)
        return updatedHost
    }

    public func password(for host: SSHHost) throws -> String {
        guard host.credential.kind == .password, let account = host.credential.account else {
            throw KeychainCredentialError.notFound
        }
        return try keychain.password(account: account)
    }

    public func removeCredential(for host: SSHHost) throws -> SSHHost {
        if let account = host.credential.account {
            try keychain.delete(account: account)
        }
        var updatedHost = host
        updatedHost.credential = CredentialRef(kind: .ask)
        return updatedHost
    }
}
