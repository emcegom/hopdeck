import { useEffect, useState } from "react";

interface FolderEditorModalProps {
  onClose: () => void;
  onCreate: (name: string) => Promise<void>;
}

export function FolderEditorModal({ onClose, onCreate }: FolderEditorModalProps) {
  const [name, setName] = useState("New Folder");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
  }, []);

  const create = async () => {
    const nextName = name.trim();

    if (!nextName) {
      setError("Folder name is required.");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      await onCreate(nextName);
      onClose();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <section
        aria-label="New folder"
        className="folder-editor"
        role="dialog"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="host-editor-header">
          <div>
            <span className="eyebrow">Folder</span>
            <h2>New folder</h2>
          </div>
          <button className="icon-button subtle" type="button" onClick={onClose} title="Close">
            x
          </button>
        </header>

        <label className="field">
          <span>Name</span>
          <input autoFocus value={name} onChange={(event) => setName(event.target.value)} />
        </label>

        {error ? <div className="form-error">{error}</div> : null}

        <footer className="modal-actions">
          <button className="secondary-action" type="button" onClick={onClose}>
            Cancel
          </button>
          <button className="primary-action" type="button" disabled={isSaving} onClick={create}>
            {isSaving ? "Creating" : "Create"}
          </button>
        </footer>
      </section>
    </div>
  );
}
