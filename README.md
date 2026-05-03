# Hopdeck

Hopdeck is a macOS-native SSH host manager and terminal workspace. It is built
with Swift, AppKit, SwiftTerm, the system OpenSSH client, macOS Keychain, and
local JSON documents.

The current branch is the native Swift implementation. The old Tauri, Rust,
React, and xterm.js implementation has been removed from this branch so the
repository root is the macOS app.

## Current Capabilities

- Native AppKit window, toolbar, sidebar, workspace, and inspector.
- SwiftTerm terminal renderer with Hopdeck-owned PTY process lifecycle.
- Local shell and `/usr/bin/ssh` session launch.
- Multiple terminal sessions with stable `sessionId` ownership.
- `Cmd+W` closes the current session without quitting the app.
- Host CRUD backed by native `hosts.json`.
- Sidebar search with built-in Smart Views, tag folders, and favorite toggles.
- Settings persistence for theme, terminal font size, SSH behavior, and
  clipboard timeout.
- Runnable local diagnostics for target shape, credential mode, jump-chain
  status, and OpenSSH availability.
- `hosts.json`, `settings.json`, and `workspaces.json` stores.
- Legacy `~/.hopdeck/hosts.json` and `settings.json` migration skeleton.
- macOS Keychain boundary through `CredentialService`.
- Release readiness model for signing, notarization, Sparkle, and GitHub
  Release work.

## Requirements

- macOS 14 or later.
- Xcode 26 or compatible Swift 6 toolchain.
- A working `/usr/bin/ssh`.

## Run

```zsh
swift run HopdeckNative
```

## Validate

```zsh
swift build
swift run HopdeckNativeCoreChecks
```

Routine checks do not create or delete Keychain items. To explicitly test a
temporary Keychain roundtrip:

```zsh
HOPDECK_RUN_KEYCHAIN_CHECKS=1 swift run HopdeckNativeCoreChecks
```

## Package A Local App

```zsh
scripts/package-app.sh
open .build/Hopdeck.app
```

The local package is ad-hoc signed for development validation. It is not a
notarized release artifact.

## Local Data

Native Hopdeck data is stored under:

```text
~/Library/Application Support/Hopdeck/
  hosts.json
  settings.json
  workspaces.json
```

Legacy import reads from:

```text
~/.hopdeck/hosts.json
~/.hopdeck/settings.json
~/.hopdeck/vault.json
```

`vault.json` is import-only. New credential writes should go through macOS
Keychain instead of plaintext JSON.

## Roadmap

The remaining production gaps are tracked in
[docs/unimplemented.md](docs/unimplemented.md). The largest remaining areas are
real Sparkle integration, signed/notarized releases, full SSH config import,
jump-chain UI, split panes, workspace restore, and runtime diagnostics.
