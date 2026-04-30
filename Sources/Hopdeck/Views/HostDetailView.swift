import SwiftUI

struct HostDetailView: View {
    let host: SSHHost
    let sshCommand: String
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let onCopyPassword: () -> Void
    let onRevealPassword: () -> Void
    let onCopyCommand: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                connectionSection
                jumpSection
                authSection
                actionsSection
                commandSection
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], alignment: .leading, spacing: 10) {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Edit", action: onEdit)
                    .frame(maxWidth: .infinity)

                Button(host.tags.contains("favorite") ? "Unfavorite" : "Favorite", action: onToggleFavorite)
                    .frame(maxWidth: .infinity)

                Button("Copy Password", action: onCopyPassword)
                    .disabled(host.auth.passwordRef == nil)
                    .frame(maxWidth: .infinity)

                Button("Reveal Password", action: onRevealPassword)
                    .disabled(host.auth.passwordRef == nil)
                    .frame(maxWidth: .infinity)

                Button("Copy Command", action: onCopyCommand)
                    .frame(maxWidth: .infinity)

                Button("Delete", role: .destructive, action: onDelete)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var commandSection: some View {
        DetailSection(title: "Command") {
            Text(sshCommand.isEmpty ? "Unable to build command." : sshCommand)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(sshCommand.isEmpty ? .secondary : .primary)
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
