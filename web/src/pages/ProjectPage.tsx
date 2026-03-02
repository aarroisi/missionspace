import { useState, useMemo } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Kanban,
  Folder,
  Hash,
  Plus,
  MoreHorizontal,
  Star,
  Trash2,
  Pencil,
  Calendar,
  X,
  Check,
  Users,
} from "lucide-react";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { CreateBoardModal } from "@/components/features/CreateBoardModal";
import { CreateDocFolderModal } from "@/components/features/CreateDocFolderModal";
import { CreateChannelModal } from "@/components/features/CreateChannelModal";
import { ManageMembersModal } from "@/components/features/ManageMembersModal";
import { format } from "date-fns";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useChatStore } from "@/stores/chatStore";
import { useToastStore } from "@/stores/toastStore";
import { Board, DocFolder, Channel } from "@/types";

type ItemType = "board" | "doc_folder" | "channel";

interface AddItemMenuProps {
  onAdd: (type: ItemType) => void;
  onClose: () => void;
}

function AddItemMenu({ onAdd, onClose }: AddItemMenuProps) {
  return (
    <div className="absolute top-full left-0 mt-1 bg-dark-surface border border-dark-border rounded-lg shadow-lg py-1 z-10 min-w-[160px]">
      <button
        onClick={() => {
          onAdd("board");
          onClose();
        }}
        className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
      >
        <Kanban size={16} />
        New Board
      </button>
      <button
        onClick={() => {
          onAdd("doc_folder");
          onClose();
        }}
        className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
      >
        <Folder size={16} />
        New Folder
      </button>
      <button
        onClick={() => {
          onAdd("channel");
          onClose();
        }}
        className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
      >
        <Hash size={16} />
        New Channel
      </button>
    </div>
  );
}

interface EditProjectModalProps {
  project: {
    id: string;
    name: string;
    description?: string;
    startDate?: string;
    endDate?: string;
  };
  onSave: (data: {
    name: string;
    description: string;
    startDate: string | null;
    endDate: string | null;
  }) => Promise<void>;
  onClose: () => void;
}

function EditProjectModal({ project, onSave, onClose }: EditProjectModalProps) {
  const [name, setName] = useState(project.name);
  const [description, setDescription] = useState(project.description || "");
  const [startDate, setStartDate] = useState(project.startDate || "");
  const [endDate, setEndDate] = useState(project.endDate || "");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");

  const handleSave = async () => {
    if (!name.trim()) {
      setError("Name is required");
      return;
    }

    if (startDate && endDate && startDate > endDate) {
      setError("End date must be after start date");
      return;
    }

    setIsSaving(true);
    setError("");

    try {
      await onSave({
        name: name.trim(),
        description: description.trim(),
        startDate: startDate || null,
        endDate: endDate || null,
      });
      onClose();
    } catch (err) {
      setError("Failed to save project");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-dark-surface border border-dark-border rounded-lg w-full max-w-md">
        <div className="flex items-center justify-between px-4 py-3 border-b border-dark-border">
          <h3 className="font-semibold text-dark-text">Edit Project</h3>
          <button
            onClick={onClose}
            className="text-dark-text-muted hover:text-dark-text"
          >
            <X size={20} />
          </button>
        </div>

        <div className="p-4 space-y-4">
          {error && (
            <div className="text-sm text-red-400 bg-red-400/10 px-3 py-2 rounded">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-dark-text-muted mb-1">
              Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Project name"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-dark-text-muted mb-1">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
              placeholder="Project description (optional)"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-dark-text-muted mb-1">
                Start Date
              </label>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-dark-text-muted mb-1">
                End Date
              </label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        <div className="flex justify-end gap-2 px-4 py-3 border-t border-dark-border">
          <button
            onClick={onClose}
            className="px-4 py-2 text-dark-text-muted hover:text-dark-text transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={isSaving}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {isSaving ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}

export function ProjectPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { success, error } = useToastStore();

  const [showAddMenu, setShowAddMenu] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState("");
  const [showDeleteProjectConfirm, setShowDeleteProjectConfirm] =
    useState(false);
  const [deleteItemConfirm, setDeleteItemConfirm] = useState<{
    type: "board" | "doc_folder" | "channel";
    id: string;
    name: string;
  } | null>(null);
  const [removeItemConfirm, setRemoveItemConfirm] = useState<{
    type: "board" | "doc_folder" | "channel";
    id: string;
    name: string;
  } | null>(null);
  const [showCreateBoardModal, setShowCreateBoardModal] = useState(false);
  const [showCreateDocFolderModal, setShowCreateDocFolderModal] =
    useState(false);
  const [showCreateChannelModal, setShowCreateChannelModal] = useState(false);
  const [showMembersModal, setShowMembersModal] = useState(false);

  const projects = useProjectStore((state) => state.projects);
  const updateProject = useProjectStore((state) => state.updateProject);
  const deleteProject = useProjectStore((state) => state.deleteProject);
  const addItem = useProjectStore((state) => state.addItem);
  const removeItem = useProjectStore((state) => state.removeItem);

  const boards = useBoardStore((state) => state.boards);
  const createBoard = useBoardStore((state) => state.createBoard);
  const deleteBoard = useBoardStore((state) => state.deleteBoard);

  const docFolders = useDocFolderStore((state) => state.folders);
  const createDocFolder = useDocFolderStore((state) => state.createFolder);
  const deleteDocFolder = useDocFolderStore((state) => state.deleteFolder);

  const channels = useChatStore((state) => state.channels);
  const createChannel = useChatStore((state) => state.createChannel);
  const deleteChannel = useChatStore((state) => state.deleteChannel);

  const project = projects.find((p) => p.id === id);

  // Get items from project_items and resolve to actual entities
  const projectItems = project?.items || [];

  const projectBoards = useMemo(() => {
    const boardIds = projectItems
      .filter((i) => i.itemType === "board")
      .map((i) => i.itemId);
    return boards.filter((b) => boardIds.includes(b.id));
  }, [projectItems, boards]);

  const projectDocFolders = useMemo(() => {
    const folderIds = projectItems
      .filter((i) => i.itemType === "doc_folder")
      .map((i) => i.itemId);
    return docFolders.filter((f) => folderIds.includes(f.id));
  }, [projectItems, docFolders]);

  const projectChannels = useMemo(() => {
    const channelIds = projectItems
      .filter((i) => i.itemType === "channel")
      .map((i) => i.itemId);
    return channels.filter((c) => channelIds.includes(c.id));
  }, [projectItems, channels]);

  const hasItems =
    projectBoards.length > 0 ||
    projectDocFolders.length > 0 ||
    projectChannels.length > 0;

  const handleAddItem = async (type: ItemType) => {
    if (!id) return;

    try {
      switch (type) {
        case "board": {
          setShowCreateBoardModal(true);
          return;
        }
        case "doc_folder": {
          setShowCreateDocFolderModal(true);
          return;
        }
        case "channel": {
          setShowCreateChannelModal(true);
          return;
        }
      }
    } catch (err) {
      console.error("Failed to create item:", err);
      error("Failed to create item");
    }
  };

  const handleToggleStar = async () => {
    if (!project) return;
    try {
      await updateProject(project.id, { starred: !project.starred });
    } catch (err) {
      console.error("Failed to update project:", err);
      error("Failed to update project");
    }
  };

  const handleDeleteProject = async () => {
    if (!project) return;

    try {
      await deleteProject(project.id);
      success("Project deleted");
      navigate("/projects");
    } catch (err) {
      console.error("Failed to delete project:", err);
      error("Failed to delete project");
    }
  };

  const handleSaveProject = async (data: {
    name: string;
    description: string;
    startDate: string | null;
    endDate: string | null;
  }) => {
    if (!project) return;
    await updateProject(project.id, {
      name: data.name,
      description: data.description || undefined,
      startDate: data.startDate || undefined,
      endDate: data.endDate || undefined,
    });
    success("Project updated");
  };

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const handleStartEditingTitle = () => {
    if (!project) return;
    setTitleValue(project.name);
    setEditingTitle(true);
  };

  const handleTitleSave = async () => {
    if (!project || !titleValue.trim()) return;
    try {
      await updateProject(project.id, { name: titleValue.trim() });
      setEditingTitle(false);
    } catch (err) {
      console.error("Failed to update project title:", err);
      error("Failed to update title");
    }
  };

  const handleRemoveFromProject = async (
    type: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => {
    if (!id) return;

    try {
      await removeItem(id, type, itemId);
      success(
        `${type.charAt(0).toUpperCase() + type.slice(1)} removed from project`,
      );
    } catch (err) {
      console.error("Failed to remove item:", err);
      error("Failed to remove item");
    }
  };

  const handleDeleteItem = async (
    type: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => {
    try {
      switch (type) {
        case "board":
          await deleteBoard(itemId);
          break;
        case "doc_folder":
          await deleteDocFolder(itemId);
          break;
        case "channel":
          await deleteChannel(itemId);
          break;
      }
      success(`${type.charAt(0).toUpperCase() + type.slice(1)} deleted`);
    } catch (err) {
      console.error("Failed to delete item:", err);
      error("Failed to delete item");
    }
  };

  const handleCreateBoard = async (name: string, prefix: string) => {
    if (!id) return;
    try {
      const board = await createBoard(name, prefix);
      await addItem(id, "board", board.id);
      success("Board created");
      setShowCreateBoardModal(false);
      navigate(`/projects/${id}/boards/${board.id}`);
    } catch (err) {
      console.error("Failed to create board:", err);
      error("Failed to create board");
    }
  };

  const handleCreateDocFolder = async (name: string, prefix: string) => {
    if (!id) return;
    try {
      const folder = await createDocFolder(name, prefix);
      await addItem(id, "doc_folder", folder.id);
      success("Folder created");
      setShowCreateDocFolderModal(false);
      navigate(`/projects/${id}/doc-folders/${folder.id}`);
    } catch (err) {
      console.error("Failed to create folder:", err);
      error("Failed to create folder");
    }
  };

  const handleCreateChannel = async (name: string) => {
    if (!id) return;
    try {
      const channel = await createChannel(name);
      await addItem(id, "channel", channel.id);
      success("Channel created");
      setShowCreateChannelModal(false);
      navigate(`/projects/${id}/channels/${channel.id}`);
    } catch (err) {
      console.error("Failed to create channel:", err);
      error("Failed to create channel");
    }
  };

  if (!project) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <p className="text-dark-text-muted">Project not found</p>
      </div>
    );
  }

  const renderItem = (
    item: Board | DocFolder | Channel,
    type: "board" | "doc_folder" | "channel",
  ) => {
    const name = (item as Board).name || (item as any).title;
    const icon =
      type === "board" ? (
        <Kanban size={18} />
      ) : type === "doc_folder" ? (
        <Folder size={18} />
      ) : (
        <Hash size={18} />
      );
    const pathType =
      type === "doc_folder" ? "doc-folders" : type === "board" ? "boards" : "channels";
    const path = `/projects/${id}/${pathType}/${item.id}`;

    return (
      <div
        key={item.id}
        className="flex items-center gap-3 p-3 rounded-lg bg-dark-surface border border-dark-border hover:border-dark-hover transition-colors group"
      >
        <button
          onClick={() => navigate(path)}
          className="flex items-center gap-3 flex-1 text-left min-w-0"
        >
          <div className="text-dark-text-muted">{icon}</div>
          <div className="text-sm font-medium text-dark-text truncate">
            {name}
          </div>
        </button>
        <Dropdown
          align="right"
          trigger={
            <button className="p-1 rounded hover:bg-dark-hover text-dark-text-muted hover:text-dark-text transition-all">
              <MoreHorizontal size={16} />
            </button>
          }
        >
          <DropdownItem
            onClick={() => setRemoveItemConfirm({ type, id: item.id, name })}
          >
            <span className="flex items-center gap-2">
              <X size={16} />
              Remove from Project
            </span>
          </DropdownItem>
          <DropdownItem
            variant="danger"
            onClick={() => setDeleteItemConfirm({ type, id: item.id, name })}
          >
            <span className="flex items-center gap-2">
              <Trash2 size={16} />
              Delete {type.charAt(0).toUpperCase() + type.slice(1)}
            </span>
          </DropdownItem>
        </Dropdown>
      </div>
    );
  };

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-dark-border flex items-center justify-between">
        {editingTitle ? (
          <div className="flex items-center gap-2">
            <input
              type="text"
              value={titleValue}
              onChange={(e) => setTitleValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  handleTitleSave();
                } else if (e.key === "Escape") {
                  setEditingTitle(false);
                }
              }}
              autoFocus
              className="text-2xl font-bold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none"
            />
            <button
              onClick={handleTitleSave}
              className="p-1.5 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
              title="Save title"
            >
              <Check size={16} />
            </button>
          </div>
        ) : (
          <div>
            <h1
              onClick={handleStartEditingTitle}
              className="text-2xl font-bold text-dark-text cursor-pointer hover:text-blue-400 transition-colors"
              title="Click to edit"
            >
              {project.name}
            </h1>
            {project.createdBy && (
              <div className="text-sm text-dark-text-muted mt-1">
                Added by {project.createdBy.name} on{" "}
                {format(new Date(project.insertedAt), "MMM d, yyyy")}
              </div>
            )}
          </div>
        )}
        <div className="flex items-center gap-2">
          <div className="relative">
            <button
              onClick={() => setShowAddMenu(!showAddMenu)}
              className="flex items-center gap-2 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors"
            >
              <Plus size={16} />
              Add Item
            </button>
            {showAddMenu && (
              <AddItemMenu
                onAdd={handleAddItem}
                onClose={() => setShowAddMenu(false)}
              />
            )}
          </div>
          <Dropdown
            align="right"
            trigger={
              <button className="p-2 hover:bg-dark-surface rounded-lg text-dark-text-muted hover:text-dark-text transition-colors">
                <MoreHorizontal size={20} />
              </button>
            }
          >
            <DropdownItem onClick={() => setShowMembersModal(true)}>
              <span className="flex items-center gap-2">
                <Users size={16} />
                Members
              </span>
            </DropdownItem>
            <DropdownItem onClick={() => setShowEditModal(true)}>
              <span className="flex items-center gap-2">
                <Pencil size={16} />
                Edit Project
              </span>
            </DropdownItem>
            <DropdownItem onClick={handleToggleStar}>
              <span className="flex items-center gap-2">
                <Star
                  size={16}
                  className={project.starred ? "fill-yellow-400" : ""}
                />
                {project.starred ? "Unstar" : "Star"}
              </span>
            </DropdownItem>
            <DropdownItem
              variant="danger"
              onClick={() => setShowDeleteProjectConfirm(true)}
            >
              <span className="flex items-center gap-2">
                <Trash2 size={16} />
                Delete Project
              </span>
            </DropdownItem>
          </Dropdown>
        </div>
      </div>

      {/* Project Info */}
      {(project.description || project.startDate || project.endDate) && (
        <div className="px-6 py-3">
          {project.description && (
            <p className="text-sm text-dark-text-muted">
              {project.description}
            </p>
          )}
          {(project.startDate || project.endDate) && (
            <div className="flex items-center gap-1 mt-1 text-xs text-dark-text-muted">
              <Calendar size={12} />
              {project.startDate && project.endDate ? (
                <span>
                  {formatDate(project.startDate)} -{" "}
                  {formatDate(project.endDate)}
                </span>
              ) : project.startDate ? (
                <span>Starts {formatDate(project.startDate)}</span>
              ) : (
                <span>Ends {formatDate(project.endDate!)}</span>
              )}
            </div>
          )}
        </div>
      )}

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-6">
        {!hasItems ? (
          <div className="flex flex-col items-center justify-center h-full text-center">
            <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-dark-surface border-2 border-dark-border mb-4">
              <Plus size={32} className="text-dark-text-muted" />
            </div>
            <h2 className="text-lg font-semibold text-dark-text mb-2">
              No items yet
            </h2>
            <p className="text-dark-text-muted mb-6 max-w-sm">
              Add boards, docs, or channels to organize your project.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => handleAddItem("board")}
                className="flex items-center gap-2 px-4 py-2 bg-dark-surface border border-dark-border hover:border-dark-hover rounded-lg text-sm text-dark-text transition-colors"
              >
                <Kanban size={16} />
                Add Board
              </button>
              <button
                onClick={() => handleAddItem("doc_folder")}
                className="flex items-center gap-2 px-4 py-2 bg-dark-surface border border-dark-border hover:border-dark-hover rounded-lg text-sm text-dark-text transition-colors"
              >
                <Folder size={16} />
                Add Folder
              </button>
              <button
                onClick={() => handleAddItem("channel")}
                className="flex items-center gap-2 px-4 py-2 bg-dark-surface border border-dark-border hover:border-dark-hover rounded-lg text-sm text-dark-text transition-colors"
              >
                <Hash size={16} />
                Add Channel
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {projectBoards.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-dark-text-muted uppercase tracking-wider mb-3 flex items-center gap-2">
                  <Kanban size={14} />
                  Boards
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {projectBoards.map((board) => renderItem(board, "board"))}
                </div>
              </div>
            )}

            {projectDocFolders.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-dark-text-muted uppercase tracking-wider mb-3 flex items-center gap-2">
                  <Folder size={14} />
                  Folders
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {projectDocFolders.map((folder) =>
                    renderItem(folder, "doc_folder"),
                  )}
                </div>
              </div>
            )}

            {projectChannels.length > 0 && (
              <div>
                <h3 className="text-sm font-semibold text-dark-text-muted uppercase tracking-wider mb-3 flex items-center gap-2">
                  <Hash size={14} />
                  Channels
                </h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {projectChannels.map((channel) =>
                    renderItem(channel, "channel"),
                  )}
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Edit Project Modal */}
      {showEditModal && (
        <EditProjectModal
          project={project}
          onSave={handleSaveProject}
          onClose={() => setShowEditModal(false)}
        />
      )}

      {/* Delete Project Confirmation Modal */}
      <ConfirmModal
        isOpen={showDeleteProjectConfirm}
        title="Delete Project"
        message={`Are you sure you want to delete "${project.name}"? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={handleDeleteProject}
        onCancel={() => setShowDeleteProjectConfirm(false)}
      />

      {/* Remove Item from Project Confirmation Modal */}
      <ConfirmModal
        isOpen={!!removeItemConfirm}
        title="Remove from Project"
        message={`Are you sure you want to remove "${removeItemConfirm?.name}" from this project?`}
        confirmText="Remove"
        confirmVariant="danger"
        onConfirm={() => {
          if (removeItemConfirm) {
            handleRemoveFromProject(
              removeItemConfirm.type,
              removeItemConfirm.id,
            );
            setRemoveItemConfirm(null);
          }
        }}
        onCancel={() => setRemoveItemConfirm(null)}
      />

      {/* Delete Item Confirmation Modal */}
      <ConfirmModal
        isOpen={!!deleteItemConfirm}
        title={`Delete ${deleteItemConfirm?.type ? deleteItemConfirm.type.charAt(0).toUpperCase() + deleteItemConfirm.type.slice(1) : ""}`}
        message={`Are you sure you want to delete "${deleteItemConfirm?.name}"? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={() => {
          if (deleteItemConfirm) {
            handleDeleteItem(deleteItemConfirm.type, deleteItemConfirm.id);
            setDeleteItemConfirm(null);
          }
        }}
        onCancel={() => setDeleteItemConfirm(null)}
      />

      {/* Create Board Modal */}
      <CreateBoardModal
        isOpen={showCreateBoardModal}
        onClose={() => setShowCreateBoardModal(false)}
        onSubmit={handleCreateBoard}
      />

      {/* Create Doc Folder Modal */}
      <CreateDocFolderModal
        isOpen={showCreateDocFolderModal}
        onClose={() => setShowCreateDocFolderModal(false)}
        onSubmit={handleCreateDocFolder}
      />

      {/* Create Channel Modal */}
      <CreateChannelModal
        isOpen={showCreateChannelModal}
        onClose={() => setShowCreateChannelModal(false)}
        onSubmit={handleCreateChannel}
      />

      {/* Members Modal */}
      {id && (
        <ManageMembersModal
          itemKind="project"
          itemId={id}
          isOpen={showMembersModal}
          onClose={() => setShowMembersModal(false)}
        />
      )}
    </div>
  );
}
