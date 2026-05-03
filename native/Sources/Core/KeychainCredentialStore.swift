import Foundation
import Security

public struct CredentialRef: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case password
        case keyPassphrase
        case agent
        case ask
        case none
    }

    public var kind: Kind
    public var account: String?

    public init(kind: Kind, account: String? = nil) {
        self.kind = kind
        self.account = account
    }
}

public enum KeychainCredentialError: Error, Equatable {
    case encodingFailed
    case notFound
    case unexpectedStatus(OSStatus)
}

public final class KeychainCredentialStore {
    public let service: String

    public init(service: String = "com.emcegom.hopdeck") {
        self.service = service
    }

    public func accountForHostPassword(hostID: UUID) -> String {
        "host:\(hostID.uuidString):password"
    }

    public func setPassword(_ password: String, account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainCredentialError.encodingFailed
        }

        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrLabel as String: "Hopdeck",
            kSecAttrComment as String: "Hopdeck SSH credential"
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainCredentialError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainCredentialError.unexpectedStatus(status)
    }

    public func password(account: String) throws -> String {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainCredentialError.notFound
        }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainCredentialError.unexpectedStatus(status)
        }
        return value
    }

    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainCredentialError.unexpectedStatus(status)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}
