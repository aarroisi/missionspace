import {
  Star,
  Plus,
  ChevronDown,
  ChevronRight,
  Kanban,
  FileText,
  Hash,
} from "lucide-react";
import { clsx } from "clsx";
import { useNavigate, useLocation } from "react-router-dom";
import { useEffect, useState, useMemo, useRef } from "react";
import { useUIStore } from "@/stores/uiStore";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocStore } from "@/stores/docStore";
import { useChatStore } from "@/stores/chatStore";
import { useToastStore } from "@/stores/toastStore";
import { Avatar } from "@/components/ui/Avatar";
import { Category } from "@/types";
import { CreateProjectModal } from "@/components/features/CreateProjectModal";
import { CreateBoardModal } from "@/components/features/CreateBoardModal";

export function InnerSidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const sidebarOpen = useUIStore((state) => state.sidebarOpen);
  const setActiveItem = useUIStore((state) => state.setActiveItem);
  const collapsedSections = useUIStore((state) => state.collapsedSections);
  const toggleSection = useUIStore((state) => state.toggleSection);
  const { success, error } = useToastStore();
  const [showCreateProjectModal, setShowCreateProjectModal] = useState(false);
  const [showCreateBoardModal, setShowCreateBoardModal] = useState(false);
  const [createBoardForProjectId, setCreateBoardForProjectId] = useState<
    string | null
  >(null);
  const [addItemDropdownProjectId, setAddItemDropdownProjectId] = useState<
    string | null
  >(null);
  const addItemDropdownRef = useRef<HTMLDivElement>(null);

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
    const docIds = new Set<string>();
    const channelIds = new Set<string>();

    projects.forEach((p) => {
      (p.items || []).forEach((item) => {
        if (item.itemType === "board") boardIds.add(item.itemId);
        if (item.itemType === "doc") docIds.add(item.itemId);
        if (item.itemType === "channel") channelIds.add(item.itemId);
      });
    });

    return { boardIds, docIds, channelIds };
  }, [projects]);

  // Determine active category from URL
  const getCurrentCategory = (): Category => {
    const path = location.pathname;

    if (path === "/") return "home";
    // All /projects/* routes (including nested /projects/:id/docs/:docId) are projects
    if (path.startsWith("/projects")) return "projects";
    if (path.startsWith("/boards")) return "boards";
    if (path.startsWith("/docs")) return "docs";
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
      const itemType = pathParts[2]; // "docs", "boards", "channels"
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
      const itemType = pathParts[2]; // "docs", "lists", "channels"
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
  // For project items, use nested URL: /projects/:projectId/docs/:docId
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
      // Nested project route
      navigate(`/projects/${projectId}/${type}/${id}`);
    } else {
      // Regular route
      navigate(`/${type}/${id}`);
    }
  };

  const createProject = useProjectStore((state) => state.createProject);
  const addItemToProject = useProjectStore((state) => state.addItem);
  const boards = useBoardStore((state) => state.boards) || [];
  const createBoard = useBoardStore((state) => state.createBoard);
  const docs = useDocStore((state) => state.docs) || [];
  const channels = useChatStore((state) => state.channels) || [];
  const directMessages = useChatStore((state) => state.directMessages) || [];
  const createChannel = useChatStore((state) => state.createChannel);

  // Handler to add item to a specific project
  const handleAddItemToProject = async (
    projectId: string,
    itemType: "board" | "doc" | "channel",
  ) => {
    setAddItemDropdownProjectId(null);

    const { navigationGuard } = useUIStore.getState();
    if (navigationGuard) {
      const canNavigate = await navigationGuard();
      if (!canNavigate) return;
    }

    try {
      if (itemType === "doc") {
        // Navigate to new doc page
        navigate(`/projects/${projectId}/docs/new`);
      } else if (itemType === "board") {
        // Show modal to get board name
        setCreateBoardForProjectId(projectId);
        setShowCreateBoardModal(true);
      } else if (itemType === "channel") {
        // Create channel and add to project
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
  const safeDocs = Array.isArray(docs) ? docs : [];
  const safeChannels = Array.isArray(channels) ? channels : [];
  const safeDirectMessages = Array.isArray(directMessages)
    ? directMessages
    : [];

  // Filter items without project for main views (use projectItemIds from above)
  const workspaceBoards = safeBoards.filter(
    (b) => !projectItemIds.boardIds.has(b.id),
  );
  const workspaceDocs = safeDocs.filter(
    (d) => !projectItemIds.docIds.has(d.id),
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
  const getProjectDocs = (projectId: string) => {
    const project = safeProjects.find((p) => p.id === projectId);
    const docIds = (project?.items || [])
      .filter((i) => i.itemType === "doc")
      .map((i) => i.itemId);
    return safeDocs.filter((d) => docIds.includes(d.id));
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
    console.log("Creating item for category:", activeCategory);

    // Check navigation guard before creating
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
          navigate("/docs/new");
          setActiveItem({ type: "docs", id: "new" });
          break;
        case "channels":
          const channel = await createChannel("new-channel");
          success("Channel created successfully");
          await navigateToItem("channels", channel.id);
          break;
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

  const handleCreateBoard = async (name: string) => {
    try {
      const board = await createBoard(name);
      if (createBoardForProjectId) {
        // Add to project
        await addItemToProject(createBoardForProjectId, "board", board.id);
        success("Board created successfully");
        setShowCreateBoardModal(false);
        navigate(`/projects/${createBoardForProjectId}/boards/${board.id}`);
      } else {
        // Standalone board
        success("Board created successfully");
        setShowCreateBoardModal(false);
        await navigateToItem("boards", board.id);
      }
    } catch (err) {
      console.error("Failed to create board:", err);
      error("Error: " + (err as Error).message);
    }
  };

  const getItemName = (item: any, type: string) => {
    if (type === "docs") return item.title;
    return item.name;
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
      case "boards":
        return <Kanban size={16} />;
      case "docs":
        return <FileText size={16} />;
      case "channels":
        return <Hash size={16} />;
      default:
        return null;
    }
  };

  const renderContent = () => {
    switch (activeCategory) {
      case "home":
        // No inner sidebar for home
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
                const projectDocs = getProjectDocs(project.id);
                const projectChannels = getProjectChannels(project.id);
                const hasItems =
                  projectBoards.length > 0 ||
                  projectDocs.length > 0 ||
                  projectChannels.length > 0;
                const isProjectActive = activeProjectId === project.id;

                return (
                  <div key={project.id} className="group">
                    <div className="flex items-center pr-3">
                      <span className="p-1">
                        {isProjectActive ? (
                          <ChevronDown size={14} />
                        ) : (
                          <ChevronRight size={14} />
                        )}
                      </span>
                      <button
                        onClick={() => navigateToItem("projects", project.id)}
                        className={clsx(
                          "flex-1 px-2 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors rounded",
                          activeItemId === project.id &&
                            activeItemType === "projects" &&
                            "bg-dark-surface text-blue-400",
                        )}
                      >
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
                                handleAddItemToProject(project.id, "doc")
                              }
                              className="w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-hover text-dark-text"
                            >
                              <FileText size={14} />
                              New Doc
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
                      <div className="ml-6 border-l border-dark-border">
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
                        {projectDocs.map((doc) => {
                          const isActive = activeItemId === doc.id;
                          return (
                            <button
                              key={doc.id}
                              onClick={() =>
                                navigateToItem("docs", doc.id, project.id)
                              }
                              className={clsx(
                                "w-full pl-3 pr-2 py-1.5 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                                isActive
                                  ? "bg-dark-surface text-blue-400"
                                  : "text-dark-text-muted",
                              )}
                            >
                              <FileText size={14} className="flex-shrink-0" />
                              <span className="truncate">{doc.title}</span>
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
            {renderStarred(workspaceDocs, "docs")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              All Docs
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {workspaceDocs.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No docs yet
                </p>
              )}
              {workspaceDocs.map((doc) => (
                <button
                  key={doc.id}
                  onClick={() => navigateToItem("docs", doc.id)}
                  className={clsx(
                    "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                    activeItemId === doc.id && "bg-dark-surface text-blue-400",
                  )}
                >
                  <FileText size={16} />
                  <span className="truncate">{doc.title}</span>
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
              {workspaceChannels.map((channel) => (
                <button
                  key={channel.id}
                  onClick={() => navigateToItem("channels", channel.id)}
                  className={clsx(
                    "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                    activeItemId === channel.id &&
                      "bg-dark-surface text-blue-400",
                  )}
                >
                  <Hash size={16} />
                  <span className="truncate">{channel.name}</span>
                </button>
              ))}
            </div>
          </div>
        );

      case "dms":
        return (
          <div>
            {renderStarred(safeDirectMessages, "dms")}
            <div className="px-3 py-1.5 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center justify-between">
              Direct Messages
              <button
                onClick={handleCreateItem}
                className="hover:text-dark-text"
                disabled
              >
                <Plus size={14} />
              </button>
            </div>
            <div className="mt-1">
              {safeDirectMessages.length === 0 && (
                <p className="px-3 py-2 text-sm text-dark-text-muted">
                  No conversations yet
                </p>
              )}
              {safeDirectMessages.map((dm) => (
                <button
                  key={dm.id}
                  onClick={() => navigateToItem("dms", dm.id)}
                  className={clsx(
                    "w-full px-3 py-2 text-left text-sm flex items-center gap-2 hover:bg-dark-surface transition-colors",
                    activeItemId === dm.id && "bg-dark-surface text-blue-400",
                  )}
                >
                  <Avatar name={dm.name} size="xs" online={dm.online} />
                  <span className="truncate">{dm.name}</span>
                </button>
              ))}
            </div>
          </div>
        );

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
    </>
  );
}
