import SwiftUI

struct RootView: View {
    @State private var hosts = SSHHost.samples
    @State private var selectedHostID: SSHHost.ID? = SSHHost.samples.first?.id
    @State private var searchText = ""
    @State private var selectedGroup = "All Hosts"
    @State private var settings = AppSettings()
    @State private var launchError: String?
    @State private var statusMessage: String?
    @State private var editingHost: SSHHost?
    @State private var isAddingHost = false
    @State private var isShowingSettings = false
    @State private var revealState: PasswordRevealState?

    private let hostStore = HostStore()
    private let vault = PasswordVault()
    private let settingsStore = AppSettingsStore()
    private let clipboard = ClipboardService()

    private var groups: [String] {
        let hostGroups = Set(hosts.map(\.group)).sorted()
        return ["Favorites", "Recent", "All Hosts"] + hostGroups
    }

    private var filteredHosts: [SSHHost] {
        hosts.filter { host in
            let matchesGroup = selectedGroup == "All Hosts"
                || selectedGroup == host.group
                || (selectedGroup == "Favorites" && host.tags.contains("favorite"))
                || (selectedGroup == "Recent" && host.lastConnectedAt != nil)

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || host.alias.localizedCaseInsensitiveContains(query)
                || host.host.localizedCaseInsensitiveContains(query)
                || host.user.localizedCaseInsensitiveContains(query)
                || host.tags.contains { $0.localizedCaseInsensitiveContains(query) }

            return matchesGroup && matchesSearch
        }
    }

    private var selectedHost: SSHHost? {
        hosts.first { $0.id == selectedHostID } ?? filteredHosts.first
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(groups: groups, selectedGroup: $selectedGroup)
        } content: {
            HostListView(
                hosts: filteredHosts,
                selectedHostID: $selectedHostID,
                searchText: $searchText,
                onConnect: { connect(to: $0) }
            )
        } detail: {
            if let selectedHost {
                HostDetailView(
                    host: selectedHost,
                    sshCommand: (try? SSHCommandBuilder().buildCommand(for: selectedHost, allHosts: hosts).command) ?? "",
                    onConnect: { connect(to: selectedHost) },
                    onEdit: { editingHost = selectedHost },
                    onDelete: { delete(selectedHost) },
                    onToggleFavorite: { toggleFavorite(selectedHost) },
                    onCopyPassword: { copyPassword(for: selectedHost) },
                    onRevealPassword: { revealPassword(for: selectedHost) },
                    onCopyCommand: { copyCommand(for: selectedHost) }
                )
            } else {
                ContentUnavailableView("No Host Selected", systemImage: "server.rack")
            }
        }
        .navigationTitle("Hopdeck")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isAddingHost = true
                } label: {
                    Label("Add Host", systemImage: "plus")
                }

                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    importSSHConfig()
                } label: {
                    Label("Import SSH Config", systemImage: "square.and.arrow.down")
                }
            }
        }
        .onAppear(perform: loadState)
        .sheet(isPresented: $isAddingHost) {
            HostEditorView(host: nil, allHosts: hosts) { host, password in
                save(host, password: password)
                isAddingHost = false
            } onCancel: {
                isAddingHost = false
            }
        }
        .sheet(item: $editingHost) { host in
            HostEditorView(host: host, allHosts: hosts) { updatedHost, password in
                save(updatedHost, password: password)
                editingHost = nil
            } onCancel: {
                editingHost = nil
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(settings: $settings) {
                saveSettings()
                isShowingSettings = false
            } onCancel: {
                loadSettings()
                isShowingSettings = false
            }
        }
        .sheet(item: $revealState) { state in
            PasswordRevealView(
                title: state.hostAlias,
                username: state.item.username,
                password: state.item.password,
                onCopy: {
                    copy(state.item.password)
                    revealState = nil
                },
                onClose: {
                    revealState = nil
                }
            )
        }
        .alert("Unable to Connect", isPresented: Binding(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
        .alert("Hopdeck", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func connect(to host: SSHHost) {
        do {
            let builder = SSHCommandBuilder()
            let resolved = try builder.buildCommand(for: host, allHosts: hosts)
            let command = try commandForLaunch(host: host, resolved: resolved)
            try TerminalLauncher(
                backend: settings.defaultTerminal,
                customTemplate: settings.customTerminalTemplate
            ).run(command: command)
            markConnected(host)
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func commandForLaunch(host: SSHHost, resolved: ResolvedSSHCommand) throws -> String {
        guard settings.autoLoginEnabled, host.auth.autoLogin else {
            return resolved.command
        }

        let credentials = try credentialsForAutoLogin(host: host)
        guard !credentials.isEmpty else {
            return resolved.command
        }

        return try AutoLoginRunner().makeCommand(sshCommand: resolved.command, credentials: credentials)
    }

    private func credentialsForAutoLogin(host: SSHHost) throws -> [AutoLoginCredentials] {
        var credentials: [AutoLoginCredentials] = []

        for jumpAlias in host.jumpChain {
            guard let jumpHost = hosts.first(where: { $0.id == jumpAlias || $0.alias == jumpAlias }),
                  let passwordRef = jumpHost.auth.passwordRef,
                  let password = try vault.password(for: passwordRef) else {
                continue
            }

            credentials.append(AutoLoginCredentials(passwordRef: passwordRef, password: password))
        }

        if let passwordRef = host.auth.passwordRef,
           let password = try vault.password(for: passwordRef) {
            credentials.append(AutoLoginCredentials(passwordRef: passwordRef, password: password))
        }

        return credentials
    }

    private func loadState() {
        do {
            hosts = try hostStore.loadHosts()
            selectedHostID = hosts.first?.id
        } catch {
            launchError = error.localizedDescription
        }

        loadSettings()
    }

    private func loadSettings() {
        do {
            settings = try settingsStore.load()
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func saveSettings() {
        do {
            try settingsStore.save(settings)
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func save(_ host: SSHHost, password: String?) {
        do {
            hosts = try hostStore.upsertHost(host)
            selectedHostID = host.id

            if let password, let passwordRef = host.auth.passwordRef {
                try vault.setItem(PasswordVaultItem(username: host.user, password: password), for: passwordRef)
            }
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func delete(_ host: SSHHost) {
        do {
            hosts = try hostStore.deleteHost(id: host.id)
            selectedHostID = hosts.first?.id
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func toggleFavorite(_ host: SSHHost) {
        var updated = host
        if updated.tags.contains("favorite") {
            updated.tags.removeAll { $0 == "favorite" }
        } else {
            updated.tags.append("favorite")
        }

        save(updated, password: nil)
    }

    private func markConnected(_ host: SSHHost) {
        var updated = host
        updated.lastConnectedAt = Date()
        do {
            hosts = try hostStore.upsertHost(updated)
        } catch {
            statusMessage = "Connected, but could not update recent activity."
        }
    }

    private func copyPassword(for host: SSHHost) {
        do {
            guard let item = try vaultItem(for: host) else {
                statusMessage = "No password is saved for \(host.alias)."
                return
            }

            copy(item.password)
            statusMessage = "Password copied. Clipboard clears in \(settings.clipboardClearSeconds) seconds."
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func revealPassword(for host: SSHHost) {
        do {
            guard let item = try vaultItem(for: host) else {
                statusMessage = "No password is saved for \(host.alias)."
                return
            }

            revealState = PasswordRevealState(hostAlias: host.alias, item: item)
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func copyCommand(for host: SSHHost) {
        do {
            let command = try SSHCommandBuilder().buildCommand(for: host, allHosts: hosts).command
            copy(command)
            statusMessage = "SSH command copied."
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func importSSHConfig() {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config", isDirectory: false)

        do {
            let text = try String(contentsOf: configURL, encoding: .utf8)
            let imported = SSHConfigParser().parse(text)
            var merged = hosts

            for host in imported {
                if let index = merged.firstIndex(where: { $0.id == host.id || $0.alias == host.alias }) {
                    merged[index] = host
                } else {
                    merged.append(host)
                }
            }

            try hostStore.saveHosts(merged)
            hosts = merged
            selectedHostID = imported.first?.id ?? selectedHostID
            statusMessage = "Imported \(imported.count) host\(imported.count == 1 ? "" : "s") from ~/.ssh/config."
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func vaultItem(for host: SSHHost) throws -> PasswordVaultItem? {
        guard let passwordRef = host.auth.passwordRef else {
            return nil
        }

        return try vault.item(for: passwordRef)
    }

    private func copy(_ value: String) {
        clipboard.copy(value)
        clipboard.clearIfStill(value, after: settings.clipboardClearSeconds)
    }
}

private struct PasswordRevealState: Identifiable {
    let id = UUID()
    var hostAlias: String
    var item: PasswordVaultItem
}
