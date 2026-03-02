import { useState, useRef } from "react";
import { clsx } from "clsx";
import { Check, X, Pencil } from "lucide-react";
import {
  RichTextEditor,
  type RichTextEditorHandle,
} from "@/lib/milkdown/RichTextEditor";
import { ContentRenderer } from "@/lib/milkdown/ContentRenderer";

interface RichTextNotesEditorProps {
  value: string;
  onSave: (value: string) => Promise<void>;
  placeholder?: string;
  className?: string;
  fileUpload?: {
    attachableType: string;
    attachableId: string;
    onError: (msg: string) => void;
  };
}

export function RichTextNotesEditor({
  value,
  onSave,
  placeholder = "Add notes...",
  className,
  fileUpload,
}: RichTextNotesEditorProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const editorHandleRef = useRef<RichTextEditorHandle | null>(null);

  const handleStartEdit = () => {
    setEditValue(value);
    setIsEditing(true);
    setTimeout(() => editorHandleRef.current?.focus(), 100);
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await onSave(editValue);
      setIsEditing(false);
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    setIsEditing(false);
    setEditValue("");
  };

  if (isEditing) {
    return (
      <div className={className}>
        <div className="border border-dark-border rounded-lg overflow-hidden bg-dark-surface">
          <RichTextEditor
            value={editValue}
            onChange={setEditValue}
            placeholder={placeholder}
            editable={true}
            fileUpload={fileUpload}
            onReady={(handle) => {
              editorHandleRef.current = handle;
            }}
            className="[&_.milkdown]:min-h-[80px] [&_.milkdown_.editor]:min-h-[80px]"
          />
        </div>
        <div className="flex gap-2 mt-2">
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="flex items-center gap-1 px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            <Check size={14} />
            {isSaving ? "Saving..." : "Save"}
          </button>
          <button
            onClick={handleCancel}
            disabled={isSaving}
            className="flex items-center gap-1 px-3 py-1.5 text-sm bg-dark-surface hover:bg-dark-border text-dark-text rounded-lg transition-colors disabled:opacity-50"
          >
            <X size={14} />
            Cancel
          </button>
        </div>
      </div>
    );
  }

  // View mode - empty
  if (!value || !value.trim()) {
    return (
      <div className={className}>
        <div
          onClick={handleStartEdit}
          className="border border-dark-border rounded-lg p-3 min-h-[80px] cursor-pointer bg-dark-surface hover:bg-dark-surface/80 transition-colors group relative"
        >
          <span className="text-dark-text-muted text-sm">{placeholder}</span>
          <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
            <Pencil size={14} className="text-dark-text-muted" />
          </div>
        </div>
      </div>
    );
  }

  // View mode - with content
  return (
    <div className={className}>
      <div
        onClick={handleStartEdit}
        className={clsx(
          "border border-dark-border rounded-lg p-3 cursor-pointer bg-dark-surface hover:bg-dark-surface/80 transition-colors group relative",
        )}
      >
        <ContentRenderer
          content={value}
          className="prose prose-invert prose-sm max-w-none"
        />
        <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <Pencil size={14} className="text-dark-text-muted" />
        </div>
      </div>
    </div>
  );
}
