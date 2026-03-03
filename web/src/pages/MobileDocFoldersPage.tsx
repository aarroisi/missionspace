import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Folder, Plus, Star } from "lucide-react";
import { format } from "date-fns";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useToastStore } from "@/stores/toastStore";
import { CreateDocFolderModal } from "@/components/features/CreateDocFolderModal";

export function MobileDocFoldersPage() {
  const navigate = useNavigate();
  const folders = useDocFolderStore((s) => s.folders) || [];
  const createFolder = useDocFolderStore((s) => s.createFolder);
  const { success, error } = useToastStore();
  const [showCreateModal, setShowCreateModal] = useState(false);

  const starred = folders.filter((f) => f.starred);
  const unstarred = folders.filter((f) => !f.starred);

  const handleCreateFolder = async (name: string, prefix: string) => {
    try {
      const folder = await createFolder(name, prefix);
      success("Folder created successfully");
      setShowCreateModal(false);
      navigate(`/doc-folders/${folder.id}`);
    } catch (err) {
      error("Error: " + (err as Error).message);
    }
  };

  const renderCard = (folder: (typeof folders)[0]) => (
    <div
      key={folder.id}
      onClick={() => navigate(`/doc-folders/${folder.id}`)}
      className="p-4 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
    >
      <Folder size={18} className="text-blue-400 flex-shrink-0" />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-xs font-mono text-dark-text-muted">
            {folder.prefix}
          </span>
          <h3 className="font-medium text-dark-text truncate">{folder.name}</h3>
        </div>
        {folder.createdBy && (
          <p className="text-xs text-dark-text-muted mt-1">
            by {folder.createdBy.name} ·{" "}
            {format(new Date(folder.insertedAt), "MMM d, yyyy")}
          </p>
        )}
      </div>
      {folder.starred && (
        <Star
          size={14}
          className="fill-yellow-400 text-yellow-400 flex-shrink-0"
        />
      )}
    </div>
  );

  return (
    <div className="flex-1 flex flex-col">
      <div className="px-4 py-3 border-b border-dark-border flex items-center justify-between">
        <h1 className="text-lg font-semibold text-dark-text">Doc Folders</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="p-2 text-dark-text-muted hover:text-dark-text transition-colors"
        >
          <Plus size={20} />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-4">
        {starred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center gap-1.5">
            <Star size={12} />
            Starred
          </div>
        )}
        {starred.length > 0 && (
          <div className="space-y-2 mb-4">{starred.map(renderCard)}</div>
        )}
        {starred.length > 0 && unstarred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
            All Folders
          </div>
        )}
        <div className="space-y-2">{unstarred.map(renderCard)}</div>
        {folders.length === 0 && (
          <div className="py-8 text-center text-dark-text-muted text-sm">
            No folders yet
          </div>
        )}
      </div>
      <CreateDocFolderModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSubmit={handleCreateFolder}
      />
    </div>
  );
}
