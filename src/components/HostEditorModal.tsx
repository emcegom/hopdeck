import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";

import type { Host, HostAuth } from "../types/hopdeck";

interface HostEditorModalProps {
  host: Host;
  hosts: Record<string, Host>;
  mode?: "create" | "edit";
  passwordValue?: string;
  onClose: () => void;
  onDelete?: (hostId: string) => Promise<void>;
  onDeletePassword?: (passwordRef: string) => Promise<void>;
  onSave: (host: Host) => Promise<void>;
  onSavePassword?: (passwordRef: string, username: string, password: string) => Promise<void>;
}

interface HostDraft {
  alias: string;
  host: string;
  user: string;
  port: string;
  tags: string;
  jumpChain: string[];
  favorite: boolean;
  isJumpHost: boolean;
  authType: HostAuth["type"];
  autoLogin: boolean;
  password: string;
  notes: string;
}

export function HostEditorModal({
  host,
  hosts,
  mode = "edit",
  passwordValue = "",
  onClose,
  onDelete,
  onDeletePassword,
  onSave,
  onSavePassword
}: HostEditorModalProps) {
  const [draft, setDraft] = useState<HostDraft>(() => toDraft(host, passwordValue));
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setDraft(toDraft(host, passwordValue));
    setError(null);
  }, [host, passwordValue]);

  const jumpCandidates = useMemo(
    () => Object.values(hosts).filter((candidate) => candidate.id !== host.id),
    [host.id, hosts]
  );

  const updateDraft = <Key extends keyof HostDraft>(key: Key, value: HostDraft[Key]) => {
    setDraft((current) => ({ ...current, [key]: value }));
  };

  const toggleJump = (hostId: string) => {
    setDraft((current) => ({
      ...current,
      jumpChain: current.jumpChain.includes(hostId)
        ? current.jumpChain.filter((item) => item !== hostId)
        : [...current.jumpChain, hostId]
    }));
  };

  const save = async () => {
    const port = Number.parseInt(draft.port, 10);

    if (!draft.alias.trim() || !draft.host.trim() || !draft.user.trim()) {
      setError("Alias, host, and user are required.");
      return;
    }

    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      setError("Port must be between 1 and 65535.");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      const passwordRef = `password:${host.id}`;
      const nextAuth = normalizeAuth(host.auth, draft.authType, passwordRef, draft.autoLogin);
      const nextHost = {
        ...host,
        alias: draft.alias.trim(),
        host: draft.host.trim(),
        user: draft.user.trim(),
        port,
        tags: draft.tags
          .split(",")
          .map((tag) => tag.trim())
          .filter(Boolean),
        jumpChain: draft.jumpChain,
        favorite: draft.favorite,
        isJumpHost: draft.isJumpHost,
        auth: nextAuth,
        notes: draft.notes
      };

      if (draft.authType === "password" && draft.password && onSavePassword) {
        await onSavePassword(passwordRef, draft.user.trim(), draft.password);
      }

      if (draft.authType !== "password" && host.auth.type === "password" && host.auth.passwordRef && onDeletePassword) {
        await onDeletePassword(host.auth.passwordRef);
      }

      await onSave(nextHost);
      onClose();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setIsSaving(false);
    }
  };

  const deleteHost = async () => {
    if (!onDelete) {
      return;
    }

    if (!isConfirmingDelete) {
      setIsConfirmingDelete(true);
      return;
    }

    setIsDeleting(true);
    setError(null);

    try {
      await onDelete(host.id);
      onClose();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setIsDeleting(false);
      setIsConfirmingDelete(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <section
        aria-label="Edit host"
        className="host-editor"
        role="dialog"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="host-editor-header">
          <div>
            <span className="eyebrow">{host.isJumpHost ? "Jump host" : "SSH host"}</span>
            <h2>{mode === "create" ? "New host" : `Edit ${host.alias}`}</h2>
          </div>
          <button className="icon-button subtle" type="button" onClick={onClose} title="Close">
            x
          </button>
        </header>

        <div className="form-grid">
          <Field label="Alias">
            <input value={draft.alias} onChange={(event) => updateDraft("alias", event.target.value)} />
          </Field>
          <Field label="Host">
            <input value={draft.host} onChange={(event) => updateDraft("host", event.target.value)} />
          </Field>
          <Field label="User">
            <input value={draft.user} onChange={(event) => updateDraft("user", event.target.value)} />
          </Field>
          <Field label="Port">
            <input
              inputMode="numeric"
              value={draft.port}
              onChange={(event) => updateDraft("port", event.target.value)}
            />
          </Field>
          <Field label="Tags">
            <input value={draft.tags} onChange={(event) => updateDraft("tags", event.target.value)} />
          </Field>
          <Field label="Auth">
            <select
              value={draft.authType}
              onChange={(event) => updateDraft("authType", event.target.value as HostAuth["type"])}
            >
              <option value="password">Password</option>
              <option value="key">Key</option>
              <option value="agent">Agent</option>
              <option value="none">None</option>
            </select>
          </Field>
        </div>

        {draft.authType === "password" ? (
          <div className="credential-panel">
            <Field label="Saved password">
              <div className="password-field">
                <input
                  type="password"
                  value={draft.password}
                  onChange={(event) => updateDraft("password", event.target.value)}
                  placeholder="Stored in ~/.hopdeck/vault.json"
                />
                <button
                  className="secondary-action compact"
                  type="button"
                  disabled={!draft.password}
                  onClick={() => void navigator.clipboard.writeText(draft.password)}
                >
                  Copy
                </button>
              </div>
            </Field>
            <label className="toggle-row">
              <input
                checked={draft.autoLogin}
                type="checkbox"
                onChange={(event) => updateDraft("autoLogin", event.target.checked)}
              />
              Auto-login when SSH asks for this password
            </label>
          </div>
        ) : null}

        <label className="toggle-row">
          <input
            checked={draft.favorite}
            type="checkbox"
            onChange={(event) => updateDraft("favorite", event.target.checked)}
          />
          Favorite
        </label>
        <label className="toggle-row">
          <input
            checked={draft.isJumpHost}
            type="checkbox"
            onChange={(event) => updateDraft("isJumpHost", event.target.checked)}
          />
          Jump host
        </label>

        <div className="jump-picker">
          <span>Jump Chain</span>
          <div>
            {jumpCandidates.length > 0 ? (
              jumpCandidates.map((candidate) => (
                <label className="jump-option" key={candidate.id}>
                  <input
                    checked={draft.jumpChain.includes(candidate.id)}
                    type="checkbox"
                    onChange={() => toggleJump(candidate.id)}
                  />
                  {candidate.alias}
                </label>
              ))
            ) : (
              <span className="muted">No other hosts</span>
            )}
          </div>
        </div>

        <Field label="Notes">
          <textarea value={draft.notes} onChange={(event) => updateDraft("notes", event.target.value)} />
        </Field>

        {error ? <div className="form-error">{error}</div> : null}

        <footer className="modal-actions">
          <div>
            {mode === "edit" && onDelete ? (
              <button className="danger-action" type="button" disabled={isDeleting} onClick={deleteHost}>
                {isDeleting ? "Deleting" : isConfirmingDelete ? "Confirm delete" : "Delete"}
              </button>
            ) : null}
          </div>
          <div className="modal-action-group">
            <button className="secondary-action" type="button" onClick={onClose}>
              Cancel
            </button>
            <button className="primary-action" type="button" disabled={isSaving} onClick={save}>
              {isSaving ? "Saving" : mode === "create" ? "Create" : "Save"}
            </button>
          </div>
        </footer>
      </section>
    </div>
  );
}

interface FieldProps {
  label: string;
  children: ReactNode;
}

function Field({ label, children }: FieldProps) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}

const toDraft = (host: Host, password: string): HostDraft => ({
  alias: host.alias,
  host: host.host,
  user: host.user,
  port: String(host.port),
  tags: host.tags.join(", "),
  jumpChain: [...host.jumpChain],
  favorite: host.favorite,
  isJumpHost: host.isJumpHost,
  authType: host.auth.type,
  autoLogin: host.auth.type === "password" ? host.auth.autoLogin : false,
  password,
  notes: host.notes
});

const normalizeAuth = (
  current: HostAuth,
  type: HostAuth["type"],
  passwordRef: string,
  autoLogin: boolean
): HostAuth => {
  if (current.type === type && type !== "password") {
    return current;
  }

  switch (type) {
    case "password":
      return { type: "password", passwordRef, autoLogin };
    case "key":
      return { type: "key", identityFile: null, useAgent: true };
    case "agent":
      return { type: "agent" };
    case "none":
      return { type: "none" };
  }
};
