import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocFolderStore } from "@/stores/docFolderStore";
import { useChatStore } from "@/stores/chatStore";
import { useAuthStore } from "@/stores/authStore";
import { useUIStore } from "@/stores/uiStore";
import {
  Briefcase,
  Folder,
  Kanban,
  MessageSquare,
  FileText,
} from "lucide-react";
import { Task, Doc } from "@/types";
import { api } from "@/lib/api";

export function HomePage() {
  const navigate = useNavigate();
  const workspace = useAuthStore((state) => state.workspace);
  const { setActiveItem } = useUIStore();
  const projects = useProjectStore((state) => state.projects) || [];
  const boards = useBoardStore((state) => state.boards) || [];
  const docFolders = useDocFolderStore((state) => state.folders) || [];
  const channels = useChatStore((state) => state.channels) || [];

  const [myTasks, setMyTasks] = useState<Task[]>([]);
  const [starredTasks, setStarredTasks] = useState<Task[]>([]);
  const [starredDocs, setStarredDocs] = useState<Doc[]>([]);

  // Fetch all tasks assigned to me and starred tasks/docs
  useEffect(() => {
    const fetchMyItems = async () => {
      try {
        const [tasksRes, childTasksRes, starredTasksRes, starredDocsRes] = await Promise.all([
          api.get<Task[]>("/tasks?assigned_to_me=true"),
          api.get<Task[]>("/tasks?assigned_to_me=true&is_subtask=true"),
          api.get<Task[]>("/tasks?starred=true"),
          api.get<{ data: Doc[] }>("/docs?starred=true"),
        ]);
        const tasks = Array.isArray(tasksRes) ? tasksRes : [];
        const childTasks = Array.isArray(childTasksRes) ? childTasksRes : [];
        setMyTasks([...tasks, ...childTasks]);
        setStarredTasks(Array.isArray(starredTasksRes) ? starredTasksRes : []);
        const docsData = starredDocsRes?.data;
        setStarredDocs(Array.isArray(docsData) ? docsData : []);
      } catch (error) {
        console.error("Failed to fetch my items:", error);
      }
    };
    fetchMyItems();
  }, []);

  // Ensure all values are arrays
  const safeProjects = Array.isArray(projects) ? projects : [];
  const safeBoards = Array.isArray(boards) ? boards : [];
  const safeDocFolders = Array.isArray(docFolders) ? docFolders : [];
  const safeChannels = Array.isArray(channels) ? channels : [];

  // Helper to find project containing an item
  const findProjectForItem = (
    itemId: string,
    itemType: "board" | "doc_folder" | "channel",
  ) => {
    return safeProjects.find((p) =>
      p.items?.some((i) => i.itemId === itemId && i.itemType === itemType),
    );
  };

  const starredItems = [
    ...safeProjects
      .filter((p) => p.starred)
      .map((p) => ({ ...p, type: "project" as const, project: undefined })),
    ...safeBoards
      .filter((b) => b.starred)
      .map((b) => ({
        ...b,
        type: "board" as const,
        project: findProjectForItem(b.id, "board"),
      })),
    ...safeDocFolders
      .filter((f) => f.starred)
      .map((f) => ({
        ...f,
        type: "doc_folder" as const,
        project: findProjectForItem(f.id, "doc_folder"),
      })),
    ...safeChannels
      .filter((c) => c.starred)
      .map((c) => ({
        ...c,
        type: "channel" as const,
        project: findProjectForItem(c.id, "channel"),
      })),
    ...starredTasks.map((t) => ({
      ...t,
      name: t.title,
      type: "task" as const,
      project: undefined,
    })),
    ...starredDocs.map((d) => ({
      ...d,
      name: d.title,
      type: "doc" as const,
      project: undefined,
    })),
  ];

  const handleItemClick = (item: (typeof starredItems)[number]) => {
    const projectId = item.project?.id;

    switch (item.type) {
      case "project":
        navigate(`/projects/${item.id}`);
        break;
      case "board":
        setActiveItem({ type: "boards", id: item.id });
        if (projectId) {
          navigate(`/projects/${projectId}/boards/${item.id}`);
        } else {
          navigate(`/boards/${item.id}`);
        }
        break;
      case "doc_folder":
        if (projectId) {
          navigate(`/projects/${projectId}/doc-folders/${item.id}`);
        } else {
          navigate(`/doc-folders/${item.id}`);
        }
        break;
      case "channel":
        setActiveItem({ type: "channels", id: item.id });
        if (projectId) {
          navigate(`/projects/${projectId}/channels/${item.id}`);
        } else {
          navigate(`/channels/${item.id}`);
        }
        break;
      case "task": {
        const task = item as Task & { type: "task" };
        const boardId = task.boardId || task.parent?.boardId;
        const taskParam = task.parentId
          ? `?task=${task.parentId}&subtask=${task.id}`
          : `?task=${task.id}`;
        if (boardId) {
          setActiveItem({ type: "boards", id: boardId });
          navigate(`/boards/${boardId}${taskParam}`);
        }
        break;
      }
      case "doc": {
        const doc = item as Doc & { type: "doc" };
        if (doc.docFolderId) {
          navigate(`/doc-folders/${doc.docFolderId}/docs/${doc.id}`);
        } else {
          navigate(`/docs/${doc.id}`);
        }
        break;
      }
    }
  };

  return (
    <div className="flex-1 overflow-y-auto p-8 bg-dark-surface">
      <h1 className="text-3xl font-bold text-dark-text mb-2">
        {workspace?.name || "Home"}
      </h1>

      <div className="mb-8">
        <h2 className="text-lg font-semibold text-dark-text mb-4">
          Starred Items
        </h2>
        {starredItems.length === 0 ? (
          <p className="text-dark-text-muted">No starred items yet</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {starredItems.map((item) => (
              <div
                key={item.id}
                onClick={() => handleItemClick(item)}
                className="p-4 bg-dark-bg border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-2 mb-2">
                  {item.type === "project" && (
                    <Briefcase size={16} className="text-orange-400" />
                  )}
                  {item.type === "board" && (
                    <Kanban size={16} className="text-blue-400" />
                  )}
                  {item.type === "doc_folder" && (
                    <Folder size={16} className="text-green-400" />
                  )}
                  {item.type === "channel" && (
                    <MessageSquare size={16} className="text-purple-400" />
                  )}
                  {item.type === "task" && (
                    <Kanban size={16} className="text-blue-400" />
                  )}
                  {item.type === "doc" && (
                    <FileText size={16} className="text-green-400" />
                  )}
                  <span className="text-xs text-dark-text-muted uppercase">
                    {item.type === "doc_folder" ? "folder" : item.type}
                  </span>
                </div>
                <h3 className="font-medium text-dark-text">
                  {"name" in item ? item.name : ""}
                </h3>
                {item.project && (
                  <p className="text-xs text-dark-text-muted mt-1 flex items-center gap-1">
                    <Briefcase size={12} />
                    {item.project.name}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* My Tasks */}
      <div>
        <h2 className="text-lg font-semibold text-dark-text mb-4">
          My Tasks
        </h2>
        {myTasks.length === 0 ? (
          <p className="text-dark-text-muted">No tasks assigned to you</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {myTasks.map((task) => (
              <div
                key={task.id}
                onClick={() => {
                  const boardId = task.boardId || task.parent?.boardId;
                  const taskParam = task.parentId
                    ? `?task=${task.parentId}&subtask=${task.id}`
                    : `?task=${task.id}`;
                  if (boardId) {
                    setActiveItem({ type: "boards", id: boardId });
                    navigate(`/boards/${boardId}${taskParam}`);
                  }
                }}
                className="p-4 bg-dark-bg border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-2 mb-2">
                  <Kanban size={16} className="text-blue-400" />
                  <span className="text-xs text-dark-text-muted uppercase">
                    Task
                  </span>
                  {task.status ? (
                    <span
                      className="ml-auto px-2 py-0.5 text-xs font-medium rounded"
                      style={{
                        backgroundColor: `${task.status.color}20`,
                        color: task.status.color,
                      }}
                    >
                      {task.status.name}
                    </span>
                  ) : task.isCompleted !== undefined && (
                    <span
                      className={`ml-auto px-2 py-0.5 text-xs font-medium rounded ${
                        task.isCompleted
                          ? "bg-green-500/20 text-green-400"
                          : "bg-yellow-500/20 text-yellow-400"
                      }`}
                    >
                      {task.isCompleted ? "Done" : "Pending"}
                    </span>
                  )}
                </div>
                <h3 className="font-medium text-dark-text">
                  {task.key && (
                    <span className="text-xs font-mono text-dark-text-muted mr-2">
                      {task.key}
                    </span>
                  )}
                  {task.title}
                </h3>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
