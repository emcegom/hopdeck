import Foundation

public struct SSHHost: Codable, Identifiable, Hashable {
    public let id: UUID
    public var alias: String
    public var address: String
    public var user: String
    public var port: Int
    public var jumpChain: [UUID]
    public var tags: [String]

    public var credential: CredentialRef

    public init(
        id: UUID,
        alias: String,
        address: String,
        user: String,
        port: Int,
        jumpChain: [UUID],
        tags: [String],
        credential: CredentialRef = CredentialRef(kind: .ask)
    ) {
        self.id = id
        self.alias = alias
        self.address = address
        self.user = user
        self.port = port
        self.jumpChain = jumpChain
        self.tags = tags
        self.credential = credential
    }

    public var displayAddress: String {
        "\(user)@\(address):\(port)"
    }
}

public struct TerminalSession: Identifiable {
    public enum State: Equatable {
        case idle
        case running
        case closing
        case exited(Int32?)
    }

    public let id: UUID
    public let host: SSHHost?
    public let title: String
    public var state: State

    public init(id: UUID, host: SSHHost?, title: String, state: State) {
        self.id = id
        self.host = host
        self.title = title
        self.state = state
    }
}

public enum ConnectionTarget: Equatable {
    case localShell
    case ssh(SSHHost)
}
