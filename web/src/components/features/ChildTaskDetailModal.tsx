import { useState, useRef, useEffect } from "react";
import {
  X,
  Quote,
  CheckSquare,
  Square,
  Trash2,
  Check,
  Star,
  ArrowLeft,
} from "lucide-react";
import { Avatar } from "@/components/ui/Avatar";
import { Modal } from "@/components/ui/Modal";
import { Message } from "./Message";
import { DiscussionThread } from "./DiscussionThread";
import { CommentEditor } from "./CommentEditor";
import { RichTextNotesEditor } from "@/components/ui/RichTextNotesEditor";
import {
  Task,
  Message as MessageType,
  User,
} from "@/types";
import { useBoardStore } from "@/stores/boardStore";
import { useChatStore } from "@/stores/chatStore";
import { useToastStore } from "@/stores/toastStore";
import { SubscriptionSection } from "./SubscriptionSection";
import { clsx } from "clsx";

interface ChildTaskDetailModalProps {
  task: Task;
  parentTask: Task;
  comments: MessageType[];
  workspaceMembers?: User[];
  onClose: () => void;
  highlightCommentId?: string | null;
}

export function ChildTaskDetailModal({
  task,
  parentTask,
  comments,
  workspaceMembers = [],
  onClose,
  highlightCommentId,
}: ChildTaskDetailModalProps) {
  const [openThread, setOpenThread] = useState<MessageType | null>(null);
  const [newComment, setNewComment] = useState("");
  const [quotingMessage, setQuotingMessage] = useState<MessageType | null>(
    null,
  );
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [isAssigneeDropdownOpen, setIsAssigneeDropdownOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState(task.title);
  const commentEditorRef = useRef<HTMLTextAreaElement>(null);
  const titleInputRef = useRef<HTMLInputElement>(null);
  const commentsEndRef = useRef<HTMLDivElement>(null);
  const { updateChildTask, deleteChildTask, toggleTaskStar } = useBoardStore();
  const { sendMessage, fetchMessages, hasMoreMessages } = useChatStore();
  const { error: toastError } = useToastStore();

  const selectedAssignee = workspaceMembers.find(
    (m) => m.id === task.assigneeId,
  );

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

  // Scroll to highlighted comment
  useEffect(() => {
    if (highlightCommentId && comments.length > 0) {
      setTimeout(() => {
        const el = document.getElementById(
          `child-task-message-${highlightCommentId}`,
        );
        if (el) {
          el.scrollIntoView({ behavior: "smooth", block: "center" });
          el.classList.add("ring-2", "ring-blue-500/50", "bg-blue-500/10");
          setTimeout(() => {
            el.classList.remove(
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
      await updateChildTask(task.id, parentTask.id, {
        title: titleValue.trim(),
      });
    } else {
      setTitleValue(task.title);
    }
    setEditingTitle(false);
  };

  const handleToggleCompletion = async () => {
    await updateChildTask(task.id, parentTask.id, {
      isCompleted: !task.isCompleted,
    });
  };

  const handleAssigneeChange = async (assigneeId: string | null) => {
    setIsAssigneeDropdownOpen(false);
    await updateChildTask(task.id, parentTask.id, { assigneeId });
  };

  const handleDueDateChange = async (dueOn: string | null) => {
    await updateChildTask(task.id, parentTask.id, { dueOn });
  };

  const handleSaveNotes = async (notes: string) => {
    await updateChildTask(task.id, parentTask.id, { notes });
  };

  const handleDelete = async () => {
    await deleteChildTask(task.id, parentTask.id);
    setIsDeleteModalOpen(false);
    onClose();
  };

  const handleAddComment = async () => {
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
    const el = document.getElementById(`child-task-message-${messageId}`);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "center" });
      el.classList.add("ring-2", "ring-blue-500/50");
      setTimeout(() => {
        el.classList.remove("ring-2", "ring-blue-500/50");
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
      <Modal
        onClose={onClose}
        size="3xl"
        variant="bg"
        showCloseButton={false}
        zIndex={55}
        maxHeight="calc(100vh - 4rem)"
      >
        {/* Header */}
        <div className="px-6 py-4 border-b border-dark-border flex items-start justify-between flex-shrink-0">
          <div className="flex-1 pr-4">
            {/* Parent link */}
            <button
              onClick={onClose}
              className="flex items-center gap-1.5 mb-2 text-xs text-dark-text-muted hover:text-blue-400 transition-colors"
            >
              <ArrowLeft size={14} />
              {parentTask.key && (
                <span className="font-mono">{parentTask.key}</span>
              )}
              <span className="truncate max-w-[300px]">
                {parentTask.title}
              </span>
            </button>

            {editingTitle ? (
              <div className="flex items-center gap-2 mb-1">
                <input
                  ref={titleInputRef}
                  type="text"
                  value={titleValue}
                  onChange={(e) => setTitleValue(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") handleTitleSave();
                    else if (e.key === "Escape") {
                      setTitleValue(task.title);
                      setEditingTitle(false);
                    }
                  }}
                  className="flex-1 text-lg font-semibold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none pb-1"
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
              <div className="mb-1">
                {task.key && (
                  <span className="text-xs font-mono text-dark-text-muted block mb-1">
                    {task.key}
                  </span>
                )}
                <div className="flex items-center gap-2">
                  <button
                    onClick={handleToggleCompletion}
                    className="flex-shrink-0 text-dark-text-muted hover:text-dark-text transition-colors"
                  >
                    {task.isCompleted ? (
                      <CheckSquare size={20} className="text-green-500" />
                    ) : (
                      <Square size={20} />
                    )}
                  </button>
                  <h2
                    onClick={() => setEditingTitle(true)}
                    className={clsx(
                      "text-lg font-semibold cursor-pointer hover:text-blue-400 transition-colors",
                      task.isCompleted
                        ? "text-dark-text-muted line-through"
                        : "text-dark-text",
                    )}
                    title="Click to edit"
                  >
                    {task.title}
                  </h2>
                </div>
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
              onClick={() => setIsDeleteModalOpen(true)}
              className="text-dark-text-muted hover:text-red-400 transition-colors p-1 hover:bg-dark-surface rounded"
              title="Delete subtask"
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
          {/* Details Section */}
          <div className="px-6 py-4 border-b border-dark-border space-y-4">
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
                  onChange={(e) =>
                    handleDueDateChange(e.target.value || null)
                  }
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

            {/* Subscribers Row */}
            <div className="flex items-center gap-6">
              <label className="w-24 flex-shrink-0 text-sm font-medium text-dark-text text-right">
                Watching
              </label>
              <SubscriptionSection itemType="task" itemId={task.id} />
            </div>
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
                      <div
                        key={comment.id}
                        id={`child-task-message-${comment.id}`}
                      >
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
              <div className="flex flex-col items-center justify-center py-6 text-center mb-4">
                <div className="w-10 h-10 rounded-full bg-dark-surface flex items-center justify-center mb-2">
                  <Quote size={16} className="text-dark-text-muted" />
                </div>
                <p className="text-dark-text-muted text-sm">
                  No comments yet.
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

      {/* Thread Panel */}
      {openThread && (
        <div className="fixed inset-0 z-[65] flex">
          <div
            className="flex-1 bg-black/20"
            onClick={() => setOpenThread(null)}
          />
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

      {/* Delete Confirmation Modal */}
      {isDeleteModalOpen && (
        <Modal
          title="Delete subtask?"
          onClose={() => setIsDeleteModalOpen(false)}
          size="sm"
          zIndex={65}
        >
          <div className="p-6">
            <p className="text-sm text-dark-text-muted mb-4">
              Are you sure you want to delete &quot;{task.title}&quot;? This
              action cannot be undone.
            </p>
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setIsDeleteModalOpen(false)}
                className="px-4 py-2 text-dark-text-muted hover:text-dark-text transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
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
