# Hopdeck Native Swift Implementation Plan

Hopdeck Native is a ground-up macOS implementation, not a port of the current
Tauri UI. The target architecture is Swift/AppKit + SwiftTerm + system
OpenSSH + PTY + Keychain + Sparkle.

## Product Direction

Hopdeck should become a macOS-native SSH host manager and terminal workspace.
The main product surface should feel closer to Finder, iTerm2, Transmit, and
Raycast than to a web dashboard.

Primary product principles:

- Use native macOS window chrome, toolbar, sidebar, menus, sheets, popovers, and
  Settings windows.
- Treat hosts, connection profiles, credentials, terminal sessions, and
  workspaces as separate concepts.
- Allow multiple sessions for the same host.
- Keep terminal session lifecycle independent from view lifecycle.
- Prefer diagnostics and explicit connection state over hiding all information
  inside terminal output.
- Store secrets in macOS Keychain, not plaintext JSON.

## Reference Projects

- SwiftTerm: native terminal renderer and AppKit terminal view.
- Infinity Terminal: native terminal performance and stable pane/session
  identity lessons.
- TermAway: SwiftTerm usage and session attach/detach ideas.
- Tempest: developer workspace organization and persistence ideas.
- electerm: useful functional breadth reference, but not the target runtime
  architecture.

## Target Architecture

```text
AppKit UI
  MainWindowController / Sidebar / HostList / Inspector
  Workspace / TabStrip / SplitPane / Settings

Application Services
  HostInventoryService
  SessionManager
  WorkspaceStateService
  CredentialService
  UpdateService

Domain
  Host / Folder / SmartView
  ConnectionProfile
  CredentialRef
  TerminalSession
  WorkspaceLayout
  JumpChain

Infrastructure
  SwiftTerm TerminalView
  PTYProcessAdapter
  OpenSSHCommandBuilder
  KeychainCredentialStore
  Versioned JSON Store
  SparkleUpdater
```

SwiftTerm is a renderer. It must not own the application's session model.
`SessionManager` owns session identity, process lifecycle, tab attachment,
exit state, and close policy.

## Phase 1: Native Spike

Goal: validate the hardest technical risk before rebuilding the whole product.

Scope:

- Create `native/` Swift Package.
- Launch an AppKit app from SwiftPM.
- Render a native window with sidebar and workspace area.
- Embed SwiftTerm.
- Start a local shell through SwiftTerm's local-process path.
- Build `/usr/bin/ssh` argv for a host.
- Maintain `sessionId` independent from tab index and host id.

Acceptance:

- `swift run HopdeckNative` opens a native macOS window.
- A local shell can run.
- Selecting a sample host shows a resolved SSH command.
- Connecting a sample host starts `/usr/bin/ssh` through PTY.
- Tab switching does not terminate the process.
- Closing or process exit updates session state.

## Phase 2: Real PTY Adapter

Replace any view-owned process convenience with a Hopdeck-owned
`PTYProcessAdapter`.

Acceptance:

- `SessionManager` owns child process lifecycle.
- View detach/attach never kills a process.
- Resize propagates to PTY.
- Exit status is recorded against `sessionId`.
- Input/output paths are testable without AppKit.

## Phase 3: Host Data And Migration

Initial storage stays versioned JSON for debuggability and compatibility.

Paths:

```text
~/Library/Application Support/Hopdeck/hosts.json
~/Library/Application Support/Hopdeck/settings.json
~/Library/Application Support/Hopdeck/workspaces.json
```

Compatibility import:

```text
~/.hopdeck/hosts.json
~/.hopdeck/settings.json
~/.hopdeck/vault.json
```

`vault.json` is import-only. New writes go to Keychain.

## Phase 4: Product MVP

Essential:

- Native sidebar with Smart Views and user folders.
- Host list and inspector.
- Host CRUD.
- SSH config import.
- Jump-chain path builder.
- Terminal tabs and split panes.
- Keychain credentials.
- Settings window.
- Connection diagnostics.

Near-term:

- Saved workspaces.
- Recent directories and recent hosts.
- Terminal themes and iTerm2 profile import.
- Sparkle updater.
- Signed/notarized release.

Later:

- Command palette.
- Prompt marks and command status.
- SFTP.
- Advanced workspace layouts.

## Release Strategy

The native app should use Sparkle 2 for updates.

Release chain:

```text
Xcode archive
Developer ID signing
Hardened Runtime
notarytool notarization
staple
DMG / zip
Sparkle appcast
GitHub Release
```

The current Tauri updater key is not reused. Apple signing and Sparkle update
signing are separate.

## Current Branch Plan

Implementation starts on:

```text
codex/native-swift-spike
```

The current Tauri app remains available on `main` until the native spike passes
the terminal, data, and release checks.

## Current Implementation Status

Completed in `native/`:

- SwiftPM package with `HopdeckNative`, `HopdeckNativeCore`, and
  `HopdeckNativeCoreChecks`.
- AppKit main window, native toolbar, split view, sidebar, workspace, and host
  inspector.
- SwiftTerm-backed terminal renderer with Hopdeck-owned `TerminalProcessAdapter`
  for local shell and `/usr/bin/ssh` processes.
- `SessionManager` owns session identity, active session, child process
  lifecycle, close policy, and session state transitions used by `Cmd+W`.
- Tab selection is synchronized back to `SessionManager`.
- Versioned host/settings/workspace JSON stores with a best-effort legacy import
  and migration path.
- Host CRUD writes through `HostInventoryService`.
- Keychain credential store plus `CredentialService`, with opt-in checks only.
- Connection diagnostics and release readiness service skeletons.
- AppKit UI skeleton for Smart Views, folders, host CRUD, settings, and
  connection diagnostics.
- Local `.app` package script that embeds SwiftTerm resources and applies
  ad-hoc signing for local validation.

Verified:

- `swift build`
- `swift run HopdeckNativeCoreChecks`
- `native/scripts/package-spike-app.sh`
- `codesign -dv native/.build/HopdeckNative.app`

Remaining production hardening:

- Signed, notarized release archives and Sparkle appcast generation.
- Real Sparkle 2 runtime integration.
- Full SSH config import, jump-chain builder UI, split panes, and workspace
  restore behavior.
- Deeper runtime diagnostics that execute reachability and credential checks
  instead of only producing a static report.
