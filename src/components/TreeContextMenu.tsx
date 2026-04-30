import { useEffect } from "react";

export interface TreeContextMenuItem {
  id: string;
  label: string;
  tone?: "default" | "danger";
  onSelect: () => void;
}

interface TreeContextMenuProps {
  x: number;
  y: number;
  items: TreeContextMenuItem[];
  onClose: () => void;
}

export function TreeContextMenu({ x, y, items, onClose }: TreeContextMenuProps) {
  useEffect(() => {
    const close = () => onClose();
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("click", close);
    window.addEventListener("contextmenu", close);
    window.addEventListener("keydown", closeOnEscape);

    return () => {
      window.removeEventListener("click", close);
      window.removeEventListener("contextmenu", close);
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  return (
    <div
      className="tree-context-menu"
      role="menu"
      style={{ left: x, top: y }}
      onClick={(event) => event.stopPropagation()}
      onContextMenu={(event) => event.preventDefault()}
    >
      {items.map((item) => (
        <button
          key={item.id}
          className={`tree-context-item${item.tone === "danger" ? " danger" : ""}`}
          type="button"
          role="menuitem"
          onClick={() => {
            item.onSelect();
            onClose();
          }}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}
