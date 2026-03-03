import { useState, useMemo, useEffect, useCallback } from "react";
import {
  DndContext,
  DragOverlay,
  closestCenter,
  pointerWithin,
  rectIntersection,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  DragStartEvent,
  DragEndEvent,
  DragOverEvent,
  CollisionDetection,
  getFirstCollision,
} from "@dnd-kit/core";
import { sortableKeyboardCoordinates } from "@dnd-kit/sortable";
import { KanbanColumn } from "./KanbanColumn";
import { TaskCard } from "./TaskCard";
import { BoardStatus, Task } from "@/types";
import { useBoardStore } from "@/stores/boardStore";

interface KanbanBoardProps {
  tasks: Task[];
  statuses: BoardStatus[];
  onTaskClick: (taskId: string) => void;
  onAddTask: (statusId: string) => void;
  selectedTaskId: string | null;
}

const COLLAPSED_COLUMNS_KEY = "kanban-collapsed-columns";

export function KanbanBoard({
  tasks,
  statuses,
  onTaskClick,
  onAddTask,
  selectedTaskId,
}: KanbanBoardProps) {
  const [activeTask, setActiveTask] = useState<Task | null>(null);
  const [activeTaskOriginalIndex, setActiveTaskOriginalIndex] = useState<
    number | null
  >(null);
  const [overStatusId, setOverStatusId] = useState<string | null>(null);
  const [dropIndex, setDropIndex] = useState<number | null>(null);
  const [collapsedColumns, setCollapsedColumns] = useState<Set<string>>(
    new Set(),
  );
  const { reorderTask } = useBoardStore();

  // Find the done status ID to default it to collapsed
  const doneStatusId = useMemo(() => {
    return statuses.find((s) => s.isDone)?.id;
  }, [statuses]);

  // Load collapsed state from localStorage on mount, defaulting done column to collapsed
  useEffect(() => {
    if (!doneStatusId) return;

    try {
      const saved = localStorage.getItem(COLLAPSED_COLUMNS_KEY);
      if (saved) {
        const parsed = new Set(JSON.parse(saved) as string[]);
        // Always add done column to collapsed set (user can expand it manually)
        parsed.add(doneStatusId);
        setCollapsedColumns(parsed);
      } else {
        // Default done column to collapsed
        setCollapsedColumns(new Set([doneStatusId]));
      }
    } catch {
      // Ignore parse errors, default to done collapsed
      setCollapsedColumns(new Set([doneStatusId]));
    }
  }, [doneStatusId]);

  // Save collapsed state to localStorage
  const saveCollapsedState = useCallback((columns: Set<string>) => {
    try {
      localStorage.setItem(COLLAPSED_COLUMNS_KEY, JSON.stringify([...columns]));
    } catch {
      // Ignore storage errors
    }
  }, []);

  const toggleColumnCollapse = useCallback(
    (statusId: string) => {
      setCollapsedColumns((prev) => {
        const next = new Set(prev);
        if (next.has(statusId)) {
          next.delete(statusId);
        } else {
          next.add(statusId);
        }
        saveCollapsedState(next);
        return next;
      });
    },
    [saveCollapsedState],
  );

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

  // Sort statuses by position, with done status always last
  const sortedStatusesWithDoneLast = useMemo(() => {
    const sorted = [...statuses].sort((a, b) => a.position - b.position);
    const done = sorted.find((s) => s.isDone);
    const regular = sorted.filter((s) => !s.isDone);
    return done ? [...regular, done] : regular;
  }, [statuses]);

  // For collision detection, we still need all statuses
  const sortedStatuses = useMemo(
    () => [...statuses].sort((a, b) => a.position - b.position),
    [statuses],
  );

  // Group tasks by statusId and sort by position
  const groupedTasks = useMemo(() => {
    const groups: Record<string, Task[]> = {};
    for (const status of sortedStatuses) {
      groups[status.id] = tasks
        .filter((t) => t.statusId === status.id)
        .sort((a, b) => a.position - b.position);
    }
    return groups;
  }, [tasks, sortedStatuses]);

  // Custom collision detection that works for both cross-column and within-column
  const collisionDetection: CollisionDetection = useCallback(
    (args) => {
      // First use closestCenter for sortable items (better for reordering)
      const closestCenterCollisions = closestCenter(args);

      // Check if we have a collision with a task
      const taskCollision = getFirstCollision(closestCenterCollisions, "id");
      if (
        taskCollision &&
        !sortedStatuses.some((s) => s.id === taskCollision)
      ) {
        // It's a task collision - use it for precise positioning
        return closestCenterCollisions;
      }

      // Use pointerWithin for column detection (cross-column moves)
      const pointerCollisions = pointerWithin(args);
      if (pointerCollisions.length > 0) {
        return pointerCollisions;
      }

      // Fallback to rect intersection
      return rectIntersection(args);
    },
    [sortedStatuses],
  );

  const handleDragStart = (event: DragStartEvent) => {
    const task = tasks.find((t) => t.id === event.active.id);
    setActiveTask(task || null);
    setOverStatusId(null);

    // Track the original index of the task in its column
    if (task) {
      const columnTasks = groupedTasks[task.statusId] || [];
      const originalIndex = columnTasks.findIndex((t) => t.id === task.id);
      setActiveTaskOriginalIndex(originalIndex);
    }
  };

  const handleDragOver = (event: DragOverEvent) => {
    const { active, over } = event;
    if (!over || !active) {
      setOverStatusId(null);
      setDropIndex(null);
      return;
    }

    const activeTask = tasks.find((t) => t.id === active.id);
    if (!activeTask) {
      setOverStatusId(null);
      setDropIndex(null);
      return;
    }

    const overId = over.id as string;
    let targetStatusId: string | null = null;
    let targetIndex: number | null = null;

    // Check if over a column directly
    const isColumnDrop = sortedStatuses.some((s) => s.id === overId);
    if (isColumnDrop) {
      targetStatusId = overId;
      // Dropping on empty column area - add to end
      targetIndex = groupedTasks[overId]?.length || 0;
    } else {
      // Over a task - find which column it belongs to
      const overTask = tasks.find((t) => t.id === overId);
      if (overTask) {
        targetStatusId = overTask.statusId;
        // Find the index of the task we're hovering over
        const columnTasks = groupedTasks[targetStatusId] || [];
        targetIndex = columnTasks.findIndex((t) => t.id === overId);
      } else {
        // Task not found - might be hovering over empty space or self
        // Try to get the droppable container from the over data
        const containerId = over.data?.current?.sortable?.containerId;
        if (containerId && sortedStatuses.some((s) => s.id === containerId)) {
          targetStatusId = containerId;
          targetIndex = groupedTasks[containerId]?.length || 0;
        }
      }
    }

    // Set target status and drop index for both cross-column and within-column
    if (targetStatusId) {
      // Only highlight column if moving to a different status
      if (targetStatusId !== activeTask.statusId) {
        setOverStatusId(targetStatusId);
      } else {
        setOverStatusId(null);
      }
      setDropIndex(targetIndex);
    } else {
      setOverStatusId(null);
      setDropIndex(null);
    }
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    const draggedTaskOriginalIndex = activeTaskOriginalIndex;

    setActiveTask(null);
    setActiveTaskOriginalIndex(null);
    setOverStatusId(null);
    setDropIndex(null);

    if (!over) return;

    const taskId = active.id as string;
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;

    // Determine target status and index
    let targetStatusId: string;
    let targetIndex: number;

    // Check if dropped on a column (status id)
    const isColumnDrop = sortedStatuses.some((s) => s.id === over.id);

    if (isColumnDrop) {
      // Dropped on column header/empty area
      targetStatusId = over.id as string;
      // For cross-column, count tasks without the dragged one
      const columnTasks = groupedTasks[targetStatusId] || [];
      if (task.statusId === targetStatusId) {
        // Same column - subtract 1 because task will be removed
        targetIndex = columnTasks.length - 1;
      } else {
        targetIndex = columnTasks.length;
      }
    } else {
      // Dropped on another task - insert at that task's position
      const overTask = tasks.find((t) => t.id === over.id);
      if (!overTask) return;

      targetStatusId = overTask.statusId;
      const columnTasks = groupedTasks[targetStatusId] || [];
      const overTaskIndex = columnTasks.findIndex((t) => t.id === over.id);

      // reorderTask expects index in the list WITHOUT the dragged task
      // So we need to adjust if dragging within same column and dropping after original position
      if (
        task.statusId === targetStatusId &&
        draggedTaskOriginalIndex !== null &&
        overTaskIndex > draggedTaskOriginalIndex
      ) {
        // The over task's index will shift down by 1 when dragged task is removed
        targetIndex = overTaskIndex - 1;
      } else {
        targetIndex = overTaskIndex;
      }
    }

    // Only reorder if something changed
    const currentColumnTasks = groupedTasks[task.statusId] || [];
    const currentIndex = currentColumnTasks.findIndex((t) => t.id === taskId);

    if (task.statusId !== targetStatusId || currentIndex !== targetIndex) {
      reorderTask(taskId, targetStatusId, targetIndex);
    }
  };

  return (
    <>
      <DndContext
        sensors={sensors}
        collisionDetection={collisionDetection}
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragEnd={handleDragEnd}
      >
        <div className="flex h-full">
          <div className="flex-1 flex overflow-x-auto gap-2 p-2">
            {sortedStatusesWithDoneLast.map((status, index) => {
              const isDragSource = activeTask?.statusId === status.id;
              const isCrossColumnDrag =
                activeTask &&
                overStatusId &&
                overStatusId !== activeTask.statusId;
              const isDragTarget = isCrossColumnDrag
                ? overStatusId === status.id
                : isDragSource;

              // Filter out the active task from the source column
              const columnTasks = groupedTasks[status.id] || [];
              const filteredTasks =
                isDragSource && activeTask
                  ? columnTasks.filter((t) => t.id !== activeTask.id)
                  : columnTasks;

              // Calculate the adjusted placeholder index for the filtered list
              let adjustedDropIndex: number | null = null;
              if (isDragTarget && dropIndex !== null) {
                if (isDragSource && !isCrossColumnDrag) {
                  // Within-column drag: adjust for removed task
                  // If dropping at or after original position, subtract 1
                  // because the task was removed from the list
                  if (
                    activeTaskOriginalIndex !== null &&
                    dropIndex > activeTaskOriginalIndex
                  ) {
                    adjustedDropIndex = dropIndex - 1;
                  } else {
                    adjustedDropIndex = dropIndex;
                  }
                } else {
                  // Cross-column drag: no adjustment needed
                  adjustedDropIndex = dropIndex;
                }
              }

              return (
                <KanbanColumn
                  key={status.id}
                  id={status.id}
                  title={status.name}
                  color={status.color}
                  tasks={filteredTasks}
                  onTaskClick={onTaskClick}
                  onAddTask={onAddTask}
                  selectedTaskId={selectedTaskId}
                  isHighlighted={
                    !!(isCrossColumnDrag && overStatusId === status.id)
                  }
                  isFirstColumn={index === 0}
                  isCollapsed={collapsedColumns.has(status.id)}
                  onToggleCollapse={() => toggleColumnCollapse(status.id)}
                  dropPlaceholderIndex={adjustedDropIndex}
                />
              );
            })}
          </div>
        </div>

        <DragOverlay>
          {activeTask ? (
            <TaskCard task={activeTask} onClick={() => {}} isDragging />
          ) : null}
        </DragOverlay>
      </DndContext>
    </>
  );
}
