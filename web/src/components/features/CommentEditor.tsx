import {
  useEffect,
  forwardRef,
  useImperativeHandle,
  useMemo,
  useRef,
} from "react";
import { Bold, Italic, List, ListOrdered, Quote, X } from "lucide-react";
import { useEditor, EditorContent, Extension } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import DOMPurify from "dompurify";
import { Message as MessageType } from "@/types";
import { clsx } from "clsx";
import { useAuthStore } from "@/stores/authStore";
import { createMentionExtension } from "@/lib/mention";

// Custom extension to handle Enter key for submission
// Checks if mention popup is active before submitting
const createSubmitExtension = (
  onSubmit: () => void,
  isMentionActiveRef: React.MutableRefObject<boolean>,
) =>
  Extension.create({
    name: "submitOnEnter",
    priority: 1000, // High priority to run before StarterKit

    addKeyboardShortcuts() {
      return {
        Enter: () => {
          // Don't submit if mention popup is active
          if (isMentionActiveRef.current) {
            return false; // Let mention handle it
          }
          onSubmit();
          return true;
        },
        "Shift-Enter": ({ editor }) => {
          // Insert a hard break (new line)
          editor.commands.first(({ commands }) => [
            () => commands.newlineInCode(),
            () => commands.splitBlock(),
          ]);
          return true;
        },
      };
    },
  });

interface CommentEditorProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  placeholder?: string;
  quotingMessage?: MessageType | null;
  onCancelQuote?: () => void;
  autoFocus?: boolean;
  variant?: "default" | "thread";
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
    },
    ref,
  ) => {
    const { members } = useAuthStore();
    const onSubmitRef = useRef(onSubmit);
    const isMentionActiveRef = useRef(false);

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

    // Memoize extensions to avoid recreating editor
    const mentionExtension = useMemo(
      () =>
        createMentionExtension({
          members: mentionMembers,
          onActiveChange: (isActive) => {
            isMentionActiveRef.current = isActive;
          },
        }),
      [mentionMembers],
    );

    const submitExtension = useMemo(
      () =>
        createSubmitExtension(() => onSubmitRef.current(), isMentionActiveRef),
      [],
    );

    const editor = useEditor({
      extensions: [
        StarterKit,
        Placeholder.configure({
          placeholder,
        }),
        mentionExtension,
        submitExtension,
      ],
      content: value,
      editorProps: {
        attributes: {
          class:
            "flex-1 bg-transparent text-dark-text placeholder:text-dark-text-muted focus:outline-none resize-none leading-6 text-base prose prose-invert max-w-none",
        },
      },
      onUpdate: ({ editor }) => {
        onChange(editor.getHTML());
      },
    });

    // Expose editor focus method
    useImperativeHandle(
      ref,
      () =>
        ({
          focus: () => editor?.commands.focus(),
        }) as any,
    );

    // Update editor content when value changes externally
    useEffect(() => {
      if (editor && value !== editor.getHTML()) {
        editor.commands.setContent(value);
      }
    }, [value, editor]);

    useEffect(() => {
      if (autoFocus && editor) {
        setTimeout(() => {
          editor.commands.focus();
        }, 100);
      }
    }, [autoFocus, editor]);

    // Focus when quoting message changes
    useEffect(() => {
      if (quotingMessage && editor) {
        setTimeout(() => {
          editor.commands.focus();
        }, 100);
      }
    }, [quotingMessage, editor]);

    const isThread = variant === "thread";
    const containerBg = isThread ? "bg-dark-bg" : "bg-dark-surface";
    const buttonHoverBg = isThread
      ? "hover:bg-dark-surface"
      : "hover:bg-dark-bg";
    const quoteBg = isThread ? "bg-dark-surface" : "bg-dark-bg";

    return (
      <div
        className={`border border-dark-border rounded-lg ${containerBg} transition-colors hover:border-gray-600 focus-within:!border-blue-500`}
      >
        <div className="flex items-center gap-1 px-3 py-2 border-b border-dark-border">
          <button
            onClick={() => editor?.chain().focus().toggleBold().run()}
            className={clsx(
              `p-1.5 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`,
              editor?.isActive("bold") && "bg-dark-border text-dark-text",
            )}
            title="Bold"
            type="button"
          >
            <Bold size={18} />
          </button>
          <button
            onClick={() => editor?.chain().focus().toggleItalic().run()}
            className={clsx(
              `p-1.5 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`,
              editor?.isActive("italic") && "bg-dark-border text-dark-text",
            )}
            title="Italic"
            type="button"
          >
            <Italic size={18} />
          </button>
          <div className="w-px h-5 bg-dark-border mx-1" />
          <button
            onClick={() => editor?.chain().focus().toggleBulletList().run()}
            className={clsx(
              `p-1.5 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`,
              editor?.isActive("bulletList") && "bg-dark-border text-dark-text",
            )}
            title="Bullet List"
            type="button"
          >
            <List size={18} />
          </button>
          <button
            onClick={() => editor?.chain().focus().toggleOrderedList().run()}
            className={clsx(
              `p-1.5 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`,
              editor?.isActive("orderedList") &&
                "bg-dark-border text-dark-text",
            )}
            title="Numbered List"
            type="button"
          >
            <ListOrdered size={18} />
          </button>
          <button
            onClick={() => editor?.chain().focus().toggleBlockquote().run()}
            className={clsx(
              `p-1.5 rounded ${buttonHoverBg} transition-colors text-dark-text-muted hover:text-dark-text`,
              editor?.isActive("blockquote") && "bg-dark-border text-dark-text",
            )}
            title="Quote"
            type="button"
          >
            <Quote size={18} />
          </button>
        </div>
        {quotingMessage && onCancelQuote && (
          <div className={`px-3 py-2 border-b border-dark-border ${quoteBg}`}>
            <div className="flex items-start gap-2">
              <div className="flex-1 text-sm">
                <div className="flex items-center gap-2 text-dark-text-muted mb-1">
                  <Quote size={14} />
                  <span>Quoting {quotingMessage.userName}</span>
                </div>
                <div
                  className="text-dark-text-muted truncate prose prose-invert prose-sm max-w-none"
                  dangerouslySetInnerHTML={{
                    __html: DOMPurify.sanitize(quotingMessage.text, {
                      ALLOWED_TAGS: [
                        "p",
                        "br",
                        "strong",
                        "em",
                        "u",
                        "s",
                        "span",
                      ],
                      ALLOWED_ATTR: [
                        "class",
                        "data-id",
                        "data-type",
                        "data-label",
                      ],
                    }),
                  }}
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
        <div className="flex items-start gap-2 px-3 py-3">
          <div className="flex-1 min-h-[24px] max-h-[200px] overflow-y-auto">
            <EditorContent editor={editor} />
          </div>
          <button
            onClick={onSubmit}
            disabled={!editor || !editor.getText().trim()}
            className="p-2 rounded-lg bg-green-600 text-white hover:bg-green-700 disabled:opacity-40 disabled:cursor-not-allowed transition-colors flex-shrink-0"
            title="Send"
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
        </div>
      </div>
    );
  },
);

CommentEditor.displayName = "CommentEditor";
