import { useEffect, useState } from "react";

import type { AppSettings } from "../types/hopdeck";

interface SettingsModalProps {
  settings: AppSettings;
  onClose: () => void;
  onImportConfig: () => Promise<void>;
  onImportSshConfig: () => Promise<void>;
  onSave: (settings: AppSettings) => Promise<void>;
  onExportConfig: () => Promise<void>;
}

export function SettingsModal({
  settings,
  onClose,
  onImportConfig,
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
