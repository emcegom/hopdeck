import Foundation

struct AutoLoginCredentials: Equatable {
    var passwordRef: String
    var password: String
}

enum AutoLoginRunnerError: LocalizedError, Equatable {
    case unableToWriteRunner

    var errorDescription: String? {
        switch self {
        case .unableToWriteRunner:
            return "Unable to create the temporary auto-login runner."
        }
    }
}

struct AutoLoginRunner {
    var temporaryDirectory: URL = FileManager.default.temporaryDirectory

    func makeCommand(sshCommand: String, credentials: [AutoLoginCredentials]) throws -> String {
        let script = scriptSource(sshCommand: sshCommand, credentials: credentials)
        let fileName = "hopdeck-\(UUID().uuidString).expect"
        let scriptURL = temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: scriptURL.path)
        } catch {
            throw AutoLoginRunnerError.unableToWriteRunner
        }

        return "/usr/bin/expect \(ShellEscaper.escape(scriptURL.path))"
    }

    func scriptSource(sshCommand: String, credentials: [AutoLoginCredentials]) -> String {
        let escapedCommand = tclEscaped(sshCommand)
        let passwords = credentials
            .map { "\"\(tclEscaped($0.password))\"" }
            .joined(separator: " ")

        return """
        #!/usr/bin/expect -f
        set timeout -1
        log_user 1
        set hopdeck_passwords [list \(passwords)]
        set hopdeck_password_index 0
        spawn /bin/zsh -lc "\(escapedCommand)"
        expect {
            -re "(?i)password:" {
                if {$hopdeck_password_index < [llength $hopdeck_passwords]} {
                    set hopdeck_password [lindex $hopdeck_passwords $hopdeck_password_index]
                    incr hopdeck_password_index
                    send -- "$hopdeck_password\\r"
                    exp_continue
                } else {
                    interact
                }
            }
            eof
        }
        interact
        """
    }

    private func tclEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}
