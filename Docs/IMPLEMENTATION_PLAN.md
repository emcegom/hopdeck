# Hopdeck Implementation Plan

## Technical Direction

Hopdeck starts as a native SwiftUI macOS application.

The first implementation should avoid building a terminal emulator. Instead, it
launches external terminal applications and lets OpenSSH handle the actual SSH
session. Hopdeck owns host metadata, vault references, validation, command
generation, and terminal launch orchestration.

Core stack:

```text
SwiftUI
Observation / Combine where appropriate
Foundation
AppKit bridge where needed
JSON files under ~/.hopdeck
OpenSSH
Terminal.app AppleScript
```

## Architecture Goals

- Keep product state local and inspectable.
- Separate models, persistence, command generation, and terminal backends.
- Make password handling explicit and auditable.
- Avoid coupling UI views to file formats.
- Support future terminal backends without rewriting connection logic.
- Support future encrypted vault and Keychain storage without changing host
  records.
- Keep MVP small enough to ship while preserving clean extension points.

## Repository Layout

```text
hopdeck/
  Package.swift
  README.md
  Docs/
    PRODUCT_DESIGN.md
    IMPLEMENTATION_PLAN.md
  Sources/
    Hopdeck/
      HopdeckApp.swift
      Models/
        SSHHost.swift
        HostGroup.swift
        HopdeckConfig.swift
        PasswordVaultModels.swift
        TerminalBackend.swift
      Services/
        HostStore.swift
        PasswordVault.swift
        SSHCommandBuilder.swift
        JumpChainResolver.swift
        TerminalLauncher.swift
        ClipboardService.swift
        SSHConfigImporter.swift
        FilePermissionService.swift
        AutoLoginRunner.swift
      Views/
        RootView.swift
        SidebarView.swift
        HostListView.swift
        HostDetailView.swift
        HostEditorView.swift
        VaultView.swift
        SettingsView.swift
      ViewModels/
        AppViewModel.swift
        HostListViewModel.swift
        HostDetailViewModel.swift
        SettingsViewModel.swift
  Tests/
    HopdeckTests/
```

## Data Files

Default directory:

```text
~/.hopdeck/
```

Files:

```text
settings.json
hosts.json
vault.json
recent.json
```

Recommended file permissions:

```text
chmod 700 ~/.hopdeck
chmod 600 ~/.hopdeck/*.json
```

MVP should create missing files on first launch and preserve unknown fields when
practical during schema migrations.

## Data Model Implementation

### `SSHHost`

Required fields:

- `id: String`
- `alias: String`
- `host: String`
- `user: String?`
- `port: Int`
- `groupId: String?`
- `tags: [String]`
- `isFavorite: Bool`
- `isJumpHost: Bool`
- `jumpChain: [String]`
- `auth: HostAuth`
- `terminal: TerminalBackendID?`
- `notes: String`
- `warning: HostWarning?`
- `source: HostSource`
- `createdAt`, `updatedAt`, `lastConnectedAt`

Validation rules:

- `alias` must be unique.
- `host` is required unless the host is an imported SSH config alias.
- `port` must be between 1 and 65535.
- `jumpChain` entries must reference existing hosts.
- `jumpChain` must not include the target host.
- Circular jump references are invalid.
- A host marked as a jump host can still be connected directly.

### `HostAuth`

Supported MVP cases:

```swift
enum HostAuth: Codable, Equatable {
    case none
    case password(passwordRef: String?, autoLogin: Bool)
    case key(identityFile: String?, useAgent: Bool)
    case sshConfig
}
```

The exact Swift representation may be a tagged struct if that is simpler for
`Codable` compatibility.

### `PasswordVault`

MVP mode:

- Plain JSON.
- Passwords are readable on disk.
- File permission warnings are shown in Settings and Vault.
- Password values are never logged.

Future modes:

- Encrypted File.
- macOS Keychain.

Host records should only store `passwordRef`; secrets must stay in the vault
implementation.

### `TerminalBackend`

MVP:

- `terminal-app`

Next:

- `iterm2`
- `wezterm`
- `ghostty`
- `alacritty`
- `kitty`
- `custom`

Backend interface:

```swift
protocol TerminalLaunching {
    func launch(command: String, title: String?) async throws
    func launchScript(path: URL, title: String?) async throws
}
```

Backends that need different argument quoting should receive a prepared command
from `SSHCommandBuilder` and handle only app launch mechanics.

## Service Responsibilities

### `HostStore`

- Create `~/.hopdeck` when missing.
- Load and save `hosts.json`.
- Provide CRUD operations for hosts and groups.
- Preserve stable IDs.
- Update timestamps.
- Publish changes to view models.

### `PasswordVault`

- Load and save `vault.json`.
- Resolve `passwordRef`.
- Add, rename, update, and delete vault items.
- Avoid printing secret values in errors.
- Report storage mode and permission warnings.

### `SSHCommandBuilder`

- Generate direct SSH commands.
- Generate `ProxyJump` / `-J` commands for jump chains.
- Generate alias-based commands for imported SSH config hosts.
- Quote shell arguments safely.
- Produce a user-visible command preview.
- Never include passwords in generated command strings.

### `JumpChainResolver`

- Resolve host IDs in order.
- Detect missing hosts and cycles.
- Return validation messages suitable for the UI.
- Provide connection path display data.

### `TerminalLauncher`

- Select backend from host override or settings default.
- Launch Terminal.app in MVP.
- Report backend availability.
- Keep backend-specific code isolated.

### `ClipboardService`

- Copy SSH commands and passwords.
- Clear clipboard after configurable timeout if clipboard still matches the
  copied secret.
- Avoid clearing unrelated clipboard content.

### `FilePermissionService`

- Check `~/.hopdeck` and JSON file modes.
- Attempt safe permission fixes when possible.
- Surface warnings when files are too permissive.

### `AutoLoginRunner`

- Create temporary expect-style scripts only when auto-login is enabled.
- Use restrictive file permissions.
- Avoid command-line password arguments.
- Remove temporary runner files when practical.
- Keep this service optional and disabled for MVP if expect is unavailable.

## Milestone 1: App Shell

Goals:

- Create SwiftUI app entry point.
- Add three-pane layout.
- Add mock host data.
- Support host selection.
- Add Connect, Copy Command, Copy Password, and Reveal Password buttons.

Files:

- `HopdeckApp.swift`
- `Views/RootView.swift`
- `Views/SidebarView.swift`
- `Views/HostListView.swift`
- `Views/HostDetailView.swift`
- `ViewModels/AppViewModel.swift`
- `Models/SSHHost.swift`

Done when:

- The app opens to a working native layout.
- Selecting a host updates the detail panel.
- The primary Connect action is visible without scrolling.

## Milestone 2: Local Host Store

Goals:

- Create `~/.hopdeck` if missing.
- Read and write `hosts.json`.
- Add host CRUD operations.
- Use sample data only when no config exists.
- Validate aliases, ports, and jump references.

Files:

- `Services/HostStore.swift`
- `Services/FilePermissionService.swift`
- `Models/HopdeckConfig.swift`
- `Models/HostGroup.swift`

Done when:

- Hosts persist across app launches.
- Invalid hosts show clear validation messages.
- Config files are created with restrictive permissions where possible.

## Milestone 3: Plain Vault

Goals:

- Read and write `~/.hopdeck/vault.json`.
- Support `passwordRef`.
- Add Copy Password.
- Add Reveal Password.
- Add clipboard auto-clear.
- Show Plain JSON warnings.

Files:

- `Services/PasswordVault.swift`
- `Services/ClipboardService.swift`
- `Models/PasswordVaultModels.swift`
- `Views/VaultView.swift`

Done when:

- A host can reference a saved password.
- The password can be copied and revealed from the UI.
- Plain JSON mode is visually obvious.
- Passwords never appear in logs.

Security rules:

- Never log passwords.
- Never include passwords in generated SSH commands.
- Never store passwords in `hosts.json`.
- Warn when vault permissions are too broad.

## Milestone 4: Terminal Launch

Goals:

- Implement Terminal.app launcher.
- Generate an SSH command for direct hosts.
- Copy generated command.
- Update `lastConnectedAt` after a launch attempt.

Files:

- `Services/TerminalLauncher.swift`
- `Services/SSHCommandBuilder.swift`
- `Models/TerminalBackend.swift`

Initial command format:

```text
ssh user@host -p port
```

Imported SSH config alias format:

```text
ssh alias
```

Done when:

- Clicking Connect opens Terminal.app and starts SSH.
- Copy SSH Command returns the same command shown in the detail panel.

## Milestone 5: Jump Host Support

Goals:

- Add `jumpChain` to host model.
- Generate direct jump command for one jump host.
- Validate jump host existence.
- Display path in detail panel.

First version can generate:

```text
ssh -J jumpUser@jumpHost:jumpPort targetUser@targetHost -p targetPort
```

Done when:

- A host can connect through one saved jump host.
- Missing or circular jump chains disable Connect and show a clear message.

## Milestone 6: Settings

Goals:

- Select default terminal backend.
- Select password storage mode.
- Configure clipboard clear timeout.
- Configure config, vault, and SSH config paths.
- Enable or disable auto-login.

Files:

- `Views/SettingsView.swift`
- `ViewModels/SettingsViewModel.swift`
- `Models/HopdeckConfig.swift`

Done when:

- The app can be adapted without editing files manually.
- Plain JSON mode remains clearly labeled.

## Milestone 7: SSH Config Import

Goals:

- Parse `~/.ssh/config`.
- Import common fields.
- Merge imported entries with Hopdeck metadata.
- Preview import before writing.

Supported fields:

- Host
- HostName
- User
- Port
- IdentityFile
- ProxyJump
- ProxyCommand
- LocalForward
- RemoteForward

Deferred:

- Full `Match` semantics.
- Complex pattern merging.
- Recursive `Include`.
- Host patterns that expand to many dynamic names.

Done when:

- Common SSH config hosts appear in the list.
- Imported entries can be connected by alias.
- Hopdeck metadata can be added without rewriting the user's SSH config.

## Milestone 8: Auto Login

Goals:

- Add expect runner generation.
- Retrieve passwords for jump host and target host.
- Open runner in Terminal.app.
- Remove temporary runner after session starts when practical.

Runner strategy:

```text
spawn ssh ...
expect "*assword:"
send "..."
interact
```

Risks:

- Password prompts vary.
- MFA may require manual input.
- Host-key confirmation can interrupt flow.
- Multi-hop order must be predictable.
- `expect` may not be installed on every target macOS environment.

Done when:

- Direct password SSH can auto-login in a documented test environment.
- One jump-host password flow can auto-login in a documented test environment.
- Failure falls back to manual terminal interaction where possible.

## Milestone 9: Additional Terminal Backends

Goals:

- Add iTerm2 launch support.
- Add command-template support for WezTerm, Ghostty, Alacritty, kitty, and
  custom commands.
- Validate backend availability.

Done when:

- User can choose the default backend in Settings.
- Host-level backend override works.
- Unsupported or missing backends show actionable errors.

## Milestone 10: 1.0 Hardening

Goals:

- Add encrypted vault.
- Add optional macOS Keychain vault.
- Add schema migrations.
- Add import/export.
- Add signed and notarized `.app` packaging.
- Add recovery docs.

Done when:

- Existing Plain JSON users can migrate to encrypted storage.
- App can be distributed as a normal macOS application.
- Data upgrade paths are covered by tests.

## Build Notes

Because this project starts as a Swift Package, Xcode can open it directly:

```zsh
open Package.swift
```

For a production `.app`, add an Xcode macOS app target after the MVP is stable.

If `xcodebuild` points to Command Line Tools, switch it:

```zsh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Testing Strategy

### Unit Tests

- `SSHCommandBuilder` direct command generation.
- `SSHCommandBuilder` jump command generation.
- Shell argument quoting.
- `JumpChainResolver` missing host detection.
- `JumpChainResolver` circular reference detection.
- `HostStore` load/save round trip.
- `PasswordVault` load/save round trip.
- Settings schema defaults and migration.

### Integration Tests

- Create temporary Hopdeck config directory.
- Load hosts and vault from fixture JSON.
- Generate command preview from stored hosts.
- Copy password and clear clipboard when safe to do so.
- Parse representative SSH config fixtures.

### Manual QA

- Launch app on clean macOS account.
- Add direct host and connect through Terminal.app.
- Add jump host and connect through Terminal.app.
- Copy and reveal password.
- Verify Plain JSON warning appears.
- Verify dark and light mode.
- Verify keyboard shortcuts.
- Verify missing backend error.

### Security QA

- Confirm secrets do not appear in logs.
- Confirm generated SSH commands do not contain passwords.
- Confirm vault permissions warning appears for broad permissions.
- Confirm temporary runner permissions are restrictive.
- Confirm Reveal Password masks again after selection/window changes.

## Risk Mitigation

- Keep auto-login optional and ship after basic manual connection is reliable.
- Implement Terminal.app first before adding backend breadth.
- Treat SSH config import as preview-and-import instead of silent mutation.
- Store vault references in hosts so storage modes can change later.
- Add command preview early to make debugging and trust easier.
- Add validation before Connect to prevent broken jump chains.
- Document Plain JSON limitations directly in UI and docs.

## MVP Acceptance Criteria

- User can add or load at least one host.
- User can edit and delete a host.
- User can save a password in Plain JSON mode.
- User can copy and reveal that password.
- User can press Connect and open Terminal.app.
- User can connect through one jump host.
- User can copy the generated SSH command.
- User can understand where files are stored.
- User can see and fix invalid jump-chain references.
- No password appears in logs or generated command-line arguments.
- App remains usable with at least 200 stored hosts.

## Release Checklist

- Product acceptance criteria are satisfied.
- Unit tests pass.
- Manual QA checklist is complete.
- Plain JSON warnings are visible in Settings and Vault.
- File permission warnings are tested.
- README links to product and implementation docs.
- Known limitations are documented.
- Build instructions are current.
