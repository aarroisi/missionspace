import { useEffect, forwardRef, useMemo, useRef, useState } from "react";
import { Quote, X } from "lucide-react";
import { Message as MessageType } from "@/types";
import { clsx } from "clsx";
import { useAuthStore } from "@/stores/authStore";
import { useIsMobile } from "@/hooks/useIsMobile";
import { ContentRenderer } from "@/lib/milkdown/ContentRenderer";
import {
  RichTextEditor,
  type RichTextEditorHandle,
} from "@/lib/milkdown/RichTextEditor";
import { $prose } from "@milkdown/utils";
import { Plugin, PluginKey } from "@milkdown/prose/state";

const submitPluginKey = new PluginKey("submit-on-enter");

/**
 * Creates a ProseMirror plugin that submits on Cmd/Ctrl+Enter.
 * Plain Enter is left to the editor so it inserts a newline.
 * Checks if mention popup is active before submitting.
 */
function createSubmitPlugin(
  onSubmitRef: React.MutableRefObject<() => void>,
  isMentionActiveRef: React.MutableRefObject<boolean>,
) {
  return $prose(() => {
    return new Plugin({
      key: submitPluginKey,
      props: {
        handleDOMEvents: {
          keydown(_view, event) {
            if (event.key !== "Enter") {
              return false;
            }

            if (isMentionActiveRef.current) {
              return false;
            }

            if (event.metaKey || event.ctrlKey) {
              event.preventDefault();
              onSubmitRef.current();
              return true;
            }

            return false;
          },
        },
      },
    });
  });
}

interface CommentEditorProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  placeholder?: string;
  quotingMessage?: MessageType | null;
  onCancelQuote?: () => void;
  autoFocus?: boolean;
  variant?: "default" | "thread";
  fileUpload?: {
    attachableType: string;
    attachableId: string;
    onError: (msg: string) => void;
  };
}

export const CommentEditor = forwardRef<
  HTMLTextAreaElement,
  CommentEditorProps
>(
  (
    {
      value,
      onChange,
      onSubmit,
      placeholder = "Add a comment...",
      quotingMessage,
      onCancelQuote,
      autoFocus = false,
      variant = "default",
      fileUpload,
    },
    ref,
  ) => {
    const { members } = useAuthStore();
    const isMobile = useIsMobile();
    const onSubmitRef = useRef(onSubmit);
    const isMentionActiveRef = useRef(false);
    const editorHandleRef = useRef<RichTextEditorHandle | null>(null);
    const [hasContent, setHasContent] = useState(false);

    // Keep ref updated
    useEffect(() => {
      onSubmitRef.current = onSubmit;
    }, [onSubmit]);

    // Convert workspace members to mention format
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

    // Create submit plugin (memoized)
    const submitPlugin = useMemo(
      () => createSubmitPlugin(onSubmitRef, isMentionActiveRef),
      [],
    );

    // Expose editor focus method via ref
    useEffect(() => {
      if (ref && typeof ref === "object" && ref !== null) {
        (ref as any).current = {
          focus: () => editorHandleRef.current?.focus(),
        };
      }
    }, [ref]);

    // Auto-focus
    useEffect(() => {
      if (autoFocus && editorHandleRef.current) {
        setTimeout(() => {
          editorHandleRef.current?.focus();
        }, 100);
      }
    }, [autoFocus]);

    // Focus when quoting message changes
    useEffect(() => {
      if (quotingMessage && editorHandleRef.current) {
        setTimeout(() => {
          editorHandleRef.current?.focus();
        }, 100);
      }
    }, [quotingMessage]);

    const handleChange = (markdown: string) => {
      onChange(markdown);
      setHasContent(markdown.trim().length > 0);
    };

    const isThread = variant === "thread";
    const containerBg = isThread ? "bg-dark-bg" : "bg-dark-surface";
    const buttonHoverBg = isThread
      ? "hover:bg-dark-surface"
      : "hover:bg-dark-bg";
    const quoteBg = isThread ? "bg-dark-surface" : "bg-dark-bg";
    const submitShortcut = useMemo(() => {
      if (typeof navigator === "undefined") {
        return "Ctrl+Enter";
      }

      return /Mac|iPhone|iPad|iPod/.test(navigator.platform)
        ? "Cmd+Enter"
        : "Ctrl+Enter";
    }, []);

    const shortcutHint = `Enter for newline | ${submitShortcut} to send`;

    const sendButton = (
      <button
        onClick={onSubmit}
        disabled={!hasContent}
        className="p-2 rounded-lg bg-green-600 text-white hover:bg-green-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors flex-shrink-0"
        aria-label={isMobile ? "Send" : `Send (${submitShortcut})`}
        title={isMobile ? "Send" : `Send (${submitShortcut})`}
        onMouseDown={(e) => e.preventDefault()}
      >
        <svg
          width="16"
          height="16"
          viewBox="0 0 16 16"
          fill="none"
          className="transform rotate-45"
        >
          <path
            d="M2 14L14 2M14 2H6M14 2V10"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </button>
    );

    return (
      <div
        className={`relative overflow-hidden ${containerBg} transition-colors`}
      >
        {quotingMessage && onCancelQuote && (
          <div className={`px-3 py-2 border-b border-dark-border ${quoteBg}`}>
            <div className="flex items-start gap-2">
              <div className="flex-1 text-sm">
                <div className="flex items-center gap-2 text-dark-text-muted mb-1">
                  <Quote size={14} />
                  <span>Quoting {quotingMessage.userName}</span>
                </div>
                <ContentRenderer
                  content={quotingMessage.text}
                  className="text-dark-text-muted truncate prose prose-invert prose-sm max-w-none"
                />
              </div>
              <button
                onClick={onCancelQuote}
                className={`p-1 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`}
                title="Cancel quote"
              >
                <X size={16} />
              </button>
            </div>
          </div>
        )}
        <RichTextEditor
          value={value}
          onChange={handleChange}
          placeholder={placeholder}
          mentions={{
            members: mentionMembers,
            onActiveChange: (active) => {
              isMentionActiveRef.current = active;
            },
          }}
          fileUpload={fileUpload}
          plugins={[submitPlugin]}
          onReady={(handle) => {
            editorHandleRef.current = handle;
          }}
          className={clsx(
            "[&_.milkdown_.editor]:outline-none [&_.milkdown_.editor]:text-base [&_.milkdown_.editor]:text-dark-text",
            "[&_.milkdown]:min-h-[24px] [&_.milkdown]:max-h-[200px] [&_.milkdown]:overflow-y-auto",
            "[&_.milkdown_.editor]:pb-10",
          )}
        />
        {!isMobile && (
          <div className="pointer-events-none absolute bottom-2 left-3 right-14 z-10 truncate text-[11px] text-dark-text-muted">
            {shortcutHint}
          </div>
        )}
        <div className="absolute bottom-2 right-2 z-10">
          {sendButton}
        </div>
      </div>
    );
  },
);

CommentEditor.displayName = "CommentEditor";
