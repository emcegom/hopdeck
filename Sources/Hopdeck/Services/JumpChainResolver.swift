import Foundation

struct ResolvedJumpChain: Equatable {
    var aliases: [String]
    var specs: [String]
}

enum JumpChainResolverError: LocalizedError, Equatable {
    case missingHost(String)

    var errorDescription: String? {
        switch self {
        case .missingHost(let alias):
            return "Missing jump host: \(alias)"
        }
    }
}

struct JumpChainResolver {
    func resolve(_ aliases: [String], allHosts: [SSHHost]) throws -> ResolvedJumpChain {
        let specs = try aliases.map { alias in
            guard let host = allHosts.first(where: { $0.id == alias || $0.alias == alias }) else {
                throw JumpChainResolverError.missingHost(alias)
            }

            return "\(host.user)@\(host.host):\(host.port)"
        }

        return ResolvedJumpChain(aliases: aliases, specs: specs)
    }
}
