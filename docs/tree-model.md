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

