import type { CSSProperties, MouseEvent } from "react";

import type { Host, TreeNode } from "../types/hopdeck";

interface TreeNavigatorProps {
  tree: TreeNode[];
  hosts: Record<string, Host>;
  expandedNodeIds: Set<string>;
  selectedHostId: string | null;
  onToggleFolder: (folderId: string) => void;
  onSelectHost: (hostId: string) => void;
  onOpenHost: (hostId: string) => void;
  onEditHost: (hostId: string) => void;
}

export function TreeNavigator({
  tree,
  hosts,
  expandedNodeIds,
  selectedHostId,
  onToggleFolder,
  onSelectHost,
  onOpenHost,
  onEditHost
}: TreeNavigatorProps) {
  if (tree.length === 0) {
    return (
      <div className="tree-empty">
        <span className="tree-empty-title">No hosts yet</span>
        <span className="tree-empty-copy">Add folders and hosts from the backend model.</span>
      </div>
    );
  }

  return (
    <nav className="tree-navigator" aria-label="Host tree">
      {tree.map((node) => (
        <TreeRow
          key={node.id}
          node={node}
          depth={0}
          hosts={hosts}
          expandedNodeIds={expandedNodeIds}
          selectedHostId={selectedHostId}
          onToggleFolder={onToggleFolder}
          onSelectHost={onSelectHost}
          onOpenHost={onOpenHost}
          onEditHost={onEditHost}
        />
      ))}
    </nav>
  );
}

interface TreeRowProps extends Omit<TreeNavigatorProps, "tree"> {
  node: TreeNode;
  depth: number;
}

function TreeRow({
  node,
  depth,
  hosts,
  expandedNodeIds,
  selectedHostId,
  onToggleFolder,
  onSelectHost,
  onOpenHost,
  onEditHost
}: TreeRowProps) {
  if (node.type === "folder") {
    const isExpanded = expandedNodeIds.has(node.id);

    return (
      <div className="tree-group">
        <button
          className="tree-row tree-folder"
          style={{ "--tree-depth": depth } as CSSProperties}
          type="button"
          aria-expanded={isExpanded}
          title={isExpanded ? "Collapse folder" : "Expand folder"}
          onClick={() => onToggleFolder(node.id)}
        >
          <span className="tree-disclosure" aria-hidden="true" />
          <span className="tree-folder-icon" aria-hidden="true" />
          <span className="tree-label">{node.name}</span>
          <span className="tree-count">{node.children.length}</span>
        </button>
        {isExpanded ? (
          <div className="tree-children">
            {node.children.map((child) => (
              <TreeRow
                key={child.id}
                node={child}
                depth={depth + 1}
                hosts={hosts}
                expandedNodeIds={expandedNodeIds}
                selectedHostId={selectedHostId}
                onToggleFolder={onToggleFolder}
                onSelectHost={onSelectHost}
                onOpenHost={onOpenHost}
                onEditHost={onEditHost}
              />
            ))}
          </div>
        ) : null}
      </div>
    );
  }

  const host = hosts[node.hostId];
  const isSelected = selectedHostId === node.hostId;
  const editHost = (event: MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
    if (host) {
      onSelectHost(node.hostId);
      onEditHost(node.hostId);
    }
  };

  return (
    <button
      className={`tree-row tree-host${isSelected ? " is-selected" : ""}${host?.favorite ? " is-favorite" : ""}`}
      style={{ "--tree-depth": depth } as CSSProperties}
      type="button"
      title={host ? "Open host" : "Missing host reference"}
      onClick={() => onSelectHost(node.hostId)}
      onDoubleClick={() => onOpenHost(node.hostId)}
      onContextMenu={editHost}
    >
      <span className="tree-leaf-spacer" aria-hidden="true" />
      <span className="tree-host-icon" aria-hidden="true" />
      <span className="tree-label">{host?.alias ?? node.hostId}</span>
      {host?.favorite ? <span className="tree-favorite" aria-label="Favorite" /> : null}
    </button>
  );
}
