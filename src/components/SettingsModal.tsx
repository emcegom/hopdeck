import { useEffect, useState } from "react";

import { isBuiltInTerminalColors, terminalBackgroundColor, terminalColorsForAppearance } from "../theme";
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
  const updateTerminal = (terminal: Partial<AppSettings["terminal"]>) => {
    setDraft((current) => ({
      ...current,
      terminal: {
        ...current.terminal,
        ...terminal
      }
    }));
  };
  const selectedFontPreset = fontPresetValue(draft.terminal.fontFamily);

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
          <div className="settings-actions terminal-preset-actions">
            <button
              className="secondary-action"
              type="button"
              onClick={() => updateTerminal(compactTerminalPreset)}
            >
              Compact terminal
            </button>
            <button
              className="secondary-action"
              type="button"
              onClick={() => updateTerminal(comfortableTerminalPreset)}
            >
              Comfortable terminal
            </button>
          </div>
          <label className="field">
            <span>Font preset</span>
            <select
              value={selectedFontPreset}
              onChange={(event) => {
                const preset = terminalFontPresets.find((item) => item.value === event.target.value);

                if (preset) {
                  updateTerminal({ fontFamily: preset.value });
                }
              }}
            >
              {terminalFontPresets.map((preset) => (
                <option key={preset.label} value={preset.value}>
                  {preset.label}
                </option>
              ))}
              <option value="custom">Custom</option>
            </select>
          </label>
          <label className="field">
            <span>Font family</span>
            <input
              value={draft.terminal.fontFamily}
              onChange={(event) => updateTerminal({ fontFamily: event.target.value })}
            />
          </label>
          <div className="settings-control-grid">
            <label className="field">
              <span>Font size</span>
              <input
                inputMode="numeric"
                value={draft.terminal.fontSize}
                onChange={(event) => updateTerminal({ fontSize: parseIntSetting(event.target.value, 13) })}
              />
            </label>
            <label className="field">
              <span>Line height</span>
              <input
                max={1.5}
                min={1}
                step={0.01}
                type="number"
                value={draft.terminal.lineHeight}
                onChange={(event) => updateTerminal({ lineHeight: parseFloatSetting(event.target.value, 1.15) })}
              />
            </label>
            <label className="field">
              <span>Letter spacing</span>
              <input
                max={2}
                min={-1}
                step={0.1}
                type="number"
                value={draft.terminal.letterSpacing}
                onChange={(event) => updateTerminal({ letterSpacing: parseFloatSetting(event.target.value, 0) })}
              />
            </label>
            <label className="field">
              <span>Cursor</span>
              <select
                value={draft.terminal.cursorStyle}
                onChange={(event) => updateTerminal({ cursorStyle: event.target.value })}
              >
                <option value="block">Block</option>
                <option value="bar">Bar</option>
                <option value="underline">Underline</option>
              </select>
            </label>
            <label className="field">
              <span>Text weight</span>
              <select
                value={draft.terminal.fontWeight}
                onChange={(event) => updateTerminal({ fontWeight: event.target.value })}
              >
                {fontWeightOptions.map((weight) => (
                  <option key={weight} value={weight}>
                    {weight}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Bold weight</span>
              <select
                value={draft.terminal.fontWeightBold}
                onChange={(event) => updateTerminal({ fontWeightBold: event.target.value })}
              >
                {fontWeightOptions.map((weight) => (
                  <option key={weight} value={weight}>
                    {weight}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Contrast</span>
              <input
                max={7}
                min={1}
                step={0.5}
                type="number"
                value={draft.terminal.minimumContrastRatio}
                onChange={(event) =>
                  updateTerminal({ minimumContrastRatio: parseFloatSetting(event.target.value, 4.5) })
                }
              />
            </label>
            <label className="check-row terminal-check-row">
              <input
                checked={draft.terminal.drawBoldTextInBrightColors}
                type="checkbox"
                onChange={(event) => updateTerminal({ drawBoldTextInBrightColors: event.target.checked })}
              />
              <span>Bright bold text</span>
            </label>
          </div>
          <div
            className="terminal-type-preview"
            style={{
              background: terminalBackgroundColor(
                draft.terminal.colors.background,
                draft.terminal.backgroundOpacity,
                draft.terminal.backgroundBlur
              ),
              color: draft.terminal.colors.foreground,
              fontFamily: draft.terminal.fontFamily,
              fontSize: `${draft.terminal.fontSize}px`,
              fontWeight: draft.terminal.fontWeight,
              letterSpacing: `${draft.terminal.letterSpacing}px`,
              lineHeight: draft.terminal.lineHeight
            }}
          >
            <span style={{ color: draft.terminal.colors.ansi[2] }}>edm@app</span>
            <span style={{ color: draft.terminal.colors.ansi[6] }}> ~/work</span>
            <span> $ </span>
            <strong style={{ color: draft.terminal.colors.ansi[3], fontWeight: draft.terminal.fontWeightBold }}>
              echo Hopdeck
            </strong>
            <span className={`terminal-preview-cursor ${draft.terminal.cursorStyle}`} style={{ background: draft.terminal.colors.cursor }} />
          </div>
          <label className="field">
            <span>Background blur</span>
            <input
              max={24}
              min={0}
              type="range"
              value={draft.terminal.backgroundBlur}
              onChange={(event) => updateTerminal({ backgroundBlur: parseIntSetting(event.target.value, 0) })}
            />
          </label>
          <label className="field">
            <span>Background opacity</span>
            <input
              max={100}
              min={15}
              type="range"
              value={draft.terminal.backgroundOpacity}
              onChange={(event) => updateTerminal({ backgroundOpacity: parseIntSetting(event.target.value, 100) })}
            />
          </label>
          <label className="check-row">
            <input
              checked={draft.terminal.autoCopySelection}
              type="checkbox"
              onChange={(event) => updateTerminal({ autoCopySelection: event.target.checked })}
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
            Import iTerm2 profile
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

const terminalFontPresets = [
  {
    label: "SF Mono",
    value: '"SFMono-Regular", "JetBrains Mono", "MesloLGS NF", "Hack Nerd Font", Menlo, Monaco, Consolas, monospace'
  },
  {
    label: "JetBrains Mono",
    value: '"JetBrains Mono", "SFMono-Regular", "MesloLGS NF", "Hack Nerd Font", Menlo, Monaco, Consolas, monospace'
  },
  {
    label: "MesloLGS NF",
    value: '"MesloLGS NF", "MesloLGS-NF-Regular", "SFMono-Regular", "JetBrains Mono", Menlo, Monaco, Consolas, monospace'
  },
  {
    label: "Menlo",
    value: 'Menlo, "SFMono-Regular", Monaco, Consolas, monospace'
  }
];

const compactTerminalPreset: Partial<AppSettings["terminal"]> = {
  fontFamily: '"SFMono-Regular", Menlo, Monaco, "JetBrains Mono", monospace',
  fontSize: 12,
  fontWeight: "400",
  fontWeightBold: "700",
  lineHeight: 1.1,
  letterSpacing: 0,
  minimumContrastRatio: 4.5,
  drawBoldTextInBrightColors: true
};

const comfortableTerminalPreset: Partial<AppSettings["terminal"]> = {
  fontFamily: '"JetBrains Mono", "SFMono-Regular", "MesloLGS NF", "Hack Nerd Font", Menlo, Monaco, Consolas, monospace',
  fontSize: 13,
  fontWeight: "400",
  fontWeightBold: "700",
  lineHeight: 1.15,
  letterSpacing: 0,
  minimumContrastRatio: 4.5,
  drawBoldTextInBrightColors: true
};

const fontWeightOptions = ["300", "400", "500", "600", "700", "800"];

const fontPresetValue = (fontFamily: string): string =>
  terminalFontPresets.find((preset) => preset.value === fontFamily)?.value ?? "custom";

const parseIntSetting = (value: string, fallback: number): number => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const parseFloatSetting = (value: string, fallback: number): number => {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : fallback;
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
