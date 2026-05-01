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
  const themeKey = terminalThemeKey(settings);

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
      theme: createXtermTheme(settings)
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
  }, [session, settings.terminal.fontFamily, settings.terminal.fontSize, themeKey]);

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

const createXtermTheme = (settings: AppSettings) => {
  const colors = settings.terminal.colors;
  const ansi = normalizeAnsi(colors.ansi);

  return {
    background: hexToRgba(colors.background, settings.terminal.backgroundOpacity / 100),
    foreground: colors.foreground,
    cursor: colors.cursor,
    selectionBackground: colors.selection,
    black: ansi[0],
    red: ansi[1],
    green: ansi[2],
    yellow: ansi[3],
    blue: ansi[4],
    magenta: ansi[5],
    cyan: ansi[6],
    white: ansi[7],
    brightBlack: ansi[8],
    brightRed: ansi[9],
    brightGreen: ansi[10],
    brightYellow: ansi[11],
    brightBlue: ansi[12],
    brightMagenta: ansi[13],
    brightCyan: ansi[14],
    brightWhite: ansi[15]
  };
};

const terminalThemeKey = (settings: AppSettings): string =>
  [
    settings.terminal.backgroundOpacity,
    settings.terminal.colors.background,
    settings.terminal.colors.foreground,
    settings.terminal.colors.cursor,
    settings.terminal.colors.selection,
    ...normalizeAnsi(settings.terminal.colors.ansi)
  ].join("|");

const normalizeAnsi = (colors: string[]): string[] =>
  colors.length === 16
    ? colors
    : [
        "#172331",
        "#EF8A80",
        "#7FD19B",
        "#E5C15D",
        "#69A7E8",
        "#B99CFF",
        "#41B6C8",
        "#DBE7F3",
        "#8EA0B4",
        "#FFB8B0",
        "#A6E3B6",
        "#F4D675",
        "#9BC7FF",
        "#CFB8FF",
        "#75D7E4",
        "#F3F7FB"
      ];

const hexToRgba = (hex: string, alpha: number): string => {
  const normalized = hex.trim().replace("#", "");
  const value =
    normalized.length === 3
      ? normalized
          .split("")
          .map((digit) => digit + digit)
          .join("")
      : normalized;

  if (!/^[0-9a-fA-F]{6}$/.test(value)) {
    return `rgba(15, 23, 32, ${clamp(alpha, 0, 1)})`;
  }

  const red = Number.parseInt(value.slice(0, 2), 16);
  const green = Number.parseInt(value.slice(2, 4), 16);
  const blue = Number.parseInt(value.slice(4, 6), 16);
  return `rgba(${red}, ${green}, ${blue}, ${clamp(alpha, 0, 1)})`;
};

const clamp = (value: number, min: number, max: number): number => Math.min(Math.max(value, min), max);
