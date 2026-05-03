import Foundation

public enum DiagnosticState: String, Codable, Equatable, Sendable {
    case pending
    case passed
    case warning
    case failed
}

public struct ConnectionDiagnostic: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var state: DiagnosticState

    public init(id: UUID = UUID(), title: String, detail: String, state: DiagnosticState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct ConnectionDiagnosticsReport: Codable, Equatable, Sendable {
    public var hostID: UUID
    public var commandPreview: String
    public var diagnostics: [ConnectionDiagnostic]

    public init(hostID: UUID, commandPreview: String, diagnostics: [ConnectionDiagnostic]) {
        self.hostID = hostID
        self.commandPreview = commandPreview
        self.diagnostics = diagnostics
    }
}

public struct ConnectionDiagnosticsService {
    private let commandBuilder: OpenSSHCommandBuilder

    public init(commandBuilder: OpenSSHCommandBuilder = OpenSSHCommandBuilder()) {
        self.commandBuilder = commandBuilder
    }

    public func staticReport(for host: SSHHost) -> ConnectionDiagnosticsReport {
        let command = commandBuilder.displayCommand(for: .ssh(host))
        return ConnectionDiagnosticsReport(
            hostID: host.id,
            commandPreview: command,
            diagnostics: [
                ConnectionDiagnostic(
                    title: "Target",
                    detail: host.displayAddress,
                    state: host.address.isEmpty ? .failed : .passed
                ),
                ConnectionDiagnostic(
                    title: "Credential",
                    detail: credentialDetail(for: host.credential),
                    state: credentialState(for: host.credential)
                ),
                ConnectionDiagnostic(
                    title: "Jump Chain",
                    detail: host.jumpChain.isEmpty ? "Direct connection" : "\(host.jumpChain.count) jump hosts",
                    state: .pending
                ),
                ConnectionDiagnostic(
                    title: "Command",
                    detail: command,
                    state: .passed
                )
            ]
        )
    }

    private func credentialDetail(for credential: CredentialRef) -> String {
        switch credential.kind {
        case .password:
            return credential.account == nil ? "Password credential missing account" : "Password stored in Keychain account"
        case .keyPassphrase:
            return "Key passphrase stored in Keychain"
        case .agent:
            return "Use SSH agent"
        case .ask:
            return "Ask during connection"
        case .none:
            return "No credential configured"
        }
    }

    private func credentialState(for credential: CredentialRef) -> DiagnosticState {
        switch credential.kind {
        case .password, .keyPassphrase:
            return credential.account == nil ? .warning : .passed
        case .agent, .ask:
            return .pending
        case .none:
            return .warning
        }
    }
}
