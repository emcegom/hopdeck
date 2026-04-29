import SwiftUI

struct HostDetailView: View {
    let host: SSHHost
    let onConnect: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                connectionSection
                jumpSection
                authSection
                actionsSection
                notesSection
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(host.alias)
                .font(.largeTitle.bold())

            Text(host.displayAddress)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionSection: some View {
        DetailSection(title: "Connection") {
            DetailRow(label: "Host", value: host.host)
            DetailRow(label: "User", value: host.user)
            DetailRow(label: "Port", value: String(host.port))
            DetailRow(label: "Group", value: host.group)
        }
    }

    private var jumpSection: some View {
        DetailSection(title: "Jump Chain") {
            Text(jumpPath)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private var authSection: some View {
        DetailSection(title: "Authentication") {
            DetailRow(label: "Method", value: host.auth.type.rawValue.capitalized)
            DetailRow(label: "Password", value: host.auth.passwordRef == nil ? "Not saved" : "Saved")
            DetailRow(label: "Auto Login", value: host.auth.autoLogin ? "Enabled" : "Disabled")
        }
    }

    private var actionsSection: some View {
        DetailSection(title: "Actions") {
            HStack(spacing: 10) {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)

                Button("Copy Password") {}
                    .disabled(host.auth.passwordRef == nil)

                Button("Reveal Password") {}
                    .disabled(host.auth.passwordRef == nil)
            }
        }
    }

    private var notesSection: some View {
        DetailSection(title: "Notes") {
            Text(host.notes.isEmpty ? "No notes." : host.notes)
                .foregroundStyle(host.notes.isEmpty ? .secondary : .primary)
        }
    }

    private var jumpPath: String {
        let path = ["Mac"] + host.jumpChain + [host.alias]
        return path.joined(separator: " -> ")
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            )
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
        }
    }
}
