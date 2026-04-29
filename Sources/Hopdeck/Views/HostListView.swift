import SwiftUI

struct HostListView: View {
    let hosts: [SSHHost]
    @Binding var selectedHostID: SSHHost.ID?
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search hosts", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(12)

            List(hosts, selection: $selectedHostID) { host in
                HostRowView(host: host)
                    .tag(host.id)
            }
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 340)
    }
}

private struct HostRowView: View {
    let host: SSHHost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(host.alias)
                    .font(.headline)

                Spacer()

                Text(host.connectionKind.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(host.displayAddress)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !host.jumpChain.isEmpty {
                Text("Jump: \(host.jumpChain.joined(separator: " -> "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}
