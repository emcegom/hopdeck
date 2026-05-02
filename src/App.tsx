import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type CSSProperties,
  type MouseEvent as ReactMouseEvent,
  type PointerEvent as ReactPointerEvent
} from "react";
import { setTheme as setAppTheme } from "@tauri-apps/api/app";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";

import { FolderEditorModal } from "./components/FolderEditorModal";
import { HostEditorModal } from "./components/HostEditorModal";
import { SettingsModal } from "./components/SettingsModal";
import { TerminalWorkspace } from "./components/TerminalWorkspace";
import { TreeNavigator, type TreeDragSource } from "./components/TreeNavigator";
import { darkTerminalColors, terminalBackgroundColor } from "./theme";
import type { AppSettings, Host, HostDocument, TerminalSession, TreeNode, VaultDocument } from "./types/hopdeck";

type HostEditorState =
  | {
      mode: "create" | "edit";
      host: Host;
      parentFolderId?: string | null;
    }
  | null;
type FolderNode = Extract<TreeNode, { type: "folder" }>;
type FolderEditorState =
  | {
      mode: "create";
      parentFolderId?: string | null;
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
  const [vault, setVault] = useState<VaultDocument | null>(null);
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [sidebarWidth, setSidebarWidth] = useState(300);
  const [searchQuery, setSearchQuery] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const systemTheme = useSystemTheme();
  const effectiveTheme = settings.theme === "system" ? systemTheme : settings.theme;

  useEffect(() => {
    void Promise.all([setAppTheme(effectiveTheme), getCurrentWindow().setTheme(effectiveTheme)]).catch(() => {
      // Browser previews do not expose the Tauri app API.
    });
  }, [effectiveTheme]);

  const selectedHost = selectedHostId && document ? document.hosts[selectedHostId] ?? null : null;

  const hostCount = useMemo(() => (document ? Object.keys(document.hosts).length : 0), [document]);
  const activeSession = useMemo(
    () => sessions.find((session) => session.id === activeSessionId) ?? sessions[0] ?? null,
    [activeSessionId, sessions]
  );
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
      const [nextDocument, nextVault, nextSettings] = await Promise.all([
        invoke<HostDocument>("get_host_document"),
        invoke<VaultDocument>("get_vault_document"),
        invoke<AppSettings>("get_app_settings")
      ]);
      setDocument(nextDocument);
      setVault(nextVault);
      setSettings(withSettingsDefaults(nextSettings));
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
        setSessions((current) => {
          current
            .filter((item) => item.hostId === hostId)
            .forEach((item) => closeBackendSession(item.id));
          return [session, ...current.filter((item) => item.hostId !== hostId)];
        });
        setActiveSessionId(session.id);
      } catch (caught) {
        const message = errorMessage(caught);
        const session = createSession(host, fallbackCommand(host), "error", message);
        setSessions((current) => {
          current
            .filter((item) => item.hostId === hostId)
            .forEach((item) => closeBackendSession(item.id));
          return [session, ...current.filter((item) => item.hostId !== hostId)];
        });
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
      const passwordRef = document?.hosts[hostId]?.auth.type === "password" ? document.hosts[hostId].auth.passwordRef : null;
      const nextDocument = await invoke<HostDocument>("delete_host", { hostId });
      if (passwordRef) {
        setVault(await invoke<VaultDocument>("delete_password", { passwordRef }));
      }
      setDocument(nextDocument);
      setSessions((current) => {
        const nextSessions = current.filter((session) => session.hostId !== hostId);
        current
          .filter((session) => session.hostId === hostId)
          .forEach((session) => closeBackendSession(session.id));
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
    [document]
  );

  const createHost = useCallback(async (host: Host, parentFolderId: string | null = null) => {
    const nextDocument = await invoke<HostDocument>("create_host", { parentId: parentFolderId, host });
    setDocument(nextDocument);
    if (parentFolderId) {
      setExpandedNodeIds((current) => new Set(current).add(parentFolderId));
    }
    setSelectedHostId(host.id);
  }, []);

  const saveHostFromEditor = useCallback(
    async (host: Host) => {
      if (hostEditor?.mode === "create") {
        await createHost(host, hostEditor.parentFolderId ?? null);
      } else {
        await saveHost(host);
      }
    },
    [createHost, hostEditor, saveHost]
  );

  const createFolder = useCallback(async (name: string, parentFolderId: string | null = null) => {
    const nextDocument = await invoke<HostDocument>("create_folder", { parentId: parentFolderId, name });
    setDocument(nextDocument);
    if (parentFolderId) {
      setExpandedNodeIds((current) => new Set(current).add(parentFolderId));
      return;
    }

    setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
  }, []);

  const savePassword = useCallback(async (passwordRef: string, username: string, password: string) => {
    const nextVault = await invoke<VaultDocument>("save_password", { passwordRef, username, password });
    setVault(nextVault);
  }, []);

  const deletePassword = useCallback(async (passwordRef: string) => {
    const nextVault = await invoke<VaultDocument>("delete_password", { passwordRef });
    setVault(nextVault);
  }, []);

  const saveSettings = useCallback(async (nextSettings: AppSettings) => {
    const saved = await invoke<AppSettings>("save_app_settings", { settings: nextSettings });
    setSettings(withSettingsDefaults(saved));
  }, []);

  const importSshConfig = useCallback(async () => {
    const nextDocument = await invoke<HostDocument>("import_ssh_config_from_default");
    setDocument(nextDocument);
    setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
  }, []);

  const exportConfig = useCallback(async () => {
    await invoke<string>("export_config_bundle");
  }, []);

  const importConfig = useCallback(async () => {
    const nextDocument = await invoke<HostDocument>("import_config_bundle");
    const [nextVault, nextSettings] = await Promise.all([
      invoke<VaultDocument>("get_vault_document"),
      invoke<AppSettings>("get_app_settings")
    ]);
    setDocument(nextDocument);
    setVault(nextVault);
    setSettings(withSettingsDefaults(nextSettings));
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
      const deletedPasswordRefs = Array.from(deletedHostIds)
        .map((hostId) => document?.hosts[hostId])
        .map((host) => (host?.auth.type === "password" ? host.auth.passwordRef : null))
        .filter((passwordRef): passwordRef is string => Boolean(passwordRef));
      const nextDocument = await invoke<HostDocument>("delete_folder", { folderId });
      await Promise.all(deletedPasswordRefs.map((passwordRef) => deletePassword(passwordRef)));

      setDocument(nextDocument);
      setExpandedNodeIds(new Set(collectExpandedFolderIds(nextDocument.tree)));
      setSessions((current) => {
        const nextSessions = current.filter((session) => !deletedHostIds.has(session.hostId));
        current
          .filter((session) => deletedHostIds.has(session.hostId))
          .forEach((session) => closeBackendSession(session.id));
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
    [deletePassword, document]
  );

  const duplicateHost = useCallback(
    async (hostId: string) => {
      if (!document) {
        return;
      }

      const host = document.hosts[hostId];
      if (!host) {
        return;
      }

      const parentFolderId = findParentFolderId(document.tree, { type: "host", nodeId: `node-${hostId}`, hostId });
      const duplicate = createDuplicateHost(host, document.hosts);
      await createHost(duplicate, parentFolderId);
      if (host.auth.type === "password" && duplicate.auth.type === "password" && host.auth.passwordRef) {
        const savedPassword = vault?.items[host.auth.passwordRef];
        if (savedPassword && duplicate.auth.passwordRef) {
          await savePassword(duplicate.auth.passwordRef, savedPassword.username, savedPassword.password);
        }
      }
    },
    [createHost, document, savePassword, vault]
  );

  const moveNode = useCallback(
    async (source: TreeDragSource, targetFolderId: string | null) => {
      if (!document) {
        return;
      }

      const moved = moveTreeNode(document.tree, source, targetFolderId);
      if (!moved) {
        return;
      }

      const nextDocument = await invoke<HostDocument>("save_host_document", {
        document: {
          ...document,
          tree: moved
        }
      });

      setDocument(nextDocument);
      if (targetFolderId) {
        setExpandedNodeIds((current) => new Set(current).add(targetFolderId));
      }
    },
    [document]
  );

  const closeSession = useCallback((sessionId: string) => {
    closeBackendSession(sessionId);
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

  const closeActiveSession = useCallback(() => {
    const sessionId = sessions.some((session) => session.id === activeSessionId)
      ? activeSessionId
      : sessions[0]?.id ?? null;

    if (sessionId) {
      closeSession(sessionId);
    }
  }, [activeSessionId, closeSession, sessions]);

  useEffect(() => {
    const closeShortcut = (event: KeyboardEvent) => {
      const isCloseShortcut =
        event.key.toLowerCase() === "w" &&
        (event.metaKey || event.ctrlKey) &&
        !event.altKey &&
        !event.shiftKey;

      if (!isCloseShortcut) {
        return;
      }

      event.preventDefault();
      event.stopPropagation();
      closeActiveSession();
    };

    window.addEventListener("keydown", closeShortcut, true);

    return () => {
      window.removeEventListener("keydown", closeShortcut, true);
    };
  }, [closeActiveSession]);

  useEffect(() => {
    let disposed = false;
    let unlisten: (() => void) | null = null;

    void listen("hopdeck-close-active-session", () => {
      closeActiveSession();
    }).then((nextUnlisten) => {
      if (disposed) {
        nextUnlisten();
      } else {
        unlisten = nextUnlisten;
      }
    });

    return () => {
      disposed = true;
      unlisten?.();
    };
  }, [closeActiveSession]);

  const markSessionClosed = useCallback((sessionId: string) => {
    setSessions((current) =>
      current.map((session) =>
        session.id === sessionId ? { ...session, status: "closed" } : session
      )
    );
  }, []);

  const importIterm2Theme = useCallback(async () => {
    const nextSettings = await invoke<AppSettings>("import_iterm2_theme");
    setSettings(withSettingsDefaults(nextSettings));
  }, []);

  const startSidebarResize = useCallback(
    (event: ReactPointerEvent<HTMLButtonElement>) => {
      if (isSidebarCollapsed) {
        return;
      }

      event.preventDefault();
      const startX = event.clientX;
      const startWidth = sidebarWidth;

      const resize = (moveEvent: PointerEvent) => {
        const nextWidth = startWidth + moveEvent.clientX - startX;
        setSidebarWidth(Math.min(520, Math.max(260, nextWidth)));
      };
      const stopResize = () => {
        window.removeEventListener("pointermove", resize);
        window.removeEventListener("pointerup", stopResize);
      };

      window.addEventListener("pointermove", resize);
      window.addEventListener("pointerup", stopResize);
    },
    [isSidebarCollapsed, sidebarWidth]
  );

  const startWindowDrag = useCallback((event: ReactMouseEvent<HTMLElement>) => {
    if (event.button !== 0) {
      return;
    }

    event.preventDefault();
    void getCurrentWindow().startDragging().catch(() => {
      // Browser previews do not expose the Tauri window API.
    });
  }, []);

  const appShellStyle = {
    "--sidebar-width": `${sidebarWidth}px`,
    "--terminal-blur": `${settings.terminal.backgroundBlur}px`,
    "--terminal-bg": terminalBackgroundColor(
      settings.terminal.colors.background,
      settings.terminal.backgroundOpacity,
      settings.terminal.backgroundBlur
    ),
    "--terminal-fg": settings.terminal.colors.foreground,
    "--terminal-accent": settings.terminal.colors.cursor
  } as CSSProperties;

  return (
    <main
      className={`app-shell${isSidebarCollapsed ? " is-sidebar-collapsed" : ""}`}
      data-theme={effectiveTheme}
      style={appShellStyle}
    >
      <aside className={`sidebar${isSidebarCollapsed ? " is-collapsed" : ""}`}>
        {isSidebarCollapsed ? (
          <button
            className="icon-button sidebar-toggle"
            type="button"
            onClick={() => setIsSidebarCollapsed(false)}
            title="Show sidebar"
            aria-label="Show sidebar"
          >
            <SidebarActionIcon name="expand" />
          </button>
        ) : (
          <>
            <header className="sidebar-header">
              <div className="sidebar-window-drag" data-tauri-drag-region onMouseDown={startWindowDrag} />
              <div className="sidebar-title">
                <h1>Hopdeck</h1>
                <p>{isLoading ? "Loading hosts..." : `${hostCount} hosts`}</p>
              </div>
              <div className="sidebar-actions">
                <button
                  className="sidebar-action-button"
                  type="button"
                  onClick={() =>
                    setHostEditor({ mode: "create", host: createDefaultHost(document?.hosts ?? {}), parentFolderId: null })
                  }
                  title="New host"
                  aria-label="New host"
                >
                  <SidebarActionIcon name="host" />
                  <span>Host</span>
                </button>
                <button
                  className="sidebar-action-button"
                  type="button"
                  onClick={() => setFolderEditor({ mode: "create", parentFolderId: null })}
                  title="New folder"
                  aria-label="New folder"
                >
                  <SidebarActionIcon name="folder" />
                  <span>Folder</span>
                </button>
                <button
                  className="sidebar-action-button"
                  type="button"
                  onClick={loadDocument}
                  title="Reload hosts"
                  aria-label="Reload hosts"
                >
                  <SidebarActionIcon name="refresh" />
                  <span>Reload</span>
                </button>
                <button
                  className="sidebar-action-button"
                  type="button"
                  onClick={() => setIsSettingsOpen(true)}
                  title="Settings"
                  aria-label="Settings"
                >
                  <SidebarActionIcon name="settings" />
                  <span>Prefs</span>
                </button>
                <button
                  className="sidebar-action-button"
                  type="button"
                  onClick={() => setIsSidebarCollapsed(true)}
                  title="Hide sidebar"
                  aria-label="Hide sidebar"
                >
                  <SidebarActionIcon name="collapse" />
                  <span>Hide</span>
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
                searchQuery={searchQuery}
                onToggleFolder={toggleFolder}
                onSelectHost={(hostId) => setSelectedHostId(hostId)}
                onOpenHost={openHost}
                onCreateHost={(parentFolderId) =>
                  setHostEditor({ mode: "create", host: createDefaultHost(document?.hosts ?? {}), parentFolderId })
                }
                onCreateFolder={(parentFolderId) => setFolderEditor({ mode: "create", parentFolderId })}
                onEditFolder={(folder) => {
                  const sourceFolder = findFolderById(document?.tree ?? [], folder.id) ?? folder;
                  setFolderEditor({ mode: "edit", folder: sourceFolder });
                }}
                onDeleteFolder={deleteFolder}
                onEditHost={(hostId) => {
                  const host = document?.hosts[hostId];
                  if (host) {
                    setHostEditor({ mode: "edit", host });
                  }
                }}
                onDuplicateHost={duplicateHost}
                onDeleteHost={deleteHost}
                onMoveNode={moveNode}
              />
            )}
          </>
        )}
      </aside>

      <button
        aria-label="Resize sidebar"
        className="sidebar-resizer"
        onPointerDown={startSidebarResize}
        tabIndex={-1}
        type="button"
      />

      <section className="workspace">
        <TerminalWorkspace
          sessions={sessions}
          activeSessionId={activeSessionId}
          selectedHost={selectedHost}
          settings={settings}
          onCloseSession={closeSession}
          onSelectSession={(sessionId) => setActiveSessionId(sessionId)}
          onSessionExit={markSessionClosed}
        />
      </section>

      {hostEditor ? (
        <HostEditorModal
          host={hostEditor.host}
          hosts={document?.hosts ?? {}}
          mode={hostEditor.mode}
          passwordValue={hostEditor.host.auth.type === "password" && hostEditor.host.auth.passwordRef ? vault?.items[hostEditor.host.auth.passwordRef]?.password ?? "" : ""}
          onClose={() => setHostEditor(null)}
          onDelete={hostEditor.mode === "edit" ? deleteHost : undefined}
          onDeletePassword={deletePassword}
          onSave={saveHostFromEditor}
          onSavePassword={savePassword}
        />
      ) : null}

      {folderEditor ? (
        <FolderEditorModal
          folder={folderEditor.mode === "edit" ? folderEditor.folder : undefined}
          mode={folderEditor.mode}
          onClose={() => setFolderEditor(null)}
          onCreate={(name) => createFolder(name, folderEditor.mode === "create" ? folderEditor.parentFolderId ?? null : null)}
          onDelete={folderEditor.mode === "edit" ? deleteFolder : undefined}
          onRename={folderEditor.mode === "edit" ? renameFolder : undefined}
        />
      ) : null}

      {isSettingsOpen ? (
        <SettingsModal
          settings={settings}
          onClose={() => setIsSettingsOpen(false)}
          onExportConfig={exportConfig}
          onImportConfig={importConfig}
          onImportIterm2Theme={importIterm2Theme}
          onImportSshConfig={importSshConfig}
          onSave={saveSettings}
        />
      ) : null}
    </main>
  );
}

type SidebarActionIconName = "host" | "folder" | "refresh" | "settings" | "collapse" | "expand";

function SidebarActionIcon({ name }: { name: SidebarActionIconName }) {
  if (name === "host") {
    return (
      <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
        <rect x="4" y="5" width="13" height="12" rx="3" />
        <path d="M8 20h8" />
        <path d="M12 17v3" />
        <circle className="sidebar-action-icon-fill" cx="17" cy="17" r="5" />
        <path className="sidebar-action-icon-on-fill" d="M17 14v6M14 17h6" />
      </svg>
    );
  }

  if (name === "folder") {
    return (
      <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M3.5 7.5h6l1.7 2h9.3v8.8a2.2 2.2 0 0 1-2.2 2.2H5.7a2.2 2.2 0 0 1-2.2-2.2Z" />
        <path d="M3.5 7.5v-1A2 2 0 0 1 5.5 4.5h4l1.7 2H18a2 2 0 0 1 2 2v1" />
        <circle className="sidebar-action-icon-fill" cx="17" cy="17" r="5" />
        <path className="sidebar-action-icon-on-fill" d="M17 14v6M14 17h6" />
      </svg>
    );
  }

  if (name === "refresh") {
    return (
      <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M19 8a7 7 0 1 0 1 6" />
        <path d="M19 4v4h-4" />
      </svg>
    );
  }

  if (name === "settings") {
    return (
      <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7h6M14 7h6" />
        <path d="M4 12h10M18 12h2" />
        <path d="M4 17h3M11 17h9" />
        <circle cx="12" cy="7" r="2" />
        <circle cx="16" cy="12" r="2" />
        <circle cx="9" cy="17" r="2" />
      </svg>
    );
  }

  if (name === "collapse") {
    return (
      <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
        <rect x="4" y="5" width="16" height="14" rx="3" />
        <path d="M9 5v14" />
        <path d="M16 9l-3 3 3 3" />
      </svg>
    );
  }

  return (
    <svg className="sidebar-action-icon" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="4" y="5" width="16" height="14" rx="3" />
      <path d="M9 5v14" />
      <path d="M13 9l3 3-3 3" />
    </svg>
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

const findParentFolderId = (tree: TreeNode[], source: TreeDragSource, parentId: string | null = null): string | null => {
  for (const node of tree) {
    if (matchesDragSource(node, source)) {
      return parentId;
    }

    if (node.type === "folder") {
      const nestedParentId = findParentFolderId(node.children, source, node.id);
      if (nestedParentId !== null) {
        return nestedParentId;
      }
    }
  }

  return null;
};

const moveTreeNode = (tree: TreeNode[], source: TreeDragSource, targetFolderId: string | null): TreeNode[] | null => {
  if (source.type === "folder" && source.nodeId === targetFolderId) {
    return null;
  }

  const removal = removeTreeNode(tree, source);
  if (!removal.removed) {
    return null;
  }

  if (targetFolderId && nodeContainsFolder(removal.removed, targetFolderId)) {
    return null;
  }

  if (!targetFolderId) {
    return [...removal.tree, removal.removed];
  }

  const insertedTree = insertTreeNode(removal.tree, targetFolderId, removal.removed);
  return insertedTree.inserted ? insertedTree.tree : null;
};

const removeTreeNode = (
  tree: TreeNode[],
  source: TreeDragSource
): { tree: TreeNode[]; removed: TreeNode | null } => {
  const nextTree: TreeNode[] = [];

  for (const node of tree) {
    if (matchesDragSource(node, source)) {
      return { tree: [...nextTree, ...tree.slice(nextTree.length + 1)], removed: node };
    }

    if (node.type === "folder") {
      const nested = removeTreeNode(node.children, source);
      if (nested.removed) {
        return {
          tree: [...nextTree, { ...node, children: nested.tree }, ...tree.slice(nextTree.length + 1)],
          removed: nested.removed
        };
      }
    }

    nextTree.push(node);
  }

  return { tree, removed: null };
};

const insertTreeNode = (
  tree: TreeNode[],
  targetFolderId: string,
  movedNode: TreeNode
): { tree: TreeNode[]; inserted: boolean } => {
  let inserted = false;
  const nextTree = tree.map((node) => {
    if (node.type === "hostRef") {
      return node;
    }

    if (node.id === targetFolderId) {
      inserted = true;
      return { ...node, expanded: true, children: [...node.children, movedNode] };
    }

    const nested = insertTreeNode(node.children, targetFolderId, movedNode);
    if (nested.inserted) {
      inserted = true;
      return { ...node, children: nested.tree };
    }

    return node;
  });

  return { tree: nextTree, inserted };
};

const matchesDragSource = (node: TreeNode, source: TreeDragSource): boolean => {
  if (source.type === "folder") {
    return node.type === "folder" && node.id === source.nodeId;
  }

  return node.type === "hostRef" && (node.id === source.nodeId || node.hostId === source.hostId);
};

const nodeContainsFolder = (node: TreeNode, folderId: string): boolean => {
  if (node.type === "hostRef") {
    return false;
  }

  return node.id === folderId || node.children.some((child) => nodeContainsFolder(child, folderId));
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

const closeBackendSession = (sessionId: string) => {
  void invoke("close_terminal_session", { sessionId }).catch(() => {
    // Error sessions and already-exited PTYs may not exist in the backend registry.
  });
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

const createDuplicateHost = (host: Host, hosts: Record<string, Host>): Host => {
  const id = nextDuplicateHostId(host.id, hosts);

  return {
    ...host,
    id,
    alias: nextDuplicateAlias(host.alias, hosts),
    auth:
      host.auth.type === "password"
        ? { ...host.auth, passwordRef: host.auth.passwordRef ? `password:${id}` : null }
        : host.auth,
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

const nextDuplicateHostId = (sourceId: string, hosts: Record<string, Host>): string => {
  const base = `${sourceId}-copy`;
  let index = 1;
  let candidate = base;

  while (hosts[candidate]) {
    index += 1;
    candidate = `${base}-${index}`;
  }

  return candidate;
};

const nextDuplicateAlias = (sourceAlias: string, hosts: Record<string, Host>): string => {
  const aliases = new Set(Object.values(hosts).map((host) => host.alias));
  const base = `${sourceAlias} copy`;
  let index = 1;
  let candidate = base;

  while (aliases.has(candidate)) {
    index += 1;
    candidate = `${base} ${index}`;
  }

  return candidate;
};

const defaultSettings: AppSettings = {
  version: 1,
  theme: "dark",
  terminal: {
    fontFamily: '"SFMono-Regular", "JetBrains Mono", "MesloLGS NF", "Hack Nerd Font", Menlo, Monaco, Consolas, monospace',
    fontSize: 13,
    fontWeight: "400",
    fontWeightBold: "700",
    lineHeight: 1.15,
    letterSpacing: 0,
    cursorStyle: "block",
    minimumContrastRatio: 4.5,
    drawBoldTextInBrightColors: true,
    backgroundBlur: 0,
    backgroundOpacity: 100,
    autoCopySelection: true,
    colors: darkTerminalColors
  },
  vault: {
    mode: "plain",
    clearClipboardAfterSeconds: 30
  },
  connection: {
    defaultOpenMode: "tab",
    autoLogin: true,
    closeTabOnDisconnect: false
  }
};

const withSettingsDefaults = (settings: AppSettings): AppSettings => ({
  ...defaultSettings,
  ...settings,
  terminal: {
    ...defaultSettings.terminal,
    ...settings.terminal,
    fontWeight: normalizeFontWeight(settings.terminal?.fontWeight, defaultSettings.terminal.fontWeight),
    fontWeightBold: normalizeFontWeight(settings.terminal?.fontWeightBold, defaultSettings.terminal.fontWeightBold),
    colors: {
      ...defaultSettings.terminal.colors,
      ...settings.terminal?.colors,
      ansi:
        settings.terminal?.colors?.ansi?.length === 16
          ? settings.terminal.colors.ansi
          : defaultSettings.terminal.colors.ansi
    }
  },
  vault: {
    ...defaultSettings.vault,
    ...settings.vault
  },
  connection: {
    ...defaultSettings.connection,
    ...settings.connection
  }
});

const useSystemTheme = (): "light" | "dark" => {
  const getSystemTheme = () =>
    typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  const [systemTheme, setSystemTheme] = useState<"light" | "dark">(getSystemTheme);

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-color-scheme: light)");
    const handleChange = () => setSystemTheme(getSystemTheme());

    mediaQuery.addEventListener("change", handleChange);
    return () => mediaQuery.removeEventListener("change", handleChange);
  }, []);

  return systemTheme;
};

const normalizeFontWeight = (value: string | undefined, fallback: string): string => {
  if (!value) {
    return fallback;
  }

  if (value === "normal") {
    return "400";
  }

  if (value === "bold") {
    return "700";
  }

  return value;
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
