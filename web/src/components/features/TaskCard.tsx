import { Calendar, CheckSquare, MessageSquare, StickyNote, Star } from "lucide-react";
import { format } from "date-fns";
import { Avatar } from "@/components/ui/Avatar";
import { Task } from "@/types";
import { clsx } from "clsx";

interface TaskCardProps {
  task: Task;
  onClick: () => void;
  isSelected?: boolean;
  isDragging?: boolean;
}

export function TaskCard({
  task,
  onClick,
  isSelected,
  isDragging,
}: TaskCardProps) {
  return (
    <div
      onClick={onClick}
      className={clsx(
        "bg-dark-surface border border-dark-border rounded-lg px-3 pt-3 pb-2 cursor-pointer hover:border-blue-500 transition-colors",
        isSelected && "border-blue-500 ring-1 ring-blue-500",
        isDragging && "shadow-lg ring-2 ring-blue-500 opacity-90",
      )}
    >
      <div className="flex items-center justify-between mb-1">
        {task.key && (
          <span className="text-xs font-mono text-dark-text-muted">
            {task.key}
          </span>
        )}
        {task.starred && (
          <Star size={12} className="fill-yellow-400 text-yellow-400 ml-auto" />
        )}
      </div>
      <h4 className="font-medium text-dark-text text-sm mb-2">{task.title}</h4>

      <div className="flex items-center gap-3 text-xs text-dark-text-muted flex-wrap">
        {task.assignee && (
          <div className="flex items-center gap-1">
            <Avatar name={task.assignee.name} size="xs" />
            <span>{task.assignee.name}</span>
          </div>
        )}

        {task.dueOn && (
          <div className="flex items-center gap-1">
            <Calendar size={12} />
            <span>{format(new Date(task.dueOn), "MMM d")}</span>
          </div>
        )}

        {task.childCount > 0 && (
          <div
            className={clsx(
              "flex items-center gap-1",
              task.childDoneCount === task.childCount && "text-green-500",
            )}
          >
            <CheckSquare size={12} />
            <span>
              {task.childDoneCount}/{task.childCount}
            </span>
          </div>
        )}

        {task.commentCount > 0 && (
          <div className="flex items-center gap-1">
            <MessageSquare size={12} />
            <span>{task.commentCount}</span>
          </div>
        )}

        {task.notes && task.notes.replace(/<[^>]*>/g, "").trim() && (
          <span title="Has notes">
            <StickyNote size={12} />
          </span>
        )}
      </div>

      {task.createdBy && (
        <div className="text-[11px] text-dark-text-muted mt-2">
          Added by {task.createdBy.name} on{" "}
          {format(new Date(task.insertedAt), "MMM d")}
        </div>
      )}
    </div>
  );
}
