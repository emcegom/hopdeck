import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2.bold())
                .padding([.top, .horizontal], 22)

            Form {
                Section("Terminal") {
                    Picker("Default Terminal", selection: $settings.defaultTerminal) {
                        ForEach(TerminalBackend.allCases) { backend in
                            Text(backend.label).tag(backend)
                        }
                    }

                    TextField("Custom Template", text: $settings.customTerminalTemplate)
                        .disabled(settings.defaultTerminal != .custom)
                }

                Section("Passwords") {
                    Picker("Storage", selection: $settings.passwordStorageMode) {
                        Text("Plain JSON").tag(PasswordVaultMode.plain)
                    }

                    Toggle("Enable Auto Login", isOn: $settings.autoLoginEnabled)
                    Stepper("Clear clipboard after \(settings.clipboardClearSeconds)s", value: $settings.clipboardClearSeconds, in: 0...300, step: 5)

                    Text("Plain JSON stores readable passwords in ~/.hopdeck/vault.json. Use it only on a trusted Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)
        }
        .frame(minWidth: 500, minHeight: 420)
    }
}
