import SwiftUI

struct HostEditorView: View {
    var originalHost: SSHHost?
    let allHosts: [SSHHost]
    let onSave: (SSHHost, String?) -> Void
    let onCancel: () -> Void

    @State private var alias: String
    @State private var host: String
    @State private var user: String
    @State private var port: String
    @State private var group: String
    @State private var tags: String
    @State private var jumpChain: String
    @State private var authType: AuthType
    @State private var autoLogin: Bool
    @State private var password: String
    @State private var notes: String

    init(
        host originalHost: SSHHost?,
        allHosts: [SSHHost],
        onSave: @escaping (SSHHost, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalHost = originalHost
        self.allHosts = allHosts
        self.onSave = onSave
        self.onCancel = onCancel

        let host = originalHost ?? SSHHost(
            id: UUID().uuidString,
            alias: "",
            host: "",
            user: NSUserName(),
            port: 22,
            group: "Production",
            tags: [],
            jumpChain: [],
            auth: AuthConfig(type: .password, passwordRef: nil, autoLogin: true),
            notes: "",
            lastConnectedAt: nil
        )

        _alias = State(initialValue: host.alias)
        _host = State(initialValue: host.host)
        _user = State(initialValue: host.user)
        _port = State(initialValue: String(host.port))
        _group = State(initialValue: host.group)
        _tags = State(initialValue: host.tags.joined(separator: ", "))
        _jumpChain = State(initialValue: host.jumpChain.joined(separator: ", "))
        _authType = State(initialValue: host.auth.type)
        _autoLogin = State(initialValue: host.auth.autoLogin)
        _password = State(initialValue: "")
        _notes = State(initialValue: host.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(originalHost == nil ? "Add Host" : "Edit Host")
                .font(.title2.bold())
                .padding([.top, .horizontal], 22)

            Form {
                Section("Connection") {
                    TextField("Alias", text: $alias)
                    TextField("Host", text: $host)
                    TextField("User", text: $user)
                    TextField("Port", text: $port)
                }

                Section("Organization") {
                    TextField("Group", text: $group)
                    TextField("Tags", text: $tags, prompt: Text("app, prod"))
                    TextField("Jump Chain", text: $jumpChain, prompt: Text("jump-prod, jump-core"))
                }

                Section("Authentication") {
                    Picker("Method", selection: $authType) {
                        Text("Password").tag(AuthType.password)
                        Text("Key").tag(AuthType.key)
                        Text("Agent").tag(AuthType.agent)
                        Text("None").tag(AuthType.none)
                    }

                    Toggle("Auto Login", isOn: $autoLogin)
                        .disabled(authType != .password)

                    SecureField("Password", text: $password)
                        .disabled(authType != .password)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(18)
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    private var canSave: Bool {
        !alias.trimmed.isEmpty
            && !host.trimmed.isEmpty
            && !user.trimmed.isEmpty
            && Int(port.trimmed) != nil
    }

    private func save() {
        let normalizedAlias = alias.trimmed
        let passwordRef = authType == .password ? "password:\(normalizedAlias)" : nil
        let savedHost = SSHHost(
            id: originalHost?.id ?? normalizedAlias,
            alias: normalizedAlias,
            host: host.trimmed,
            user: user.trimmed,
            port: Int(port.trimmed) ?? 22,
            group: group.trimmed.isEmpty ? "Ungrouped" : group.trimmed,
            tags: tags.csvValues,
            jumpChain: jumpChain.csvValues,
            auth: AuthConfig(type: authType, passwordRef: passwordRef, autoLogin: authType == .password && autoLogin),
            notes: notes,
            lastConnectedAt: originalHost?.lastConnectedAt
        )

        onSave(savedHost, password.isEmpty ? nil : password)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var csvValues: [String] {
        split(separator: ",")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}
