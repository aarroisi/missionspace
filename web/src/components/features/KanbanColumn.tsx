import { useDroppable } from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { ChevronsRightLeft, Plus } from "lucide-react";
import { SortableTaskCard } from "./SortableTaskCard";
import { Task } from "@/types";
import { clsx } from "clsx";

interface KanbanColumnProps {
  id: string;
  title: string;
  color: string;
  tasks: Task[];
  onTaskClick: (taskId: string) => void;
  onAddTask: (statusId: string) => void;
  selectedTaskId: string | null;
  isHighlighted?: boolean;
  isFirstColumn?: boolean;
  isCollapsed?: boolean;
  onToggleCollapse?: () => void;
  dropPlaceholderIndex?: number | null;
}

export function KanbanColumn({
  id,
  title,
  color,
  tasks,
  onTaskClick,
  onAddTask,
  selectedTaskId,
  isHighlighted = false,
  isFirstColumn = false,
  isCollapsed = false,
  onToggleCollapse,
  dropPlaceholderIndex,
}: KanbanColumnProps) {
  const { setNodeRef } = useDroppable({ id });

  // Create a subtle background color from the status color (20% opacity)
  const bgStyle = {
    backgroundColor: isHighlighted ? undefined : `${color}33`,
  };

  // Collapsed view - vertical sidebar (matches DoneColumn styling)
  if (isCollapsed) {
    return (
      <div
        ref={setNodeRef}
        className={clsx(
          "flex-shrink-0 w-16 flex flex-col items-center py-4 rounded-lg transition-colors cursor-pointer hover:brightness-110",
          isHighlighted && "bg-blue-500/10",
        )}
        style={bgStyle}
        onClick={onToggleCollapse}
        data-testid={`column-${title.toLowerCase()}`}
      >
        <div className="text-dark-text-muted font-medium text-lg mb-2">
          ({tasks.length})
        </div>
        <div
          className="text-dark-text-muted text-xs font-semibold tracking-wider"
          style={{ writingMode: "vertical-rl", textOrientation: "mixed" }}
        >
          {title.toUpperCase()}
        </div>
      </div>
    );
  }

  return (
    <div
      ref={setNodeRef}
      className={clsx(
        "flex-shrink-0 w-80 flex flex-col px-2 py-4 rounded-lg transition-colors",
        isHighlighted && "bg-blue-500/10",
      )}
      style={bgStyle}
      data-testid={`column-${title.toLowerCase()}`}
    >
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-1">
          {onToggleCollapse && (
            <button
              onClick={onToggleCollapse}
              className="text-dark-text-muted hover:text-dark-text p-1 rounded hover:bg-dark-surface transition-colors"
              title="Collapse column"
            >
              <ChevronsRightLeft size={16} />
            </button>
          )}
          <h3 className="font-semibold text-dark-text">
            {title}{" "}
            <span className="text-dark-text-muted font-normal">
              ({tasks.length})
            </span>
          </h3>
        </div>
        <button
          onClick={() => onAddTask(id)}
          className="text-dark-text-muted hover:text-dark-text p-1 rounded hover:bg-dark-surface transition-colors"
        >
          <Plus size={16} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto space-y-2 p-1">
        <SortableContext
          id={id}
          items={tasks.map((t) => t.id)}
          strategy={verticalListSortingStrategy}
        >
          {tasks.map((task, index) => (
            <div key={task.id}>
              {dropPlaceholderIndex === index && (
                <div className="h-16 mb-2 rounded-lg border-2 border-dashed border-blue-400 bg-blue-400/10" />
              )}
              <SortableTaskCard
                task={task}
                onClick={() => onTaskClick(task.id)}
                isSelected={selectedTaskId === task.id}
              />
            </div>
          ))}
          {dropPlaceholderIndex != null &&
            dropPlaceholderIndex >= tasks.length && (
              <div className="h-16 rounded-lg border-2 border-dashed border-blue-400 bg-blue-400/10" />
            )}
        </SortableContext>

        {isFirstColumn && (
          <button
            onClick={() => onAddTask(id)}
            className="w-full py-2 px-3 text-sm text-dark-text-muted hover:text-dark-text hover:bg-dark-surface/50 rounded-lg border border-dashed border-dark-border/50 hover:border-dark-border transition-colors flex items-center justify-center gap-2"
          >
            <Plus size={14} />
            <span>Add task</span>
          </button>
        )}
      </div>
    </div>
  );
}
