# Hopdeck Product Design

## Name

**Hopdeck**

Tagline:

> Native SSH launchpad for macOS.

The name combines **Hop**, meaning SSH jump hosts and server hopping, with
**deck**, meaning a focused set of cards, controls, and saved targets.

## Product Vision

Hopdeck is a native SwiftUI macOS SSH connection manager for engineers who want
fast, local, button-based access to servers without adopting a cloud account,
Electron shell, or heavyweight terminal suite.

Its core promise:

> Search a server, press Connect, and land in the right shell.

Hopdeck should feel like a small, trustworthy macOS utility: quick to open,
clear about what it stores, respectful of local files, and explicit about every
jump and password used during a connection.

## Product Goals

- Provide one-click SSH launch for direct hosts and jump-host paths.
- Keep all configuration local by default.
- Support a local password vault, including an intentionally visible Plain JSON
  mode for users who want readable local control.
- Make jump chains readable before connection so users know exactly where the
  session will go.
- Launch into external terminal apps instead of building a terminal emulator in
  the first versions.
- Offer multiple terminal backends over time: Terminal.app, iTerm2, WezTerm,
  Ghostty, Alacritty, kitty, and custom commands.
- Import useful OpenSSH configuration without hiding the generated SSH command.
- Stay fast, native, and low-memory on Apple Silicon and Intel Macs.

## Non-Goals For Early Versions

- Cloud sync, team sharing, or accounts.
- Full remote desktop management.
- Built-in terminal emulator.
- Built-in SFTP file manager.
- Enterprise policy management.
- Full replacement for every OpenSSH feature.
- Automatic bypass of MFA or interactive security prompts.
- Background network scanning or host discovery.

## Target Users

### Primary Personas

**Backend Engineer**

- Manages staging, production, and personal development servers.
- Often knows the target host but not the exact SSH command.
- Values fast search, favorites, and copyable commands.

**SRE / Operations Engineer**

- Moves through bastions, production hosts, and database machines.
- Needs the connection path to be visible before launching.
- Cares about recent hosts, tags, notes, and avoiding mistakes.

**Database Administrator**

- Uses specific database jump paths and privileged accounts.
- Needs notes, warnings, and clear authentication state.
- Wants quick password copy/reveal with deliberate confirmation.

**macOS Power User Migrating From Xshell, SecureCRT, Termius, WindTerm**

- Wants a native macOS app rather than a heavy cross-platform shell.
- Expects host groups, buttons, jump hosts, and saved credentials.
- May prefer local password visibility instead of Keychain-only storage.

### Secondary Personas

**Solo Developer / Homelab User**

- Manages a handful of VPS, NAS, and home servers.
- Wants simple JSON backup and no subscription.

**Consultant**

- Switches between client environments.
- Needs clear grouping and reduced risk of connecting to the wrong host.

## User Problems

- Too many server names, IP addresses, accounts, ports, and jump paths to
  remember.
- Jump-host commands are tedious and error-prone to type repeatedly.
- Password entry across jump chains is repetitive.
- SSH config can become hard to scan as environments grow.
- Electron and Java clients can feel heavy on macOS.
- Some users want local password visibility and file-level ownership.
- Users need to know whether a saved host is direct, proxied, password-based, or
  key-based before connecting.

## Product Principles

- Native macOS first.
- Local-first configuration.
- Button-based connection flow.
- Clear over clever: show the command/path when possible.
- Do not require iTerm2.
- Do not require cloud sync or accounts.
- Support password visibility only through deliberate user action.
- Never pretend Plain JSON is secure; label it honestly.
- Keep SSH semantics understandable instead of hiding everything behind magic.
- Degrade gracefully when a terminal backend or helper tool is unavailable.

## Core Experience

Hopdeck opens to a three-pane interface:

```text
Sidebar            Host List              Detail
---------------------------------------------------------------
Favorites          prod-app-01            prod-app-01
Recent             prod-db-01             app@10.0.1.20:22
All Hosts          jump-prod
Production                               Path
Staging                                  Mac -> jump-prod -> prod-app-01
Jump Hosts
                                          Auth
                                          Password vault item available

                                          [Connect]
                                          [Copy Password]
                                          [Reveal Password]
```

The primary path:

```text
Open Hopdeck -> Search host -> Press Connect -> External terminal opens -> SSH login completes
```

The app should make the selected host feel actionable immediately. Search,
keyboard selection, and the Connect button are more important than decorative
content.

## Core Workflows

### Direct SSH

```text
Mac -> prod-app-01
```

1. User selects or searches for `prod-app-01`.
2. Detail panel shows `app@10.0.1.20:22`.
3. User presses Connect.
4. Hopdeck opens the configured terminal backend with `ssh app@10.0.1.20 -p 22`.

### Single Jump Host

```text
Mac -> jump-prod -> prod-app-01
```

1. User opens a target host that references `jump-prod`.
2. Detail panel shows the complete path.
3. User presses Connect.
4. Hopdeck generates an OpenSSH `-J` command or compatible backend command.
5. Terminal opens at the target login flow.

### Multi-Hop Chain

```text
Mac -> jump-edge -> jump-core -> prod-db-01
```

1. User selects a host with multiple jump references.
2. Detail panel renders each hop in order.
3. Validation flags missing hosts, missing users, or circular references.
4. Connect is disabled until the chain is valid.

### Password Copy / Reveal

1. User selects a host with a `passwordRef`.
2. Copy Password copies the value to the clipboard and starts an auto-clear
   timer.
3. Reveal Password requires an explicit click and masks again when the user
   changes host or the window loses focus.
4. Plain JSON mode displays a visible storage warning in Settings and vault
   views.

### Button-Based Auto Login

1. User presses Connect on a password-backed host.
2. Hopdeck resolves target and jump-chain passwords.
3. If auto-login is enabled, Hopdeck creates a temporary expect-style runner.
4. The selected terminal launches the runner.
5. The runner handles expected password prompts and then yields control to the
   interactive shell.

Auto-login must remain optional because prompt text, MFA, host-key prompts, and
security policy can vary by environment.

### Host Creation

1. User chooses Add Host.
2. User enters alias, host, port, user, group, tags, and auth method.
3. User optionally chooses jump hosts from existing entries.
4. Hopdeck validates the command preview before saving.
5. Host appears in All Hosts and any selected group.

### SSH Config Import

1. User opens Import from `~/.ssh/config`.
2. Hopdeck previews discovered hosts.
3. User selects entries to import or link.
4. Hopdeck stores app-specific metadata separately from OpenSSH source data.
5. Imported hosts remain clear about which fields came from SSH config.

## Information Architecture

### Primary Navigation

- Favorites
- Recent
- All Hosts
- Groups
- Tags
- Jump Hosts
- Vault
- Settings

### Sidebar Behavior

- Favorites and Recent are smart collections.
- Groups are user-defined and can be nested later, but MVP should keep them
  flat.
- Jump Hosts lists entries marked as reusable hops.
- Vault opens a password-item list without showing secret values by default.
- Settings contains storage, terminal, clipboard, and import options.

### Host List

Each row should show:

- Alias.
- User and address.
- Group or tag chips.
- Direct, single-hop, or multi-hop status.
- Authentication type: password, key, agent, or config alias.
- Last connected time.
- Favorite state.
- Validation state if the host is incomplete.

### Detail Panel

The detail panel contains:

- Alias and favorite button.
- Connection summary.
- Jump chain visualization.
- Generated command preview.
- Authentication status.
- Primary actions.
- Notes.
- Warnings for production or sensitive hosts.
- Edit metadata.

### Settings

Settings should include:

- Default terminal backend.
- Password storage mode.
- Clipboard clear timeout.
- Config directory path.
- Vault path.
- SSH config import path.
- Auto-login toggle.
- Temporary runner cleanup policy.
- Advanced custom terminal command template.

## Visual Direction

Hopdeck should feel like a polished macOS utility: quiet, dense enough for work,
and visually clear. The design should favor stable panes, native controls,
compact rows, and readable status labels over marketing-style layouts.

### Layout

- Three-pane `NavigationSplitView` on desktop widths.
- Collapsed navigation on narrow windows.
- Dense host rows with clear selection state.
- Detail actions grouped near the top so Connect is always easy to reach.
- No nested card layouts; use native grouped panels where needed.

### Visual Tone

- Calm, professional, and utility-focused.
- Strong contrast for selected hosts and dangerous actions.
- Small color accents for group/tag identity.
- Avoid using color alone for production warnings.
- Prefer SF Symbols and native macOS controls.

### Light Theme

```text
Background      #F7F8FA
Panel           #FFFFFF
Primary Text    #1D1D1F
Secondary Text  #6E7581
Border          #E4E7EC
Accent          #2F80ED
Success         #27AE60
Warning         #F2994A
Danger          #EB5757
```

### Dark Theme

```text
Background      #101214
Panel           #171A1D
Elevated        #20242A
Primary Text    #F2F4F7
Secondary Text  #9AA4B2
Border          #2B3036
Accent          #5AA9FF
Success         #4CD17D
Warning         #F5B85B
Danger          #FF6B6B
```

### Icon And Logo Concept

Logo concept:

```text
o--o
   |
   o
```

This represents local machine, jump host, and target host.

Recommended SF Symbols:

- `terminal` for Connect.
- `lock` / `lock.open` for vault state.
- `rectangle.connected.to.line.below` for jump paths.
- `star` for favorites.
- `clock` for recent hosts.
- `doc.on.doc` for copy actions.
- `exclamationmark.triangle` for warnings.

## Main Actions

- Connect
- Connect in New Window
- Connect With Backend
- Copy SSH Command
- Copy Password
- Reveal Password
- Add Host
- Edit Host
- Duplicate Host
- Delete Host
- Import SSH Config
- Validate Host

## Keyboard Shortcuts

```text
Enter             Connect selected host
Cmd+K             Search hosts
Cmd+N             Add host
Cmd+E             Edit selected host
Cmd+R             Reload configuration
Cmd+,             Settings
Cmd+Shift+C       Copy SSH command
Cmd+Shift+P       Copy password
Space             Preview selected host
```

## Data Model

Hopdeck supports two source categories:

```text
~/.ssh/config
~/.hopdeck/*.json
```

OpenSSH config remains the compatibility source for standard SSH aliases.
Hopdeck JSON stores app-specific fields: groups, tags, notes, vault references,
auto-login settings, preferred terminal, warning labels, and visual metadata.

### Host

```json
{
  "id": "prod-app-01",
  "alias": "prod-app-01",
  "host": "10.0.1.20",
  "user": "app",
  "port": 22,
  "groupId": "production",
  "tags": ["app", "prod"],
  "isFavorite": true,
  "isJumpHost": false,
  "jumpChain": ["jump-prod"],
  "auth": {
    "type": "password",
    "passwordRef": "password:prod-app-01",
    "identityFile": null,
    "useAgent": false,
    "autoLogin": true
  },
  "terminal": "system-default",
  "warning": {
    "level": "production",
    "message": "Production app server"
  },
  "notes": "Restart service through deploy playbook only.",
  "source": {
    "type": "hopdeck",
    "sshConfigHost": null
  },
  "timestamps": {
    "createdAt": "2026-04-29T00:00:00Z",
    "updatedAt": "2026-04-29T00:00:00Z",
    "lastConnectedAt": null
  }
}
```

### Group

```json
{
  "id": "production",
  "name": "Production",
  "color": "#EB5757",
  "sortOrder": 10
}
```

### Vault Item

```json
{
  "id": "password:prod-app-01",
  "label": "prod-app-01 app password",
  "username": "app",
  "password": "prod-password",
  "hostIds": ["prod-app-01"],
  "createdAt": "2026-04-29T00:00:00Z",
  "updatedAt": "2026-04-29T00:00:00Z"
}
```

### Settings

```json
{
  "version": 1,
  "defaultTerminal": "terminal-app",
  "passwordStorageMode": "plain-json",
  "clipboardClearSeconds": 30,
  "autoLoginEnabled": false,
  "configDirectory": "~/.hopdeck",
  "sshConfigPath": "~/.ssh/config"
}
```

## Password Storage

Hopdeck supports three storage modes:

```text
Plain JSON
Encrypted File
macOS Keychain
```

The product should default to Encrypted File when that mode is implemented, but
it must allow Plain JSON for users who explicitly want readable local password
storage.

Plain vault example:

```json
{
  "version": 1,
  "mode": "plain-json",
  "items": {
    "password:jump-prod": {
      "username": "zane",
      "password": "jump-password"
    },
    "password:prod-app-01": {
      "username": "app",
      "password": "prod-password"
    }
  }
}
```

When Plain JSON is selected, the UI should show:

```text
Passwords are stored as readable text in ~/.hopdeck/vault.json.
Use this only on a trusted Mac.
```

## Security Boundary

Hopdeck is a local SSH launcher, not an SSH security product. It should reduce
typing and configuration mistakes while preserving OpenSSH behavior and local
user control.

### In Scope

- File permission checks for `~/.hopdeck` and vault files.
- Clear labeling of Plain JSON mode.
- No password logging.
- No password transmission to Hopdeck-owned services.
- Clipboard auto-clear after a configurable timeout.
- Masked password display by default.
- Temporary runner creation with restrictive permissions.
- Deletion of temporary auto-login runners when practical.
- Validation of jump-chain references and circular paths.
- Visible command preview for generated SSH sessions.

### Out Of Scope

- Protection from a compromised macOS user account.
- Protection from screen recording, clipboard monitors, or malware.
- Bypassing SSH server policy, MFA, or host-key verification.
- Guaranteeing auto-login for every custom password prompt.
- Enterprise secrets governance.

### Required Security Behaviors

- Never write passwords to logs, analytics, crash text, or debug output.
- Never include passwords in command-line arguments.
- Do not store secrets in `hosts.json`.
- Use `chmod 700 ~/.hopdeck` and `chmod 600 ~/.hopdeck/*.json` where possible.
- Warn if vault files are world-readable.
- Require deliberate user action for Reveal Password.
- Mask secrets when app focus changes.
- Make Plain JSON warnings persistent, not dismiss-only.

## Terminal Backends

Hopdeck should not require iTerm2.

Supported backends:

- Terminal.app
- iTerm2
- WezTerm
- Ghostty
- Alacritty
- kitty
- Custom command

MVP starts with Terminal.app. iTerm2 can follow once backend abstractions are in
place. Other terminals should use documented command-line launch behavior and a
template system where needed.

## Command Generation

Direct host:

```text
ssh app@10.0.1.20 -p 22
```

Single jump host:

```text
ssh -J jump@jump.example.com:22 app@10.0.1.20 -p 22
```

Imported SSH config alias:

```text
ssh prod-app-01
```

Hopdeck should prefer generated commands for Hopdeck-owned hosts and alias-based
commands for imported SSH config entries when that preserves user intent.

## MVP Scope

Hopdeck 0.1 should include:

- Native SwiftUI app shell.
- Three-pane host browser.
- Manual host creation and editing.
- Local JSON host storage.
- Plain JSON password vault.
- Search and filtering.
- Direct SSH connect through Terminal.app.
- Single jump-host connect through Terminal.app.
- Copy SSH Command.
- Copy Password.
- Reveal Password.
- Basic Settings for config path, terminal backend, and clipboard timeout.
- Clear Plain JSON warnings.

## Version Roadmap

### 0.1 MVP

- SwiftUI app skeleton.
- Host model and local host store.
- Host list/detail.
- Plain local config.
- Plain local password vault.
- Terminal.app launch.
- Direct SSH and one jump host.
- Password copy/reveal.

### 0.2 Usability

- Favorites.
- Recent hosts.
- Better host editor validation.
- iTerm2 support.
- Jump chain visualization.
- Clipboard auto-clear.
- Basic SSH config import.

### 0.3 Automation

- expect-based auto-login.
- Multi-hop password handling.
- Settings page polish.
- Backend chooser.
- Command preview improvements.
- Permission warnings.

### 0.4 Compatibility

- WezTerm, Ghostty, Alacritty, kitty, and custom command backends.
- Import/export.
- SSH config merge strategy.
- Better ProxyJump and ProxyCommand support.

### 1.0

- Encrypted vault.
- Optional macOS Keychain mode.
- Signed and notarized `.app` build.
- Migration tools.
- Reliable update path for config schema versions.
- Documentation and recovery guidance.

## Product Risks

- Password auto-login can be brittle because prompts vary by server, locale, MFA,
  and host-key state.
- Plain JSON vault can create false confidence if warnings are too subtle.
- Terminal backend behavior differs across apps and versions.
- SSH config parsing can be complex, especially `Include`, `Match`,
  `ProxyCommand`, and patterns.
- Multi-hop errors can be hard to explain unless validation is precise.
- Users may expect a built-in terminal because many SSH managers include one.
- Clipboard auto-clear may fail if another app overwrites the clipboard.

## Acceptance Criteria

### MVP Product Acceptance

- User can add, edit, and delete a host.
- User can search hosts and connect with the keyboard or Connect button.
- User can save a password in Plain JSON mode.
- User can copy and reveal that password with clear warnings.
- User can press Connect and open Terminal.app.
- User can connect through one jump host.
- User can copy the generated SSH command.
- User can understand where host and vault files are stored.
- User can see whether a host is direct, jump-based, password-based, or
  key-based.
- No password appears in logs or generated command-line arguments.

### Design Acceptance

- The first screen is the actual connection manager, not a landing page.
- The app works comfortably in light and dark mode.
- The host list remains usable with at least 200 hosts.
- The selected host, connection path, and primary action are visible without
  scrolling in a standard desktop window.
- Production warnings are visible without relying only on color.
- Plain JSON mode is unmistakably labeled.

### Documentation Acceptance

- Product docs explain goals, personas, workflows, IA, visual direction, data
  model, security boundary, roadmap, risks, and MVP acceptance.
- Implementation docs map product requirements to concrete SwiftUI models,
  services, milestones, tests, and release gates.
