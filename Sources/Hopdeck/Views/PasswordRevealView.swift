import SwiftUI

struct PasswordRevealView: View {
    let title: String
    let username: String
    let password: String
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                DetailLine(label: "Username", value: username)
                DetailLine(label: "Password", value: password)
            }

            Text("This password is shown from the local Hopdeck vault.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Close", action: onClose)
                Button("Copy Password", action: onCopy)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
