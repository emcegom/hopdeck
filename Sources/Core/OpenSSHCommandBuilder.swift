import Foundation

public struct OpenSSHCommandBuilder {
    public init() {}

    public func build(target: ConnectionTarget) -> (
        executable: String,
        arguments: [String],
        execName: String?,
        currentDirectory: String
    ) {
        switch target {
        case .localShell:
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let execName = "-" + URL(fileURLWithPath: shell).lastPathComponent
            return (shell, [], execName, NSHomeDirectory())
        case .ssh(let host):
            return (
                "/usr/bin/ssh",
                [
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=10",
                    "-tt",
                    "-p", String(host.port),
                    "\(host.user)@\(host.address)"
                ],
                nil,
                NSHomeDirectory()
            )
        }
    }

    public func displayCommand(for target: ConnectionTarget) -> String {
        let command = build(target: target)
        return ([command.executable] + command.arguments).map(shellQuote).joined(separator: " ")
    }

    public func processCommand(for target: ConnectionTarget) -> TerminalProcessCommand {
        let command = build(target: target)
        return TerminalProcessCommand(
            executable: command.executable,
            arguments: command.arguments,
            execName: command.execName,
            currentDirectory: command.currentDirectory
        )
    }

    private func shellQuote(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
