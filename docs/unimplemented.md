# Unimplemented Items

This branch is the root Swift/AppKit implementation of Hopdeck. The previous
Tauri/Rust/React application has been removed, but the native product is not yet
production complete.

## Product Experience

- Settings controls are visible but not fully bound to `settings.json`.
- Smart Views and folders are displayed, but folder management, drag/drop, and
  smart-view predicates are not fully interactive.
- Host CRUD is minimal: save, clone, and delete work, but validation, sheet
  presentation, confirmation flows, duplicate detection, and polished errors are
  still missing.
- Search, filtering, favorites, recent hosts, and recent directories are not yet
  implemented.
- Workspace restore is not implemented. `workspaces.json` exists, but the app
  does not restore previous tabs or layouts on launch.
- Split panes are not implemented.

## SSH And Terminal

- Full SSH config import is not implemented.
- Jump-chain builder UI is not implemented.
- Password prompt detection and auto-entry are not implemented.
- Remote SSH login has a process path, but needs end-to-end manual validation
  against real hosts and failure cases.
- Terminal themes are stored in settings but not fully applied to SwiftTerm.
- iTerm2 profile import is not implemented.
- Prompt marks, command status, reconnect, and terminal failure banners are not
  implemented.

## Credentials And Migration

- `CredentialService` can write to Keychain, but there is no finished UI for
  saving, updating, deleting, or selecting credentials.
- Legacy `vault.json` import to Keychain is not implemented.
- Sensitive-data warnings for importing plaintext credentials are not
  implemented.
- Schema migration exists as a skeleton, not a full versioned upgrade framework.

## Diagnostics

- Diagnostics reports are static.
- Reachability checks, SSH dry-run checks, credential checks, and jump-chain
  checks are not executed yet.
- Diagnostics results are not persisted or tied to session failure banners.

## Release And Updates

- Sparkle 2 is not integrated at runtime.
- Developer ID signing is not configured.
- Hardened Runtime is not configured.
- Notarization and stapling are not automated.
- DMG creation is not implemented in the Swift-native release path.
- GitHub Release automation and appcast generation are not implemented.

## Testing

- The current validation target is `HopdeckNativeCoreChecks`.
- There is no XCTest suite yet.
- There are no AppKit UI tests.
- PTY lifecycle tests are shallow and should cover detach/attach, resize,
  process exit, and close behavior more deeply.
- Migration tests use inline fixtures and should move to stable fixture files.
