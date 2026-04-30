import Foundation

struct ResolvedSSHCommand: Equatable {
    var command: String
    var jumpSpecs: [String]
    var targetSpec: String
}

enum SSHCommandBuilderError: LocalizedError, Equatable {
    case missingHost(String)

    var errorDescription: String? {
        switch self {
        case .missingHost(let alias):
            return "Missing jump host: \(alias)"
        }
    }
}

struct SSHCommandBuilder {
    func buildCommand(for host: SSHHost, allHosts: [SSHHost]) throws -> ResolvedSSHCommand {
        let jumpSpecs = try JumpChainResolver()
            .resolve(host.jumpChain, allHosts: allHosts)
            .specs

        let targetSpec = "\(host.user)@\(host.host)"
        var parts = ["ssh"]

        if !jumpSpecs.isEmpty {
            parts.append("-J")
            parts.append(ShellEscaper.escape(jumpSpecs.joined(separator: ",")))
        }

        parts.append(ShellEscaper.escape(targetSpec))
        parts.append("-p")
        parts.append(String(host.port))

        return ResolvedSSHCommand(
            command: parts.joined(separator: " "),
            jumpSpecs: jumpSpecs,
            targetSpec: targetSpec
        )
    }
}

enum ShellEscaper {
    static func escape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
