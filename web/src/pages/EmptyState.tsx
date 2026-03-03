import { useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  Briefcase,
  Kanban,
  Folder,
  Hash,
  MessageSquare,
  Plus,
} from "lucide-react";
import { Category } from "@/types";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useChatStore } from "@/stores/chatStore";
import { useToastStore } from "@/stores/toastStore";
import { CreateProjectModal } from "@/components/features/CreateProjectModal";
import { CreateBoardModal } from "@/components/features/CreateBoardModal";
import { CreateDocFolderModal } from "@/components/features/CreateDocFolderModal";
import { CreateChannelModal } from "@/components/features/CreateChannelModal";

export function EmptyState() {
  const location = useLocation();
  const navigate = useNavigate();
  const { success, error } = useToastStore();

  const [showCreateProjectModal, setShowCreateProjectModal] = useState(false);
  const [showCreateBoardModal, setShowCreateBoardModal] = useState(false);
  const [showCreateDocFolderModal, setShowCreateDocFolderModal] = useState(false);
  const [showCreateChannelModal, setShowCreateChannelModal] = useState(false);

  const createProject = useProjectStore((state) => state.createProject);
  const createBoard = useBoardStore((state) => state.createBoard);
  const createFolder = useDocFolderStore((state) => state.createFolder);
  const createChannel = useChatStore((state) => state.createChannel);

  // Determine category from URL
  const getCurrentCategory = (): Category => {
    const path = location.pathname;
    if (path.startsWith("/projects")) return "projects";
    if (path.startsWith("/boards")) return "boards";
    if (path.startsWith("/doc-folders")) return "docs";
    if (path.startsWith("/docs")) return "docs";
    if (path.startsWith("/channels")) return "channels";
    if (path.startsWith("/dms")) return "dms";
    return "home";
  };

  const category = getCurrentCategory();

  const getCategoryInfo = () => {
    switch (category) {
      case "projects":
        return {
          title: "Projects",
          icon: Briefcase,
          description: "Organize your work into projects",
          actionText: "Create Project",
          action: () => {
            setShowCreateProjectModal(true);
          },
        };
      case "boards":
        return {
          title: "Boards",
          icon: Kanban,
          description: "Create boards to organize your tasks",
          actionText: "Create Board",
          action: () => {
            setShowCreateBoardModal(true);
          },
        };
      case "docs":
        return {
          title: "Folders",
          icon: Folder,
          description: "Organize your documents into folders",
          actionText: "Create Folder",
          action: () => {
            setShowCreateDocFolderModal(true);
          },
        };
      case "channels":
        return {
          title: "Channels",
          icon: Hash,
          description: "Start team conversations in channels",
          actionText: "Create Channel",
          action: () => {
            setShowCreateChannelModal(true);
          },
        };
      case "dms":
        return {
          title: "Direct Messages",
          icon: MessageSquare,
          description: "Send direct messages to team members",
          actionText: null,
          action: null,
        };
      default:
        return {
          title: "Welcome",
          icon: Folder,
          description: "Select a category to get started",
          actionText: null,
          action: null,
        };
    }
  };

  const {
    title,
    icon: Icon,
    description,
    actionText,
    action,
  } = getCategoryInfo();

  const handleCreate = async () => {
    if (action) {
      try {
        await action();
      } catch (err) {
        console.error("Failed to create item:", err);
        error("Error: " + (err as Error).message);
      }
    }
  };

  const handleCreateProject = async (data: {
    name: string;
    description?: string;
    memberIds: string[];
  }) => {
    try {
      const project = await createProject({
        name: data.name,
        description: data.description,
        memberIds: data.memberIds,
      });
      success("Project created successfully");
      setShowCreateProjectModal(false);
      navigate(`/projects/${project.id}`);
    } catch (err) {
      console.error("Failed to create project:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateBoard = async (name: string, prefix: string) => {
    try {
      const board = await createBoard(name, prefix);
      success("Board created successfully");
      setShowCreateBoardModal(false);
      navigate(`/boards/${board.id}`);
    } catch (err) {
      console.error("Failed to create board:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateDocFolder = async (name: string, prefix: string) => {
    try {
      const folder = await createFolder(name, prefix);
      success("Folder created successfully");
      setShowCreateDocFolderModal(false);
      navigate(`/doc-folders/${folder.id}`);
    } catch (err) {
      console.error("Failed to create folder:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateChannel = async (name: string) => {
    try {
      const channel = await createChannel(name);
      success("Channel created successfully");
      setShowCreateChannelModal(false);
      navigate(`/channels/${channel.id}`);
    } catch (err) {
      console.error("Failed to create channel:", err);
      error("Error: " + (err as Error).message);
    }
  };

  return (
    <div className="flex-1 flex items-center justify-center p-4 md:p-8">
      <div className="text-center max-w-md">
        <div className="inline-flex items-center justify-center w-24 h-24 rounded-full bg-dark-surface border-2 border-dark-border mb-6">
          <Icon size={48} className="text-dark-text-muted" />
        </div>

        <h2 className="text-2xl font-bold text-dark-text mb-3">{title}</h2>
        <p className="text-dark-text-muted mb-8">{description}</p>

        {actionText && action !== null && (
          <button
            onClick={handleCreate}
            className="inline-flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
          >
            <Plus size={20} />
            {actionText}
          </button>
        )}
      </div>

      <CreateProjectModal
        isOpen={showCreateProjectModal}
        onClose={() => setShowCreateProjectModal(false)}
        onSubmit={handleCreateProject}
      />

      <CreateBoardModal
        isOpen={showCreateBoardModal}
        onClose={() => setShowCreateBoardModal(false)}
        onSubmit={handleCreateBoard}
      />

      <CreateDocFolderModal
        isOpen={showCreateDocFolderModal}
        onClose={() => setShowCreateDocFolderModal(false)}
        onSubmit={handleCreateDocFolder}
      />

      <CreateChannelModal
        isOpen={showCreateChannelModal}
        onClose={() => setShowCreateChannelModal(false)}
        onSubmit={handleCreateChannel}
      />
    </div>
  );
}
