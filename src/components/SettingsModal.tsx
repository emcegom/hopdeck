import { useEffect, useState } from "react";

import { isBuiltInTerminalColors, terminalColorsForAppearance } from "../theme";
import type { AppSettings } from "../types/hopdeck";

interface SettingsModalProps {
  settings: AppSettings;
  onClose: () => void;
  onImportConfig: () => Promise<void>;
  onImportIterm2Theme: () => Promise<void>;
  onImportSshConfig: () => Promise<void>;
  onSave: (settings: AppSettings) => Promise<void>;
  onExportConfig: () => Promise<void>;
}

export function SettingsModal({
  settings,
  onClose,
  onImportConfig,
  onImportIterm2Theme,
  onImportSshConfig,
  onSave,
  onExportConfig
}: SettingsModalProps) {
  const [draft, setDraft] = useState<AppSettings>(settings);
  const [status, setStatus] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    setDraft(settings);
    setStatus(null);
  }, [settings]);

  const save = async () => {
    setIsSaving(true);
    setStatus(null);

    try {
      await onSave(draft);
      onClose();
    } catch (caught) {
      setStatus(errorMessage(caught));
    } finally {
      setIsSaving(false);
    }
  };

  const runAction = async (action: () => Promise<void>, message: string) => {
    setStatus(null);

    try {
      await action();
      setStatus(message);
    } catch (caught) {
      setStatus(errorMessage(caught));
    }
  };

  const updateAppearance = (theme: AppSettings["theme"]) => {
    setDraft((current) => {
      const effectiveTheme = theme === "system" ? current.theme === "light" ? "light" : "dark" : theme;
      const shouldFollowTheme = isBuiltInTerminalColors(current.terminal.colors);

      return {
        ...current,
        theme,
        terminal: {
          ...current.terminal,
          colors: shouldFollowTheme ? terminalColorsForAppearance(effectiveTheme) : current.terminal.colors
        }
      };
    });
  };

  const applyTerminalPalette = (theme: Exclude<AppSettings["theme"], "system">) => {
    setDraft((current) => ({
      ...current,
      terminal: {
        ...current.terminal,
        colors: terminalColorsForAppearance(theme)
      }
    }));
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <section
        aria-label="Settings"
        className="settings-editor"
        role="dialog"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="host-editor-header">
          <div>
            <span className="eyebrow">Workspace</span>
            <h2>Settings</h2>
          </div>
          <button className="icon-button subtle" type="button" onClick={onClose} title="Close">
            x
          </button>
        </header>

        <div className="settings-section">
          <h3>Appearance</h3>
          <label className="field">
            <span>Theme</span>
            <select value={draft.theme} onChange={(event) => updateAppearance(event.target.value as AppSettings["theme"])}>
              <option value="dark">Dark</option>
              <option value="light">Light</option>
              <option value="system">System</option>
            </select>
          </label>
          <div className="settings-actions">
            <button className="secondary-action" type="button" onClick={() => applyTerminalPalette("light")}>
              Light terminal colors
            </button>
            <button className="secondary-action" type="button" onClick={() => applyTerminalPalette("dark")}>
              Dark terminal colors
            </button>
          </div>
        </div>

        <div className="settings-section">
          <h3>Terminal</h3>
          <label className="field">
            <span>Font size</span>
            <input
              inputMode="numeric"
              value={draft.terminal.fontSize}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  terminal: { ...current.terminal, fontSize: Number.parseInt(event.target.value, 10) || 13 }
                }))
              }
            />
          </label>
          <label className="field">
            <span>Background blur</span>
            <input
              max={24}
              min={0}
              type="range"
              value={draft.terminal.backgroundBlur}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  terminal: { ...current.terminal, backgroundBlur: Number.parseInt(event.target.value, 10) }
                }))
              }
            />
          </label>
          <label className="field">
            <span>Background opacity</span>
            <input
              max={100}
              min={15}
              type="range"
              value={draft.terminal.backgroundOpacity}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  terminal: { ...current.terminal, backgroundOpacity: Number.parseInt(event.target.value, 10) }
                }))
              }
            />
          </label>
          <label className="check-row">
            <input
              checked={draft.terminal.autoCopySelection}
              type="checkbox"
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  terminal: { ...current.terminal, autoCopySelection: event.target.checked }
                }))
              }
            />
            <span>Copy selection automatically</span>
          </label>
          <div className="theme-preview" aria-label="Terminal colors preview">
            {draft.terminal.colors.ansi.slice(0, 16).map((color, index) => (
              <span key={`${color}-${index}`} style={{ background: color }} />
            ))}
          </div>
          <button
            className="secondary-action"
            type="button"
            onClick={() =>
              void runAction(async () => {
                await onImportIterm2Theme();
              }, "Imported current iTerm2 profile")
            }
          >
            Import iTerm2 theme
          </button>
        </div>

        <div className="settings-section">
          <h3>Import / Export</h3>
          <p className="settings-note">
            Backups include hosts, settings, and the plain vault. Anyone who can read the backup can read saved
            passwords.
          </p>
          <div className="settings-actions">
            <button
              className="secondary-action"
              type="button"
              onClick={() => void runAction(onImportSshConfig, "Imported ~/.ssh/config")}
            >
              Import SSH config
            </button>
            <button
              className="secondary-action"
              type="button"
              onClick={() => void runAction(onExportConfig, "Exported backup to ~/.hopdeck/hopdeck-backup.json")}
            >
              Export backup
            </button>
            <button
              className="secondary-action"
              type="button"
              onClick={() => void runAction(onImportConfig, "Imported backup from ~/.hopdeck/hopdeck-backup.json")}
            >
              Import backup
            </button>
          </div>
        </div>

        {status ? <div className="form-error neutral">{status}</div> : null}

        <footer className="modal-actions">
          <div />
          <div className="modal-action-group">
            <button className="secondary-action" type="button" onClick={onClose}>
              Cancel
            </button>
            <button className="primary-action" type="button" disabled={isSaving} onClick={save}>
              {isSaving ? "Saving" : "Save"}
            </button>
          </div>
        </footer>
      </section>
    </div>
  );
}

const errorMessage = (caught: unknown): string => {
  if (caught instanceof Error) {
    return caught.message;
  }

  if (typeof caught === "string") {
    return caught;
  }

  return "Unknown error";
};
