import { useCallback, useEffect, useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";

import { FolderEditorModal } from "./components/FolderEditorModal";
import { HostEditorModal } from "./components/HostEditorModal";
import { TerminalWorkspace } from "./components/TerminalWorkspace";
import { TreeNavigator } from "./components/TreeNavigator";
import type { Host, HostDocument, TerminalSession, TreeNode } from "./types/hopdeck";

type HostEditorState =
  | {
      mode: "create" | "edit";
      host: Host;
    }
  | null;
type FolderNode = Extract<TreeNode, { type: "folder" }>;
type FolderEditorState =
  | {
      mode: "create";
    }
  | {
      mode: "edit";
      folder: FolderNode;
    }
  | null;

function App() {
  const [document, setDocument] = useState<HostDocument | null>(null);
  const [expandedNodeIds, setExpandedNodeIds] = useState<Set<string>>(new Set());
  const [selectedHostId, setSelectedHostId] = useState<string | null>(null);
  const [sessions, setSessions] = useState<TerminalSession[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [hostEditor, setHostEditor] = useState<HostEditorState>(null);
  const [folderEditor, setFolderEditor] = useState<FolderEditorState>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const selectedHost = selectedHostId && document ? document.hosts[selectedHostId] ?? null : null;

  const hostCount = useMemo(() => (document ? Object.keys(document.hosts).length : 0), [document]);
  const filteredTree = useMemo(
    () => filterTree(document?.tree ?? [], document?.hosts ?? {}, searchQuery),
    [document, searchQuery]
  );
  const visibleExpandedNodeIds = useMemo(
    () => (searchQuery.trim() ? new Set(collectFolderIds(filteredTree)) : expandedNodeIds),
    [expandedNodeIds, filteredTree, searchQuery]
  );

  const loadDocument = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const nextDocument = await invoke<HostDocument>("get_host_document");
      setDocument(nextDocument);
      setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
      setSelectedHostId((current) =>
        current && nextDocument.hosts[current] ? current : firstHostId(nextDocument.tree, nextDocument.hosts)
      );
    } catch (caught) {
      setError(errorMessage(caught));
      setDocument(null);
      setExpandedNodeIds(new Set());
      setSelectedHostId(null);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadDocument();
  }, [loadDocument]);

  const toggleFolder = useCallback((folderId: string) => {
    setExpandedNodeIds((current) => {
      const next = new Set(current);

      if (next.has(folderId)) {
        next.delete(folderId);
      } else {
        next.add(folderId);
      }

      return next;
    });
  }, []);

  const openHost = useCallback(
    async (hostId: string) => {
      const host = document?.hosts[hostId];

      if (!host) {
        return;
      }

      setSelectedHostId(hostId);

      try {
        const session = await invoke<TerminalSession>("start_terminal_session", { hostId });
        setSessions((current) => [session, ...current.filter((item) => item.hostId !== hostId)]);
        setActiveSessionId(session.id);
      } catch (caught) {
        const message = errorMessage(caught);
        const session = createSession(host, fallbackCommand(host), "error", message);
        setSessions((current) => [session, ...current.filter((item) => item.hostId !== hostId)]);
        setActiveSessionId(session.id);
      }
    },
    [document]
  );

  const saveHost = useCallback(async (host: Host) => {
    const nextDocument = await invoke<HostDocument>("update_host", { host });
    setDocument(nextDocument);
    setSelectedHostId(host.id);
  }, []);

  const deleteHost = useCallback(
    async (hostId: string) => {
      const nextDocument = await invoke<HostDocument>("delete_host", { hostId });
      setDocument(nextDocument);
      setSessions((current) => {
        const nextSessions = current.filter((session) => session.hostId !== hostId);
        setActiveSessionId((currentActiveSessionId) =>
          nextSessions.some((session) => session.id === currentActiveSessionId)
            ? currentActiveSessionId
            : nextSessions[0]?.id ?? null
        );
        return nextSessions;
      });
      setSelectedHostId((current) =>
        current === hostId ? firstHostId(nextDocument.tree, nextDocument.hosts) : current
      );
    },
    []
  );

  const createHost = useCallback(async (host: Host) => {
    const nextDocument = await invoke<HostDocument>("create_host", { parentId: null, host });
    setDocument(nextDocument);
    setSelectedHostId(host.id);
  }, []);

  const saveHostFromEditor = useCallback(
    async (host: Host) => {
      if (hostEditor?.mode === "create") {
        await createHost(host);
      } else {
        await saveHost(host);
      }
    },
    [createHost, hostEditor?.mode, saveHost]
  );

  const createFolder = useCallback(async (name: string) => {
    const nextDocument = await invoke<HostDocument>("create_folder", { parentId: null, name });
    setDocument(nextDocument);
    setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
  }, []);

  const renameFolder = useCallback(async (folderId: string, name: string) => {
    const nextDocument = await invoke<HostDocument>("update_folder", { folderId, name });
    setDocument(nextDocument);
  }, []);

  const deleteFolder = useCallback(
    async (folderId: string) => {
      const folder = findFolderById(document?.tree ?? [], folderId);
      const deletedHostIds = new Set(folder ? collectHostIds(folder.children) : []);
      const nextDocument = await invoke<HostDocument>("delete_folder", { folderId });

      setDocument(nextDocument);
      setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
      setSessions((current) => {
        const nextSessions = current.filter((session) => !deletedHostIds.has(session.hostId));
        setActiveSessionId((currentActiveSessionId) =>
          nextSessions.some((session) => session.id === currentActiveSessionId)
            ? currentActiveSessionId
            : nextSessions[0]?.id ?? null
        );
        return nextSessions;
      });
      setSelectedHostId((current) =>
        current && deletedHostIds.has(current) ? firstHostId(nextDocument.tree, nextDocument.hosts) : current
      );
    },
    [document]
  );

  const closeSession = useCallback((sessionId: string) => {
    setSessions((current) => {
      const nextSessions = current.filter((session) => session.id !== sessionId);

      setActiveSessionId((currentActiveSessionId) => {
        if (currentActiveSessionId !== sessionId) {
          return currentActiveSessionId;
        }

        return nextSessions[0]?.id ?? null;
      });

      return nextSessions;
    });
  }, []);

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <header className="sidebar-header">
          <div>
            <h1>Hopdeck</h1>
            <p>{isLoading ? "Loading hosts..." : `${hostCount} hosts`}</p>
          </div>
          <div className="sidebar-actions">
            <button
              className="icon-button"
              type="button"
              onClick={() => setHostEditor({ mode: "create", host: createDefaultHost(document?.hosts ?? {}) })}
              title="New host"
            >
              <span className="new-host-icon" aria-hidden="true" />
            </button>
            <button
              className="icon-button"
              type="button"
              onClick={() => setFolderEditor({ mode: "create" })}
              title="New folder"
            >
              <span className="new-folder-icon" aria-hidden="true" />
            </button>
            <button className="icon-button" type="button" onClick={loadDocument} title="Reload hosts">
              <span className="reload-icon" aria-hidden="true" />
            </button>
          </div>
        </header>

        {error ? (
          <div className="load-error" role="alert">
            <strong>Unable to load host document</strong>
            <span>{error}</span>
          </div>
        ) : null}

        <label className="sidebar-search">
          <span className="search-icon" aria-hidden="true" />
          <input
            aria-label="Search hosts"
            placeholder="Search hosts"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
          />
        </label>

        {isLoading ? (
          <div className="loading-list" aria-label="Loading host tree">
            <span />
            <span />
            <span />
          </div>
        ) : (
          <TreeNavigator
            tree={filteredTree}
            hosts={document?.hosts ?? {}}
            expandedNodeIds={visibleExpandedNodeIds}
            selectedHostId={selectedHostId}
            onToggleFolder={toggleFolder}
            onSelectHost={(hostId) => setSelectedHostId(hostId)}
            onOpenHost={openHost}
            onEditFolder={(folder) => {
              const sourceFolder = findFolderById(document?.tree ?? [], folder.id) ?? folder;
              setFolderEditor({ mode: "edit", folder: sourceFolder });
            }}
            onEditHost={(hostId) => {
              const host = document?.hosts[hostId];
              if (host) {
                setHostEditor({ mode: "edit", host });
              }
            }}
          />
        )}
      </aside>

      <section className="workspace">
        <TerminalWorkspace
          sessions={sessions}
          activeSessionId={activeSessionId}
          selectedHost={selectedHost}
          onCloseSession={closeSession}
          onSelectSession={(sessionId) => setActiveSessionId(sessionId)}
        />
      </section>

      {hostEditor ? (
        <HostEditorModal
          host={hostEditor.host}
          hosts={document?.hosts ?? {}}
          mode={hostEditor.mode}
          onClose={() => setHostEditor(null)}
          onDelete={hostEditor.mode === "edit" ? deleteHost : undefined}
          onSave={saveHostFromEditor}
        />
      ) : null}

      {folderEditor ? (
        <FolderEditorModal
          folder={folderEditor.mode === "edit" ? folderEditor.folder : undefined}
          mode={folderEditor.mode}
          onClose={() => setFolderEditor(null)}
          onCreate={createFolder}
          onDelete={folderEditor.mode === "edit" ? deleteFolder : undefined}
          onRename={folderEditor.mode === "edit" ? renameFolder : undefined}
        />
      ) : null}
    </main>
  );
}

const collectExpandedFolderIds = (tree: TreeNode[]): string[] => {
  const ids: string[] = [];

  for (const node of tree) {
    if (node.type === "folder") {
      if (node.expanded) {
        ids.push(node.id);
      }

      ids.push(...collectExpandedFolderIds(node.children));
    }
  }

  return ids;
};

const collectFolderIds = (tree: TreeNode[]): string[] => {
  const ids: string[] = [];

  for (const node of tree) {
    if (node.type === "folder") {
      ids.push(node.id, ...collectFolderIds(node.children));
    }
  }

  return ids;
};

const findFolderById = (tree: TreeNode[], folderId: string): FolderNode | null => {
  for (const node of tree) {
    if (node.type === "hostRef") {
      continue;
    }

    if (node.id === folderId) {
      return node;
    }

    const nested = findFolderById(node.children, folderId);
    if (nested) {
      return nested;
    }
  }

  return null;
};

const collectHostIds = (tree: TreeNode[]): string[] => {
  const hostIds: string[] = [];

  for (const node of tree) {
    if (node.type === "hostRef") {
      hostIds.push(node.hostId);
    } else {
      hostIds.push(...collectHostIds(node.children));
    }
  }

  return hostIds;
};

const filterTree = (tree: TreeNode[], hosts: Record<string, Host>, query: string): TreeNode[] => {
  const normalizedQuery = query.trim().toLocaleLowerCase();

  if (!normalizedQuery) {
    return tree;
  }

  return tree.reduce<TreeNode[]>((matches, node) => {
    if (node.type === "hostRef") {
      const host = hosts[node.hostId];
      if (host && matchesHost(host, normalizedQuery)) {
        matches.push(node);
      }
      return matches;
    }

    const children = filterTree(node.children, hosts, normalizedQuery);
    const folderMatches = node.name.toLocaleLowerCase().includes(normalizedQuery);

    if (!folderMatches && children.length === 0) {
      return matches;
    }

    matches.push({
      ...node,
      expanded: true,
      children: folderMatches ? node.children : children
    });
    return matches;
  }, []);
};

const matchesHost = (host: Host, query: string): boolean => {
  return [
    host.alias,
    host.host,
    host.user,
    `${host.user}@${host.host}`,
    ...host.tags
  ].some((value) => value.toLocaleLowerCase().includes(query));
};

const firstHostId = (tree: TreeNode[], hosts: Record<string, Host>): string | null => {
  for (const node of tree) {
    if (node.type === "hostRef" && hosts[node.hostId]) {
      return node.hostId;
    }

    if (node.type === "hostRef") {
      continue;
    }

    const nestedHostId = firstHostId(node.children, hosts);

    if (nestedHostId) {
      return nestedHostId;
    }
  }

  return null;
};

const createSession = (
  host: Host,
  command: string,
  status: TerminalSession["status"],
  message?: string
): TerminalSession => ({
  id: `${host.id}-${Date.now()}`,
  hostId: host.id,
  title: host.alias,
  command,
  status,
  message,
  createdAt: new Date().toISOString()
});

const fallbackCommand = (host: Host): string => {
  const userPrefix = host.user ? `${host.user}@` : "";
  return `ssh -p ${host.port} ${userPrefix}${host.host}`;
};

const createDefaultHost = (hosts: Record<string, Host>): Host => {
  const id = nextHostId(hosts);

  return {
    id,
    alias: "new-host",
    host: "127.0.0.1",
    user: "root",
    port: 22,
    tags: [],
    favorite: false,
    isJumpHost: false,
    jumpChain: [],
    auth: { type: "password", passwordRef: null, autoLogin: false },
    notes: "",
    createdAt: null,
    updatedAt: null,
    lastConnectedAt: null
  };
};

const nextHostId = (hosts: Record<string, Host>): string => {
  const base = "new-host";
  let index = 1;
  let candidate = base;

  while (hosts[candidate]) {
    index += 1;
    candidate = `${base}-${index}`;
  }

  return candidate;
};

const errorMessage = (caught: unknown): string => {
  if (caught instanceof Error) {
    return caught.message;
  }

  if (typeof caught === "string") {
    return caught;
  }

  return "Unknown error";
};

export default App;
