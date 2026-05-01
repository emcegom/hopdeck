import { useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { FitAddon } from "@xterm/addon-fit";
import { Terminal } from "@xterm/xterm";

import {
  displayHost,
  type AppSettings,
  type Host,
  type TerminalExitEvent,
  type TerminalOutputEvent,
  type TerminalSession
} from "../types/hopdeck";

interface TerminalWorkspaceProps {
  sessions: TerminalSession[];
  activeSessionId: string | null;
  selectedHost: Host | null;
  settings: AppSettings;
  onCloseSession: (sessionId: string) => void;
  onSelectSession: (sessionId: string) => void;
}

export function TerminalWorkspace({
  sessions,
  activeSessionId,
  selectedHost,
  settings,
  onCloseSession,
  onSelectSession
}: TerminalWorkspaceProps) {
  const activeSession = sessions.find((session) => session.id === activeSessionId) ?? sessions[0] ?? null;

  return (
    <section className="terminal-workspace" aria-label="Terminal workspace">
      <header className="terminal-tabs">
        {sessions.length > 0 ? (
          sessions.map((session) => (
            <div
              className={`terminal-tab${session.id === activeSession?.id ? " is-active" : ""}`}
              key={session.id}
              title={session.title}
            >
              <button className="terminal-tab-label" type="button" onClick={() => onSelectSession(session.id)}>
                <span className={`status-dot ${session.status}`} aria-hidden="true" />
                <span>{session.title}</span>
              </button>
              <button
                className="terminal-tab-close"
                onClick={() => onCloseSession(session.id)}
                type="button"
                title="Close session"
              >
                x
              </button>
            </div>
          ))
        ) : (
          <span className="terminal-placeholder-label">
            {selectedHost ? `${selectedHost.alias}  ${displayHost(selectedHost)}` : "Hopdeck"}
          </span>
        )}
      </header>

      <div className="terminal-surface">
        {activeSession ? (
          sessions.map((session) => (
            <TerminalPane
              isActive={session.id === activeSession.id}
              key={session.id}
              settings={settings}
              session={session}
            />
          ))
        ) : (
          <div className="terminal-empty">
            <span className="terminal-cursor" aria-hidden="true" />
            <span>{selectedHost ? selectedHost.alias : "No active session"}</span>
          </div>
        )}
      </div>
    </section>
  );
}

interface TerminalPaneProps {
  session: TerminalSession;
  isActive: boolean;
  settings: AppSettings;
}

function TerminalPane({ session, isActive, settings }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);

  useEffect(() => {
    const container = containerRef.current;

    if (!container) {
      return;
    }

    const terminal = new Terminal({
      allowTransparency: true,
      cursorBlink: true,
      convertEol: true,
      fontFamily: settings.terminal.fontFamily,
      fontSize: settings.terminal.fontSize,
      theme: {
        background: "rgba(15, 23, 32, 0)",
        foreground: "#dbe7f3",
        cursor: "#41b6c8",
        selectionBackground: "#24384a"
      }
    });
    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(container);
    terminal.write(`\x1b[90m$ ${session.command}\x1b[0m\r\n`);

    if (session.message) {
      terminal.write(`\x1b[90m${session.message}\x1b[0m\r\n`);
    }

    const dataDisposable = terminal.onData((data) => {
      void invoke("write_terminal_session", { sessionId: session.id, data });
    });

    terminalRef.current = terminal;
    fitAddonRef.current = fitAddon;

    let outputUnlisten: (() => void) | null = null;
    let exitUnlisten: (() => void) | null = null;
    let disposed = false;

    void listen<TerminalOutputEvent>("terminal-output", (event) => {
      if (event.payload.sessionId === session.id) {
        terminal.write(event.payload.data);
      }
    }).then((unlisten) => {
      if (disposed) {
        unlisten();
      } else {
        outputUnlisten = unlisten;
      }
    });

    void listen<TerminalExitEvent>("terminal-exit", (event) => {
      if (event.payload.sessionId === session.id) {
        terminal.write("\r\n\x1b[90m[hopdeck] session closed\x1b[0m\r\n");
      }
    }).then((unlisten) => {
      if (disposed) {
        unlisten();
      } else {
        exitUnlisten = unlisten;
      }
    });

    const resize = () => {
      try {
        fitAddon.fit();
        void invoke("resize_terminal_session", {
          sessionId: session.id,
          rows: terminal.rows,
          cols: terminal.cols
        });
      } catch {
        // xterm can throw while the pane is hidden; the next visible resize will recover.
      }
    };

    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(container);
    window.setTimeout(resize, 0);

    return () => {
      disposed = true;
      outputUnlisten?.();
      exitUnlisten?.();
      resizeObserver.disconnect();
      dataDisposable.dispose();
      terminal.dispose();
      terminalRef.current = null;
      fitAddonRef.current = null;
      void invoke("close_terminal_session", { sessionId: session.id });
    };
  }, [session, settings.terminal.fontFamily, settings.terminal.fontSize]);

  useEffect(() => {
    if (!isActive) {
      return;
    }

    window.setTimeout(() => {
      try {
        fitAddonRef.current?.fit();
        terminalRef.current?.focus();
      } catch {
        // Hidden panes are measured again once they are visible.
      }
    }, 0);
  }, [isActive]);

  return (
    <div
      className={`terminal-pane${isActive ? " is-active" : ""}`}
      ref={containerRef}
      aria-hidden={!isActive}
    />
  );
}
