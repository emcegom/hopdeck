# Hopdeck

Hopdeck is a native macOS SSH launchpad for engineers who frequently connect to servers through jump hosts.

The product goal is simple: turn complex SSH targets, jump chains, and saved credentials into a clear local connection panel.

## Direction

- Native macOS interface with SwiftUI.
- Local-first host and password storage.
- One-click SSH login through external terminals.
- Support for direct hosts, single jump hosts, and multi-hop chains.
- No forced cloud account or sync.

## Current State

This repository contains the first SwiftUI project skeleton plus product and implementation documents.

Important docs:

- [Product Design](Docs/PRODUCT_DESIGN.md)
- [Implementation Plan](Docs/IMPLEMENTATION_PLAN.md)
- [Rust/Tauri Tree Model Design](Docs/RUST_TAURI_TREE_MODEL_DESIGN.md)

## Requirements

- macOS 14 or newer.
- Xcode 15 or newer recommended.
- Swift 6 compatible toolchain.

Your machine currently has Xcode installed, but if `xcodebuild` still points to Command Line Tools, run:

```zsh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then verify:

```zsh
xcodebuild -version
swift --version
```

## Development

Open the package in Xcode:

```zsh
open Package.swift
```

Or build from the terminal:

```zsh
swift build
```

Run tests:

```zsh
swift test
```

Build a local macOS app bundle:

```zsh
chmod +x scripts/build_app.sh
scripts/build_app.sh
open .build/app/Hopdeck.app
```

The first production app bundle target can be added once the MVP screens and services settle.
