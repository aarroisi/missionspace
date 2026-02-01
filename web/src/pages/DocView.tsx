import { useEffect, useState, useRef, useMemo } from "react";
import {
  useParams,
  useSearchParams,
  useNavigate,
  useLocation,
} from "react-router-dom";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import { createMentionExtension } from "@/lib/mention";
import {
  Bold,
  Italic,
  List,
  ListOrdered,
  Quote,
  Undo,
  Redo,
  Edit3,
  Check,
  ArrowDown,
  X,
  MoreHorizontal,
  Star,
  Trash2,
} from "lucide-react";
import { format } from "date-fns";
import { Message } from "@/components/features/Message";
import { DiscussionThread } from "@/components/features/DiscussionThread";
import { CommentEditor } from "@/components/features/CommentEditor";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { useDocStore } from "@/stores/docStore";
import { useChatStore } from "@/stores/chatStore";
import { useUIStore } from "@/stores/uiStore";
import { useProjectStore } from "@/stores/projectStore";
import { useToastStore } from "@/stores/toastStore";
import { useAuthStore } from "@/stores/authStore";
import { Message as MessageType, Doc } from "@/types";
import { clsx } from "clsx";

export function DocView() {
  const { id: docId, projectId: projectIdParam } = useParams<{
    id: string;
    projectId?: string;
  }>();
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const { docs, getDoc, updateDoc, createDoc, deleteDoc, toggleDocStar } =
    useDocStore();
  const { messages, fetchMessages, sendMessage, hasMoreMessages } =
    useChatStore();
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const { setNavigationGuard } = useUIStore();
  const addItemToProject = useProjectStore((state) => state.addItem);
  const { success, error } = useToastStore();
  const isNewDoc = docId === "new";

  // Get initial edit mode from URL
  const editParam = searchParams.get("edit");
  const highlightCommentId = searchParams.get("comment");
  const [isEditing, setIsEditing] = useState(isNewDoc || editParam === "true");
  const [openThread, setOpenThread] = useState<MessageType | null>(null);
  const [newComment, setNewComment] = useState("");
  const [quotingMessage, setQuotingMessage] = useState<MessageType | null>(
    null,
  );
  const [editedTitle, setEditedTitle] = useState("");
  const [editedContent, setEditedContent] = useState("");
  const [showJumpToBottom, setShowJumpToBottom] = useState(false);
  const [showUnsavedModal, setShowUnsavedModal] = useState(false);
  const [showSaveConfirmModal, setShowSaveConfirmModal] = useState(false);
  const [showCancelConfirmModal, setShowCancelConfirmModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const titleInputRef = useRef<HTMLInputElement>(null);
  const commentEditorRef = useRef<HTMLTextAreaElement>(null);
  const doc = isNewDoc ? null : docs.find((d) => d.id === docId);
  const rawDocComments =
    docId && !isNewDoc && Array.isArray(messages[`doc:${docId}`])
      ? messages[`doc:${docId}`]
      : [];
  // Backend returns messages in desc order (newest first), reverse for chat display (oldest first)
  const docComments = [...rawDocComments].reverse();
  const topLevelComments = docComments.filter((c) => !c.parentId);
  const threadMessages = docComments.filter((c) => c.parentId);

  const { members } = useAuthStore();

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

  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder: "Start writing...",
      }),
      createMentionExtension({ members: mentionMembers }),
    ],
    content: doc?.content || "",
    editable: isEditing,
    onUpdate: ({ editor }) => {
      if (isEditing) {
        setEditedContent(editor.getHTML());
      }
    },
  });

  // Check if there are unsaved changes
  const hasUnsavedChanges = () => {
    if (!isEditing) return false;
    if (isNewDoc) {
      return editedTitle.trim() !== "" || editedContent.trim() !== "";
    }
    return (
      editedTitle.trim() !== (doc?.title?.trim() || "") ||
      editedContent !== (doc?.content || "")
    );
  };

  // Set up navigation guard
  useEffect(() => {
    const guard = async (): Promise<boolean> => {
      if (hasUnsavedChanges()) {
        return new Promise((resolve) => {
          setShowUnsavedModal(true);
          // Store resolve function to be called by modal actions
          (window as any).__navResolve = resolve;
        });
      }
      return true;
    };

    setNavigationGuard(guard);
    return () => setNavigationGuard(null);
  }, [
    isEditing,
    editedTitle,
    editedContent,
    doc,
    isNewDoc,
    location.pathname,
    setNavigationGuard,
  ]);

  // Warn before leaving page with unsaved changes (browser navigation)
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (hasUnsavedChanges()) {
        e.preventDefault();
        e.returnValue = "";
      }
    };

    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, [isEditing, editedTitle, editedContent, doc, isNewDoc]);

  const handleDiscardChanges = () => {
    setShowUnsavedModal(false);
    if ((window as any).__navResolve) {
      (window as any).__navResolve(true);
      delete (window as any).__navResolve;
    }
  };

  const handleCancelNavigation = () => {
    setShowUnsavedModal(false);
    if ((window as any).__navResolve) {
      (window as any).__navResolve(false);
      delete (window as any).__navResolve;
    }
  };

  const handleSaveAndNavigate = async () => {
    try {
      // Call the actual save logic directly without confirmation
      // (user already confirmed via the unsaved changes modal)
      await performSave();
      setShowUnsavedModal(false);
      if ((window as any).__navResolve) {
        (window as any).__navResolve(true);
        delete (window as any).__navResolve;
      }
    } catch (err) {
      // Error is already handled in performSave
      if ((window as any).__navResolve) {
        (window as any).__navResolve(false);
        delete (window as any).__navResolve;
      }
    }
  };

  const performSave = async () => {
    if (!editedTitle.trim()) {
      error("Document title cannot be empty");
      throw new Error("Title is empty");
    }

    try {
      if (isNewDoc) {
        // Create new document (without projectId - we use project_items now)
        const newDoc = await createDoc(editedTitle.trim(), editedContent || "");

        // If created from a project, add it to the project
        if (projectIdParam) {
          await addItemToProject(projectIdParam, "doc", newDoc.id);
        }

        success("Document created successfully");
        // Navigate to the doc view (nested if from project)
        if (projectIdParam) {
          navigate(`/projects/${projectIdParam}/docs/${newDoc.id}`);
        } else {
          navigate(`/docs/${newDoc.id}`);
        }
      } else {
        // Update existing document
        if (!docId) return;

        const updates: Partial<Doc> = {};

        if (editedTitle.trim() !== doc?.title) {
          updates.title = editedTitle.trim();
        }

        if (editedContent !== doc?.content) {
          updates.content = editedContent;
        }

        if (Object.keys(updates).length > 0) {
          await updateDoc(docId, updates);
          success("Document saved successfully");
        }

        handleExitEditMode();
      }
    } catch (err) {
      console.error("Failed to save doc:", err);
      error("Error saving document: " + (err as Error).message);
      throw err;
    }
  };

  useEffect(() => {
    if (docId && !isNewDoc) {
      getDoc(docId);
      fetchMessages("doc", docId);
      // Clear state when navigating to a different doc
      setQuotingMessage(null);
      setNewComment("");

      // Exit edit mode unless URL says to edit
      const editParam = searchParams.get("edit");
      setIsEditing(editParam === "true");

      // Restore thread from URL if present
      const threadId = searchParams.get("thread");
      if (threadId) {
        // Thread will be set after messages are loaded
        setOpenThread(null);
      } else {
        setOpenThread(null);
      }
    } else if (isNewDoc) {
      // Clear state for new document
      setEditedTitle("");
      setEditedContent("");
      setQuotingMessage(null);
      setNewComment("");
      setOpenThread(null);
      setIsEditing(true); // Always in edit mode for new docs
      if (editor) {
        editor.commands.setContent("");
      }
    }
  }, [docId, isNewDoc, getDoc, fetchMessages, editor, searchParams]);

  useEffect(() => {
    if (editor && doc) {
      editor.commands.setContent(doc.content);
      setEditedTitle(doc.title);
      setEditedContent(doc.content);
    }
  }, [doc, editor]);

  // Focus title input for new docs
  useEffect(() => {
    if (isNewDoc && titleInputRef.current) {
      setTimeout(() => {
        titleInputRef.current?.focus();
      }, 100);
    }
  }, [isNewDoc]);

  // Restore thread from URL when messages are loaded
  useEffect(() => {
    const threadId = searchParams.get("thread");
    if (threadId && docComments.length > 0) {
      const message = docComments.find((m) => m.id === threadId);
      if (message && (!openThread || openThread.id !== threadId)) {
        setOpenThread(message);
      }
    } else if (!threadId && openThread) {
      setOpenThread(null);
    }
  }, [searchParams, docComments]);

  // Scroll to and highlight comment if highlightCommentId is provided
  useEffect(() => {
    if (highlightCommentId && docComments.length > 0) {
      // Small delay to ensure the DOM is rendered
      setTimeout(() => {
        const messageElement = document.getElementById(
          `message-${highlightCommentId}`,
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
  }, [highlightCommentId, docComments]);

  useEffect(() => {
    if (editor) {
      editor.setEditable(isEditing);
    }
  }, [isEditing, editor]);

  // Monitor scroll position to show/hide jump to bottom button
  useEffect(() => {
    const scrollContainer = scrollContainerRef.current;
    if (!scrollContainer) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
      const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
      // Show button if user is more than 200px from bottom
      setShowJumpToBottom(distanceFromBottom > 200);
    };

    scrollContainer.addEventListener("scroll", handleScroll);
    handleScroll(); // Check initial state

    return () => scrollContainer.removeEventListener("scroll", handleScroll);
  }, [docComments]); // Re-check when comments change

  const handleEnterEditMode = () => {
    setIsEditing(true);
    const params = new URLSearchParams(searchParams);
    params.set("edit", "true");
    setSearchParams(params);
  };

  const handleExitEditMode = () => {
    setIsEditing(false);
    const params = new URLSearchParams(searchParams);
    params.delete("edit");
    setSearchParams(params);
  };

  const handleCancelEdit = () => {
    // Check if there are unsaved changes
    if (hasUnsavedChanges()) {
      setShowCancelConfirmModal(true);
    } else {
      performCancelEdit();
    }
  };

  const performCancelEdit = () => {
    // Reset to original content
    if (doc) {
      setEditedTitle(doc.title);
      setEditedContent(doc.content || "");
      if (editor) {
        editor.commands.setContent(doc.content || "");
      }
    }
    handleExitEditMode();
  };

  const handleConfirmCancel = () => {
    setShowCancelConfirmModal(false);
    if (isNewDoc) {
      performCancelNew();
    } else {
      performCancelEdit();
    }
  };

  const handleCancelCancelModal = () => {
    setShowCancelConfirmModal(false);
  };

  const handleCancelNew = () => {
    // Check if there's any content in the new doc
    if (editedTitle.trim() !== "" || editedContent.trim() !== "") {
      setShowCancelConfirmModal(true);
    } else {
      navigate("/docs");
    }
  };

  const performCancelNew = () => {
    // Navigate back to project if we came from there, otherwise to docs
    if (projectIdParam) {
      navigate(`/projects/${projectIdParam}`);
    } else {
      navigate("/docs");
    }
  };

  const handleSave = async () => {
    // Validate title is not empty
    if (!editedTitle.trim()) {
      error("Document title cannot be empty");
      return;
    }

    // Show confirmation modal before saving
    setShowSaveConfirmModal(true);
  };

  const handleConfirmSave = async () => {
    setShowSaveConfirmModal(false);
    try {
      await performSave();
    } catch (err) {
      // Error already handled in performSave
    }
  };

  const handleCancelSave = () => {
    setShowSaveConfirmModal(false);
  };

  const handleJumpToBottom = () => {
    const scrollContainer = scrollContainerRef.current;
    if (scrollContainer) {
      scrollContainer.scrollTo({
        top: scrollContainer.scrollHeight,
        behavior: "smooth",
      });
    }
  };

  const handleQuotedClick = (messageId: string) => {
    const messageElement = document.getElementById(`message-${messageId}`);
    if (messageElement) {
      messageElement.scrollIntoView({ behavior: "smooth", block: "center" });

      // Add highlight effect
      messageElement.classList.add("ring-2", "ring-blue-500/50");
      setTimeout(() => {
        messageElement.classList.remove("ring-2", "ring-blue-500/50");
      }, 2000);
    }
  };

  const handleOpenThread = (message: MessageType) => {
    setOpenThread(message);
    setSearchParams({ thread: message.id });
  };

  const handleCloseThread = () => {
    setOpenThread(null);
    setSearchParams({});
  };

  const handleQuote = (message: MessageType) => {
    setQuotingMessage(message);
    // Focus the comment editor
    setTimeout(() => {
      commentEditorRef.current?.focus();
    }, 100);
  };

  const handleAddComment = async () => {
    // Check for empty content - strip HTML tags to check actual text
    const textContent = newComment.replace(/<[^>]*>/g, "").trim();
    if (!textContent || !docId) return;
    try {
      await sendMessage(
        "doc",
        docId,
        newComment,
        undefined, // parentId - not used for top-level comments
        quotingMessage?.id, // quoteId
      );
      setNewComment("");
      setQuotingMessage(null);
      success("Comment added successfully");

      // Scroll to bottom after comment is added
      setTimeout(() => {
        const scrollContainer = document.querySelector(
          ".flex-1.overflow-y-auto",
        );
        if (scrollContainer) {
          scrollContainer.scrollTo({
            top: scrollContainer.scrollHeight,
            behavior: "smooth",
          });
        }
      }, 100);
    } catch (err) {
      console.error("Failed to add comment:", err);
      error("Error adding comment: " + (err as Error).message);
    }
  };

  if (!doc && !isNewDoc) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <p className="text-dark-text-muted">Select a doc to view</p>
      </div>
    );
  }

  const getThreadReplies = (messageId: string) => {
    return threadMessages.filter((m) => m.parentId === messageId);
  };

  const handleLoadMore = async () => {
    if (!docId || isNewDoc || isLoadingMore) return;
    setIsLoadingMore(true);
    try {
      await fetchMessages("doc", docId, true);
    } finally {
      setIsLoadingMore(false);
    }
  };

  const handleToggleStar = async () => {
    if (!doc) return;
    await toggleDocStar(doc.id);
  };

  const handleDeleteDoc = async () => {
    if (!doc) return;
    await deleteDoc(doc.id);
    // Navigate back to project if doc was inside a project, otherwise to docs list
    if (projectIdParam) {
      navigate(`/projects/${projectIdParam}`);
    } else {
      navigate("/docs");
    }
  };

  return (
    <div className="flex-1 flex overflow-hidden">
      <div className="flex-1 flex flex-col overflow-hidden relative">
        <div className="px-6 py-4 border-b border-dark-border max-w-7xl mx-auto w-full">
          <div className="flex items-center justify-between">
            <div className="flex-1 min-w-0">
              <input
                ref={titleInputRef}
                type="text"
                value={isEditing ? editedTitle : doc?.title || ""}
                onChange={(e) => setEditedTitle(e.target.value)}
                disabled={!isEditing}
                className={clsx(
                  "text-2xl font-bold text-dark-text bg-transparent border-none outline-none w-full",
                  !isEditing && "cursor-default",
                )}
                placeholder="Add a title..."
              />
              {!isNewDoc && doc && doc.createdBy && (
                <div className="text-sm text-dark-text-muted mt-1">
                  Added by {doc.createdBy.name} on{" "}
                  {format(new Date(doc.insertedAt), "MMM d, yyyy")}
                  {doc.updatedAt !== doc.insertedAt && (
                    <span>
                      {" "}
                      · Updated {format(new Date(doc.updatedAt), "MMM d, yyyy")}
                    </span>
                  )}
                </div>
              )}
            </div>
            <div className="flex items-center gap-2 md:gap-3 flex-shrink-0">
              {isEditing && !isNewDoc && hasUnsavedChanges() && (
                <>
                  <span className="hidden lg:flex text-sm text-amber-500 items-center gap-1">
                    <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse"></span>
                    Unsaved changes
                  </span>
                  <span
                    className="lg:hidden w-2 h-2 min-w-[0.5rem] min-h-[0.5rem] rounded-full bg-amber-500 animate-pulse ml-2"
                    title="Unsaved changes"
                  ></span>
                </>
              )}
              {isNewDoc ? (
                <>
                  <button
                    onClick={handleCancelNew}
                    className="flex items-center gap-2 p-2 lg:px-4 lg:py-2 rounded-lg bg-dark-surface hover:bg-dark-border text-dark-text transition-colors flex-shrink-0"
                    title="Cancel"
                  >
                    <X size={16} className="flex-shrink-0" />
                    <span className="hidden lg:inline whitespace-nowrap">
                      Cancel
                    </span>
                  </button>
                  <button
                    onClick={handleSave}
                    disabled={!editedTitle.trim()}
                    className="flex items-center gap-2 p-2 lg:px-4 lg:py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex-shrink-0"
                    title="Save"
                  >
                    <Check size={16} className="flex-shrink-0" />
                    <span className="hidden lg:inline whitespace-nowrap">
                      Save
                    </span>
                  </button>
                </>
              ) : (
                <>
                  {isEditing ? (
                    <>
                      <button
                        onClick={handleCancelEdit}
                        className="flex items-center gap-2 p-2 lg:px-4 lg:py-2 rounded-lg bg-dark-surface hover:bg-dark-border text-dark-text transition-colors flex-shrink-0"
                        title="Cancel"
                      >
                        <X size={16} className="flex-shrink-0" />
                        <span className="hidden lg:inline whitespace-nowrap">
                          Cancel
                        </span>
                      </button>
                      <button
                        onClick={handleSave}
                        disabled={!editedTitle.trim()}
                        className="flex items-center gap-2 p-2 lg:px-4 lg:py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex-shrink-0"
                        title="Save"
                      >
                        <Check size={16} className="flex-shrink-0" />
                        <span className="hidden lg:inline whitespace-nowrap">
                          Save
                        </span>
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        onClick={handleEnterEditMode}
                        className="flex items-center gap-2 p-2 lg:px-4 lg:py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors flex-shrink-0"
                        title="Edit"
                      >
                        <Edit3 size={16} className="flex-shrink-0" />
                        <span className="hidden lg:inline whitespace-nowrap">
                          Edit
                        </span>
                      </button>
                      <Dropdown
                        align="right"
                        trigger={
                          <button className="p-2 rounded transition-colors text-dark-text-muted hover:bg-dark-surface">
                            <MoreHorizontal size={18} />
                          </button>
                        }
                      >
                        <DropdownItem onClick={handleToggleStar}>
                          <span className="flex items-center gap-2">
                            <Star
                              size={16}
                              className={
                                doc?.starred
                                  ? "fill-yellow-400 text-yellow-400"
                                  : ""
                              }
                            />
                            {doc?.starred ? "Unstar" : "Star"}
                          </span>
                        </DropdownItem>
                        <DropdownItem
                          variant="danger"
                          onClick={() => setShowDeleteConfirm(true)}
                        >
                          <span className="flex items-center gap-2">
                            <Trash2 size={16} />
                            Delete Doc
                          </span>
                        </DropdownItem>
                      </Dropdown>
                    </>
                  )}
                </>
              )}
            </div>
          </div>
        </div>

        {isEditing && editor && (
          <div className="px-8 py-3 border-b border-dark-border flex items-center gap-2 max-w-7xl mx-auto w-full">
            <button
              onClick={() => editor.chain().focus().toggleBold().run()}
              className={clsx(
                "p-2 rounded transition-colors",
                editor.isActive("bold")
                  ? "bg-blue-600 text-white"
                  : "text-dark-text-muted hover:bg-dark-surface",
              )}
            >
              <Bold size={16} />
            </button>
            <button
              onClick={() => editor.chain().focus().toggleItalic().run()}
              className={clsx(
                "p-2 rounded transition-colors",
                editor.isActive("italic")
                  ? "bg-blue-600 text-white"
                  : "text-dark-text-muted hover:bg-dark-surface",
              )}
            >
              <Italic size={16} />
            </button>
            <button
              onClick={() => editor.chain().focus().toggleBulletList().run()}
              className={clsx(
                "p-2 rounded transition-colors",
                editor.isActive("bulletList")
                  ? "bg-blue-600 text-white"
                  : "text-dark-text-muted hover:bg-dark-surface",
              )}
            >
              <List size={16} />
            </button>
            <button
              onClick={() => editor.chain().focus().toggleOrderedList().run()}
              className={clsx(
                "p-2 rounded transition-colors",
                editor.isActive("orderedList")
                  ? "bg-blue-600 text-white"
                  : "text-dark-text-muted hover:bg-dark-surface",
              )}
            >
              <ListOrdered size={16} />
            </button>
            <button
              onClick={() => editor.chain().focus().toggleBlockquote().run()}
              className={clsx(
                "p-2 rounded transition-colors",
                editor.isActive("blockquote")
                  ? "bg-blue-600 text-white"
                  : "text-dark-text-muted hover:bg-dark-surface",
              )}
            >
              <Quote size={16} />
            </button>
            <div className="w-px h-6 bg-dark-border mx-1" />
            <button
              onClick={() => editor.chain().focus().undo().run()}
              className="p-2 rounded text-dark-text-muted hover:bg-dark-surface transition-colors"
            >
              <Undo size={16} />
            </button>
            <button
              onClick={() => editor.chain().focus().redo().run()}
              className="p-2 rounded text-dark-text-muted hover:bg-dark-surface transition-colors"
            >
              <Redo size={16} />
            </button>
          </div>
        )}

        <div
          className="flex-1 overflow-y-auto relative"
          ref={scrollContainerRef}
        >
          <div className="px-8 py-6 max-w-7xl mx-auto w-full">
            {!doc?.content && !isEditing ? (
              <div className="flex flex-col items-center justify-center py-24 text-center">
                <div className="w-16 h-16 rounded-full bg-dark-surface flex items-center justify-center mb-4">
                  <svg
                    width="32"
                    height="32"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="text-dark-text-muted"
                  >
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                    <line x1="12" y1="18" x2="12" y2="12" />
                    <line x1="9" y1="15" x2="15" y2="15" />
                  </svg>
                </div>
                <p className="text-dark-text-muted text-base mb-2">
                  This document is empty
                </p>
                <p className="text-dark-text-muted text-sm">
                  Click Edit to start writing
                </p>
              </div>
            ) : (
              <EditorContent
                editor={editor}
                className="prose prose-invert prose-slate max-w-none"
              />
            )}
          </div>

          {!isEditing && (
            <div className="px-8 py-6 border-t border-dark-border max-w-7xl mx-auto w-full">
              {topLevelComments.length > 0 ? (
                <>
                  <h3 className="text-sm font-medium text-dark-text mb-4">
                    Comments ({topLevelComments.length})
                  </h3>
                  {docId && !isNewDoc && hasMoreMessages("doc", docId) && (
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
                  <div className="space-y-1">
                    {topLevelComments.map((comment) => {
                      const replies = getThreadReplies(comment.id);
                      return (
                        <div key={comment.id} id={`message-${comment.id}`}>
                          <Message
                            message={comment}
                            onReply={() => handleOpenThread(comment)}
                            onQuote={() => handleQuote(comment)}
                            onQuotedClick={handleQuotedClick}
                          />
                          {replies.length > 0 && (
                            <button
                              onClick={() => handleOpenThread(comment)}
                              className="ml-14 text-xs text-blue-400 hover:underline"
                            >
                              {replies.length}{" "}
                              {replies.length === 1 ? "reply" : "replies"}
                            </button>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </>
              ) : (
                <div className="flex flex-col items-center justify-center py-12 text-center">
                  <div className="w-12 h-12 rounded-full bg-dark-surface flex items-center justify-center mb-4">
                    <Quote size={24} className="text-dark-text-muted" />
                  </div>
                  <p className="text-dark-text-muted text-sm">
                    No comments yet. Be the first to add one below.
                  </p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Jump to bottom button */}
        {!isEditing && showJumpToBottom && (
          <button
            onClick={handleJumpToBottom}
            className="absolute right-8 p-3 rounded-full bg-blue-600 text-white shadow-lg hover:bg-blue-700 transition-all z-10"
            style={{ bottom: quotingMessage ? "200px" : "140px" }}
            title="Jump to bottom"
          >
            <ArrowDown size={20} />
          </button>
        )}

        {!isEditing && (
          <div className="border-t border-dark-border bg-dark-bg p-4 max-w-7xl mx-auto w-full">
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
        )}
      </div>

      {openThread && (
        <DiscussionThread
          parentMessage={openThread}
          threadMessages={threadMessages}
          onClose={handleCloseThread}
          onSendReply={async (parentId, text, quoteId) => {
            if (!docId) return;
            await sendMessage("doc", docId, text, parentId, quoteId);
          }}
        />
      )}

      <ConfirmModal
        isOpen={showUnsavedModal}
        title="Unsaved Changes"
        message="You have unsaved changes. Do you want to save them before leaving?"
        confirmText="Save & Leave"
        cancelText="Stay"
        discardText="Discard Changes"
        confirmVariant="primary"
        onConfirm={handleSaveAndNavigate}
        onCancel={handleCancelNavigation}
        onDiscard={handleDiscardChanges}
      />

      <ConfirmModal
        isOpen={showSaveConfirmModal}
        title="Confirm Save"
        message={`Are you sure you want to save ${isNewDoc ? "this new document" : "changes to this document"}?`}
        confirmText="Save"
        cancelText="Cancel"
        confirmVariant="primary"
        onConfirm={handleConfirmSave}
        onCancel={handleCancelSave}
      />

      <ConfirmModal
        isOpen={showCancelConfirmModal}
        title="Discard Changes?"
        message="You have unsaved changes. Are you sure you want to discard all changes?"
        confirmText="Discard"
        cancelText="Keep Editing"
        confirmVariant="danger"
        onConfirm={handleConfirmCancel}
        onCancel={handleCancelCancelModal}
      />

      {/* Delete Confirmation Modal */}
      <ConfirmModal
        isOpen={showDeleteConfirm}
        title="Delete Doc"
        message={`Are you sure you want to delete "${doc?.title}"? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={handleDeleteDoc}
        onCancel={() => setShowDeleteConfirm(false)}
      />
    </div>
  );
}
