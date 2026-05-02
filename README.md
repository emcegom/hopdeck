# Hopdeck

Hopdeck is a local-first SSH jump console for macOS. It keeps host inventory,
jump chains, saved connection settings, and embedded terminal sessions in one
focused desktop app while still using the system `ssh` client for the actual
connection.

It is built with Rust, Tauri, React, and xterm.js.

## Highlights

- Manage hosts in an expandable folder tree.
- Create, edit, duplicate, move, favorite, and delete SSH hosts.
- Open hosts in embedded terminal tabs.
- Build jump-host connections through `ssh -J`.
- Search by alias, address, user, `user@host`, and tags.
- Import hosts from `~/.ssh/config`.
- Import and export Hopdeck backup bundles.
- Tune terminal appearance, font settings, opacity, blur, and colors.
- Import the current iTerm2 profile colors.
- Keep data on your machine under `~/.hopdeck/`.

Hopdeck does not automate Terminal.app or iTerm2 windows. Terminal sessions run
inside the app through a local pseudoterminal and the OpenSSH binary already on
your Mac.

## Install

Hopdeck currently publishes a macOS Apple Silicon build:

```text
Hopdeck_0.1.0_aarch64.app.zip
```

Install from the GitHub release:

```zsh
curl -L \
  -o ~/Downloads/Hopdeck_0.1.0_aarch64.app.zip \
  https://github.com/emcegom/hopdeck/releases/download/v0.1.0/Hopdeck_0.1.0_aarch64.app.zip

ditto -x -k ~/Downloads/Hopdeck_0.1.0_aarch64.app.zip ~/Downloads/
mv ~/Downloads/Hopdeck.app /Applications/Hopdeck.app
open /Applications/Hopdeck.app
```

If macOS blocks the first launch because the app is not notarized yet, remove
the quarantine attribute and open it again:

```zsh
xattr -dr com.apple.quarantine /Applications/Hopdeck.app
open /Applications/Hopdeck.app
```

You can also download the zip from the release page, unarchive it, and drag
`Hopdeck.app` into `/Applications`.

## Usage

On first launch, Hopdeck creates a sample host tree if no local host document
exists. Add or import real hosts, then double-click a host to open a terminal
session.

Common workflows:

- Use the left sidebar to browse folders and hosts.
- Double-click a host to start an SSH session.
- Use terminal tabs in the workspace to switch between active sessions.
- Press `Cmd+W` to close the current terminal tab.
- Use Settings to adjust theme, terminal rendering, import/export, and iTerm2
  color import.
- Use host jump chains when a target should connect through one or more jump
  hosts.

## Local Data

Hopdeck is local-first. The main app data directory is:

```text
~/.hopdeck/
```

Current files:

```text
~/.hopdeck/
  hosts.json                 # host tree, host records, jump chains
  vault.json                 # plain saved password vault
  settings.json              # UI, terminal, and connection settings
  hopdeck-backup.json        # default export/import bundle path
```

Back up `~/.hopdeck/` before deleting or reinstalling Hopdeck if you want to
keep your hosts, settings, and saved credentials.

## Security Notes

Hopdeck's current vault mode is `plain`. Saved password values are written to:

```text
~/.hopdeck/vault.json
```

Anyone who can read that file can read the saved passwords. Hopdeck does not
currently use macOS Keychain or encrypted vault storage.

For sensitive environments:

- Prefer SSH agent or key-based authentication.
- Avoid storing production passwords in the plain vault unless the local
  plaintext risk is acceptable.
- Use disk encryption and normal file permission hygiene.
- Treat exported backup bundles as sensitive because they include the vault.

Password auto-login is a convenience feature: when enabled, Hopdeck watches the
embedded terminal for password-like prompts and writes the saved password once
for that session.

## Backup And Import

The Settings screen can export a Hopdeck bundle to:

```text
~/.hopdeck/hopdeck-backup.json
```

The same screen can import that bundle back into Hopdeck. Before import,
Hopdeck writes a timestamped copy of the current local data:

```text
~/.hopdeck/hopdeck-backup-before-import-YYYYMMDDHHMMSS.json
```

You can also back up the raw files manually:

```zsh
mkdir -p ~/Desktop/hopdeck-backup
cp ~/.hopdeck/hosts.json ~/Desktop/hopdeck-backup/
cp ~/.hopdeck/vault.json ~/Desktop/hopdeck-backup/
cp ~/.hopdeck/settings.json ~/Desktop/hopdeck-backup/
```

Manual restore:

```zsh
mkdir -p ~/.hopdeck
cp ~/Desktop/hopdeck-backup/hosts.json ~/.hopdeck/hosts.json
cp ~/Desktop/hopdeck-backup/vault.json ~/.hopdeck/vault.json
cp ~/Desktop/hopdeck-backup/settings.json ~/.hopdeck/settings.json
```

Restart Hopdeck after manually replacing JSON files so the app reloads them
from disk.

## Development

Requirements:

- macOS.
- Rust and Cargo.
- Node.js 20+ and npm.
- Tauri 2 prerequisites for macOS.
- A working local `ssh` binary for terminal session testing.

Install dependencies:

```zsh
npm install
```

Run the desktop app in development:

```zsh
npm run dev
```

Build the frontend:

```zsh
npm run frontend:build
```

Run Rust backend tests:

```zsh
cd src-tauri
cargo test
```

Build a production app bundle:

```zsh
npm run build
```

The macOS bundle is created under:

```text
src-tauri/target/release/bundle/macos/Hopdeck.app
```

Create a release zip:

```zsh
mkdir -p release
ditto -c -k --sequesterRsrc --keepParent \
  src-tauri/target/release/bundle/macos/Hopdeck.app \
  release/Hopdeck_0.1.0_aarch64.app.zip
shasum -a 256 release/Hopdeck_0.1.0_aarch64.app.zip
```

## Uninstall

Quit Hopdeck and remove the app bundle:

```zsh
osascript -e 'quit app "Hopdeck"'
rm -rf /Applications/Hopdeck.app
```

Remove local Hopdeck data only if you want to delete hosts, settings, saved
passwords, and backup bundles:

```zsh
rm -rf ~/.hopdeck
```

Optional macOS/Tauri runtime cleanup:

```zsh
rm -rf ~/Library/Application\ Support/com.emcegom.hopdeck
rm -rf ~/Library/Caches/com.emcegom.hopdeck
rm -rf ~/Library/WebKit/com.emcegom.hopdeck
rm -rf ~/Library/Saved\ Application\ State/com.emcegom.hopdeck.savedState
rm -f ~/Library/Preferences/com.emcegom.hopdeck.plist
```

The `~/Library/...` paths contain runtime preferences, caches, WebView data, and
saved window state. Your important Hopdeck data is under `~/.hopdeck/`.

## Troubleshooting

### The app starts with sample hosts

Hopdeck creates sample data when `~/.hopdeck/hosts.json` does not exist or is
empty. Create or import real hosts, then reload or restart the app.

### JSON edits are not visible

Restart Hopdeck, or use the sidebar reload button. The running frontend keeps a
copy of the currently loaded host document in memory.

### SSH fails immediately

Check the same target with the system `ssh` command in a normal terminal.
Hopdeck runs local OpenSSH, so DNS, keys, agent state, known-host prompts,
jump-host reachability, and network access still come from your local
environment.

### A jump-host command looks wrong

Inspect the host's `jumpChain` in `~/.hopdeck/hosts.json`. Each item must point
to an existing host id. When a host or folder is deleted, Hopdeck prunes deleted
host ids from remaining jump chains.

### Passwords are visible in the vault file

That is expected for the current plain vault mode. Use SSH keys or the local SSH
agent when you need stronger credential handling.

### Background blur is missing

Open Settings and confirm `Background blur` is greater than `0`. The persisted
value lives in `~/.hopdeck/settings.json` as `terminal.backgroundBlur`.

## Roadmap

- Signed and notarized macOS release packaging.
- Safer credential storage beyond the plain vault.
- Stronger session lifecycle controls, including reconnect behavior.
- Smart views for favorites, recent hosts, jump hosts, and all hosts.
- Larger-inventory workflows such as duplicate detection and bulk editing.
- Automated frontend coverage for core interactions.

## Documentation

- [Tree model](docs/tree-model.md)
- [Terminal interaction design](docs/terminal-interaction-design.md)
- [Product acceptance checklist](docs/product-acceptance-checklist.md)
