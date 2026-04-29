import SwiftUI

struct RootView: View {
    @State private var hosts = SSHHost.samples
    @State private var selectedHostID: SSHHost.ID? = SSHHost.samples.first?.id
    @State private var searchText = ""
    @State private var selectedGroup = "All Hosts"
    @State private var launchError: String?

    private var groups: [String] {
        let hostGroups = Set(hosts.map(\.group)).sorted()
        return ["Favorites", "Recent", "All Hosts"] + hostGroups
    }

    private var filteredHosts: [SSHHost] {
        hosts.filter { host in
            let matchesGroup = selectedGroup == "All Hosts"
                || selectedGroup == host.group
                || selectedGroup == "Favorites"
                || selectedGroup == "Recent"

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
                searchText: $searchText
            )
        } detail: {
            if let selectedHost {
                HostDetailView(host: selectedHost) {
                    connect(to: selectedHost)
                }
            } else {
                ContentUnavailableView("No Host Selected", systemImage: "server.rack")
            }
        }
        .navigationTitle("Hopdeck")
        .alert("Unable to Connect", isPresented: Binding(
            get: { launchError != nil },
            set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
    }

    private func connect(to host: SSHHost) {
        do {
            try TerminalLauncher(backend: .terminalApp).connect(to: host)
        } catch {
            launchError = error.localizedDescription
        }
    }
}
