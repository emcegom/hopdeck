import Foundation

struct SSHHost: Identifiable, Hashable, Codable {
    var id: String
    var alias: String
    var host: String
    var user: String
    var port: Int
    var group: String
    var tags: [String]
    var jumpChain: [String]
    var auth: AuthConfig
    var notes: String
    var lastConnectedAt: Date?

    var displayAddress: String {
        "\(user)@\(host):\(port)"
    }

    var connectionKind: ConnectionKind {
        if jumpChain.count > 1 {
            return .multiHop
        }

        if jumpChain.count == 1 {
            return .jump
        }

        return .direct
    }
}

struct AuthConfig: Hashable, Codable {
    var type: AuthType
    var passwordRef: String?
    var autoLogin: Bool
}

enum AuthType: String, Hashable, Codable {
    case password
    case key
    case agent
    case none
}

enum ConnectionKind: String {
    case direct = "Direct"
    case jump = "Jump"
    case multiHop = "Multi-hop"
}

extension SSHHost {
    static let samples: [SSHHost] = [
        SSHHost(
            id: "jump-prod",
            alias: "jump-prod",
            host: "1.2.3.4",
            user: "zane",
            port: 22,
            group: "Jump Hosts",
            tags: ["jump", "prod"],
            jumpChain: [],
            auth: AuthConfig(type: .password, passwordRef: "password:jump-prod", autoLogin: true),
            notes: "Production jump host.",
            lastConnectedAt: nil
        ),
        SSHHost(
            id: "prod-app-01",
            alias: "prod-app-01",
            host: "10.0.1.20",
            user: "app",
            port: 22,
            group: "Production",
            tags: ["app", "prod"],
            jumpChain: ["jump-prod"],
            auth: AuthConfig(type: .password, passwordRef: "password:prod-app-01", autoLogin: true),
            notes: "Production application server.",
            lastConnectedAt: nil
        )
    ]
}
