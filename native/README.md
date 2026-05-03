# Hopdeck Native Spike

This directory contains the first Swift/AppKit spike for the next native Hopdeck
implementation.

The spike intentionally starts small:

- Native AppKit window and toolbar.
- Finder-style host sidebar with sample hosts.
- SwiftTerm-backed terminal view.
- Local shell and `/usr/bin/ssh` command construction.
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

The core checks cover SSH command construction and host JSON storage. Keychain
roundtrip checks are opt-in so routine validation does not create or delete
Keychain items:

```zsh
HOPDECK_RUN_KEYCHAIN_CHECKS=1 swift run HopdeckNativeCoreChecks
```

Current spike checklist:

- [x] Native AppKit window, toolbar, split view, and host sidebar.
- [x] SwiftTerm-backed local shell and `/usr/bin/ssh` session launch path.
- [x] `Cmd+W` is bound to `Close Session`, not application quit.
- [x] Tab selection is synchronized with the session model.
- [x] Session close state is routed through `SessionManager`.
- [x] Host JSON document storage and legacy import skeleton.
- [x] Keychain credential store, with no default write during normal checks.
- [x] Local `.app` package script with bundled SwiftTerm resources.

This is not the production native app yet. It is the first validation target for
the highest-risk area: SwiftTerm + PTY + session lifecycle.
