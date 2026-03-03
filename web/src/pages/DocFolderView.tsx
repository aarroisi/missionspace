import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useDocStore } from "@/stores/docStore";
import { useToastStore } from "@/stores/toastStore";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { ManageMembersModal } from "@/components/features/ManageMembersModal";
import {
  FileText,
  Plus,
  Star,
  Trash2,
  MoreHorizontal,
  Users,
} from "lucide-react";
import { MobileBackButton } from "@/components/ui/MobileBackButton";
import { format } from "date-fns";

export function DocFolderView() {
  const { id, folderId: folderIdParam, projectId: projectIdParam } = useParams<{
    id?: string;
    folderId?: string;
    projectId?: string;
  }>();
  const folderId = folderIdParam || id;
  const navigate = useNavigate();
  const { folders, fetchFolders, updateFolder, deleteFolder, toggleFolderStar } =
    useDocFolderStore();
  const { docs, fetchDocs } = useDocStore();
  const { success, error } = useToastStore();

  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showMembersModal, setShowMembersModal] = useState(false);
  const [isEditingName, setIsEditingName] = useState(false);
  const [editedName, setEditedName] = useState("");

  const folder = folders.find((f) => f.id === folderId);

  // Fetch folders if not loaded (e.g. direct URL navigation)
  useEffect(() => {
    if (folderId && folders.length === 0) {
      fetchFolders();
    }
  }, [folderId, folders, fetchFolders]);

  useEffect(() => {
    if (folderId) {
      fetchDocs(false, folderId);
    }
  }, [folderId, fetchDocs]);

  useEffect(() => {
    if (folder) {
      setEditedName(folder.name);
    }
  }, [folder]);

  const folderDocs = docs.filter((d) => d.docFolderId === folderId);

  const handleNewDoc = () => {
    if (projectIdParam) {
      navigate(
        `/projects/${projectIdParam}/doc-folders/${folderId}/docs/new`,
      );
    } else {
      navigate(`/doc-folders/${folderId}/docs/new`);
    }
  };

  const handleDocClick = (docId: string) => {
    if (projectIdParam) {
      navigate(
        `/projects/${projectIdParam}/doc-folders/${folderId}/docs/${docId}`,
      );
    } else {
      navigate(`/doc-folders/${folderId}/docs/${docId}`);
    }
  };

  const handleToggleStar = async () => {
    if (!folderId) return;
    await toggleFolderStar(folderId);
  };

  const handleDeleteFolder = async () => {
    if (!folderId) return;
    try {
      await deleteFolder(folderId);
      success("Folder deleted successfully");
      if (projectIdParam) {
        navigate(`/projects/${projectIdParam}`);
      } else {
        navigate("/docs");
      }
    } catch (err) {
      error("Error deleting folder: " + (err as Error).message);
    }
  };

  const handleSaveName = async () => {
    if (!folderId || !editedName.trim()) return;
    if (editedName.trim() === folder?.name) {
      setIsEditingName(false);
      return;
    }
    try {
      await updateFolder(folderId, { name: editedName.trim() });
      success("Folder name updated");
      setIsEditingName(false);
    } catch (err) {
      error("Error updating folder: " + (err as Error).message);
    }
  };

  if (!folder) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <p className="text-dark-text-muted">Select a folder to view</p>
      </div>
    );
  }

  return (
    <>
      <div className="flex-1 flex flex-col overflow-hidden">
        <div className="px-4 py-3 md:px-6 md:py-4 border-b border-dark-border">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3 min-w-0">
              <MobileBackButton to={projectIdParam ? `/projects/${projectIdParam}` : "/doc-folders"} />
              <span className="px-2 py-1 text-xs font-mono font-semibold bg-blue-500/20 text-blue-400 rounded">
                {folder.prefix}
              </span>
              {isEditingName ? (
                <input
                  type="text"
                  value={editedName}
                  onChange={(e) => setEditedName(e.target.value)}
                  onBlur={handleSaveName}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleSaveName();
                    if (e.key === "Escape") {
                      setEditedName(folder.name);
                      setIsEditingName(false);
                    }
                  }}
                  className="text-lg md:text-2xl font-bold text-dark-text bg-transparent border-b border-blue-500 outline-none"
                  autoFocus
                />
              ) : (
                <h1
                  className="text-lg md:text-2xl font-bold text-dark-text cursor-pointer hover:text-blue-400 transition-colors truncate"
                  onClick={() => setIsEditingName(true)}
                >
                  {folder.name}
                </h1>
              )}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={handleNewDoc}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors"
              >
                <Plus size={16} />
                New Doc
              </button>
              <Dropdown
                align="right"
                trigger={
                  <button className="p-2 rounded transition-colors text-dark-text-muted hover:bg-dark-surface">
                    <MoreHorizontal size={18} />
                  </button>
                }
              >
                {!projectIdParam && (
                  <DropdownItem onClick={() => setShowMembersModal(true)}>
                    <span className="flex items-center gap-2">
                      <Users size={16} />
                      Members
                    </span>
                  </DropdownItem>
                )}
                <DropdownItem onClick={handleToggleStar}>
                  <span className="flex items-center gap-2">
                    <Star
                      size={16}
                      className={
                        folder.starred
                          ? "fill-yellow-400 text-yellow-400"
                          : ""
                      }
                    />
                    {folder.starred ? "Unstar" : "Star"}
                  </span>
                </DropdownItem>
                <DropdownItem
                  variant="danger"
                  onClick={() => setShowDeleteConfirm(true)}
                >
                  <span className="flex items-center gap-2">
                    <Trash2 size={16} />
                    Delete Folder
                  </span>
                </DropdownItem>
              </Dropdown>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4 md:p-6">
          {folderDocs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-24 text-center">
              <div className="w-16 h-16 rounded-full bg-dark-surface flex items-center justify-center mb-4">
                <FileText size={32} className="text-dark-text-muted" />
              </div>
              <p className="text-dark-text-muted text-base mb-2">
                No documents yet
              </p>
              <p className="text-dark-text-muted text-sm mb-4">
                Create a new doc to get started
              </p>
              <button
                onClick={handleNewDoc}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors"
              >
                <Plus size={16} />
                New Doc
              </button>
            </div>
          ) : (
            <div className="space-y-2 max-w-4xl">
              {folderDocs.map((doc) => (
                <div
                  key={doc.id}
                  onClick={() => handleDocClick(doc.id)}
                  className="p-4 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
                >
                  <FileText
                    size={18}
                    className="text-green-400 flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      {doc.key && (
                        <span className="text-xs font-mono text-dark-text-muted">
                          {doc.key}
                        </span>
                      )}
                      <h3 className="font-medium text-dark-text truncate">
                        {doc.title}
                      </h3>
                    </div>
                    {doc.createdBy && (
                      <p className="text-xs text-dark-text-muted mt-1">
                        by {doc.createdBy.name} ·{" "}
                        {format(new Date(doc.insertedAt), "MMM d, yyyy")}
                      </p>
                    )}
                  </div>
                  {doc.starred && (
                    <Star
                      size={14}
                      className="fill-yellow-400 text-yellow-400 flex-shrink-0"
                    />
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <ConfirmModal
        isOpen={showDeleteConfirm}
        title="Delete Folder"
        message={`Are you sure you want to delete "${folder.name}" and all its documents? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={handleDeleteFolder}
        onCancel={() => setShowDeleteConfirm(false)}
      />

      {/* Members Modal (standalone folders only, not project items) */}
      {!projectIdParam && folderId && (
        <ManageMembersModal
          itemKind="doc_folder"
          itemId={folderId}
          isOpen={showMembersModal}
          onClose={() => setShowMembersModal(false)}
        />
      )}
    </>
  );
}
