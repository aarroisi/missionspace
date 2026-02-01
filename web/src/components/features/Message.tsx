import { useState, useEffect } from "react";
import { formatDistanceToNow } from "date-fns";
import { Reply, Quote, Pencil, Trash2, Check, X } from "lucide-react";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import { Avatar } from "@/components/ui/Avatar";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Message as MessageType } from "@/types";
import { clsx } from "clsx";
import DOMPurify from "dompurify";
import { useMemberProfile } from "@/contexts/MemberProfileContext";
import { useAuthStore } from "@/stores/authStore";
import { useChatStore } from "@/stores/chatStore";
import { createMentionExtension } from "@/lib/mention";

interface MessageProps {
  message: MessageType;
  quotedMessage?: MessageType;
  onReply?: () => void;
  onQuote?: () => void;
  onQuotedClick?: (messageId: string) => void;
  className?: string;
}

export function Message({
  message,
  quotedMessage,
  onReply,
  onQuote,
  onQuotedClick,
  className,
}: MessageProps) {
  const { openMemberProfile } = useMemberProfile();
  const { user, members } = useAuthStore();
  const { updateMessage, deleteMessage } = useChatStore();
  const [isEditing, setIsEditing] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  // Check if current user is the message author
  const isAuthor = user?.id === message.userId;

  // Check if message was edited
  const isEdited = message.updatedAt !== message.insertedAt;

  // Use the quote from the message itself if not provided
  const displayQuote = quotedMessage || message.quote;

  // Mention members for editor
  const mentionMembers = members.map((m) => ({
    id: m.id,
    name: m.name,
    email: m.email,
    avatar: m.avatar,
    online: m.online,
  }));

  // Editor for editing mode
  const editor = useEditor({
    extensions: [
      StarterKit,
      createMentionExtension({ members: mentionMembers }),
    ],
    content: message.text,
    editorProps: {
      attributes: {
        class:
          "prose prose-invert max-w-none focus:outline-none text-base text-dark-text",
      },
    },
  });

  // Update editor content when message changes
  useEffect(() => {
    if (editor && !isEditing) {
      editor.commands.setContent(message.text);
    }
  }, [message.text, editor, isEditing]);

  // Handle clicks on mention spans
  const handleContentClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const target = e.target as HTMLElement;
    if (target.classList.contains("mention")) {
      const memberId = target.getAttribute("data-id");
      if (memberId) {
        e.preventDefault();
        e.stopPropagation();
        openMemberProfile(memberId);
      }
    }
  };

  const handleEdit = () => {
    if (editor) {
      editor.commands.setContent(message.text);
      editor.commands.focus("end");
    }
    setIsEditing(true);
  };

  const handleCancelEdit = () => {
    if (editor) {
      editor.commands.setContent(message.text);
    }
    setIsEditing(false);
  };

  const handleSaveEdit = async () => {
    if (!editor) return;

    const newText = editor.getHTML();
    const textContent = editor.getText().trim();

    if (!textContent) return;

    setIsSaving(true);
    try {
      await updateMessage(message.id, newText);
      setIsEditing(false);
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

  // Sanitize HTML to prevent XSS attacks while allowing mentions
  const sanitizedText = DOMPurify.sanitize(message.text, {
    ALLOWED_TAGS: [
      "p",
      "br",
      "strong",
      "em",
      "u",
      "s",
      "ul",
      "ol",
      "li",
      "blockquote",
      "pre",
      "code",
      "h1",
      "h2",
      "h3",
      "h4",
      "h5",
      "h6",
      "span",
    ],
    ALLOWED_ATTR: ["class", "data-id", "data-type", "data-label"],
  });
  return (
    <div
      className={clsx(
        "flex gap-3 px-4 py-3 hover:bg-dark-surface/50 group relative",
        className,
      )}
    >
      <Avatar name={message.userName} size="sm" />
      <div className="flex-1 min-w-0">
        <div className="flex items-baseline gap-2 flex-wrap">
          <span className="font-semibold text-dark-text text-sm">
            {message.userName}
          </span>
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
            <div
              className="text-sm text-dark-text-muted mt-1 line-clamp-2 prose prose-invert prose-sm max-w-none"
              dangerouslySetInnerHTML={{
                __html: DOMPurify.sanitize(displayQuote.text, {
                  ALLOWED_TAGS: ["p", "br", "strong", "em", "u", "s", "span"],
                  ALLOWED_ATTR: ["class", "data-id", "data-type", "data-label"],
                }),
              }}
            />
          </button>
        )}

        {isEditing ? (
          <div className="mt-2">
            <div className="border border-dark-border rounded-lg bg-dark-surface p-2">
              <EditorContent editor={editor} />
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
          <div
            className="ProseMirror text-base text-dark-text mt-1 whitespace-pre-wrap break-words prose prose-invert prose-slate max-w-none"
            dangerouslySetInnerHTML={{ __html: sanitizedText }}
            onClick={handleContentClick}
          />
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
