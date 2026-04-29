import Foundation

struct SSHConfigParser {
    func parse(_ text: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentAliases: [String] = []
        var fields: [String: String] = [:]

        func flush() {
            guard !currentAliases.isEmpty else {
                return
            }

            for alias in currentAliases where !alias.contains("*") && !alias.contains("?") {
                let hostName = fields["hostname"] ?? alias
                let user = fields["user"] ?? NSUserName()
                let port = Int(fields["port"] ?? "") ?? 22
                let proxyJump = fields["proxyjump"]
                let jumpChain = proxyJump?
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? []

                hosts.append(
                    SSHHost(
                        id: alias,
                        alias: alias,
                        host: hostName,
                        user: user,
                        port: port,
                        group: jumpChain.isEmpty ? "Imported" : "Imported Jump",
                        tags: [],
                        jumpChain: jumpChain,
                        auth: AuthConfig(type: .agent, passwordRef: nil, autoLogin: false),
                        notes: "Imported from ~/.ssh/config",
                        lastConnectedAt: nil
                    )
                )
            }
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard let keyPart = parts.first else {
                continue
            }

            let key = keyPart.lowercased()
            let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            if key == "host" {
                flush()
                currentAliases = value
                    .split(whereSeparator: { $0 == " " || $0 == "\t" })
                    .map(String.init)
                fields = [:]
            } else if !currentAliases.isEmpty {
                fields[key] = value
            }
        }

        flush()
        return hosts
    }
}
