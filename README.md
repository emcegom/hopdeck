# Hopdeck

Hopdeck is a local-first SSH jump console for macOS. It is built with Rust,
Tauri, React, xterm.js, and a real expandable tree model so day-to-day host
navigation feels closer to Xshell-style session management than to scripting
Terminal.app or iTerm2.

The product goal is straightforward: keep SSH inventory, jump chains, and
terminal sessions in one focused desktop app while leaving connection execution
to the system `ssh` client.

## Product Positioning

Hopdeck is for operators and developers who maintain many SSH targets and need
fast switching, clear grouping, and explicit jump-host paths.

It is intentionally local-first:

- Host inventory is stored on disk under `~/.hopdeck/`.
- SSH sessions are launched locally through `portable-pty`.
- Hopdeck does not depend on a hosted service, browser account, or remote sync.
- macOS Keychain is not used in the current credential model.

Hopdeck is not trying to replace full terminal emulators. It provides a managed
connection workspace around the system SSH client, with the terminal embedded in
the app.

## Core Interaction Model

- The left sidebar is the source of truth for navigation.
- Folders can be expanded, collapsed, created, renamed, and deleted.
- Hosts are selected from the tree and edited in a modal.
- Double-clicking a host starts an SSH terminal session.
- Search filters hosts by alias, address, user, `user@host`, and tags.
- The right workspace is reserved for terminal tabs and session output.
- A host can reference one or more jump hosts; Hopdeck converts that chain into
  an `ssh -J` command.
- Failed session starts are surfaced as terminal-like tabs with the attempted
  command and error message.

The current UI avoids AppleScript automation and does not open external
Terminal.app or iTerm2 windows.

## Feature Scope

### P0

P0 is the minimum usable SSH workspace:

- Load and save a local `version: 2` host document.
- Create a sample tree on first launch or empty data file.
- Migrate legacy flat/grouped `version: 1` host files into the tree model.
- Display nested folders and host references in the sidebar.
- Create, rename, and delete folders.
- Create, edit, and delete hosts.
- Remove deleted hosts from the tree and from affected jump chains.
- Build SSH commands from host metadata and jump chains.
- Start embedded terminal sessions through the local `ssh` binary.
- Write user input to the pty and stream SSH output back into xterm.js.
- Search host inventory by common connection fields.

### P1

P1 turns the prototype into a daily driver:

- Persist and expose app settings, including theme and terminal preferences.
- Add a visible background blur setting for terminal or window surfaces.
- Add import and export flows for host documents and vault documents.
- Add stronger validation before replacing imported data.
- Add session lifecycle controls such as reconnect and close-on-disconnect.
- Add drag-and-drop reorganization inside the tree.
- Add Favorites, Recent, Jump Hosts, and All Hosts smart views.
- Add password copy/autofill affordances that match the selected vault mode.
- Improve empty states, destructive action confirmations, and error recovery.

### P2

P2 covers polish, scale, and interoperability:

- Optional encrypted vault modes beyond the current plain vault.
- Optional macOS Keychain integration if the product chooses to support it later.
- Per-host visual preferences and terminal profiles.
- Multi-window or detached terminal support.
- Connection history, audit-friendly local activity metadata, and richer recent
  session views.
- Cross-machine import/export compatibility guarantees.
- Bulk editing and duplicate detection for large inventories.
- Backup rotation and recovery tools for `~/.hopdeck`.

## Credential Security

Hopdeck currently models credentials with a plain local vault:

```text
~/.hopdeck/vault.json
```

The current vault mode is `plain`. A plain vault stores password values in JSON
that can be viewed by anyone who can read the file. This is useful for early
local testing and migration work, but it is not encrypted secret storage.

Important security notes:

- The current implementation does not use macOS Keychain.
- Plain vault passwords are inspectable on disk.
- File permissions and disk encryption are the user's primary protection.
- Do not place production passwords in `vault.json` unless that local risk is
  acceptable.
- SSH agent and key-based authentication are preferred when available.

The host model can reference password records with `passwordRef`. When a host is
configured for password auth and auto-login is enabled, Hopdeck watches the
embedded SSH terminal output for password/passphrase prompts and writes the
stored password once for that session.

## Background Blur Setting

Hopdeck exposes background blur as a terminal appearance setting:

- Users can set blur strength from the app settings UI.
- The value is persisted as `terminal.backgroundBlur` in
  `~/.hopdeck/settings.json`.
- The terminal surface applies the value after reload.
- A value of `0` disables blur.
- The setting is intentionally subtle so terminal text stays readable.

## Import And Export

Hopdeck's data model is JSON-first, which makes manual backup possible even
before a dedicated UI exists.

Current data files:

```text
~/.hopdeck/
  hosts.json
  vault.json
  settings.json
```

Manual export:

```zsh
mkdir -p ~/Desktop/hopdeck-backup
cp ~/.hopdeck/hosts.json ~/Desktop/hopdeck-backup/
cp ~/.hopdeck/vault.json ~/Desktop/hopdeck-backup/
cp ~/.hopdeck/settings.json ~/Desktop/hopdeck-backup/
```

Manual import:

```zsh
mkdir -p ~/.hopdeck
cp ~/Desktop/hopdeck-backup/hosts.json ~/.hopdeck/hosts.json
cp ~/Desktop/hopdeck-backup/vault.json ~/.hopdeck/vault.json
cp ~/Desktop/hopdeck-backup/settings.json ~/.hopdeck/settings.json
```

Restart Hopdeck after manual import so the app reloads the files from disk.

Dedicated import/export UI should validate JSON shape, preserve a backup of the
previous local files, and clearly warn when importing a plain vault.

## Development Requirements

- macOS.
- Rust and Cargo.
- Node.js 20+ and npm.
- Tauri 2 prerequisites for macOS.
- A working local `ssh` binary for terminal session testing.

## Install Dependencies

```zsh
npm install
```

## Run In Development

```zsh
npm run dev
```

This runs `tauri dev`, which starts the Vite frontend and the Tauri shell.

## Build Frontend

```zsh
npm run frontend:build
```

This runs TypeScript checking and Vite production bundling.

## Test Rust Backend

```zsh
cd src-tauri
cargo test
```

The current backend tests cover tree persistence, folder operations, legacy
migration, and SSH command construction.

## Build App

```zsh
npm run build
```

This runs the configured Tauri build. The app bundle is produced under the
Tauri target output directory, for example:

```text
src-tauri/target/release/bundle/macos/
```

## Troubleshooting

### The app starts with sample hosts

Hopdeck creates a sample host tree when `~/.hopdeck/hosts.json` does not exist
or is empty. Create or import real hosts, then reload or restart the app.

### Host data does not change after editing JSON

Restart Hopdeck, or use the sidebar reload button. The running frontend keeps a
copy of the currently loaded host document in state.

### SSH session fails immediately

Check that the system `ssh` command works in a normal terminal for the same
target. Hopdeck builds and runs `ssh` locally, so DNS, keys, agent state, known
hosts prompts, jump host reachability, and network access still come from the
local environment.

### Jump host command looks wrong

Inspect the host's `jumpChain` in `~/.hopdeck/hosts.json`. Each item must point
to an existing host id. When a host or folder is deleted, Hopdeck prunes deleted
host ids from remaining jump chains.

### Passwords are visible in the vault file

That is expected for the current `plain` vault mode. Hopdeck does not encrypt
`vault.json` and does not use macOS Keychain yet.

### Imported data fails to load

Validate that `hosts.json` is either the current tree model:

```json
{
  "version": 2,
  "tree": [],
  "hosts": {}
}
```

or a legacy grouped host file that Hopdeck can migrate. Keep a copy of the
broken file before replacing it.

### Background blur is missing or does not persist

Open Settings and confirm `Background blur` is greater than `0`. The persisted
value lives in `~/.hopdeck/settings.json` as `terminal.backgroundBlur`.

## Roadmap

- Add timestamped backup rotation before import.
- Add richer validation and preview for imported data.
- Add signed/notarized DMG release automation.
- Add smart views for Favorites, Recent, Jump Hosts, and All Hosts.
- Add safer credential storage options beyond the plain vault.
- Add stronger terminal lifecycle controls and reconnect behavior.
- Add automated frontend tests for core interactions.
- Add release packaging notes for signed/notarized macOS builds.

## Documentation

- [Tree model](docs/tree-model.md)
- [Product acceptance checklist](docs/product-acceptance-checklist.md)
