import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useProjectStore } from "@/stores/projectStore";
import { useBoardStore } from "@/stores/boardStore";
import { useDocStore } from "@/stores/docStore";
import { useChatStore } from "@/stores/chatStore";
import { useAuthStore } from "@/stores/authStore";
import { useUIStore } from "@/stores/uiStore";
import {
  CheckSquare,
  FileText,
  Folder,
  Kanban,
  MessageSquare,
  Square,
} from "lucide-react";
import { Task, Subtask } from "@/types";
import { api } from "@/lib/api";

export function HomePage() {
  const navigate = useNavigate();
  const workspace = useAuthStore((state) => state.workspace);
  const { setActiveItem } = useUIStore();
  const projects = useProjectStore((state) => state.projects) || [];
  const boards = useBoardStore((state) => state.boards) || [];
  const docs = useDocStore((state) => state.docs) || [];
  const channels = useChatStore((state) => state.channels) || [];

  const [myTasks, setMyTasks] = useState<Task[]>([]);
  const [mySubtasks, setMySubtasks] = useState<Subtask[]>([]);

  // Fetch my tasks and subtasks
  useEffect(() => {
    const fetchMyItems = async () => {
      try {
        const [tasksRes, subtasksRes] = await Promise.all([
          api.get<Task[]>("/tasks?assigned_to_me=true"),
          api.get<Subtask[]>("/subtasks?assigned_to_me=true"),
        ]);
        setMyTasks(Array.isArray(tasksRes) ? tasksRes : []);
        setMySubtasks(Array.isArray(subtasksRes) ? subtasksRes : []);
      } catch (error) {
        console.error("Failed to fetch my items:", error);
      }
    };
    fetchMyItems();
  }, []);

  // Ensure all values are arrays
  const safeProjects = Array.isArray(projects) ? projects : [];
  const safeBoards = Array.isArray(boards) ? boards : [];
  const safeDocs = Array.isArray(docs) ? docs : [];
  const safeChannels = Array.isArray(channels) ? channels : [];

  // Helper to find project containing an item
  const findProjectForItem = (
    itemId: string,
    itemType: "board" | "doc" | "channel",
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
    ...safeDocs
      .filter((d) => d.starred)
      .map((d) => ({
        ...d,
        type: "doc" as const,
        project: findProjectForItem(d.id, "doc"),
      })),
    ...safeChannels
      .filter((c) => c.starred)
      .map((c) => ({
        ...c,
        type: "channel" as const,
        project: findProjectForItem(c.id, "channel"),
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
      case "doc":
        if (projectId) {
          navigate(`/projects/${projectId}/docs/${item.id}`);
        } else {
          navigate(`/docs/${item.id}`);
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
    }
  };

  return (
    <div className="flex-1 overflow-y-auto p-8">
      <h1 className="text-3xl font-bold text-dark-text mb-2">
        {workspace?.name || "Home"}
      </h1>
      <p className="text-dark-text-muted mb-8">Welcome to your workspace!</p>

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
                className="p-4 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-2 mb-2">
                  {item.type === "project" && (
                    <Folder size={16} className="text-orange-400" />
                  )}
                  {item.type === "board" && (
                    <Kanban size={16} className="text-blue-400" />
                  )}
                  {item.type === "doc" && (
                    <FileText size={16} className="text-green-400" />
                  )}
                  {item.type === "channel" && (
                    <MessageSquare size={16} className="text-purple-400" />
                  )}
                  <span className="text-xs text-dark-text-muted uppercase">
                    {item.type}
                  </span>
                </div>
                <h3 className="font-medium text-dark-text">
                  {"name" in item
                    ? item.name
                    : "title" in item
                      ? item.title
                      : ""}
                </h3>
                {item.project && (
                  <p className="text-xs text-dark-text-muted mt-1 flex items-center gap-1">
                    <Folder size={12} />
                    {item.project.name}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* My Tasks and Subtasks - 2 columns */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* My Tasks */}
        <div>
          <h2 className="text-lg font-semibold text-dark-text mb-4">
            My Tasks
          </h2>
          {myTasks.length === 0 ? (
            <p className="text-dark-text-muted">No tasks assigned to you</p>
          ) : (
            <div className="space-y-2">
              {myTasks.map((task) => (
                <div
                  key={task.id}
                  onClick={() => {
                    setActiveItem({ type: "boards", id: task.boardId });
                    navigate(`/boards/${task.boardId}?task=${task.id}`);
                  }}
                  className="p-3 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
                >
                  <Kanban size={16} className="text-blue-400 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <h3 className="font-medium text-dark-text truncate">
                      {task.title}
                    </h3>
                  </div>
                  {task.status && (
                    <span
                      className="px-2 py-0.5 text-xs font-medium rounded"
                      style={{
                        backgroundColor: `${task.status.color}20`,
                        color: task.status.color,
                      }}
                    >
                      {task.status.name}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* My Subtasks */}
        <div>
          <h2 className="text-lg font-semibold text-dark-text mb-4">
            My Subtasks
          </h2>
          {mySubtasks.length === 0 ? (
            <p className="text-dark-text-muted">No subtasks assigned to you</p>
          ) : (
            <div className="space-y-2">
              {mySubtasks.map((subtask) => (
                <div
                  key={subtask.id}
                  onClick={() => {
                    if (subtask.task?.boardId) {
                      setActiveItem({
                        type: "boards",
                        id: subtask.task.boardId,
                      });
                      navigate(
                        `/boards/${subtask.task.boardId}?task=${subtask.taskId}&subtask=${subtask.id}`,
                      );
                    }
                  }}
                  className="p-3 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
                >
                  {subtask.isCompleted ? (
                    <CheckSquare
                      size={16}
                      className="text-green-500 flex-shrink-0"
                    />
                  ) : (
                    <Square
                      size={16}
                      className="text-dark-text-muted flex-shrink-0"
                    />
                  )}
                  <div className="flex-1 min-w-0">
                    <h3
                      className={`font-medium truncate ${subtask.isCompleted ? "text-dark-text-muted line-through" : "text-dark-text"}`}
                    >
                      {subtask.title}
                    </h3>
                  </div>
                  <span
                    className={`px-2 py-0.5 text-xs font-medium rounded ${
                      subtask.isCompleted
                        ? "bg-green-500/20 text-green-400"
                        : "bg-yellow-500/20 text-yellow-400"
                    }`}
                  >
                    {subtask.isCompleted ? "Done" : "Pending"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
