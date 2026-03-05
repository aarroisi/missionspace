import {
  Star,
  Plus,
  ChevronDown,
  ChevronRight,
  Kanban,
  Folder,
  Hash,
  Briefcase,
  MessageSquare,
} from "lucide-react";
import { clsx } from "clsx";
import { useNavigate, useLocation } from "react-router-dom";
import { useEffect, useState, useMemo, useRef } from "react";
import { useUIStore } from "@/stores/uiStore";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useChatStore } from "@/stores/chatStore";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Avatar } from "@/components/ui/Avatar";
import { useMemberProfile } from "@/contexts/MemberProfileContext";
import { Category } from "@/types";
import { CreateProjectModal } from "@/components/features/CreateProjectModal";
import { CreateBoardModal } from "@/components/features/CreateBoardModal";
import { CreateDocFolderModal } from "@/components/features/CreateDocFolderModal";
import { CreateChannelModal } from "@/components/features/CreateChannelModal";

export function InnerSidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const sidebarOpen = useUIStore((state) => state.sidebarOpen);
  const setActiveItem = useUIStore((state) => state.setActiveItem);
  const collapsedSections = useUIStore((state) => state.collapsedSections);
  const toggleSection = useUIStore((state) => state.toggleSection);
  const { success, error } = useToastStore();
  const { openMemberProfile } = useMemberProfile();
  const [showCreateProjectModal, setShowCreateProjectModal] = useState(false);
  const [showCreateBoardModal, setShowCreateBoardModal] = useState(false);
  const [showCreateDocFolderModal, setShowCreateDocFolderModal] =
    useState(false);
  const [showCreateChannelModal, setShowCreateChannelModal] = useState(false);
  const [createBoardForProjectId, setCreateBoardForProjectId] = useState<
    string | null
  >(null);
  const [createDocFolderForProjectId, setCreateDocFolderForProjectId] =
    useState<string | null>(null);
  const [addItemDropdownProjectId, setAddItemDropdownProjectId] = useState<
    string | null
  >(null);
  const [, setShowNewDM] = useState(false);
  const [, setDmSearch] = useState("");
  const addItemDropdownRef = useRef<HTMLDivElement>(null);

  const unreadChannelIds = useChatStore((state) => state.unreadChannelIds);
  const unreadDmIds = useChatStore((state) => state.unreadDmIds);
  const fetchUnreadItems = useChatStore((state) => state.fetchUnreadItems);

  useEffect(() => {
    fetchUnreadItems();
  }, [fetchUnreadItems]);

  const projects = useProjectStore((state) => state.projects) || [];

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        addItemDropdownRef.current &&
        !addItemDropdownRef.current.contains(event.target as Node)
      ) {
        setAddItemDropdownProjectId(null);
      }
    };

    if (addItemDropdownProjectId) {
      document.addEventListener("mousedown", handleClickOutside);
      return () =>
        document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [addItemDropdownProjectId]);

  // Get all item IDs that belong to projects (for determining category)
  const projectItemIds = useMemo(() => {
    const boardIds = new Set<string>();
    const docFolderIds = new Set<string>();
    const channelIds = new Set<string>();

    projects.forEach((p) => {
      (p.items || []).forEach((item) => {
        if (item.itemType === "board") boardIds.add(item.itemId);
        if (item.itemType === "doc_folder") docFolderIds.add(item.itemId);
        if (item.itemType === "channel") channelIds.add(item.itemId);
      });
    });

    return { boardIds, docFolderIds, channelIds };
  }, [projects]);

  // Determine active category from URL
  const getCurrentCategory = (): Category => {
    const path = location.pathname;

    if (path === "/dashboard") return "home";
    if (path.startsWith("/projects")) return "projects";
    if (path.startsWith("/boards")) return "boards";
    if (path.startsWith("/doc-folders") || path.startsWith("/docs"))
      return "docs";
    if (path.startsWith("/channels")) return "channels";
    if (path.startsWith("/dms")) return "dms";
    return "home";
  };

  const activeCategory = getCurrentCategory();

  // Compute active item and project directly from URL for immediate highlighting
  const { activeItemId, activeItemType, activeProjectId } = useMemo(() => {
    const path = location.pathname;
    const pathParts = path.split("/").filter(Boolean);

    // Handle nested project routes: /projects/:projectId/docs/:docId
    if (pathParts[0] === "projects" && pathParts.length >= 4) {
      const projectId = pathParts[1];
      const itemType = pathParts[2];
      const itemId = pathParts[3];
      if (itemId && itemId !== "new") {
        return {
          activeItemId: itemId,
          activeItemType: itemType,
          activeProjectId: projectId,
        };
      }
      return {
        activeItemId: null,
        activeItemType: null,
        activeProjectId: projectId,
      };
    }

    // Handle project routes: /projects/:id
    if (pathParts[0] === "projects" && pathParts.length >= 2) {
      const projectId = pathParts[1];
      return {
        activeItemId: projectId,
        activeItemType: "projects",
        activeProjectId: projectId,
      };
    }

    // Handle regular routes: /docs/:id, /lists/:id, etc.
    if (pathParts.length >= 2) {
      const category = pathParts[0];
      const id = pathParts[1];
      if (id && id !== "new") {
        return {
          activeItemId: id,
          activeItemType: category,
          activeProjectId: null,
        };
      }
    }
    return { activeItemId: null, activeItemType: null, activeProjectId: null };
  }, [location.pathname]);

  // Sync activeItem store with current URL (for other components that need it)
  useEffect(() => {
    const path = location.pathname;
    const pathParts = path.split("/").filter(Boolean);

    // Handle nested project routes: /projects/:projectId/docs/:docId
    if (pathParts[0] === "projects" && pathParts.length >= 4) {
      const itemType = pathParts[2];
      const itemId = pathParts[3];
      if (itemId && itemId !== "new") {
        setActiveItem({ type: itemType as Category, id: itemId });
      } else {
        setActiveItem(null);
      }
      return;
    }

    // Handle regular routes: /docs/:id, /lists/:id, etc.
    if (pathParts.length >= 2) {
      const category = pathParts[0];
      const id = pathParts[1];

      if (id && id !== "new") {
        setActiveItem({ type: category as Category, id });
      } else {
        setActiveItem(null);
      }
    } else {
      setActiveItem(null);
    }
  }, [location.pathname, setActiveItem]);

  // Helper to navigate to an item with guard check
  const navigateToItem = async (
    type: string,
    id: string,
    projectId?: string,
  ) => {
    const { navigationGuard } = useUIStore.getState();
    if (navigationGuard) {
      const canNavigate = await navigationGuard();
      if (!canNavigate) return;
    }
    setActiveItem({ type: type as any, id });

    if (projectId) {
      navigate(`/projects/${projectId}/${type}/${id}`);
    } else {
      navigate(`/${type}/${id}`);
    }
  };

  const createProject = useProjectStore((state) => state.createProject);
  const addItemToProject = useProjectStore((state) => state.addItem);
  const boards = useBoardStore((state) => state.boards) || [];
  const createBoard = useBoardStore((state) => state.createBoard);
  const docFolders = useDocFolderStore((state) => state.folders) || [];
  const createDocFolder = useDocFolderStore((state) => state.createFolder);
  const channels = useChatStore((state) => state.channels) || [];
  const directMessages = useChatStore((state) => state.directMessages) || [];
  const createChannel = useChatStore((state) => state.createChannel);
  const createDirectMessage = useChatStore((state) => state.createDirectMessage);
  const currentUser = useAuthStore((state) => state.user);
  const workspaceMembers = useAuthStore((state) => state.members) || [];

  // Handler to add item to a specific project
  const handleAddItemToProject = async (
    projectId: string,
    itemType: "board" | "doc_folder" | "channel",
  ) => {
    setAddItemDropdownProjectId(null);

    const { navigationGuard } = useUIStore.getState();
    if (navigationGuard) {
      const canNavigate = await navigationGuard();
      if (!canNavigate) return;
    }

    try {
      if (itemType === "doc_folder") {
        setCreateDocFolderForProjectId(projectId);
        setShowCreateDocFolderModal(true);
      } else if (itemType === "board") {
        setCreateBoardForProjectId(projectId);
        setShowCreateBoardModal(true);
      } else if (itemType === "channel") {
        const channel = await createChannel("new-channel");
        await addItemToProject(projectId, "channel", channel.id);
        success("Channel created successfully");
        navigate(`/projects/${projectId}/channels/${channel.id}`);
      }
    } catch (err) {
      console.error("Failed to create item:", err);
      error("Error: " + (err as Error).message);
    }
  };

  // Ensure all are arrays
  const safeProjects = Array.isArray(projects) ? projects : [];
  const safeBoards = Array.isArray(boards) ? boards : [];
  const safeDocFolders = Array.isArray(docFolders) ? docFolders : [];
  const safeChannels = Array.isArray(channels) ? channels : [];
  const safeDirectMessages = Array.isArray(directMessages)
    ? directMessages
    : [];

  // Filter items without project for main views
  const workspaceBoards = safeBoards.filter(
    (b) => !projectItemIds.boardIds.has(b.id),
  );
  const workspaceDocFolders = safeDocFolders.filter(
    (f) => !projectItemIds.docFolderIds.has(f.id),
  );
  const workspaceChannels = safeChannels.filter(
    (c) => !projectItemIds.channelIds.has(c.id),
  );

  // Helper to get items for a specific project
  const getProjectBoards = (projectId: string) => {
    const project = safeProjects.find((p) => p.id === projectId);
    const boardIds = (project?.items || [])
      .filter((i) => i.itemType === "board")
      .map((i) => i.itemId);
    return safeBoards.filter((b) => boardIds.includes(b.id));
  };
  const getProjectDocFolders = (projectId: string) => {
    const project = safeProjects.find((p) => p.id === projectId);
    const folderIds = (project?.items || [])
      .filter((i) => i.itemType === "doc_folder")
      .map((i) => i.itemId);
    return safeDocFolders.filter((f) => folderIds.includes(f.id));
  };
  const getProjectChannels = (projectId: string) => {
    const project = safeProjects.find((p) => p.id === projectId);
    const channelIds = (project?.items || [])
      .filter((i) => i.itemType === "channel")
      .map((i) => i.itemId);
    return safeChannels.filter((c) => channelIds.includes(c.id));
  };

  if (!sidebarOpen) return null;

  const handleCreateItem = async () => {
    const { navigationGuard } = useUIStore.getState();
    if (navigationGuard) {
      const canNavigate = await navigationGuard();
      if (!canNavigate) return;
    }

    try {
      switch (activeCategory) {
        case "projects":
          setShowCreateProjectModal(true);
          return;
        case "boards":
          setCreateBoardForProjectId(null);
          setShowCreateBoardModal(true);
          return;
        case "docs":
          setCreateDocFolderForProjectId(null);
          setShowCreateDocFolderModal(true);
          return;
        case "channels":
          setShowCreateChannelModal(true);
          return;
      }
    } catch (err) {
      console.error("Failed to create item:", err);
      error("Error: " + (err as Error).message);
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
      await navigateToItem("projects", project.id);
    } catch (err) {
      console.error("Failed to create project:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateBoard = async (name: string, prefix: string) => {
    try {
      const board = await createBoard(name, prefix);
      if (createBoardForProjectId) {
        await addItemToProject(createBoardForProjectId, "board", board.id);
        success("Board created successfully");
        setShowCreateBoardModal(false);
        navigate(`/projects/${createBoardForProjectId}/boards/${board.id}`);
      } else {
        success("Board created successfully");
        setShowCreateBoardModal(false);
        await navigateToItem("boards", board.id);
      }
    } catch (err) {
      console.error("Failed to create board:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateDocFolder = async (name: string, prefix: string) => {
    try {
      const folder = await createDocFolder(name, prefix);
      if (createDocFolderForProjectId) {
        await addItemToProject(
          createDocFolderForProjectId,
          "doc_folder",
          folder.id,
        );
        success("Folder created successfully");
        setShowCreateDocFolderModal(false);
        navigate(
          `/projects/${createDocFolderForProjectId}/doc-folders/${folder.id}`,
        );
      } else {
        success("Folder created successfully");
        setShowCreateDocFolderModal(false);
        await navigateToItem("doc-folders", folder.id);
      }
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
      await navigateToItem("channels", channel.id);
    } catch (err) {
      console.error("Failed to create channel:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const handleStartDM = async (userId: string) => {
    try {
      const dm = await createDirectMessage(userId);
      setShowNewDM(false);
      setDmSearch("");
      await navigateToItem("dms", dm.id);
    } catch (err) {
      console.error("Failed to create DM:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const getItemName = (item: any, _type: string) => {
    return item.name || item.title;
  };

  const renderStarred = (items: any[], type: string) => {
    if (!items || !Array.isArray(items)) return null;
    const starred = items.filter((item) => item.starred);
    if (starred.length === 0) return null;

    return (
      <div className="mb-4">
        <button
          onClick={() => toggleSection("starred")}
          className="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider w-full hover:text-dark-text"
        >
          {collapsedSections["starred"] ? (
            <ChevronRight size={14} />
          ) : (
            <ChevronDown size={14} />
          )}
          <Star size={14} />
          Starred
        </button>
        {!collapsedSections["starred"] && (
          <div className="mt-1">
            {starred.map((item) => (
              <button
                key={item.id}
                onClick={() => navigateToItem(type, item.id)}
                className={clsx(
                  "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                  activeItemId === item.id && "bg-dark-surface text-blue-400",
                )}
              >
                {getItemIcon(type)}
                <span className="truncate">{getItemName(item, type)}</span>
              </button>
            ))}
          </div>
        )}
      </div>
    );
  };

  const getItemIcon = (type: string) => {
    switch (type) {
      case "projects":
        return <Briefcase size={16} />;
      case "boards":
        return <Kanban size={16} />;
      case "doc-folders":
        return <Folder size={16} />;
      case "channels":
        return <Hash size={16} />;
      case "dms":
        return <MessageSquare size={16} />;
      default:
        return null;
    }
  };

  const renderContent = () => {
    switch (activeCategory) {
      case "home":
        return null;

      case "projects":
        return (
          <div>
            {renderStarred(safeProjects, "projects")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              All Projects
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {safeProjects.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No projects yet
                </p>
              )}
              {safeProjects.map((project) => {
                const projectBoards = getProjectBoards(project.id);
                const projectDocFolders = getProjectDocFolders(project.id);
                const projectChannels = getProjectChannels(project.id);
                const hasItems =
                  projectBoards.length > 0 ||
                  projectDocFolders.length > 0 ||
                  projectChannels.length > 0;
                const isProjectActive = activeProjectId === project.id;

                return (
                  <div key={project.id} className="group">
                    <div className="flex items-center pr-3">
                      <button
                        onClick={() => navigateToItem("projects", project.id)}
                        className={clsx(
                          "flex-1 px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors rounded",
                          activeItemId === project.id &&
                            activeItemType === "projects" &&
                            "bg-dark-surface text-blue-400",
                        )}
                      >
                        <span className="flex-shrink-0">
                          {isProjectActive ? (
                            <ChevronDown size={14} />
                          ) : (
                            <ChevronRight size={14} />
                          )}
                        </span>
                        <span className="truncate flex-1">{project.name}</span>
                      </button>
                      <div className="relative">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            setAddItemDropdownProjectId(
                              addItemDropdownProjectId === project.id
                                ? null
                                : project.id,
                            );
                          }}
                          className={clsx(
                            "hover:text-dark-text text-dark-text-muted transition-all",
                            addItemDropdownProjectId === project.id
                              ? "opacity-100"
                              : "opacity-0 group-hover:opacity-100",
                          )}
                          title="Add item to project"
                        >
                          <Plus size={14} />
                        </button>
                        {addItemDropdownProjectId === project.id && (
                          <div
                            ref={addItemDropdownRef}
                            className="absolute right-0 top-6 z-50 w-40 bg-dark-surface border border-dark-border rounded-lg shadow-lg py-1"
                          >
                            <button
                              onClick={() =>
                                handleAddItemToProject(project.id, "board")
                              }
                              className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
                            >
                              <Kanban size={14} />
                              New Board
                            </button>
                            <button
                              onClick={() =>
                                handleAddItemToProject(
                                  project.id,
                                  "doc_folder",
                                )
                              }
                              className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
                            >
                              <Folder size={14} />
                              New Folder
                            </button>
                            <button
                              onClick={() =>
                                handleAddItemToProject(project.id, "channel")
                              }
                              className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
                            >
                              <Hash size={14} />
                              New Channel
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                    {isProjectActive && (
                      <div className="ml-[19px] border-l border-dark-border">
                        {!hasItems && (
                          <p className="pl-3 py-1.5 text-xs text-dark-text-muted">
                            No items yet
                          </p>
                        )}
                        {projectBoards.map((board) => {
                          const isActive = activeItemId === board.id;
                          return (
                            <button
                              key={board.id}
                              onClick={() =>
                                navigateToItem("boards", board.id, project.id)
                              }
                              className={clsx(
                                "w-full pl-3 pr-2 py-1.5 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                                isActive
                                  ? "bg-dark-surface text-blue-400"
                                  : "text-dark-text-muted",
                              )}
                            >
                              <Kanban size={14} className="flex-shrink-0" />
                              <span className="truncate">{board.name}</span>
                            </button>
                          );
                        })}
                        {projectDocFolders.map((folder) => {
                          const isActive = activeItemId === folder.id;
                          return (
                            <button
                              key={folder.id}
                              onClick={() =>
                                navigateToItem(
                                  "doc-folders",
                                  folder.id,
                                  project.id,
                                )
                              }
                              className={clsx(
                                "w-full pl-3 pr-2 py-1.5 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                                isActive
                                  ? "bg-dark-surface text-blue-400"
                                  : "text-dark-text-muted",
                              )}
                            >
                              <Folder size={14} className="flex-shrink-0" />
                              <span className="truncate">{folder.name}</span>
                            </button>
                          );
                        })}
                        {projectChannels.map((channel) => {
                          const isActive = activeItemId === channel.id;
                          return (
                            <button
                              key={channel.id}
                              onClick={() =>
                                navigateToItem(
                                  "channels",
                                  channel.id,
                                  project.id,
                                )
                              }
                              className={clsx(
                                "w-full pl-3 pr-2 py-1.5 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                                isActive
                                  ? "bg-dark-surface text-blue-400"
                                  : "text-dark-text-muted",
                              )}
                            >
                              <Hash size={14} className="flex-shrink-0" />
                              <span className="truncate">{channel.name}</span>
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        );

      case "boards":
        return (
          <div>
            {renderStarred(workspaceBoards, "boards")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              All Boards
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {workspaceBoards.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No boards yet
                </p>
              )}
              {workspaceBoards.map((board) => (
                <button
                  key={board.id}
                  onClick={() => navigateToItem("boards", board.id)}
                  className={clsx(
                    "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                    activeItemId === board.id &&
                      "bg-dark-surface text-blue-400",
                  )}
                >
                  <Kanban size={16} />
                  <span className="truncate">{board.name}</span>
                </button>
              ))}
            </div>
          </div>
        );

      case "docs":
        return (
          <div>
            {renderStarred(workspaceDocFolders, "doc-folders")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              All Folders
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {workspaceDocFolders.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No folders yet
                </p>
              )}
              {workspaceDocFolders.map((folder) => (
                <button
                  key={folder.id}
                  onClick={() => navigateToItem("doc-folders", folder.id)}
                  className={clsx(
                    "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                    activeItemId === folder.id &&
                      "bg-dark-surface text-blue-400",
                  )}
                >
                  <Folder size={16} />
                  <span className="truncate">{folder.name}</span>
                </button>
              ))}
            </div>
          </div>
        );

      case "channels":
        return (
          <div>
            {renderStarred(workspaceChannels, "channels")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              All Channels
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {workspaceChannels.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No channels yet
                </p>
              )}
              {workspaceChannels.map((channel) => {
                const isUnread = unreadChannelIds.has(channel.id);
                return (
                  <button
                    key={channel.id}
                    onClick={() => navigateToItem("channels", channel.id)}
                    className={clsx(
                      "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                      activeItemId === channel.id &&
                        "bg-dark-surface text-blue-400",
                      isUnread && activeItemId !== channel.id && "font-semibold text-dark-text",
                    )}
                  >
                    <Hash size={16} />
                    <span className="truncate flex-1">{channel.name}</span>
                    {isUnread && activeItemId !== channel.id && (
                      <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        );

      case "dms": {
        // Build a combined list: existing DMs first, then remaining members
        const dmMembers = safeDirectMessages.map((dm) => ({
          id: dm.userId,
          name: dm.name,
          avatar: dm.avatar,
          online: dm.online,
          dmId: dm.id,
          starred: dm.starred,
        }));
        const dmUserIds = new Set(dmMembers.map((m) => m.id));
        const otherMembers = workspaceMembers
          .filter(
            (m) => m.id !== currentUser?.id && !dmUserIds.has(m.id),
          )
          .map((m) => ({
            id: m.id,
            name: m.name,
            avatar: m.avatar,
            online: m.online,
            dmId: null as string | null,
            starred: false,
          }));
        const allDmMembers = [...dmMembers, ...otherMembers];

        return (
          <div>
            {renderStarred(safeDirectMessages, "dms")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
              Direct Messages
            </div>
            <div className="mt-1">
              {allDmMembers.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No conversations yet
                </p>
              )}
              {allDmMembers.map((member) => {
                const isUnread = member.dmId ? unreadDmIds.has(member.dmId) : false;
                return (
                  <button
                    key={member.id}
                    onClick={() => {
                      if (member.dmId) {
                        navigateToItem("dms", member.dmId);
                      } else {
                        handleStartDM(member.id);
                      }
                    }}
                    className={clsx(
                      "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                      member.dmId && activeItemId === member.dmId &&
                        "bg-dark-surface text-blue-400",
                      isUnread && activeItemId !== member.dmId && "font-semibold text-dark-text",
                    )}
                  >
                    <span
                      className="flex items-center gap-2 flex-1 min-w-0"
                      onClick={(event) => {
                        event.stopPropagation();
                        openMemberProfile(member.id);
                      }}
                      title={`Open ${member.name}'s profile`}
                    >
                      <Avatar
                        name={member.name}
                        src={member.avatar}
                        size="xs"
                        online={member.online}
                      />
                      <span className="truncate">{member.name}</span>
                    </span>
                    {isUnread && activeItemId !== member.dmId && (
                      <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        );
      }

      default:
        return null;
    }
  };

  const content = renderContent();

  // Don't render sidebar if there's no content (e.g., home page)
  if (!content) {
    return null;
  }

  return (
    <>
      <div className="w-52 bg-dark-surface border-r border-dark-border overflow-y-auto flex-shrink-0 pt-4">
        {content}
      </div>

      <CreateProjectModal
        isOpen={showCreateProjectModal}
        onClose={() => setShowCreateProjectModal(false)}
        onSubmit={handleCreateProject}
      />

      <CreateBoardModal
        isOpen={showCreateBoardModal}
        onClose={() => {
          setShowCreateBoardModal(false);
          setCreateBoardForProjectId(null);
        }}
        onSubmit={handleCreateBoard}
      />
      <CreateDocFolderModal
        isOpen={showCreateDocFolderModal}
        onClose={() => {
          setShowCreateDocFolderModal(false);
          setCreateDocFolderForProjectId(null);
        }}
        onSubmit={handleCreateDocFolder}
      />
      <CreateChannelModal
        isOpen={showCreateChannelModal}
        onClose={() => setShowCreateChannelModal(false)}
        onSubmit={handleCreateChannel}
      />
    </>
  );
}
