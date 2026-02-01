import { useState, useRef, useEffect } from "react";
import { X, Quote, Trash2, Check, CheckSquare, Square } from "lucide-react";
import { format } from "date-fns";
import { Avatar } from "@/components/ui/Avatar";
import { Modal } from "@/components/ui/Modal";
import { Message } from "./Message";
import { DiscussionThread } from "./DiscussionThread";
import { CommentEditor } from "./CommentEditor";
import { RichTextNotesEditor } from "@/components/ui/RichTextNotesEditor";
import { Subtask, Message as MessageType, User } from "@/types";
import { useBoardStore } from "@/stores/boardStore";
import { useChatStore } from "@/stores/chatStore";
import { clsx } from "clsx";

interface SubtaskDetailModalProps {
  subtask: Subtask;
  comments: MessageType[];
  workspaceMembers?: User[];
  onClose: () => void;
  onDeleted?: () => void;
  highlightCommentId?: string | null;
}

export function SubtaskDetailModal({
  subtask,
  comments,
  workspaceMembers = [],
  onClose,
  onDeleted,
  highlightCommentId,
}: SubtaskDetailModalProps) {
  const [openThread, setOpenThread] = useState<MessageType | null>(null);
  const [newComment, setNewComment] = useState("");
  const [quotingMessage, setQuotingMessage] = useState<MessageType | null>(
    null,
  );
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [isAssigneeDropdownOpen, setIsAssigneeDropdownOpen] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleValue, setTitleValue] = useState(subtask.title);
  const [isSavingDetails, setIsSavingDetails] = useState(false);
  // Local state for batched save
  const [localAssigneeId, setLocalAssigneeId] = useState<string | undefined>(
    subtask.assigneeId ?? undefined,
  );
  const [localDueDate, setLocalDueDate] = useState(subtask.dueOn || "");
  const [localNotes, setLocalNotes] = useState(subtask.notes || "");
  const commentEditorRef = useRef<HTMLTextAreaElement>(null);
  const titleInputRef = useRef<HTMLInputElement>(null);
  const commentsEndRef = useRef<HTMLDivElement>(null);
  const { updateSubtask, deleteSubtask } = useBoardStore();
  const { sendMessage, fetchMessages, hasMoreMessages } = useChatStore();

  const selectedAssignee = workspaceMembers.find(
    (m) => m.id === localAssigneeId,
  );

  // Check if any details have changed (only 3 fields now - no status)
  const hasDetailsChanged =
    (localAssigneeId || null) !== (subtask.assigneeId || null) ||
    (localDueDate || null) !== (subtask.dueOn || null) ||
    (localNotes || "") !== (subtask.notes || "");

  // Close on escape key (unless thread is open)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !openThread && !isDeleteModalOpen) {
        onClose();
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [onClose, openThread, isDeleteModalOpen]);

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
          `subtask-message-${highlightCommentId}`,
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

  const handleLocalAssigneeChange = (assigneeId: string | null) => {
    setLocalAssigneeId(assigneeId || undefined);
    setIsAssigneeDropdownOpen(false);
  };

  const handleTitleSave = async () => {
    if (titleValue.trim() && titleValue !== subtask.title) {
      await updateSubtask(subtask.id, { title: titleValue.trim() });
    } else {
      setTitleValue(subtask.title);
    }
    setEditingTitle(false);
  };

  const handleToggleCompleted = async () => {
    await updateSubtask(subtask.id, { isCompleted: !subtask.isCompleted });
  };

  const handleSaveDetails = async () => {
    if (!hasDetailsChanged) return;
    setIsSavingDetails(true);
    try {
      await updateSubtask(subtask.id, {
        assigneeId: localAssigneeId || null,
        dueOn: localDueDate || null,
        notes: localNotes,
      });
    } finally {
      setIsSavingDetails(false);
    }
  };

  const handleDelete = async () => {
    await deleteSubtask(subtask.id);
    setIsDeleteModalOpen(false);
    onDeleted?.();
    onClose();
  };

  const handleAddComment = async () => {
    const textContent = newComment.replace(/<[^>]*>/g, "").trim();
    if (!textContent) return;
    await sendMessage(
      "subtask",
      subtask.id,
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
    const messageElement = document.getElementById(
      `subtask-message-${messageId}`,
    );
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
      await fetchMessages("subtask", subtask.id, true);
    } finally {
      setIsLoadingMore(false);
    }
  };

  return (
    <Modal
      onClose={onClose}
      size="3xl"
      variant="bg"
      maxHeight="80vh"
      showCloseButton={false}
      zIndex={70}
    >
      {/* Header */}
      <div className="px-6 py-4 border-b border-dark-border flex items-start justify-between flex-shrink-0">
        <div className="flex items-start gap-3 flex-1 pr-4">
          {/* Checkbox */}
          <button
            onClick={handleToggleCompleted}
            className="flex-shrink-0 mt-0.5 text-dark-text-muted hover:text-dark-text transition-colors"
          >
            {subtask.isCompleted ? (
              <CheckSquare size={24} className="text-green-500" />
            ) : (
              <Square size={24} />
            )}
          </button>

          <div className="flex-1">
            {editingTitle ? (
              <div className="flex items-center gap-2">
                <input
                  ref={titleInputRef}
                  type="text"
                  value={titleValue}
                  onChange={(e) => setTitleValue(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      handleTitleSave();
                    } else if (e.key === "Escape") {
                      setTitleValue(subtask.title);
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
              <h2
                onClick={() => setEditingTitle(true)}
                className={clsx(
                  "text-lg font-semibold cursor-pointer hover:text-blue-400 transition-colors",
                  subtask.isCompleted
                    ? "text-dark-text-muted line-through"
                    : "text-dark-text",
                )}
                title="Click to edit"
              >
                {subtask.title}
              </h2>
            )}
            {subtask.createdBy && (
              <div className="text-sm text-dark-text-muted mt-2">
                Added by {subtask.createdBy.name} on{" "}
                {format(new Date(subtask.insertedAt), "MMM d, yyyy")}
              </div>
            )}
          </div>
        </div>
        <div className="flex items-center gap-1">
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
        {/* Subtask Details Section */}
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
                    onClick={() => handleLocalAssigneeChange(null)}
                    className={clsx(
                      "w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-dark-border transition-colors",
                      !localAssigneeId && "bg-dark-border",
                    )}
                  >
                    <span className="text-dark-text-muted">Unassigned</span>
                  </button>
                  {workspaceMembers.map((member) => (
                    <button
                      key={member.id}
                      onClick={() => handleLocalAssigneeChange(member.id)}
                      className={clsx(
                        "w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-dark-border transition-colors",
                        localAssigneeId === member.id && "bg-dark-border",
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
                value={localDueDate}
                onChange={(e) => setLocalDueDate(e.target.value)}
                className={clsx(
                  "px-2 py-1.5 bg-transparent border-none text-sm focus:outline-none cursor-pointer [&::-webkit-calendar-picker-indicator]:invert",
                  localDueDate
                    ? "text-dark-text"
                    : "text-dark-text-muted [&::-webkit-datetime-edit]:text-dark-text-muted",
                )}
              />
              {localDueDate && (
                <button
                  onClick={() => setLocalDueDate("")}
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
                value={localNotes}
                onChange={setLocalNotes}
                placeholder="Add notes..."
              />
            </div>
          </div>

          {/* Save Button */}
          <div className="flex items-start gap-6">
            <div className="w-24 flex-shrink-0" />
            <div className="flex-1">
              <button
                onClick={handleSaveDetails}
                disabled={!hasDetailsChanged || isSavingDetails}
                className={clsx(
                  "px-4 py-2 text-sm font-medium rounded transition-colors",
                  hasDetailsChanged
                    ? "bg-blue-600 text-white hover:bg-blue-700"
                    : "bg-dark-surface text-dark-text-muted cursor-not-allowed",
                )}
              >
                {isSavingDetails ? "Saving..." : "Save"}
              </button>
            </div>
          </div>
        </div>

        {/* Comments Section */}
        <div className="px-6 py-4">
          {topLevelComments.length > 0 ? (
            <>
              <h3 className="text-sm font-medium text-dark-text mb-3">
                Comments ({topLevelComments.length})
              </h3>
              {hasMoreMessages("subtask", subtask.id) && (
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
                    <div key={comment.id} id={`subtask-message-${comment.id}`}>
                      <Message
                        message={comment}
                        onReply={() => setOpenThread(comment)}
                        onQuote={() => handleQuote(comment)}
                        onQuotedClick={handleQuotedClick}
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
        />
      </div>

      {/* Thread Panel - Outside modal, fixed on right */}
      {openThread && (
        <div className="fixed top-0 right-0 bottom-0 w-96 bg-dark-surface border-l border-dark-border z-[80] flex flex-col shadow-2xl">
          <DiscussionThread
            parentMessage={openThread}
            threadMessages={threadMessages}
            onClose={() => setOpenThread(null)}
            onSendReply={async (parentId, text, quoteId) => {
              await sendMessage("subtask", subtask.id, text, parentId, quoteId);
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
          zIndex={80}
        >
          <div className="p-6">
            <p className="text-sm text-dark-text-muted mb-4">
              Are you sure you want to delete "{subtask.title}"? This will also
              delete all comments. This action cannot be undone.
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
    </Modal>
  );
}
