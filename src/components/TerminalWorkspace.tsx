import { useCallback, useEffect, useRef, type MouseEvent as ReactMouseEvent } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { writeText as writeClipboardText } from "@tauri-apps/plugin-clipboard-manager";
import { FitAddon } from "@xterm/addon-fit";
import { Terminal, type FontWeight } from "@xterm/xterm";

import { terminalBackgroundColor } from "../theme";
import {
  displayHost,
  type AppSettings,
  type Host,
  type TerminalExitEvent,
  type TerminalOutputChunk,
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
  onSessionExit: (sessionId: string) => void;
}

export function TerminalWorkspace({
  sessions,
  activeSessionId,
  selectedHost,
  settings,
  onCloseSession,
  onSelectSession,
  onSessionExit
}: TerminalWorkspaceProps) {
  const activeSession = sessions.find((session) => session.id === activeSessionId) ?? sessions[0] ?? null;
  const startWindowDrag = useCallback((event: ReactMouseEvent<HTMLElement>) => {
    const target = event.target as HTMLElement;

    if (event.button !== 0 || target.closest("button, .terminal-tab")) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    void getCurrentWindow().startDragging().catch(() => {
      // Browser previews do not expose the Tauri window API.
    });
  }, []);

  return (
    <section className="terminal-workspace" aria-label="Terminal workspace">
      <header className="terminal-tabs" data-tauri-drag-region onMouseDown={startWindowDrag}>
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
              onSessionExit={onSessionExit}
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
  onSessionExit: (sessionId: string) => void;
}

function TerminalPane({ session, isActive, settings, onSessionExit }: TerminalPaneProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const resizeRef = useRef<(() => void) | null>(null);
  const lastSeqRef = useRef(0);
  const themeKey = terminalThemeKey(settings);

  useEffect(() => {
    const container = containerRef.current;

    if (!container) {
      return;
    }

    const terminal = new Terminal({
      allowTransparency: true,
      cursorStyle: terminalCursorStyle(settings.terminal.cursorStyle),
      cursorBlink: true,
      convertEol: true,
      drawBoldTextInBrightColors: settings.terminal.drawBoldTextInBrightColors,
      fontFamily: settings.terminal.fontFamily,
      fontSize: settings.terminal.fontSize,
      fontWeight: terminalFontWeight(settings.terminal.fontWeight, "400"),
      fontWeightBold: terminalFontWeight(settings.terminal.fontWeightBold, "700"),
      letterSpacing: settings.terminal.letterSpacing,
      lineHeight: settings.terminal.lineHeight,
      minimumContrastRatio: settings.terminal.minimumContrastRatio,
      scrollback: 10000,
      scrollOnUserInput: true,
      theme: createXtermTheme(settings)
    });
    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(container);
    let disposed = false;
    let shouldStickToBottom = true;
    let resizeFrame: number | null = null;

    const writeAndKeepBottom = (data: string, forceScroll = false) => {
      const shouldFollowBottom = forceScroll || shouldStickToBottom || isTerminalAtBottom(terminal);

      terminal.write(data, () => {
        if (!disposed && shouldFollowBottom) {
          terminal.scrollToBottom();
          shouldStickToBottom = true;
        }
      });
    };

    const writeOutputChunk = (chunk: TerminalOutputChunk) => {
      if (chunk.seq <= lastSeqRef.current) {
        return;
      }

      lastSeqRef.current = chunk.seq;
      writeAndKeepBottom(chunk.data);
    };

    const dataDisposable = terminal.onData((data) => {
      shouldStickToBottom = true;
      terminal.scrollToBottom();
      void invoke("write_terminal_session", { sessionId: session.id, data }).catch((caught) => {
        terminal.write(`\r\n\x1b[31m[hopdeck] input failed: ${String(caught)}\x1b[0m\r\n`);
      });
    });
    const scrollDisposable = terminal.onScroll(() => {
      shouldStickToBottom = isTerminalAtBottom(terminal);
    });
    let autoCopyTimer: number | null = null;
    let lastCopiedSelection = "";
    let reportedAutoCopyError = false;
    const scheduleAutoCopySelection = () => {
      if (autoCopyTimer !== null) {
        window.clearTimeout(autoCopyTimer);
      }

      autoCopyTimer = window.setTimeout(() => {
        autoCopyTimer = null;
        const selectedText = terminal.getSelection();

        if (!selectedText || selectedText === lastCopiedSelection) {
          return;
        }

        lastCopiedSelection = selectedText;
        void copyTextToClipboard(selectedText).catch((caught) => {
          if (!reportedAutoCopyError) {
            reportedAutoCopyError = true;
            terminal.write(`\r\n\x1b[31m[hopdeck] auto-copy failed: ${String(caught)}\x1b[0m\r\n`);
          }
        });
      }, 150);
    };
    const autoCopyDisposable = settings.terminal.autoCopySelection
      ? terminal.onSelectionChange(scheduleAutoCopySelection)
      : null;
    const autoCopyPointerHandler = settings.terminal.autoCopySelection ? scheduleAutoCopySelection : null;

    if (autoCopyPointerHandler) {
      container.addEventListener("mouseup", autoCopyPointerHandler);
      container.addEventListener("touchend", autoCopyPointerHandler);
    }

    terminalRef.current = terminal;
    fitAddonRef.current = fitAddon;

    let outputUnlisten: (() => void) | null = null;
    let exitUnlisten: (() => void) | null = null;

    void listen<TerminalOutputEvent>("terminal-output", (event) => {
      if (event.payload.sessionId === session.id) {
        writeOutputChunk(event.payload);
      }
    })
      .then((unlisten) => {
        if (disposed) {
          unlisten();
        } else {
          outputUnlisten = unlisten;
        }
      })
      .catch((caught) => {
        terminal.write(`\r\n\x1b[31m[hopdeck] output listener failed: ${String(caught)}\x1b[0m\r\n`);
      });

    void invoke<TerminalOutputChunk[]>("read_terminal_session_output", {
      sessionId: session.id,
      afterSeq: lastSeqRef.current
    })
      .then((chunks) => {
        if (!disposed) {
          chunks.forEach(writeOutputChunk);
        }
      })
      .catch((caught) => {
        terminal.write(`\r\n\x1b[31m[hopdeck] output replay failed: ${String(caught)}\x1b[0m\r\n`);
      });

    void listen<TerminalExitEvent>("terminal-exit", (event) => {
      if (event.payload.sessionId === session.id) {
        writeAndKeepBottom("\r\n\x1b[90m[hopdeck] session closed\x1b[0m\r\n", true);
        onSessionExit(session.id);
      }
    })
      .then((unlisten) => {
        if (disposed) {
          unlisten();
        } else {
          exitUnlisten = unlisten;
        }
      })
      .catch((caught) => {
        terminal.write(`\r\n\x1b[31m[hopdeck] exit listener failed: ${String(caught)}\x1b[0m\r\n`);
      });

    const resize = () => {
      if (resizeFrame !== null) {
        window.cancelAnimationFrame(resizeFrame);
      }

      resizeFrame = window.requestAnimationFrame(() => {
        resizeFrame = null;

        if (disposed) {
          return;
        }

        try {
          fitAddon.fit();
          void invoke("resize_terminal_session", {
            sessionId: session.id,
            rows: terminal.rows,
            cols: terminal.cols
          });
          if (shouldStickToBottom) {
            terminal.scrollToBottom();
          }
        } catch {
          // xterm can throw while the pane is hidden; the next visible resize will recover.
        }
      });
    };
    resizeRef.current = resize;

    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(container);
    if (container.parentElement) {
      resizeObserver.observe(container.parentElement);
    }
    window.addEventListener("resize", resize);
    window.setTimeout(resize, 0);

    return () => {
      disposed = true;
      if (resizeFrame !== null) {
        window.cancelAnimationFrame(resizeFrame);
      }
      outputUnlisten?.();
      exitUnlisten?.();
      autoCopyDisposable?.dispose();
      scrollDisposable.dispose();
      if (autoCopyPointerHandler) {
        container.removeEventListener("mouseup", autoCopyPointerHandler);
        container.removeEventListener("touchend", autoCopyPointerHandler);
      }
      if (autoCopyTimer !== null) {
        window.clearTimeout(autoCopyTimer);
      }
      resizeObserver.disconnect();
      window.removeEventListener("resize", resize);
      resizeRef.current = null;
      dataDisposable.dispose();
      terminal.dispose();
      terminalRef.current = null;
      fitAddonRef.current = null;
    };
  }, [
    session.id,
    settings.terminal.autoCopySelection,
    settings.terminal.fontFamily,
    settings.terminal.fontSize,
    settings.terminal.fontWeight,
    settings.terminal.fontWeightBold,
    settings.terminal.lineHeight,
    settings.terminal.letterSpacing,
    settings.terminal.cursorStyle,
    settings.terminal.minimumContrastRatio,
    settings.terminal.drawBoldTextInBrightColors,
    themeKey,
    onSessionExit
  ]);

  useEffect(() => {
    if (!isActive) {
      return;
    }

    window.setTimeout(() => {
      try {
        resizeRef.current?.();
        terminalRef.current?.refresh(0, terminalRef.current.rows - 1);
        terminalRef.current?.scrollToBottom();
        terminalRef.current?.focus();
      } catch {
        // Hidden panes are measured again once they are visible.
      }
    }, 0);
  }, [isActive]);

  return (
    <div
      className={`terminal-pane${isActive ? " is-active" : ""}`}
      aria-hidden={!isActive}
    >
      <div className="terminal-pane-inner" ref={containerRef} />
    </div>
  );
}

const createXtermTheme = (settings: AppSettings) => {
  const colors = settings.terminal.colors;
  const ansi = normalizeAnsi(colors.ansi);

  return {
    background: terminalBackgroundColor(
      colors.background,
      settings.terminal.backgroundOpacity,
      settings.terminal.backgroundBlur
    ),
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
    settings.terminal.backgroundBlur,
    settings.terminal.colors.background,
    settings.terminal.colors.foreground,
    settings.terminal.colors.cursor,
    settings.terminal.colors.selection,
    ...normalizeAnsi(settings.terminal.colors.ansi)
  ].join("|");

const terminalCursorStyle = (cursorStyle: string): "block" | "underline" | "bar" => {
  if (cursorStyle === "underline" || cursorStyle === "bar") {
    return cursorStyle;
  }

  return "block";
};

const terminalFontWeight = (fontWeight: string, fallback: FontWeight): FontWeight => {
  if (fontWeight === "normal" || fontWeight === "bold") {
    return fontWeight;
  }

  const parsed = Number.parseInt(fontWeight, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const copyTextToClipboard = async (text: string): Promise<void> => {
  try {
    await writeClipboardText(text);
    return;
  } catch (pluginError) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text);
        return;
      } catch {
        // Report the plugin error because it is the expected packaged-app path.
      }
    }

    throw pluginError;
  }
};

const isTerminalAtBottom = (terminal: Terminal): boolean => {
  const buffer = terminal.buffer.active;
  return buffer.viewportY >= buffer.baseY;
};

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
