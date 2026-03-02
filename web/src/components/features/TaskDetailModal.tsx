import { useState, useRef, useEffect } from "react";
import {
  X,
  Quote,
  ChevronDown,
  CheckSquare,
  Square,
  Trash2,
  Check,
  Star,
} from "lucide-react";
import { format } from "date-fns";
import { Avatar } from "@/components/ui/Avatar";
import { Modal } from "@/components/ui/Modal";
import { Message } from "./Message";
import { DiscussionThread } from "./DiscussionThread";
import { CommentEditor } from "./CommentEditor";
import { RichTextNotesEditor } from "@/components/ui/RichTextNotesEditor";
import {
  Task,
  BoardStatus,
  Message as MessageType,
  User,
} from "@/types";
import { useBoardStore } from "@/stores/boardStore";
import { useChatStore } from "@/stores/chatStore";
import { useToastStore } from "@/stores/toastStore";
import { clsx } from "clsx";

interface TaskDetailModalProps {
  task: Task;
  childTasks: Task[];
  comments: MessageType[];
  statuses: BoardStatus[];
  workspaceMembers?: User[];
  onClose: () => void;
  onChildTaskClick?: (childTaskId: string) => void;
  highlightCommentId?: string | null;
}

export function TaskDetailModal({
  task,
  childTasks,
  comments,
  statuses,
  workspaceMembers = [],
  onClose,
  onChildTaskClick,
  highlightCommentId,
}: TaskDetailModalProps) {
  const [openThread, setOpenThread] = useState<MessageType | null>(null);
  const [newComment, setNewComment] = useState("");
  const [quotingMessage, setQuotingMessage] = useState<MessageType | null>(
    null,
  );
  const [newChildTask, setNewChildTask] = useState("");
  const [isAddingChildTask, setIsAddingChildTask] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [isStatusDropdownOpen, setIsStatusDropdownOpen] = useState(false);
  const [isAssigneeDropdownOpen, setIsAssigneeDropdownOpen] = useState(false);
  const [childTaskToDelete, setChildTaskToDelete] = useState<Task | null>(null);
  const [isDeleteTaskModalOpen, setIsDeleteTaskModalOpen] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState(task.title);
  const commentEditorRef = useRef<HTMLTextAreaElement>(null);
  const childTaskInputRef = useRef<HTMLInputElement>(null);
  const titleInputRef = useRef<HTMLInputElement>(null);
  const commentsEndRef = useRef<HTMLDivElement>(null);
  const {
    updateTask,
    updateChildTask,
    createChildTask,
    deleteChildTask,
    deleteTask,
    toggleTaskStar,
  } = useBoardStore();
  const { sendMessage, fetchMessages, hasMoreMessages } = useChatStore();
  const { error: toastError } = useToastStore();

  const sortedStatuses = [...statuses].sort((a, b) => a.position - b.position);
  const currentStatus = sortedStatuses.find((s) => s.id === task.statusId);
  const selectedAssignee = workspaceMembers.find(
    (m) => m.id === task.assigneeId,
  );

  // Calculate checklist progress
  const completedCount = childTasks.filter((s) => s.isCompleted).length;
  const totalCount = childTasks.length;
  const progressPercent =
    totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

  // Close on escape key (only when thread is not open)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !openThread && !editingTitle) {
        onClose();
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [onClose, openThread, editingTitle]);

  // Focus title input when editing
  useEffect(() => {
    if (editingTitle && titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, [editingTitle]);

  // Scroll to and highlight comment if highlightCommentId is provided
  useEffect(() => {
    if (highlightCommentId && comments.length > 0) {
      // Small delay to ensure the DOM is rendered
      setTimeout(() => {
        const messageElement = document.getElementById(
          `task-message-${highlightCommentId}`,
        );
        if (messageElement) {
          messageElement.scrollIntoView({
            behavior: "smooth",
            block: "center",
          });
          messageElement.classList.add(
            "ring-2",
            "ring-blue-500/50",
            "bg-blue-500/10",
          );
          setTimeout(() => {
            messageElement.classList.remove(
              "ring-2",
              "ring-blue-500/50",
              "bg-blue-500/10",
            );
          }, 3000);
        }
      }, 300);
    }
  }, [highlightCommentId, comments]);

  const handleTitleSave = async () => {
    if (titleValue.trim() && titleValue !== task.title) {
      await updateTask(task.id, { title: titleValue.trim() });
    } else {
      setTitleValue(task.title);
    }
    setEditingTitle(false);
  };

  const handleStatusChange = async (statusId: string) => {
    setIsStatusDropdownOpen(false);
    await updateTask(task.id, { statusId });
  };

  const handleAssigneeChange = async (assigneeId: string | null) => {
    setIsAssigneeDropdownOpen(false);
    await updateTask(task.id, { assigneeId });
  };

  const handleDueDateChange = async (dueOn: string | null) => {
    await updateTask(task.id, { dueOn });
  };

  const handleSaveNotes = async (notes: string) => {
    await updateTask(task.id, { notes });
  };

  const handleChildTaskToggle = async (child: Task) => {
    await updateChildTask(child.id, task.id, { isCompleted: !child.isCompleted });
  };

  const handleAddChildTask = async () => {
    if (!newChildTask.trim()) return;
    await createChildTask(task.id, { title: newChildTask, isCompleted: false });
    setNewChildTask("");
    childTaskInputRef.current?.focus();
  };

  const handleDeleteChildTask = async () => {
    if (!childTaskToDelete) return;
    await deleteChildTask(childTaskToDelete.id, task.id);
    setChildTaskToDelete(null);
  };

  const handleDeleteTask = async () => {
    await deleteTask(task.id);
    setIsDeleteTaskModalOpen(false);
    onClose();
  };

  const handleStartAddingChildTask = () => {
    setIsAddingChildTask(true);
    setTimeout(() => {
      childTaskInputRef.current?.focus();
    }, 50);
  };

  const handleCancelAddingChildTask = () => {
    setIsAddingChildTask(false);
    setNewChildTask("");
  };

  const handleAddComment = async () => {
    // Check for empty content - strip HTML tags to check actual text
    const textContent = newComment.replace(/<[^>]*>/g, "").trim();
    if (!textContent) return;
    await sendMessage(
      "task",
      task.id,
      newComment,
      undefined,
      quotingMessage?.id,
    );
    setNewComment("");
    setQuotingMessage(null);
    // Scroll to bottom after comment is added
    setTimeout(() => {
      commentsEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, 100);
  };

  const handleQuote = (message: MessageType) => {
    setQuotingMessage(message);
    setTimeout(() => {
      commentEditorRef.current?.focus();
    }, 100);
  };

  const handleQuotedClick = (messageId: string) => {
    const messageElement = document.getElementById(`task-message-${messageId}`);
    if (messageElement) {
      messageElement.scrollIntoView({ behavior: "smooth", block: "center" });
      messageElement.classList.add("ring-2", "ring-blue-500/50");
      setTimeout(() => {
        messageElement.classList.remove("ring-2", "ring-blue-500/50");
      }, 2000);
    }
  };

  const sortedComments = [...comments].reverse();
  const topLevelComments = sortedComments.filter((c) => !c.parentId);
  const threadMessages = sortedComments.filter((c) => c.parentId);

  const getThreadReplies = (messageId: string) => {
    return threadMessages.filter((m) => m.parentId === messageId);
  };

  const handleLoadMore = async () => {
    if (isLoadingMore) return;
    setIsLoadingMore(true);
    try {
      await fetchMessages("task", task.id, true);
    } finally {
      setIsLoadingMore(false);
    }
  };

  return (
    <>
    <Modal onClose={onClose} size="full" variant="bg" showCloseButton={false}>
      {/* Header */}
      <div className="px-6 py-4 border-b border-dark-border flex items-start justify-between flex-shrink-0">
        <div className="flex-1 pr-4">
          {editingTitle ? (
            <div className="flex items-center gap-2 mb-2">
              <input
                ref={titleInputRef}
                type="text"
                value={titleValue}
                onChange={(e) => setTitleValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    handleTitleSave();
                  } else if (e.key === "Escape") {
                    setTitleValue(task.title);
                    setEditingTitle(false);
                  }
                }}
                className="flex-1 text-xl font-semibold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none pb-1"
              />
              <button
                onClick={handleTitleSave}
                className="p-1.5 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
                title="Save title"
              >
                <Check size={18} />
              </button>
            </div>
          ) : (
            <div className="mb-2">
              {task.key && (
                <span className="text-xs font-mono text-dark-text-muted block mb-1">
                  {task.key}
                </span>
              )}
              <h2
                onClick={() => setEditingTitle(true)}
                className="text-xl font-semibold text-dark-text cursor-pointer hover:text-blue-400 transition-colors"
                title="Click to edit"
              >
                {task.title}
              </h2>
            </div>
          )}
          {task.createdBy && (
            <div className="text-sm text-dark-text-muted">
              Added by {task.createdBy.name} on{" "}
              {format(new Date(task.insertedAt), "MMM d, yyyy")}
            </div>
          )}
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => toggleTaskStar(task.id)}
            className="text-dark-text-muted hover:text-yellow-400 transition-colors p-1 hover:bg-dark-surface rounded"
            title={task.starred ? "Unstar" : "Star"}
          >
            <Star
              size={18}
              className={task.starred ? "fill-yellow-400 text-yellow-400" : ""}
            />
          </button>
          <button
            onClick={() => setIsDeleteTaskModalOpen(true)}
            className="text-dark-text-muted hover:text-red-400 transition-colors p-1 hover:bg-dark-surface rounded"
            title="Delete task"
          >
            <Trash2 size={18} />
          </button>
          <button
            onClick={onClose}
            className="text-dark-text-muted hover:text-dark-text transition-colors p-1 hover:bg-dark-surface rounded"
          >
            <X size={20} />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
          {/* Task Details Section */}
          <div className="px-6 py-4 border-b border-dark-border space-y-4">
            {/* Status Row */}
            <div className="flex items-start gap-6">
              <label className="w-24 flex-shrink-0 text-sm font-medium text-dark-text text-right pt-2">
                Status
              </label>
              <div className="flex-1 relative">
                <div className="flex items-center gap-2">
                  {currentStatus && (
                    <div
                      className="w-3 h-3 rounded-full flex-shrink-0"
                      style={{ backgroundColor: currentStatus.color }}
                    />
                  )}
                  <button
                    onClick={() =>
                      setIsStatusDropdownOpen(!isStatusDropdownOpen)
                    }
                    className="flex items-center gap-2 px-3 py-1.5 bg-dark-surface border border-dark-border rounded text-sm hover:border-dark-text-muted transition-colors"
                  >
                    <span className="text-dark-text">
                      {currentStatus?.name || "Select status"}
                    </span>
                    <ChevronDown
                      size={14}
                      className={clsx(
                        "text-dark-text-muted transition-transform",
                        isStatusDropdownOpen && "rotate-180",
                      )}
                    />
                  </button>
                </div>
                {isStatusDropdownOpen && (
                  <div className="absolute z-10 mt-1 bg-dark-surface border border-dark-border rounded-lg shadow-lg overflow-hidden">
                    {sortedStatuses.map((status) => (
                      <button
                        key={status.id}
                        onClick={() => handleStatusChange(status.id)}
                        className={clsx(
                          "w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-dark-border transition-colors",
                          task.statusId === status.id && "bg-dark-border",
                        )}
                      >
                        <div
                          className="w-3 h-3 rounded-full"
                          style={{ backgroundColor: status.color }}
                        />
                        <span className="text-dark-text">{status.name}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Assignee Row */}
            <div className="flex items-start gap-6">
              <label className="w-24 flex-shrink-0 text-sm font-medium text-dark-text text-right pt-2">
                Assigned to
              </label>
              <div className="flex-1 relative">
                <button
                  onClick={() =>
                    setIsAssigneeDropdownOpen(!isAssigneeDropdownOpen)
                  }
                  className="flex items-center gap-2 text-sm hover:text-blue-400 transition-colors py-1.5"
                >
                  {selectedAssignee ? (
                    <>
                      <Avatar name={selectedAssignee.name} size="xs" />
                      <span className="text-dark-text">
                        {selectedAssignee.name}
                      </span>
                    </>
                  ) : (
                    <span className="text-dark-text-muted">
                      Type names to assign...
                    </span>
                  )}
                </button>
                {isAssigneeDropdownOpen && (
                  <div className="absolute z-10 mt-1 bg-dark-surface border border-dark-border rounded-lg shadow-lg overflow-hidden max-h-48 overflow-y-auto min-w-[200px]">
                    <button
                      onClick={() => handleAssigneeChange(null)}
                      className={clsx(
                        "w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-dark-border transition-colors",
                        !task.assigneeId && "bg-dark-border",
                      )}
                    >
                      <span className="text-dark-text-muted">Unassigned</span>
                    </button>
                    {workspaceMembers.map((member) => (
                      <button
                        key={member.id}
                        onClick={() => handleAssigneeChange(member.id)}
                        className={clsx(
                          "w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-dark-border transition-colors",
                          task.assigneeId === member.id && "bg-dark-border",
                        )}
                      >
                        <Avatar name={member.name} size="xs" />
                        <span className="text-dark-text">{member.name}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Due Date Row */}
            <div className="flex items-start gap-6">
              <label className="w-24 flex-shrink-0 text-sm font-medium text-dark-text text-right pt-2">
                Due on
              </label>
              <div className="flex-1 flex items-center gap-2">
                <input
                  type="date"
                  value={task.dueOn || ""}
                  onChange={(e) => handleDueDateChange(e.target.value || null)}
                  className={clsx(
                    "px-2 py-1.5 bg-transparent border-none text-sm focus:outline-none cursor-pointer [&::-webkit-calendar-picker-indicator]:invert",
                    task.dueOn
                      ? "text-dark-text"
                      : "text-dark-text-muted [&::-webkit-datetime-edit]:text-dark-text-muted",
                  )}
                />
                {task.dueOn && (
                  <button
                    onClick={() => handleDueDateChange(null)}
                    className="text-dark-text-muted hover:text-red-400 transition-colors p-1"
                    title="Clear due date"
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            </div>

            {/* Notes Row */}
            <div className="flex items-start gap-6">
              <label className="w-24 flex-shrink-0 text-sm font-medium text-dark-text text-right pt-2">
                Notes
              </label>
              <div className="flex-1">
                <RichTextNotesEditor
                  value={task.notes || ""}
                  onSave={handleSaveNotes}
                  placeholder="Add notes..."
                  fileUpload={{
                    attachableType: "task",
                    attachableId: task.id,
                    onError: (msg) => toastError(msg),
                  }}
                />
              </div>
            </div>

          </div>

          {/* Subtasks Section */}
          <div className="px-6 py-4 border-b border-dark-border">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <CheckSquare size={16} className="text-dark-text-muted" />
                <h3 className="text-sm font-medium text-dark-text">Subtasks</h3>
              </div>
              {totalCount > 0 && (
                <span className="text-xs text-dark-text-muted">
                  {completedCount}/{totalCount}
                </span>
              )}
            </div>

            {totalCount > 0 && (
              <div className="mb-3">
                <div className="h-2 bg-dark-surface rounded-full overflow-hidden">
                  <div
                    className={clsx(
                      "h-full transition-all duration-300 rounded-full",
                      progressPercent === 100 ? "bg-green-500" : "bg-blue-500",
                    )}
                    style={{ width: `${progressPercent}%` }}
                  />
                </div>
              </div>
            )}

            <div className="space-y-1">
              {childTasks.map((child) => (
                <div
                  key={child.id}
                  className="group flex items-start gap-2 py-1.5 px-1 -mx-1 rounded hover:bg-dark-surface transition-colors"
                >
                  <button
                    onClick={() => handleChildTaskToggle(child)}
                    className="flex-shrink-0 mt-0.5 text-dark-text-muted hover:text-dark-text transition-colors"
                  >
                    {child.isCompleted ? (
                      <CheckSquare size={18} className="text-green-500" />
                    ) : (
                      <Square size={18} />
                    )}
                  </button>
                  <button
                    onClick={() => onChildTaskClick?.(child.id)}
                    className={clsx(
                      "flex-1 text-sm leading-relaxed text-left hover:text-blue-400 transition-colors",
                      child.isCompleted
                        ? "text-dark-text-muted line-through"
                        : "text-dark-text",
                    )}
                  >
                    {child.key && (
                      <span className="text-xs font-mono text-dark-text-muted mr-1.5">
                        {child.key}
                      </span>
                    )}
                    {child.title}
                  </button>
                  <button
                    onClick={() => setChildTaskToDelete(child)}
                    className="flex-shrink-0 opacity-0 group-hover:opacity-100 p-1 text-dark-text-muted hover:text-red-400 transition-all"
                    title="Delete item"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              ))}
            </div>

            {isAddingChildTask ? (
              <div className="mt-2">
                <input
                  ref={childTaskInputRef}
                  type="text"
                  value={newChildTask}
                  onChange={(e) => setNewChildTask(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && newChildTask.trim()) {
                      handleAddChildTask();
                    } else if (e.key === "Escape") {
                      handleCancelAddingChildTask();
                    }
                  }}
                  placeholder="Add a subtask..."
                  className="w-full px-3 py-2 bg-dark-surface border border-dark-border rounded-lg text-sm text-dark-text placeholder:text-dark-text-muted focus:outline-none focus:border-blue-500"
                />
                <div className="flex items-center gap-2 mt-2">
                  <button
                    onClick={handleAddChildTask}
                    disabled={!newChildTask.trim()}
                    className="px-3 py-1.5 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  >
                    Add
                  </button>
                  <button
                    onClick={handleCancelAddingChildTask}
                    className="px-3 py-1.5 text-dark-text-muted text-sm hover:text-dark-text transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={handleStartAddingChildTask}
                className="mt-2 text-sm text-dark-text-muted hover:text-dark-text transition-colors"
              >
                + Add a subtask
              </button>
            )}
          </div>

          {/* Comments Section */}
          <div className="px-6 py-4">
            {topLevelComments.length > 0 ? (
              <>
                <h3 className="text-sm font-medium text-dark-text mb-3">
                  Comments ({topLevelComments.length})
                </h3>
                {hasMoreMessages("task", task.id) && (
                  <div className="mb-4 flex justify-center">
                    <button
                      onClick={handleLoadMore}
                      disabled={isLoadingMore}
                      className="px-4 py-2 text-sm text-blue-400 hover:text-blue-300 hover:bg-dark-surface rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {isLoadingMore ? "Loading..." : "Load older comments"}
                    </button>
                  </div>
                )}
                <div className="space-y-1 mb-4">
                  {topLevelComments.map((comment) => {
                    const replies = getThreadReplies(comment.id);
                    return (
                      <div key={comment.id} id={`task-message-${comment.id}`}>
                        <Message
                          message={comment}
                          onReply={() => setOpenThread(comment)}
                          onQuote={() => handleQuote(comment)}
                          onQuotedClick={handleQuotedClick}
                          fileUpload={{
                            attachableType: "task",
                            attachableId: task.id,
                            onError: (msg) => toastError(msg),
                          }}
                        />
                        {replies.length > 0 && (
                          <button
                            onClick={() => setOpenThread(comment)}
                            className="ml-14 text-xs text-blue-400 hover:underline"
                          >
                            {replies.length}{" "}
                            {replies.length === 1 ? "reply" : "replies"}
                          </button>
                        )}
                      </div>
                    );
                  })}
                  <div ref={commentsEndRef} />
                </div>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center py-8 text-center mb-4">
                <div className="w-12 h-12 rounded-full bg-dark-surface flex items-center justify-center mb-3">
                  <Quote size={20} className="text-dark-text-muted" />
                </div>
                <p className="text-dark-text-muted text-sm">
                  No comments yet. Be the first to add one below.
                </p>
              </div>
            )}
          </div>

      </div>

      {/* Comment Editor - Fixed at bottom */}
      <div className="border-t border-dark-border p-4 flex-shrink-0">
        <CommentEditor
          ref={commentEditorRef}
          value={newComment}
          onChange={setNewComment}
          onSubmit={handleAddComment}
          placeholder="Add a comment..."
          quotingMessage={quotingMessage}
          onCancelQuote={() => setQuotingMessage(null)}
          fileUpload={{
            attachableType: "task",
            attachableId: task.id,
            onError: (msg) => toastError(msg),
          }}
        />
      </div>
    </Modal>

    {/* Thread Panel - Fixed overlay above modal */}
    {openThread && (
      <div className="fixed inset-0 z-[60] flex">
        <div className="flex-1 bg-black/20" onClick={() => setOpenThread(null)} />
        <DiscussionThread
          parentMessage={openThread}
          threadMessages={threadMessages}
          onClose={() => setOpenThread(null)}
          onSendReply={async (parentId, text, quoteId) => {
            await sendMessage("task", task.id, text, parentId, quoteId);
          }}
          fileUpload={{
            attachableType: "task",
            attachableId: task.id,
            onError: (msg) => toastError(msg),
          }}
        />
      </div>
    )}

    {/* Delete Child Task Confirmation Modal */}
    {childTaskToDelete && (
      <Modal
        title="Delete item?"
        onClose={() => setChildTaskToDelete(null)}
        size="sm"
        zIndex={60}
      >
        <div className="p-6">
          <p className="text-sm text-dark-text-muted mb-4">
            Are you sure you want to delete "{childTaskToDelete.title}"? This
            action cannot be undone.
          </p>
          <div className="flex justify-end gap-2">
            <button
              onClick={() => setChildTaskToDelete(null)}
              className="px-4 py-2 text-dark-text-muted hover:text-dark-text transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleDeleteChildTask}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              Delete
            </button>
          </div>
        </div>
      </Modal>
    )}

    {/* Delete Task Confirmation Modal */}
    {isDeleteTaskModalOpen && (
      <Modal
        title="Delete task?"
        onClose={() => setIsDeleteTaskModalOpen(false)}
        size="sm"
        zIndex={60}
      >
        <div className="p-6">
          <p className="text-sm text-dark-text-muted mb-4">
            Are you sure you want to delete "{task.title}"? This will also
            delete all subtasks and comments. This action cannot be undone.
          </p>
          <div className="flex justify-end gap-2">
            <button
              onClick={() => setIsDeleteTaskModalOpen(false)}
              className="px-4 py-2 text-dark-text-muted hover:text-dark-text transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleDeleteTask}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              Delete
            </button>
          </div>
        </div>
      </Modal>
    )}
    </>
  );
}
