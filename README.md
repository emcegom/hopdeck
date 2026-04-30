# Hopdeck

Hopdeck is a local-first SSH jump console built with Rust, Tauri, React, and a real expandable tree model.

The goal is to provide an Xshell-like workflow for macOS without depending on AppleScript automation of iTerm2 or Terminal.app.

## Current Direction

- Rust backend with Tauri commands.
- React frontend with a folder-style tree navigator.
- Host data stored locally in `~/.hopdeck/hosts.json`.
- Tree model is the primary navigation model.
- Internal terminal workspace runs through `portable-pty` and xterm.js.
- Legacy Swift-era `version: 1` host files are migrated into the Rust tree model on launch.

## Interaction Model

- Double-click a host in the left tree to open an SSH session in the terminal workspace.
- Right-click a host to edit connection settings.
- Use the sidebar search to filter hosts by alias, address, user, or tag.
- Delete a host from the edit dialog with a second confirmation click.
- The right side is reserved for terminals; configuration opens as a modal.

## Development Requirements

- Rust and Cargo.
- Node.js 20+ and npm.
- macOS Tauri prerequisites.

## Install Dependencies

```zsh
npm install
```

## Run In Development

```zsh
npm run dev
```

## Build Frontend

```zsh
npm run frontend:build
```

## Test Rust Backend

```zsh
cd src-tauri
cargo test
```

## Build App

```zsh
npm run build
```

## Data Files

Hopdeck writes local data under:

```text
~/.hopdeck/
  hosts.json
  vault.json
  settings.json
```

The current implementation creates a sample tree on first launch.
