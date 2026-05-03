# Hopdeck Native Spike

This directory contains the first Swift/AppKit spike for the next native Hopdeck
implementation.

The spike intentionally starts small:

- Native AppKit window and toolbar.
- Finder-style host sidebar with sample hosts.
- SwiftTerm-backed terminal view with Hopdeck-owned PTY process adapter.
- Local shell and `/usr/bin/ssh` process launch.
- Session identity separated from host identity and UI position.

Run it with:

```zsh
cd native
swift run HopdeckNative
```

Build and package a local `.app` with:

```zsh
native/scripts/package-spike-app.sh
```

Validate the non-UI core with:

```zsh
cd native
swift run HopdeckNativeCoreChecks
```

The core checks cover SSH command construction, host/settings/workspace JSON
storage, and the legacy import/migration skeleton. Keychain roundtrip checks are
opt-in so routine validation does not create or delete Keychain items:

```zsh
HOPDECK_RUN_KEYCHAIN_CHECKS=1 swift run HopdeckNativeCoreChecks
```

Current spike checklist:

- [x] Native AppKit window, toolbar, split view, and host sidebar.
- [x] SwiftTerm-backed terminal renderer with Hopdeck-owned PTY process adapter.
- [x] Local shell and `/usr/bin/ssh` session launch path.
- [x] `Cmd+W` is bound to `Close Session`, not application quit.
- [x] Tab selection is synchronized with the session model.
- [x] Session close state is routed through `SessionManager`.
- [x] Host JSON document storage and legacy import skeleton.
- [x] Settings/workspace JSON document storage and native data migration skeleton.
- [x] Host CRUD writes through the native host inventory service.
- [x] Keychain credential store and credential service, with no default write during normal checks.
- [x] Connection diagnostics and release readiness service skeletons.
- [x] Local `.app` package script with bundled SwiftTerm resources.

Native data documents default to the user Application Support directory:

- `~/Library/Application Support/Hopdeck/hosts.json`
- `~/Library/Application Support/Hopdeck/settings.json`
- `~/Library/Application Support/Hopdeck/workspaces.json`

`MigrationService` can import the current legacy `~/.hopdeck/hosts.json` and
`~/.hopdeck/settings.json` files into those native documents. The workspace
document is derived from imported host folders for now and includes the initial
smart-view and connection-profile skeleton.

This is not the production native app yet. It is now a native implementation
spike with the main architecture seams in place: AppKit UI, session-owned PTY,
native JSON storage, Keychain credential boundaries, diagnostics, and local app
packaging.
