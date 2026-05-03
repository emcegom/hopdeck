import { useMemo, useState } from "react";
import type { CSSProperties, DragEvent, MouseEvent, ReactNode } from "react";

import type { Host, TreeNode } from "../types/hopdeck";
import { TreeContextMenu, type TreeContextMenuItem } from "./TreeContextMenu";

type FolderNode = Extract<TreeNode, { type: "folder" }>;

export type TreeDragSource =
  | {
      type: "folder";
      nodeId: string;
    }
  | {
      type: "host";
      nodeId: string;
      hostId: string;
    };

export interface TreeMoveTarget {
  parentId: string | null;
  index?: number;
}

type TreeDropTarget = TreeMoveTarget & {
  folderId?: string;
  position: "before" | "inside" | "after" | "root";
};

interface TreeNavigatorProps {
  tree: TreeNode[];
  hosts: Record<string, Host>;
  expandedNodeIds: Set<string>;
  selectedHostId: string | null;
  searchQuery?: string;
  onToggleFolder: (folderId: string) => void;
  onSelectHost: (hostId: string) => void;
  onOpenHost: (hostId: string) => void;
  onCreateHost: (parentFolderId: string | null) => void;
  onCreateFolder: (parentFolderId: string | null) => void;
  onEditFolder: (folder: FolderNode) => void;
  onDeleteFolder: (folderId: string) => void;
  onEditHost: (hostId: string) => void;
  onDuplicateHost: (hostId: string) => void;
  onDeleteHost: (hostId: string) => void;
  onMoveNode: (source: TreeDragSource, target: TreeMoveTarget) => void;
}

export function TreeNavigator({
  tree,
  hosts,
  expandedNodeIds,
  selectedHostId,
  searchQuery = "",
  onToggleFolder,
  onSelectHost,
  onOpenHost,
  onCreateHost,
  onCreateFolder,
  onEditFolder,
  onDeleteFolder,
  onEditHost,
  onDuplicateHost,
  onDeleteHost,
  onMoveNode
}: TreeNavigatorProps) {
  const [menu, setMenu] = useState<{
    x: number;
    y: number;
    items: TreeContextMenuItem[];
  } | null>(null);
  const [dragSource, setDragSource] = useState<TreeDragSource | null>(null);
  const [dropTarget, setDropTarget] = useState<TreeDropTarget | null>(null);
  const normalizedSearchQuery = useMemo(() => searchQuery.trim().toLocaleLowerCase(), [searchQuery]);
  const closeMenu = () => setMenu(null);

  if (tree.length === 0) {
    return (
      <div className="tree-empty">
        <span className="tree-empty-title">No hosts yet</span>
        <span className="tree-empty-copy">Use the toolbar or a folder menu to add hosts.</span>
      </div>
    );
  }

  const showFolderMenu = (event: MouseEvent<HTMLElement>, folder: FolderNode) => {
    event.preventDefault();
    event.stopPropagation();
    setMenu({
      x: event.clientX,
      y: event.clientY,
      items: [
        { id: "new-host", label: "New Host", onSelect: () => onCreateHost(folder.id) },
        { id: "new-folder", label: "New Folder", onSelect: () => onCreateFolder(folder.id) },
        { id: "rename", label: "Rename", onSelect: () => onEditFolder(folder) },
        { id: "delete", label: "Delete", tone: "danger", onSelect: () => onDeleteFolder(folder.id) }
      ]
    });
  };

  const showHostMenu = (event: MouseEvent<HTMLElement>, hostId: string) => {
    event.preventDefault();
    event.stopPropagation();
    onSelectHost(hostId);
    setMenu({
      x: event.clientX,
      y: event.clientY,
      items: [
        { id: "connect", label: "Connect", onSelect: () => onOpenHost(hostId) },
        { id: "edit", label: "Edit", onSelect: () => onEditHost(hostId) },
        { id: "duplicate", label: "Duplicate", onSelect: () => onDuplicateHost(hostId) },
        { id: "delete", label: "Delete", tone: "danger", onSelect: () => onDeleteHost(hostId) }
      ]
    });
  };

  const showRootDropTarget = (event: DragEvent<HTMLElement>) => {
    const source = readDragSource(event);
    if (!source) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    event.dataTransfer.dropEffect = "move";
    setDragSource(source);
    setDropTarget({ parentId: null, position: "root" });
  };

  const dropOnRoot = (event: DragEvent<HTMLElement>) => {
    const source = readDragSource(event);
    if (!source) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    onMoveNode(source, { parentId: null });
    setDragSource(null);
    setDropTarget(null);
  };

  const clearDropTargetIfLeavingTree = (event: DragEvent<HTMLElement>) => {
    const nextTarget = event.relatedTarget;
    if (nextTarget instanceof Node && event.currentTarget.contains(nextTarget)) {
      return;
    }

    setDropTarget(null);
  };

  return (
    <nav className="tree-navigator" aria-label="Host tree" onDragLeave={clearDropTargetIfLeavingTree}>
      {tree.map((node, index) => (
        <TreeRow
          key={node.id}
          node={node}
          depth={0}
          index={index}
          parentId={null}
          hosts={hosts}
          expandedNodeIds={expandedNodeIds}
          selectedHostId={selectedHostId}
          normalizedSearchQuery={normalizedSearchQuery}
          dragSource={dragSource}
          dropTarget={dropTarget}
          onToggleFolder={onToggleFolder}
          onSelectHost={onSelectHost}
          onOpenHost={onOpenHost}
          onShowFolderMenu={showFolderMenu}
          onShowHostMenu={showHostMenu}
          onDragSourceChange={setDragSource}
          onDropTargetChange={setDropTarget}
          onMoveNode={onMoveNode}
        />
      ))}
      {dragSource ? (
        <div
          className={`tree-root-drop${dropTarget?.position === "root" ? " is-active" : ""}`}
          onDragOver={showRootDropTarget}
          onDrop={dropOnRoot}
        >
          Move to root
        </div>
      ) : null}
      {menu ? <TreeContextMenu x={menu.x} y={menu.y} items={menu.items} onClose={closeMenu} /> : null}
    </nav>
  );
}

interface TreeRowProps {
  node: TreeNode;
  depth: number;
  index: number;
  parentId: string | null;
  hosts: Record<string, Host>;
  expandedNodeIds: Set<string>;
  selectedHostId: string | null;
  normalizedSearchQuery: string;
  dragSource: TreeDragSource | null;
  dropTarget: TreeDropTarget | null;
  onToggleFolder: (folderId: string) => void;
  onSelectHost: (hostId: string) => void;
  onOpenHost: (hostId: string) => void;
  onShowFolderMenu: (event: MouseEvent<HTMLElement>, folder: FolderNode) => void;
  onShowHostMenu: (event: MouseEvent<HTMLElement>, hostId: string) => void;
  onDragSourceChange: (source: TreeDragSource | null) => void;
  onDropTargetChange: (target: TreeDropTarget | null) => void;
  onMoveNode: (source: TreeDragSource, target: TreeMoveTarget) => void;
}

function TreeRow({
  node,
  depth,
  index,
  parentId,
  hosts,
  expandedNodeIds,
  selectedHostId,
  normalizedSearchQuery,
  dragSource,
  dropTarget,
  onToggleFolder,
  onSelectHost,
  onOpenHost,
  onShowFolderMenu,
  onShowHostMenu,
  onDragSourceChange,
  onDropTargetChange,
  onMoveNode
}: TreeRowProps) {
  const rowDropTarget = (event: DragEvent<HTMLElement>): TreeDropTarget | null => {
    const source = readDragSource(event);
    if (!source) {
      return null;
    }

    const bounds = event.currentTarget.getBoundingClientRect();
    const ratio = bounds.height > 0 ? (event.clientY - bounds.top) / bounds.height : 0.5;

    if (node.type === "folder") {
      if (ratio < 0.25) {
        return { parentId, index, position: "before" };
      }

      if (ratio > 0.75) {
        return { parentId, index: index + 1, position: "after" };
      }

      return { parentId: node.id, folderId: node.id, position: "inside" };
    }

    return ratio < 0.5
      ? { parentId, index, position: "before" }
      : { parentId, index: index + 1, position: "after" };
  };

  const showDropTarget = (event: DragEvent<HTMLElement>) => {
    const target = rowDropTarget(event);
    if (!target) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    event.dataTransfer.dropEffect = "move";
    onDragSourceChange(readDragSource(event));
    onDropTargetChange(target);
  };

  const dropOnRow = (event: DragEvent<HTMLElement>) => {
    const source = readDragSource(event);
    const target = rowDropTarget(event);
    if (!source || !target) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    onMoveNode(source, { parentId: target.parentId, index: target.index });
    onDragSourceChange(null);
    onDropTargetChange(null);
  };

  const dragSourceForNode = (): TreeDragSource | null => {
    if (node.type === "folder") {
      return { type: "folder", nodeId: node.id };
    }

    return hosts[node.hostId] ? { type: "host", nodeId: node.id, hostId: node.hostId } : null;
  };
  const isDragging = dragSource ? sourceMatchesNode(dragSource, node) : false;
  const dropClass = dropTargetClass(dropTarget, node, parentId, index);

  if (node.type === "folder") {
    const isExpanded = expandedNodeIds.has(node.id);

    return (
      <div className="tree-group">
        <div
          className={`tree-row tree-folder${isDragging ? " is-dragging" : ""}${dropClass}`}
          style={{ "--tree-depth": depth } as CSSProperties}
          role="button"
          tabIndex={0}
          aria-expanded={isExpanded}
          draggable
          title={isExpanded ? "Collapse folder" : "Expand folder"}
          onClick={() => onToggleFolder(node.id)}
          onKeyDown={(event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              onToggleFolder(node.id);
            }
          }}
          onContextMenu={(event) => onShowFolderMenu(event, node)}
          onDragStart={(event) => {
            const source = dragSourceForNode();
            if (source) {
              writeDragSource(event, source);
              onDragSourceChange(source);
            }
          }}
          onDragOver={showDropTarget}
          onDragEnd={() => {
            onDragSourceChange(null);
            onDropTargetChange(null);
          }}
          onDrop={dropOnRow}
        >
          <span className="tree-disclosure" aria-hidden="true" />
          <span className="tree-folder-icon" aria-hidden="true" />
          <span className="tree-label">{highlightMatch(node.name, normalizedSearchQuery)}</span>
          <span className="tree-count">{node.children.length}</span>
          <button
            className="tree-row-menu"
            type="button"
            title="Folder actions"
            onClick={(event) => onShowFolderMenu(event, node)}
          >
            ...
          </button>
        </div>
        {isExpanded ? (
          <div className="tree-children">
            {node.children.map((child, childIndex) => (
              <TreeRow
                key={child.id}
                node={child}
                depth={depth + 1}
                index={childIndex}
                parentId={node.id}
                hosts={hosts}
                expandedNodeIds={expandedNodeIds}
                selectedHostId={selectedHostId}
                normalizedSearchQuery={normalizedSearchQuery}
                dragSource={dragSource}
                dropTarget={dropTarget}
                onToggleFolder={onToggleFolder}
                onSelectHost={onSelectHost}
                onOpenHost={onOpenHost}
                onShowFolderMenu={onShowFolderMenu}
                onShowHostMenu={onShowHostMenu}
                onDragSourceChange={onDragSourceChange}
                onDropTargetChange={onDropTargetChange}
                onMoveNode={onMoveNode}
              />
            ))}
          </div>
        ) : null}
      </div>
    );
  }

  const host = hosts[node.hostId];
  const isSelected = selectedHostId === node.hostId;
  const label = host?.alias ?? node.hostId;

  return (
    <div
      className={`tree-row tree-host${isSelected ? " is-selected" : ""}${host?.favorite ? " is-favorite" : ""}${isDragging ? " is-dragging" : ""}${dropClass}`}
      style={{ "--tree-depth": depth } as CSSProperties}
      role="button"
      tabIndex={0}
      draggable={Boolean(host)}
      title={host ? "Open host" : "Missing host reference"}
      onClick={() => onSelectHost(node.hostId)}
      onDoubleClick={() => onOpenHost(node.hostId)}
      onKeyDown={(event) => {
        if (event.key === "Enter") {
          event.preventDefault();
          onOpenHost(node.hostId);
        }
      }}
      onContextMenu={(event) => {
        if (host) {
          onShowHostMenu(event, node.hostId);
        }
      }}
      onDragStart={(event) => {
        const source = dragSourceForNode();
        if (source) {
          writeDragSource(event, source);
          onDragSourceChange(source);
        }
      }}
      onDragOver={showDropTarget}
      onDragEnd={() => {
        onDragSourceChange(null);
        onDropTargetChange(null);
      }}
      onDrop={dropOnRow}
    >
      <span className="tree-leaf-spacer" aria-hidden="true" />
      <span className="tree-host-icon" aria-hidden="true" />
      <span className="tree-host-text">
        <span className="tree-label">{highlightMatch(label, normalizedSearchQuery)}</span>
        {host ? <SearchSnippet host={host} query={normalizedSearchQuery} fallback={label} /> : null}
      </span>
      {host?.favorite ? <span className="tree-favorite" aria-label="Favorite" /> : null}
      {host ? (
        <button
          className="tree-row-menu"
          type="button"
          title="Host actions"
          onClick={(event) => onShowHostMenu(event, node.hostId)}
        >
          ...
        </button>
      ) : (
        <span />
      )}
    </div>
  );
}

function SearchSnippet({ host, query, fallback }: { host: Host; query: string; fallback: string }) {
  if (!query) {
    return null;
  }

  const fields = [
    host.host,
    host.user,
    `${host.user}@${host.host}`,
    host.tags.join(", ")
  ].filter((value) => value && value !== fallback);
  const match = fields.find((value) => value.toLocaleLowerCase().includes(query));

  if (!match) {
    return null;
  }

  return <span className="tree-search-snippet">{highlightMatch(match, query)}</span>;
}

function highlightMatch(value: string, query: string): ReactNode {
  if (!query) {
    return value;
  }

  const index = value.toLocaleLowerCase().indexOf(query);
  if (index === -1) {
    return value;
  }

  return (
    <>
      {value.slice(0, index)}
      <mark>{value.slice(index, index + query.length)}</mark>
      {value.slice(index + query.length)}
    </>
  );
}

function writeDragSource(event: DragEvent<HTMLElement>, source: TreeDragSource) {
  event.stopPropagation();
  event.dataTransfer.effectAllowed = "move";
  event.dataTransfer.setData("application/x-hopdeck-tree-node", JSON.stringify(source));
}

function readDragSource(event: DragEvent<HTMLElement>): TreeDragSource | null {
  const raw = event.dataTransfer.getData("application/x-hopdeck-tree-node");

  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as Partial<TreeDragSource>;
    if (parsed.type === "folder" && typeof parsed.nodeId === "string") {
      return { type: "folder", nodeId: parsed.nodeId };
    }

    if (parsed.type === "host" && typeof parsed.nodeId === "string" && typeof parsed.hostId === "string") {
      return { type: "host", nodeId: parsed.nodeId, hostId: parsed.hostId };
    }
  } catch {
    return null;
  }

  return null;
}

function dropTargetClass(
  target: TreeDropTarget | null,
  node: TreeNode,
  parentId: string | null,
  index: number
): string {
  if (!target || target.position === "root") {
    return "";
  }

  if (target.position === "inside" && node.type === "folder" && target.folderId === node.id) {
    return " is-drop-inside";
  }

  if (
    (target.position === "before" || target.position === "after") &&
    target.parentId === parentId &&
    target.index === (target.position === "before" ? index : index + 1)
  ) {
    return target.position === "before" ? " is-drop-before" : " is-drop-after";
  }

  return "";
}

function sourceMatchesNode(source: TreeDragSource, node: TreeNode): boolean {
  if (source.type === "folder") {
    return node.type === "folder" && node.id === source.nodeId;
  }

  return node.type === "hostRef" && node.id === source.nodeId;
}
