import { useEffect, useState, useMemo, useRef } from "react";
import { useSearchParams, useNavigate, useParams } from "react-router-dom";
import { format } from "date-fns";
import {
  LayoutGrid,
  List,
  Settings,
  Plus,
  GripVertical,
  Check,
  MoreHorizontal,
  Star,
  Trash2,
  Users,
} from "lucide-react";
import { MobileBackButton } from "@/components/ui/MobileBackButton";
import {
  DndContext,
  DragOverlay,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  DragStartEvent,
  DragEndEvent,
  DragOverEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useDroppable } from "@dnd-kit/core";
import { KanbanBoard } from "@/components/features/KanbanBoard";
import { TaskDetailModal } from "@/components/features/TaskDetailModal";
import { ChildTaskDetailModal } from "@/components/features/ChildTaskDetailModal";
import { StatusManager } from "@/components/features/StatusManager";
import { ManageMembersModal } from "@/components/features/ManageMembersModal";
import { useBoardStore } from "@/stores/boardStore";
import { useChatStore } from "@/stores/chatStore";
import { useUIStore } from "@/stores/uiStore";
import { useAuthStore } from "@/stores/authStore";
import { Modal } from "@/components/ui/Modal";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { api } from "@/lib/api";
import { User, Task } from "@/types";
import { clsx } from "clsx";

// Sortable task row component for table view
function SortableTaskRow({
  task,
  isSelected,
  onClick,
}: {
  task: Task;
  isSelected: boolean;
  onClick: () => void;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: task.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={clsx(
        "flex items-center px-4 py-3 border-b border-dark-border cursor-pointer hover:bg-dark-surface/50 transition-colors",
        isSelected && "bg-blue-500/10",
      )}
    >
      <div
        {...attributes}
        {...listeners}
        className="mr-2 cursor-grab text-dark-text-muted hover:text-dark-text"
      >
        <GripVertical size={16} />
      </div>
      <div className="flex-1 min-w-0 flex items-center gap-2" onClick={onClick}>
        {task.key && (
          <span className="text-xs font-mono text-dark-text-muted flex-shrink-0">
            {task.key}
          </span>
        )}
        <span className="text-dark-text truncate">{task.title}</span>
      </div>
      <div className="w-32 text-sm text-dark-text-muted text-right hidden md:block">
        {task.assignee?.name || "-"}
      </div>
      <div className="w-32 text-sm text-dark-text-muted text-right hidden md:block">
        {task.dueOn ? new Date(task.dueOn).toLocaleDateString() : "-"}
      </div>
    </div>
  );
}

// Droppable status section for table view
function DroppableStatusSection({
  statusId,
  isHighlighted,
  isEmpty,
  children,
}: {
  statusId: string;
  isHighlighted: boolean;
  isEmpty: boolean;
  children: React.ReactNode;
}) {
  const { setNodeRef } = useDroppable({ id: `status-${statusId}` });

  return (
    <div
      ref={setNodeRef}
      className={clsx(
        "transition-colors",
        isHighlighted && "bg-blue-500/10",
        isEmpty && !isHighlighted && "min-h-[1px]",
      )}
    >
      {children}
      {isEmpty && isHighlighted && (
        <div className="flex items-center px-4 py-3 border-b border-dark-border border-dashed text-dark-text-muted text-sm">
          Drop here to move task
        </div>
      )}
    </div>
  );
}

export function BoardView() {
  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();
  const { projectId, id: boardIdParam } = useParams<{ projectId?: string; id?: string }>();
  const { activeItem } = useUIStore();
  const {
    boards,
    tasks,
    childTasks,
    fetchBoards,
    fetchTasks,
    fetchChildTasks,
    createTask,
    reorderTask,
    updateBoard,
    deleteBoard,
    toggleBoardStar,
  } = useBoardStore();
  const { messages, fetchMessages } = useChatStore();
  const { isOwner } = useAuthStore();
  const [isAddingTask, setIsAddingTask] = useState(false);
  const [newTaskStatusId, setNewTaskStatusId] = useState<string | null>(null);
  const [newTaskTitle, setNewTaskTitle] = useState("");
  const [isStatusManagerOpen, setIsStatusManagerOpen] = useState(false);
  const [workspaceMembers, setWorkspaceMembers] = useState<User[]>([]);
  const [activeTask, setActiveTask] = useState<Task | null>(null);
  const [overStatusId, setOverStatusId] = useState<string | null>(null);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState("");
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showMembersModal, setShowMembersModal] = useState(false);
  const titleInputRef = useRef<HTMLInputElement>(null);

  // Get view mode and task/subtask IDs from URL
  const viewMode = (searchParams.get("view") as "board" | "table") || "board";
  const taskParam = searchParams.get("task");
  const subtaskParam = searchParams.get("subtask");
  const highlightCommentId = searchParams.get("comment");

  const setViewMode = (mode: "board" | "table") => {
    const newParams = new URLSearchParams(searchParams);
    if (mode === "board") {
      newParams.delete("view"); // Default, no need to store
    } else {
      newParams.set("view", mode);
    }
    setSearchParams(newParams);
  };

  const boardId = activeItem?.id || boardIdParam;
  const board = Array.isArray(boards)
    ? boards.find((b) => b.id === boardId)
    : undefined;
  const rawBoardTasks = boardId ? tasks[boardId] : undefined;
  const boardTasks = Array.isArray(rawBoardTasks) ? rawBoardTasks : [];

  const selectedTask = taskParam ? boardTasks.find((t) => t.id === taskParam) : undefined;
  const taskChildTasks = taskParam ? childTasks[taskParam] || [] : [];
  const selectedChildTask = subtaskParam
    ? taskChildTasks.find((t) => t.id === subtaskParam)
    : undefined;
  const childTaskMessages = subtaskParam
    ? messages[`task:${subtaskParam}`] || []
    : [];

  // Drag and drop sensors
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(TouchSensor, {
      activationConstraint: {
        delay: 250,
        tolerance: 5,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  // Sort statuses by position
  const sortedStatuses = useMemo(
    () => [...(board?.statuses || [])].sort((a, b) => a.position - b.position),
    [board?.statuses],
  );

  // Group tasks by statusId and sort by position
  const groupedTasks = useMemo(() => {
    const groups: Record<string, Task[]> = {};
    for (const status of sortedStatuses) {
      groups[status.id] = boardTasks
        .filter((t) => t.statusId === status.id)
        .sort((a, b) => a.position - b.position);
    }
    return groups;
  }, [boardTasks, sortedStatuses]);

  const handleDragStart = (event: DragStartEvent) => {
    const task = boardTasks.find((t) => t.id === event.active.id);
    setActiveTask(task || null);
    setOverStatusId(null);
  };

  const handleDragOver = (event: DragOverEvent) => {
    const { active, over } = event;
    if (!over || !active) {
      setOverStatusId(null);
      return;
    }

    const activeTask = boardTasks.find((t) => t.id === active.id);
    if (!activeTask) {
      setOverStatusId(null);
      return;
    }

    const overId = over.id as string;
    let targetStatusId: string | null = null;

    if (overId.startsWith("status-")) {
      targetStatusId = overId.replace("status-", "");
    } else {
      const overTask = boardTasks.find((t) => t.id === overId);
      if (overTask) {
        targetStatusId = overTask.statusId;
      }
    }

    // Only highlight if moving to a different status
    if (targetStatusId && targetStatusId !== activeTask.statusId) {
      setOverStatusId(targetStatusId);
    } else {
      setOverStatusId(null);
    }
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    setActiveTask(null);
    setOverStatusId(null);

    if (!over) return;

    const taskId = active.id as string;
    const task = boardTasks.find((t) => t.id === taskId);
    if (!task) return;

    // Determine target status and index
    let targetStatusId: string;
    let targetIndex: number;

    const overId = over.id as string;

    // Check if dropped on a status section (droppable area)
    if (overId.startsWith("status-")) {
      targetStatusId = overId.replace("status-", "");
      targetIndex = groupedTasks[targetStatusId]?.length || 0;
    } else {
      // Dropped on another task
      const overTask = boardTasks.find((t) => t.id === overId);
      if (!overTask) return;

      targetStatusId = overTask.statusId;
      const columnTasks = groupedTasks[targetStatusId] || [];
      targetIndex = columnTasks.findIndex((t) => t.id === overId);
    }

    // Only reorder if something changed
    const currentColumnTasks = groupedTasks[task.statusId] || [];
    const currentIndex = currentColumnTasks.findIndex((t) => t.id === taskId);

    if (task.statusId !== targetStatusId || currentIndex !== targetIndex) {
      reorderTask(taskId, targetStatusId, targetIndex);
    }
  };

  useEffect(() => {
    if (boardIdParam && (!Array.isArray(boards) || boards.length === 0)) {
      fetchBoards();
    }
  }, [boardIdParam, boards, fetchBoards]);

  useEffect(() => {
    if (boardId) {
      fetchTasks(boardId);
    }
  }, [boardId, fetchTasks]);

  useEffect(() => {
    if (taskParam) {
      fetchChildTasks(taskParam);
      fetchMessages("task", taskParam);
    }
  }, [taskParam, fetchChildTasks, fetchMessages]);

  useEffect(() => {
    if (subtaskParam) {
      fetchMessages("task", subtaskParam);
    }
  }, [subtaskParam, fetchMessages]);

  // Fetch workspace members for assignee dropdown
  useEffect(() => {
    const fetchMembers = async () => {
      if (isOwner()) {
        try {
          const members = await api.get<User[]>("/workspace/members");
          setWorkspaceMembers(members);
        } catch (error) {
          console.error("Failed to fetch workspace members:", error);
        }
      }
    };
    fetchMembers();
  }, [isOwner]);

  // Focus title input when editing
  useEffect(() => {
    if (editingTitle && titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, [editingTitle]);

  const handleStartEditingTitle = () => {
    if (board) {
      setTitleValue(board.name);
      setEditingTitle(true);
    }
  };

  const handleTitleSave = async () => {
    if (!board) return;
    if (titleValue.trim() && titleValue !== board.name) {
      await updateBoard(board.id, { name: titleValue.trim() });
    } else {
      setTitleValue(board.name);
    }
    setEditingTitle(false);
  };

  const handleToggleStar = async () => {
    if (!board) return;
    await toggleBoardStar(board.id);
  };

  const handleDeleteBoard = async () => {
    if (!board) return;
    await deleteBoard(board.id);
    // Navigate back to project if board was inside a project, otherwise to boards list
    if (projectId) {
      navigate(`/projects/${projectId}`);
    } else {
      navigate("/boards");
    }
  };

  const handleTaskClick = (taskId: string) => {
    setSearchParams({ task: taskId });
  };

  const handleCloseTask = () => {
    setSearchParams({});
  };

  const handleChildTaskClick = (childTaskId: string) => {
    const newParams = new URLSearchParams(searchParams);
    newParams.set("subtask", childTaskId);
    setSearchParams(newParams);
  };

  const handleCloseChildTask = () => {
    const newParams = new URLSearchParams(searchParams);
    newParams.delete("subtask");
    setSearchParams(newParams);
  };

  const handleAddTask = (statusId: string) => {
    setNewTaskStatusId(statusId);
    setIsAddingTask(true);
    setNewTaskTitle("");
  };

  const handleCreateTask = async () => {
    if (!newTaskTitle.trim() || !boardId || !newTaskStatusId) return;

    await createTask(boardId, {
      title: newTaskTitle.trim(),
      statusId: newTaskStatusId,
    });
    setIsAddingTask(false);
    setNewTaskStatusId(null);
    setNewTaskTitle("");
  };

  if (!board) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <p className="text-dark-text-muted">Select a board to view tasks</p>
      </div>
    );
  }

  const renderBoardView = () => (
    <div className="flex-1 overflow-hidden">
      <KanbanBoard
        tasks={boardTasks}
        statuses={board?.statuses || []}
        onTaskClick={handleTaskClick}
        onAddTask={handleAddTask}
        selectedTaskId={taskParam}
      />
    </div>
  );

  const renderTableView = () => {
    // Also include tasks with no status (shouldn't happen but just in case)
    const tasksWithoutStatus = boardTasks.filter(
      (task) => !sortedStatuses.some((s) => s.id === task.statusId),
    );

    const renderStatusSeparator = (
      statusId: string,
      name: string,
      color: string,
      count: number,
    ) => (
      <div
        className="flex items-center px-4 py-2 bg-dark-bg border-b border-dark-border"
        style={{ borderLeftColor: color, borderLeftWidth: "3px" }}
      >
        <div className="flex-1 flex items-center gap-2">
          <div className="w-4" /> {/* Spacer for grip handle alignment */}
          <span className="text-sm font-medium text-dark-text-muted">
            {name}
          </span>
          <span className="text-xs text-dark-text-muted">({count})</span>
          <button
            onClick={() => {
              setNewTaskStatusId(statusId);
              setNewTaskTitle("");
            }}
            className="ml-1 p-0.5 rounded hover:bg-dark-surface text-dark-text-muted hover:text-dark-text transition-colors"
            title="Add task"
          >
            <Plus size={14} />
          </button>
        </div>
      </div>
    );

    return (
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragEnd={handleDragEnd}
      >
        <div className="flex-1 overflow-y-auto">
          <div className="border border-dark-border rounded-lg m-6 overflow-hidden">
            {/* Table header */}
            <div className="flex items-center px-4 py-2 bg-dark-surface border-b border-dark-border">
              <div className="w-6" /> {/* Spacer for grip handle */}
              <div className="flex-1">
                <span className="text-xs font-medium text-dark-text-muted uppercase tracking-wide">
                  Task
                </span>
              </div>
              <div className="w-32 text-right hidden md:block">
                <span className="text-xs font-medium text-dark-text-muted uppercase tracking-wide">
                  Assignee
                </span>
              </div>
              <div className="w-32 text-right hidden md:block">
                <span className="text-xs font-medium text-dark-text-muted uppercase tracking-wide">
                  Due Date
                </span>
              </div>
            </div>

            {sortedStatuses.map((status) => {
              const statusTasks = groupedTasks[status.id] || [];
              return (
                <div key={status.id}>
                  {renderStatusSeparator(
                    status.id,
                    status.name,
                    status.color,
                    statusTasks.length,
                  )}
                  <DroppableStatusSection
                    statusId={status.id}
                    isHighlighted={overStatusId === status.id}
                    isEmpty={statusTasks.length === 0}
                  >
                    <SortableContext
                      items={statusTasks.map((t) => t.id)}
                      strategy={verticalListSortingStrategy}
                    >
                      {statusTasks.map((task) => (
                        <SortableTaskRow
                          key={task.id}
                          task={task}
                          isSelected={taskParam === task.id}
                          onClick={() => handleTaskClick(task.id)}
                        />
                      ))}
                    </SortableContext>
                  </DroppableStatusSection>
                  {/* Inline add task input */}
                  {newTaskStatusId === status.id && (
                    <div className="flex items-center px-4 py-2 border-b border-dark-border bg-dark-surface/30">
                      <div className="w-6" /> {/* Spacer for grip handle */}
                      <input
                        type="text"
                        value={newTaskTitle}
                        onChange={(e) => setNewTaskTitle(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") handleCreateTask();
                          if (e.key === "Escape") {
                            setNewTaskStatusId(null);
                            setNewTaskTitle("");
                          }
                        }}
                        onBlur={() => {
                          if (!newTaskTitle.trim()) {
                            setNewTaskStatusId(null);
                            setNewTaskTitle("");
                          }
                        }}
                        placeholder="Task title..."
                        className="flex-1 bg-transparent text-dark-text placeholder-dark-text-muted focus:outline-none"
                        autoFocus
                      />
                      <div className="w-32" />
                      <div className="w-32" />
                    </div>
                  )}
                </div>
              );
            })}

            {/* Tasks without status (fallback) */}
            {tasksWithoutStatus.length > 0 && (
              <div>
                {renderStatusSeparator(
                  "no-status",
                  "No Status",
                  "#6b7280",
                  tasksWithoutStatus.length,
                )}
                {tasksWithoutStatus.map((task) => (
                  <SortableTaskRow
                    key={task.id}
                    task={task}
                    isSelected={taskParam === task.id}
                    onClick={() => handleTaskClick(task.id)}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Drag overlay */}
        <DragOverlay>
          {activeTask ? (
            <div className="flex items-center px-4 py-3 bg-dark-surface border border-dark-border rounded shadow-lg">
              <GripVertical size={16} className="mr-2 text-dark-text-muted" />
              <div className="flex-1 min-w-0 flex items-center gap-2">
                {activeTask.key && (
                  <span className="text-xs font-mono text-dark-text-muted flex-shrink-0">
                    {activeTask.key}
                  </span>
                )}
                <span className="text-dark-text truncate">
                  {activeTask.title}
                </span>
              </div>
              <div className="w-32 text-sm text-dark-text-muted text-right">
                {activeTask.assignee?.name || "-"}
              </div>
              <div className="w-32 text-sm text-dark-text-muted text-right">
                {activeTask.dueOn
                  ? new Date(activeTask.dueOn).toLocaleDateString()
                  : "-"}
              </div>
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>
    );
  };

  return (
    <div className="flex-1 flex flex-col overflow-hidden min-w-0">
      <div className="px-4 py-3 md:px-6 md:py-4 border-b border-dark-border flex items-center justify-between">
        <div className="flex items-center gap-2 min-w-0">
        <MobileBackButton to={projectId ? `/projects/${projectId}` : "/boards"} />
        {editingTitle ? (
          <div className="flex items-center gap-2">
            <input
              ref={titleInputRef}
              type="text"
              value={titleValue}
              onChange={(e) => setTitleValue(e.target.value)}
              onBlur={handleTitleSave}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  handleTitleSave();
                } else if (e.key === "Escape") {
                  setTitleValue(board.name);
                  setEditingTitle(false);
                }
              }}
              className="text-lg md:text-2xl font-bold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none"
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
              className="text-lg md:text-2xl font-bold text-dark-text cursor-pointer hover:text-blue-400 transition-colors"
              title="Click to edit"
            >
              {board.name}
            </h1>
            {board.createdBy && (
              <div className="text-sm text-dark-text-muted mt-1">
                Added by {board.createdBy.name} on{" "}
                {format(new Date(board.insertedAt), "MMM d, yyyy")}
              </div>
            )}
          </div>
        )}
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsStatusManagerOpen(true)}
            className="p-2 rounded transition-colors text-dark-text-muted hover:bg-dark-surface"
            title="Manage statuses"
          >
            <Settings size={18} />
          </button>
          <button
            onClick={() => setViewMode("board")}
            className={clsx(
              "p-2 rounded transition-colors",
              viewMode === "board"
                ? "bg-blue-600 text-white"
                : "text-dark-text-muted hover:bg-dark-surface",
            )}
            title="Board view"
          >
            <LayoutGrid size={18} />
          </button>
          <button
            onClick={() => setViewMode("table")}
            className={clsx(
              "p-2 rounded transition-colors",
              viewMode === "table"
                ? "bg-blue-600 text-white"
                : "text-dark-text-muted hover:bg-dark-surface",
            )}
            title="Table view"
          >
            <List size={18} />
          </button>
          <Dropdown
            align="right"
            trigger={
              <button className="p-2 rounded transition-colors text-dark-text-muted hover:bg-dark-surface">
                <MoreHorizontal size={18} />
              </button>
            }
          >
            {!projectId && (
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
                    board?.starred ? "fill-yellow-400 text-yellow-400" : ""
                  }
                />
                {board?.starred ? "Unstar" : "Star"}
              </span>
            </DropdownItem>
            <DropdownItem
              variant="danger"
              onClick={() => setShowDeleteConfirm(true)}
            >
              <span className="flex items-center gap-2">
                <Trash2 size={16} />
                Delete Board
              </span>
            </DropdownItem>
          </Dropdown>
        </div>
      </div>

      {viewMode === "board" ? renderBoardView() : renderTableView()}

      {/* Task Detail Modal */}
      {selectedTask && (
        <TaskDetailModal
          task={selectedTask}
          childTasks={taskChildTasks}
          comments={messages[`task:${taskParam}`] || []}
          statuses={board?.statuses || []}
          workspaceMembers={workspaceMembers}
          onClose={handleCloseTask}
          onChildTaskClick={handleChildTaskClick}
          highlightCommentId={!subtaskParam ? highlightCommentId : null}
        />
      )}

      {/* Child Task Detail Modal */}
      {selectedChildTask && selectedTask && (
        <ChildTaskDetailModal
          task={selectedChildTask}
          parentTask={selectedTask}
          comments={childTaskMessages}
          workspaceMembers={workspaceMembers}
          onClose={handleCloseChildTask}
          highlightCommentId={subtaskParam ? highlightCommentId : null}
        />
      )}

      {/* Add Task Modal */}
      {isAddingTask && (
        <Modal
          title="Add Task"
          onClose={() => setIsAddingTask(false)}
          className="w-96"
        >
          <div className="p-6">
            <input
              type="text"
              value={newTaskTitle}
              onChange={(e) => setNewTaskTitle(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") handleCreateTask();
                if (e.key === "Escape") setIsAddingTask(false);
              }}
              placeholder="Task title"
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 mb-4"
              autoFocus
            />
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setIsAddingTask(false)}
                className="px-4 py-2 text-dark-text-muted hover:text-dark-text transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleCreateTask}
                disabled={!newTaskTitle.trim()}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Add Task
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Status Manager Modal */}
      {isStatusManagerOpen && board && (
        <StatusManager
          boardId={board.id}
          statuses={board.statuses || []}
          tasks={boardTasks}
          onClose={() => setIsStatusManagerOpen(false)}
        />
      )}

      {/* Delete Confirmation Modal */}
      <ConfirmModal
        isOpen={showDeleteConfirm}
        title="Delete Board"
        message={`Are you sure you want to delete "${board?.name}"? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={handleDeleteBoard}
        onCancel={() => setShowDeleteConfirm(false)}
      />

      {/* Members Modal (standalone items only, not project items) */}
      {!projectId && boardId && (
        <ManageMembersModal
          itemKind="list"
          itemId={boardId}
          isOpen={showMembersModal}
          onClose={() => setShowMembersModal(false)}
        />
      )}
    </div>
  );
}
