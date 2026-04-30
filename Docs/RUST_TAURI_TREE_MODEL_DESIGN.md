# Hopdeck Rust/Tauri Tree Model Design

## Purpose

This document defines the redesigned Hopdeck direction after the SwiftUI
external-terminal experiment.

The new product direction is:

```text
Rust + Tauri + xterm.js + portable-pty
```

The new navigation model is a real expandable tree, similar to Xshell,
SecureCRT, Finder, and IDE project navigators. Hosts are no longer primarily
shown as a flat list filtered by sidebar categories. The tree becomes the
central interaction surface.

## Product Positioning

Hopdeck is a local-first SSH jump console.

Core promise:

```text
Open Hopdeck, expand a folder, double-click a host, land in a terminal tab.
```

The app should feel like a lightweight SSH workspace:

- Server folders are visible and scannable.
- Jump hosts can live beside normal hosts.
- Double-click connects.
- Single-click previews details.
- Terminal sessions are opened inside Hopdeck.
- Passwords and host metadata remain local.

## Why Tree Model

Flat groups break down when environments grow. A tree model matches how users
think about infrastructure:

```text
Company
  Production
    Jump Hosts
    Apps
    Databases
  Staging
    Apps
  Development
    Personal
```

Benefits:

- Nested organization without overloading tags.
- Natural migration path from Xshell-style folders.
- Clear place for jump hosts, apps, databases, and client environments.
- Better keyboard navigation.
- Easier future drag-and-drop reorganization.
- One source of truth for navigation order.

## High-Level UI

Hopdeck uses a two-zone layout:

```text
┌──────────────────────────────┬──────────────────────────────────────┐
│ Tree Navigator               │ Detail / Terminal Workspace           │
├──────────────────────────────┼──────────────────────────────────────┤
│ Search                       │ Selected Host Detail                  │
│                              │ or                                   │
│ ▾ Favorites                  │ Terminal Tabs                         │
│   prod-app-01                │                                      │
│ ▾ Production                 │ [prod-app-01] [prod-db-01]            │
│   ▾ Jump Hosts               │                                      │
│     jump-prod                │ app@prod-app-01:~$                    │
│   ▾ Apps                     │                                      │
│     prod-app-01              │                                      │
│     prod-app-02              │                                      │
│   ▾ Databases                │                                      │
│     prod-db-01               │                                      │
│ ▸ Staging                    │                                      │
└──────────────────────────────┴──────────────────────────────────────┘
```

The old Sidebar + Host List split is removed. The tree is both navigation and
host list.

## Tree Interaction Model

### Folder Nodes

Single click:

- Select folder.
- Show folder detail, child count, notes, and actions.

Double click:

- Expand or collapse folder.

Context menu:

- New Folder
- New Host
- Rename
- Duplicate
- Delete
- Expand All
- Collapse All

Keyboard:

- Left: collapse folder or move to parent.
- Right: expand folder.
- Enter: expand/collapse.
- Delete: delete after confirmation.

### Host Nodes

Single click:

- Select host.
- Show host detail.

Double click:

- Connect host.
- Open terminal tab in the workspace.

Context menu:

- Connect
- Connect in New Tab
- Edit
- Duplicate
- Favorite / Unfavorite
- Copy SSH Command
- Copy Password
- Reveal Password
- Delete

Keyboard:

- Enter: connect selected host.
- Cmd+Enter: connect in new tab.
- Space: preview detail.

### Smart Nodes

Smart nodes are generated views, not stored as physical folders:

```text
Favorites
Recent
Jump Hosts
All Hosts
Invalid Hosts
```

They appear at the top of the tree and can be expanded like folders. Their
children reference existing host IDs.

Smart node rules:

- Favorites: hosts with `favorite = true`.
- Recent: hosts with `lastConnectedAt`, sorted descending.
- Jump Hosts: hosts with `isJumpHost = true` or used by another host's
  `jumpChain`.
- Invalid Hosts: hosts with validation errors.
- All Hosts: every host sorted by alias.

Smart nodes do not own hosts. Dragging out of smart nodes should move the real
host only if the user drags to a physical folder.

## Tree Data Model

Hopdeck should use a real tree model rather than `folderPath`.

The navigation tree and host records are separate:

- Tree nodes define structure, order, and hierarchy.
- Host records define SSH connection metadata.

This separation allows:

- One host record to be referenced by smart nodes.
- Future aliases or shortcuts without duplicating credentials.
- Stable host IDs during folder reorganization.
- Custom ordering independent of host creation time.

## JSON Schema

Primary file:

```text
~/.hopdeck/hosts.json
```

Top-level structure:

```json
{
  "version": 2,
  "tree": [
    {
      "type": "folder",
      "id": "folder-production",
      "name": "Production",
      "expanded": true,
      "children": [
        {
          "type": "folder",
          "id": "folder-production-jump-hosts",
          "name": "Jump Hosts",
          "expanded": true,
          "children": [
            {
              "type": "hostRef",
              "id": "node-jump-prod",
              "hostId": "jump-prod"
            }
          ]
        },
        {
          "type": "folder",
          "id": "folder-production-apps",
          "name": "Apps",
          "expanded": true,
          "children": [
            {
              "type": "hostRef",
              "id": "node-prod-app-01",
              "hostId": "prod-app-01"
            }
          ]
        }
      ]
    }
  ],
  "hosts": {
    "jump-prod": {
      "id": "jump-prod",
      "alias": "jump-prod",
      "host": "1.2.3.4",
      "user": "zane",
      "port": 22,
      "tags": ["prod", "jump"],
      "favorite": false,
      "isJumpHost": true,
      "jumpChain": [],
      "auth": {
        "type": "password",
        "passwordRef": "password:jump-prod",
        "autoLogin": true
      },
      "notes": "Production jump host.",
      "createdAt": "2026-04-30T00:00:00Z",
      "updatedAt": "2026-04-30T00:00:00Z",
      "lastConnectedAt": null
    },
    "prod-app-01": {
      "id": "prod-app-01",
      "alias": "prod-app-01",
      "host": "10.0.1.20",
      "user": "app",
      "port": 22,
      "tags": ["prod", "app"],
      "favorite": true,
      "isJumpHost": false,
      "jumpChain": ["jump-prod"],
      "auth": {
        "type": "password",
        "passwordRef": "password:prod-app-01",
        "autoLogin": true
      },
      "notes": "Production app server.",
      "createdAt": "2026-04-30T00:00:00Z",
      "updatedAt": "2026-04-30T00:00:00Z",
      "lastConnectedAt": null
    }
  }
}
```

## Rust Types

Suggested model:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostDocument {
    pub version: u32,
    pub tree: Vec<TreeNode>,
    pub hosts: BTreeMap<String, Host>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum TreeNode {
    #[serde(rename = "folder")]
    Folder {
        id: String,
        name: String,
        expanded: bool,
        children: Vec<TreeNode>,
    },
    #[serde(rename = "hostRef")]
    HostRef {
        id: String,
        host_id: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Host {
    pub id: String,
    pub alias: String,
    pub host: String,
    pub user: String,
    pub port: u16,
    pub tags: Vec<String>,
    pub favorite: bool,
    pub is_jump_host: bool,
    pub jump_chain: Vec<String>,
    pub auth: HostAuth,
    pub notes: String,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
    pub last_connected_at: Option<DateTime<Utc>>,
}
```

Auth model:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum HostAuth {
    #[serde(rename = "password")]
    Password {
        password_ref: Option<String>,
        auto_login: bool,
    },
    #[serde(rename = "key")]
    Key {
        identity_file: Option<String>,
        use_agent: bool,
    },
    #[serde(rename = "agent")]
    Agent,
    #[serde(rename = "none")]
    None,
}
```

## Frontend Types

TypeScript model:

```ts
export type TreeNode =
  | {
      type: "folder";
      id: string;
      name: string;
      expanded: boolean;
      children: TreeNode[];
    }
  | {
      type: "hostRef";
      id: string;
      hostId: string;
    };

export interface HostDocument {
  version: number;
  tree: TreeNode[];
  hosts: Record<string, Host>;
}
```

Tree rendering:

```text
TreeNavigator
  SmartSection
  TreeNodeView
    FolderNode
    HostNode
```

## Tree Validation

Validation happens in Rust and is surfaced to the UI.

Rules:

- Every `hostRef.hostId` must exist in `hosts`.
- Folder IDs must be unique.
- HostRef node IDs must be unique.
- A physical host should appear at most once in the physical tree for MVP.
- Smart nodes may reference hosts without owning them.
- Empty folders are valid.
- Deleting a folder requires either deleting contained hosts or moving them.
- `jumpChain` IDs must exist in `hosts`.
- `jumpChain` must not contain the target host ID.
- Cycles in jump chains are invalid.

Validation output:

```rust
pub struct TreeValidationIssue {
    pub severity: ValidationSeverity,
    pub node_id: Option<String>,
    pub host_id: Option<String>,
    pub message: String,
}
```

## Tree Commands

Tauri commands:

```rust
get_host_document() -> HostDocument
save_host_document(document: HostDocument)

create_folder(parent_id: Option<String>, name: String) -> HostDocument
rename_folder(folder_id: String, name: String) -> HostDocument
delete_folder(folder_id: String, mode: DeleteFolderMode) -> HostDocument
move_node(node_id: String, target_folder_id: Option<String>, index: usize) -> HostDocument

create_host(parent_folder_id: Option<String>, host: Host, password: Option<String>) -> HostDocument
update_host(host: Host, password: Option<String>) -> HostDocument
delete_host(host_id: String) -> HostDocument
duplicate_host(host_id: String, target_folder_id: Option<String>) -> HostDocument

toggle_favorite(host_id: String) -> HostDocument
mark_connected(host_id: String) -> HostDocument
validate_host_document() -> Vec<TreeValidationIssue>
```

Delete folder modes:

```rust
pub enum DeleteFolderMode {
    DeleteChildren,
    MoveChildrenToParent,
}
```

## Search Behavior

Search does not destroy tree context. It filters and reveals matching paths.

Example query:

```text
prod db
```

Result:

```text
▾ Production
  ▾ Databases
    prod-db-01
```

Rules:

- Match host alias, host address, user, tags, notes.
- Match folder names.
- Keep ancestors visible for matched descendants.
- Highlight matched text.
- Enter connects first selected host result.
- Escape clears search and restores expansion state.

## Drag And Drop

MVP can ship without drag and drop, but the model must support it.

Future behavior:

- Drag host to folder: move hostRef node.
- Drag folder to folder: move subtree.
- Drag smart-node host into folder: create/move physical hostRef.
- Drag external SSH config import into folder: create imported host records.

## Import Strategy

Import from `~/.ssh/config` should place imported hosts into a chosen folder.

Default:

```text
Imported
  ~/.ssh/config
    host-a
    host-b
```

Rules:

- Existing host aliases are updated only after confirmation.
- Imported fields are marked with `source = "sshConfig"`.
- App-only metadata remains local in Hopdeck.
- Imported jump hosts are resolved if their aliases exist in the same import.

## Migration From Existing Swift JSON

Current Swift prototype uses a flat host array:

```json
{
  "version": 1,
  "hosts": [
    {
      "id": "prod-app-01",
      "group": "Production"
    }
  ]
}
```

Migration to tree document:

1. Load existing flat hosts.
2. Group by `group`.
3. Create one folder per group.
4. Insert each host as a `hostRef`.
5. Convert `tags` containing `favorite` into `favorite = true`.
6. Preserve `jumpChain`, `auth`, `notes`, and timestamps.
7. Write version `2` document.

Example:

```text
group = "Production"
```

becomes:

```text
Production
  prod-app-01
```

Hosts without a group go to:

```text
Ungrouped
```

## Terminal Workspace Relationship

The tree only selects and launches hosts. Active sessions live in the terminal
workspace.

Selecting a host:

```text
Tree -> Detail Panel
```

Double-clicking a host:

```text
Tree -> connect_host(hostId) -> Terminal Tab
```

The terminal tab title defaults to host alias.

If the same host is double-clicked while already connected:

MVP behavior:

```text
Focus existing tab.
```

Optional later behavior:

```text
Ask whether to open another session.
```

## Visual Design

Tree rows:

```text
▾ Production
  ▾ Apps
    ● prod-app-01       Password  Jump
    ● prod-app-02       Key       Direct
  ▾ Databases
    ● prod-db-01        Password  Multi-hop
```

Suggested icons:

- Folder: standard folder.
- Host: server icon.
- Jump host: connected nodes icon.
- Favorite: star marker.
- Password: lock marker.
- Key: key marker.
- Invalid: warning marker.
- Connected: green dot.

Row density should be close to Finder or Xcode navigator, not oversized cards.

## MVP Scope For Tree Model

Required:

- Render physical tree.
- Render smart nodes: Favorites, Recent, Jump Hosts, All Hosts.
- Expand/collapse folders.
- Single-click host detail.
- Double-click host connect.
- Create/edit/delete host.
- Create/rename/delete folder.
- Move host to folder through edit dialog or context menu.
- Search with ancestor preservation.
- Persist tree order.
- Validate missing host references and missing jump hosts.

Deferred:

- Drag and drop.
- Multi-select.
- Tree keyboard reordering.
- Per-folder environment variables.
- Shared/team folder sync.

## Implementation Plan

Phase 1: Data Foundation

- Create Rust `HostDocument`, `TreeNode`, and `Host`.
- Implement JSON load/save.
- Add migration from version 1 flat hosts.
- Add validation.
- Add unit tests for tree traversal, validation, and migration.

Phase 2: Tree UI

- Create `TreeNavigator`.
- Render folder and host nodes recursively.
- Add expand/collapse state.
- Add selection state.
- Add smart nodes.
- Add search filtering.

Phase 3: Host Actions

- Single-click detail.
- Double-click connect.
- Context menu.
- Create/edit/delete host.
- Create/rename/delete folder.

Phase 4: Terminal Integration

- Connect selected host to PTY session.
- Focus existing session if already connected.
- Update Recent smart node after connection.

Phase 5: Polish

- Drag and drop.
- Better icons and badges.
- Import destination picker.
- Validation badges.
- Keyboard shortcuts.

## Acceptance Criteria

Tree model is complete when:

- A user can create nested folders.
- A user can create hosts inside any folder.
- A user can expand/collapse folders.
- A user can single-click a host to inspect it.
- A user can double-click a host to connect.
- Favorites, Recent, Jump Hosts, and All Hosts appear as smart nodes.
- The tree order persists after restart.
- Missing host refs are detected and shown as validation issues.
- Migration from flat host JSON produces a usable folder tree.
- Unit tests cover traversal, migration, validation, and command building.

