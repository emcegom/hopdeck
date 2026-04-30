# Product Acceptance Checklist

This checklist describes what Hopdeck should satisfy before a feature level is
considered accepted. It is written for product review, manual QA, and release
readiness.

## Product Positioning

- [ ] Hopdeck is described as a local-first macOS SSH jump console.
- [ ] The app is clearly positioned as an SSH inventory and terminal workspace,
      not as a hosted sync service.
- [ ] Users can understand that Hopdeck runs the local `ssh` binary rather than
      automating Terminal.app or iTerm2.
- [ ] Local data ownership and local filesystem risk are visible in the docs.

## P0 Acceptance

- [ ] First launch creates `~/.hopdeck/hosts.json` with a sample tree.
- [ ] Empty `hosts.json` is repaired by writing the sample tree.
- [ ] Current `version: 2` host documents load without migration.
- [ ] Legacy flat/grouped host documents migrate into the tree model.
- [ ] Sidebar renders nested folders and host references.
- [ ] Folder expand and collapse works without losing selection.
- [ ] New root folders can be created.
- [ ] Existing folders can be renamed.
- [ ] Folder deletion removes nested host records and related host references.
- [ ] New hosts can be created from the UI.
- [ ] Existing hosts can be edited from the UI.
- [ ] Host deletion removes the host from the map and from the tree.
- [ ] Deleting a host also removes that host id from other hosts' jump chains.
- [ ] Search matches alias, host, user, `user@host`, and tags.
- [ ] Double-clicking a host starts an embedded terminal session.
- [ ] Terminal input is written to the pty.
- [ ] Terminal output streams back into xterm.js.
- [ ] SSH commands include `-J` when a host has a jump chain.
- [ ] Session start failures are shown in the workspace with the attempted
      command and error message.

## P1 Acceptance

- [ ] App settings are loaded from and saved to `~/.hopdeck/settings.json`.
- [ ] Theme preference supports system, light, and dark modes.
- [ ] Terminal font family, font size, and cursor style are user configurable.
- [ ] Background blur is visible as a terminal/window appearance setting.
- [ ] Background blur persists as `terminal.backgroundBlur`.
- [ ] Setting blur to `0` disables blur.
- [ ] Blur does not make terminal text fail basic readability review.
- [ ] Host document export is available from the app.
- [ ] Host document import validates JSON before replacing local data.
- [ ] Vault export is available from the app.
- [ ] Vault import warns clearly when importing plain password data.
- [ ] Import keeps a backup of the previous local data files.
- [ ] Drag-and-drop tree reorganization preserves host ids and metadata.
- [ ] Favorites, Recent, Jump Hosts, and All Hosts smart views are available or
      explicitly deferred in the release notes.
- [ ] Session reconnect and close-on-disconnect behavior are controllable.

## P2 Acceptance

- [ ] A non-plain credential storage option is designed and documented.
- [ ] If macOS Keychain is added, migration and fallback behavior are documented.
- [ ] Large inventories remain searchable and navigable without noticeable UI
      stalls.
- [ ] Bulk editing is available for common host metadata.
- [ ] Duplicate host detection is available during create or import.
- [ ] Backup rotation or recovery tooling exists for `~/.hopdeck`.
- [ ] Cross-machine import/export compatibility is documented.
- [ ] Release builds have clear signing and notarization notes.

## Credential Safety

- [x] Documentation states that the current vault mode is `plain`.
- [x] Documentation states that `~/.hopdeck/vault.json` can reveal passwords.
- [x] Documentation states that Hopdeck does not currently use macOS Keychain.
- [x] Users are warned not to store production passwords in the plain vault
      unless the local plaintext risk is acceptable.
- [x] SSH key and agent-based authentication are recommended where practical.
- [ ] Any import/export flow warns before exporting or importing password data.

## Import And Export

- [x] Export includes hosts data.
- [x] Export includes settings data.
- [x] Export includes vault data in the local bundle.
- [x] Import validates host document version and tree shape.
- [x] Import validates that `hostRef.hostId` values exist in the `hosts` map.
- [x] Import validates that jump-chain host ids exist.
- [x] Import preserves a timestamped backup before replacing local files.
- [x] Manual import/export instructions remain available for recovery.

## Development And Release

- [ ] `npm install` installs frontend and Tauri CLI dependencies.
- [ ] `npm run dev` starts the Tauri development app.
- [ ] `npm run frontend:build` passes TypeScript checking and Vite build.
- [ ] `cd src-tauri && cargo test` passes.
- [ ] `npm run build` creates a production Tauri app bundle.
- [ ] Release notes mention whether the build is signed or notarized.
- [ ] Release notes mention the credential storage mode.

## Troubleshooting Coverage

- [ ] Docs explain why sample data appears on first launch.
- [ ] Docs explain where Hopdeck stores local data.
- [ ] Docs explain how to reload after manual JSON edits.
- [ ] Docs explain how local SSH, SSH agent, known hosts, DNS, and jump-host
      reachability affect session startup.
- [ ] Docs explain that visible plain vault passwords are expected in the
      current mode.
- [ ] Docs explain the current background blur persistence gap.

## Roadmap Review

- [ ] Roadmap separates must-have daily-driver work from polish.
- [ ] Credential hardening is visible on the roadmap.
- [ ] Import/export hardening is visible on the roadmap.
- [ ] Background blur persistence is visible on the roadmap.
- [ ] Smart views and drag-and-drop are visible on the roadmap.
- [ ] Packaging, signing, and notarization are visible on the roadmap.
