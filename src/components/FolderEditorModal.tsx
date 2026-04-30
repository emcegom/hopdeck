import { useEffect, useState } from "react";

interface FolderEditorModalProps {
  folder?: {
    id: string;
    name: string;
  };
  mode?: "create" | "edit";
  onClose: () => void;
  onCreate: (name: string) => Promise<void>;
  onDelete?: (folderId: string) => Promise<void>;
  onRename?: (folderId: string, name: string) => Promise<void>;
}

export function FolderEditorModal({
  folder,
  mode = "create",
  onClose,
  onCreate,
  onDelete,
  onRename
}: FolderEditorModalProps) {
  const [name, setName] = useState(folder?.name ?? "New Folder");
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isConfirmingDelete, setIsConfirmingDelete] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setName(folder?.name ?? "New Folder");
    setError(null);
    setIsConfirmingDelete(false);
  }, [folder]);

  const create = async () => {
    const nextName = name.trim();

    if (!nextName) {
      setError("Folder name is required.");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      if (mode === "edit" && folder && onRename) {
        await onRename(folder.id, nextName);
      } else {
        await onCreate(nextName);
      }
      onClose();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setIsSaving(false);
    }
  };

  const deleteFolder = async () => {
    if (!folder || !onDelete) {
      return;
    }

    if (!isConfirmingDelete) {
      setIsConfirmingDelete(true);
      return;
    }

    setIsDeleting(true);
    setError(null);

    try {
      await onDelete(folder.id);
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
        aria-label={mode === "edit" ? "Edit folder" : "New folder"}
        className="folder-editor"
        role="dialog"
        onClick={(event) => event.stopPropagation()}
      >
        <header className="host-editor-header">
          <div>
            <span className="eyebrow">Folder</span>
            <h2>{mode === "edit" ? `Edit ${folder?.name ?? "folder"}` : "New folder"}</h2>
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
          <div>
            {mode === "edit" && folder && onDelete ? (
              <button className="danger-action" type="button" disabled={isDeleting} onClick={deleteFolder}>
                {isDeleting ? "Deleting" : isConfirmingDelete ? "Confirm delete" : "Delete"}
              </button>
            ) : null}
          </div>
          <div className="modal-action-group">
            <button className="secondary-action" type="button" onClick={onClose}>
              Cancel
            </button>
            <button className="primary-action" type="button" disabled={isSaving} onClick={create}>
              {isSaving ? "Saving" : mode === "edit" ? "Save" : "Create"}
            </button>
          </div>
        </footer>
      </section>
    </div>
  );
}
