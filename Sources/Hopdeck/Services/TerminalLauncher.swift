import AppKit
import Foundation

enum TerminalLaunchError: Error, LocalizedError {
    case appleScriptFailed(String)
    case unsupportedBackend(TerminalBackend)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let message):
            return message
        case .unsupportedBackend(let backend):
            return "\(backend.label) is not implemented yet."
        case .processLaunchFailed(let message):
            return message
        }
    }
}

struct TerminalLauncher {
    var backend: TerminalBackend = .terminalApp
    var customTemplate: String = "{{command}}"

    func connect(to host: SSHHost, allHosts: [SSHHost]) throws {
        let resolved = try SSHCommandBuilder().buildCommand(for: host, allHosts: allHosts)
        try run(command: resolved.command)
    }

    func sshCommand(for host: SSHHost) -> String {
        if host.jumpChain.isEmpty {
            return "ssh \(shellEscaped("\(host.user)@\(host.host)")) -p \(host.port)"
        }

        let jump = host.jumpChain.joined(separator: ",")
        return "ssh -J \(shellEscaped(jump)) \(shellEscaped("\(host.user)@\(host.host)")) -p \(host.port)"
    }

    func run(command: String) throws {
        switch backend {
        case .terminalApp:
            try runInTerminalApp(command)
        case .iTerm2:
            try runIniTerm2(command)
        case .wezTerm:
            try launchProcess("/usr/bin/env", arguments: ["wezterm", "start", "--", "/bin/zsh", "-lc", command])
        case .ghostty:
            try launchProcess("/usr/bin/env", arguments: ["ghostty", "-e", "/bin/zsh", "-lc", command])
        case .alacritty:
            try launchProcess("/usr/bin/env", arguments: ["alacritty", "-e", "/bin/zsh", "-lc", command])
        case .kitty:
            try launchProcess("/usr/bin/env", arguments: ["kitty", "/bin/zsh", "-lc", command])
        case .custom:
            let rendered = customTemplate.replacingOccurrences(of: "{{command}}", with: command)
            try launchProcess("/bin/zsh", arguments: ["-lc", rendered])
        }
    }

    private func runInTerminalApp(_ command: String) throws {
        let script = """
        tell application "Terminal"
          activate
          do script "\(appleScriptEscaped(command))"
        end tell
        """

        try executeAppleScript(script)
    }

    private func runIniTerm2(_ command: String) throws {
        let script = """
        tell application "iTerm2"
          activate
          create window with default profile
          tell current session of current window
            write text "\(appleScriptEscaped(command))"
          end tell
        end tell
        """

        try executeAppleScript(script)
    }

    private func executeAppleScript(_ source: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw TerminalLaunchError.appleScriptFailed("Unable to create AppleScript.")
        }

        script.executeAndReturnError(&error)

        if let error {
            throw TerminalLaunchError.appleScriptFailed(error.description)
        }
    }

    private func launchProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            throw TerminalLaunchError.processLaunchFailed(error.localizedDescription)
        }
    }

    private func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
