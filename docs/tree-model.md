# Tree Model

Hopdeck uses a real tree model instead of flat groups.

The main document is stored at:

```text
~/.hopdeck/hosts.json
```

Top-level shape:

```json
{
  "version": 2,
  "tree": [],
  "hosts": {}
}
```

Tree nodes:

```ts
type TreeNode =
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
```

Hosts live in a map keyed by stable host id. Folders only reference hosts.

This lets Hopdeck support:

- Nested folders.
- Stable host metadata during reorganization.
- Smart nodes such as Favorites, Recent, Jump Hosts, and All Hosts.
- Future drag-and-drop without rewriting host records.

## Current Operations

The Rust backend currently supports:

- Loading the host document from `~/.hopdeck/hosts.json`.
- Creating a sample document when the file is missing or empty.
- Saving a replacement document.
- Creating, renaming, and deleting folders.
- Creating, updating, deleting, and favoriting hosts.
- Pruning deleted host ids from other hosts' jump chains.
- Migrating legacy flat/grouped host files into the `version: 2` tree model.

## Import Validation Expectations

Any product import flow should validate the same invariants before replacing the
local file:

- `version` is supported.
- Every `hostRef.hostId` points to an entry in `hosts`.
- Every host id is unique.
- Every `jumpChain` entry points to an existing host.
- Folder names are non-empty.
- Imported data is backed up before writing to `~/.hopdeck/hosts.json`.
