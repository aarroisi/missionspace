import { useState, useMemo, useRef } from "react";
import { formatDistanceToNow } from "date-fns";
import { Reply, Quote, Pencil, Trash2, Check, X } from "lucide-react";
import { Avatar } from "@/components/ui/Avatar";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Message as MessageType } from "@/types";
import { clsx } from "clsx";
import { useMemberProfile } from "@/contexts/MemberProfileContext";
import { useAuthStore } from "@/stores/authStore";
import { useChatStore } from "@/stores/chatStore";
import { ContentRenderer } from "@/lib/milkdown/ContentRenderer";
import {
  RichTextEditor,
  type RichTextEditorHandle,
} from "@/lib/milkdown/RichTextEditor";

interface MessageProps {
  message: MessageType;
  quotedMessage?: MessageType;
  onReply?: () => void;
  onQuote?: () => void;
  onQuotedClick?: (messageId: string) => void;
  replyCount?: number;
  onReplyCountClick?: () => void;
  className?: string;
  fileUpload?: {
    attachableType: string;
    attachableId: string;
    onError: (msg: string) => void;
  };
}

export function Message({
  message,
  quotedMessage,
  onReply,
  onQuote,
  onQuotedClick,
  replyCount,
  onReplyCountClick,
  className,
  fileUpload,
}: MessageProps) {
  const { openMemberProfile } = useMemberProfile();
  const { user, members } = useAuthStore();
  const { updateMessage, deleteMessage } = useChatStore();
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState("");
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const editorHandleRef = useRef<RichTextEditorHandle | null>(null);

  // Check if current user is the message author
  const isAuthor = user?.id === message.userId;

  // Check if message was edited
  const isEdited = message.updatedAt !== message.insertedAt;

  // Use the quote from the message itself if not provided
  const displayQuote = quotedMessage || message.quote;

  // Mention members for editor
  const mentionMembers = useMemo(
    () =>
      members.map((m) => ({
        id: m.id,
        name: m.name,
        email: m.email,
        avatar: m.avatar,
        online: m.online,
      })),
    [members],
  );

  const handleEdit = () => {
    setEditValue(message.text);
    setIsEditing(true);
    setTimeout(() => {
      editorHandleRef.current?.focus();
    }, 100);
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditValue("");
  };

  const handleSaveEdit = async () => {
    const textContent = editValue.trim();
    if (!textContent) return;

    setIsSaving(true);
    try {
      await updateMessage(message.id, editValue);
      setIsEditing(false);
      setEditValue("");
    } catch (error) {
      console.error("Failed to update message:", error);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await deleteMessage(message.id);
      setShowDeleteConfirm(false);
    } catch (error) {
      console.error("Failed to delete message:", error);
    } finally {
      setIsDeleting(false);
    }
  };

  const handleMentionClick = (memberId: string) => {
    openMemberProfile(memberId);
  };

  const handleAuthorClick = () => {
    openMemberProfile(message.userId);
  };

  return (
    <div
      className={clsx(
        "flex gap-3 px-4 py-3 md:px-6 md:py-4 hover:bg-dark-surface/50 group relative",
        className,
      )}
    >
      <button
        type="button"
        onClick={handleAuthorClick}
        className="inline-flex rounded-full bg-transparent p-0 border-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/60"
        title={`Open ${message.userName}'s profile`}
      >
        <Avatar name={message.userName} src={message.avatar} size="sm" />
      </button>
      <div className="flex-1 min-w-0">
        <div className="flex items-baseline gap-2 flex-wrap">
          <button
            type="button"
            onClick={handleAuthorClick}
            className="font-semibold text-dark-text text-sm hover:text-blue-400 transition-colors bg-transparent p-0 border-0"
            title={`Open ${message.userName}'s profile`}
          >
            {message.userName}
          </button>
          <span className="text-xs text-dark-text-muted">
            {formatDistanceToNow(new Date(message.insertedAt), {
              addSuffix: true,
            })}
          </span>
          {isEdited && (
            <span
              className="text-xs text-dark-text-muted italic"
              title={`Edited ${new Date(message.updatedAt).toLocaleString()}`}
            >
              (edited)
            </span>
          )}
        </div>

        {displayQuote && (
          <button
            onClick={() => onQuotedClick?.(displayQuote.id)}
            className="mt-1 mb-2 pl-3 border-l-2 border-blue-500/50 bg-dark-surface/50 rounded py-1 px-2 hover:bg-dark-surface transition-colors w-full text-left"
          >
            <div className="text-xs text-dark-text-muted flex items-center gap-1">
              <Quote size={12} />
              <span className="font-semibold">{displayQuote.userName}</span>
            </div>
            <ContentRenderer
              content={displayQuote.text}
              className="text-sm text-dark-text-muted mt-1 line-clamp-2 prose prose-invert prose-sm max-w-none"
              onMentionClick={handleMentionClick}
            />
          </button>
        )}

        {isEditing ? (
          <div className="mt-2">
            <div className="border border-dark-border rounded-lg bg-dark-surface overflow-hidden">
              <RichTextEditor
                value={editValue}
                onChange={setEditValue}
                mentions={{ members: mentionMembers }}
                fileUpload={fileUpload}
                onReady={(handle) => {
                  editorHandleRef.current = handle;
                }}
                className="[&_.milkdown_.editor]:outline-none [&_.milkdown_.editor]:text-base [&_.milkdown_.editor]:text-dark-text [&_.milkdown_.editor]:p-2"
              />
            </div>
            <div className="flex gap-2 mt-2">
              <button
                onClick={handleSaveEdit}
                disabled={isSaving}
                className="flex items-center gap-1 px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50"
              >
                <Check size={14} />
                {isSaving ? "Saving..." : "Save"}
              </button>
              <button
                onClick={handleCancelEdit}
                disabled={isSaving}
                className="flex items-center gap-1 px-3 py-1.5 text-sm bg-dark-surface hover:bg-dark-border text-dark-text rounded-lg transition-colors disabled:opacity-50"
              >
                <X size={14} />
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <ContentRenderer
            content={message.text}
            className="text-base text-dark-text mt-1 whitespace-pre-wrap break-words prose prose-invert prose-slate max-w-none"
            onMentionClick={handleMentionClick}
          />
        )}

        {replyCount != null && replyCount > 0 && onReplyCountClick && (
          <button
            onClick={onReplyCountClick}
            className="mt-1 text-xs text-blue-400 hover:underline"
          >
            {replyCount} {replyCount === 1 ? "reply" : "replies"}
          </button>
        )}

        {/* Action buttons - absolutely positioned to not take up space */}
        {!isEditing && (onReply || onQuote || isAuthor) && (
          <div className="absolute top-2 right-4 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity bg-dark-bg border border-dark-border rounded-lg shadow-lg">
            {onReply && (
              <button
                onClick={onReply}
                className="p-2 text-dark-text-muted hover:text-blue-400 hover:bg-dark-surface transition-colors rounded-l-lg"
                title="Reply"
              >
                <Reply size={16} />
              </button>
            )}
            {onQuote && (
              <button
                onClick={onQuote}
                className={clsx(
                  "p-2 text-dark-text-muted hover:text-blue-400 hover:bg-dark-surface transition-colors",
                  !onReply && "rounded-l-lg",
                  !isAuthor && "rounded-r-lg",
                )}
                title="Quote"
              >
                <Quote size={16} />
              </button>
            )}
            {isAuthor && (
              <>
                <button
                  onClick={handleEdit}
                  className={clsx(
                    "p-2 text-dark-text-muted hover:text-blue-400 hover:bg-dark-surface transition-colors",
                    !onReply && !onQuote && "rounded-l-lg",
                  )}
                  title="Edit"
                >
                  <Pencil size={16} />
                </button>
                <button
                  onClick={() => setShowDeleteConfirm(true)}
                  className="p-2 text-dark-text-muted hover:text-red-400 hover:bg-dark-surface transition-colors rounded-r-lg"
                  title="Delete"
                >
                  <Trash2 size={16} />
                </button>
              </>
            )}
          </div>
        )}
      </div>

      {/* Delete confirmation modal */}
      <ConfirmModal
        isOpen={showDeleteConfirm}
        title="Delete Message"
        message="Are you sure you want to delete this message? This action cannot be undone."
        confirmText={isDeleting ? "Deleting..." : "Delete"}
        confirmVariant="danger"
        onConfirm={handleDelete}
        onCancel={() => setShowDeleteConfirm(false)}
      />
    </div>
  );
}
