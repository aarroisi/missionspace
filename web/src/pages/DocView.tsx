import { useEffect, useState, useRef, useMemo } from "react";
import {
  useParams,
  useSearchParams,
  useNavigate,
  useLocation,
} from "react-router-dom";
import {
  RichTextEditor,
  type RichTextEditorHandle,
} from "@/lib/milkdown/RichTextEditor";
import {
  Edit3,
  Check,
  ArrowDown,
  X,
  Star,
  Trash2,
  Quote,
} from "lucide-react";
import { format } from "date-fns";
import { Message } from "@/components/features/Message";
import { DiscussionThread } from "@/components/features/DiscussionThread";
import { CommentEditor } from "@/components/features/CommentEditor";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { useDocStore } from "@/stores/docStore";
import { useChatStore } from "@/stores/chatStore";
import { useUIStore } from "@/stores/uiStore";
import { useToastStore } from "@/stores/toastStore";
import { useAuthStore } from "@/stores/authStore";
import { useIsMobile } from "@/hooks/useIsMobile";
import { useMessageChannel } from "@/hooks/useMessageChannel";
import { SubscriptionSection } from "@/components/features/SubscriptionSection";
import { Message as MessageType } from "@/types";

export function DocView() {
  const {
    id: docId,
    folderId: folderIdParam,
    projectId: projectIdParam,
  } = useParams<{
    id: string;
    folderId?: string;
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
  const [editingTitle, setEditingTitle] = useState(false);
  const [editedContent, setEditedContent] = useState("");
  const [showJumpToBottom, setShowJumpToBottom] = useState(false);
  const [showUnsavedModal, setShowUnsavedModal] = useState(false);
  const [showSaveConfirmModal, setShowSaveConfirmModal] = useState(false);
  const [showCancelConfirmModal, setShowCancelConfirmModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const isMobile = useIsMobile();
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const titleInputRef = useRef<HTMLInputElement>(null);
  const commentEditorRef = useRef<HTMLTextAreaElement>(null);
  const editorHandleRef = useRef<RichTextEditorHandle | null>(null);
  const doc = isNewDoc ? null : docs.find((d) => d.id === docId);
  useMessageChannel(docId && !isNewDoc ? `doc:${docId}` : "");
  const folderId = folderIdParam || doc?.docFolderId;
  const rawDocComments =
    docId && !isNewDoc && Array.isArray(messages[`doc:${docId}`])
      ? messages[`doc:${docId}`]
      : [];
  // Backend returns messages in desc order (newest first), reverse for chat display (oldest first)
  const docComments = [...rawDocComments].reverse();
  const topLevelComments = docComments.filter((c) => !c.parentId);
  const threadMessages = docComments.filter((c) => c.parentId);
  const hideMobileHeaderActions = isMobile && editingTitle;

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

  // Check if there are unsaved content changes (title saves separately)
  const hasUnsavedChanges = () => {
    if (!isEditing) return false;
    if (isNewDoc) {
      return editedTitle.trim() !== "" || editedContent.trim() !== "";
    }
    return editedContent !== (doc?.content || "");
  };

  const handleSaveTitle = async () => {
    if (!doc || !docId || isNewDoc) return;
    const newTitle = editedTitle.trim();
    if (!newTitle || newTitle === doc.title) {
      setEditedTitle(doc.title);
    } else {
      try {
        await updateDoc(docId, { title: newTitle });
      } catch (err) {
        error("Error updating title: " + (err as Error).message);
        setEditedTitle(doc.title);
      }
    }
    setEditingTitle(false);
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
        if (!folderId) {
          error("A folder is required to create a document");
          throw new Error("No folder selected");
        }
        const newDoc = await createDoc(
          editedTitle.trim(),
          editedContent || "",
          folderId,
        );

        success("Document created successfully");
        if (projectIdParam && folderIdParam) {
          navigate(
            `/projects/${projectIdParam}/doc-folders/${folderIdParam}/docs/${newDoc.id}`,
          );
        } else if (folderIdParam) {
          navigate(`/doc-folders/${folderIdParam}/docs/${newDoc.id}`);
        } else {
          navigate(`/docs/${newDoc.id}`);
        }
      } else {
        // Update existing document content only (title saves separately)
        if (!docId) return;

        if (editedContent !== doc?.content) {
          await updateDoc(docId, { content: editedContent });
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
      setIsEditing(true);
    }
  }, [docId, isNewDoc, getDoc, fetchMessages, searchParams]);

  useEffect(() => {
    if (doc) {
      if (!editingTitle) {
        setEditedTitle(doc.title);
      }
      if (!isEditing) {
        setEditedContent(doc.content);
      }
    }
  }, [doc]);

  // Focus title input for new docs
  useEffect(() => {
    if (isNewDoc && titleInputRef.current) {
      setTimeout(() => {
        titleInputRef.current?.focus();
      }, 100);
    }
  }, [isNewDoc]);

  // Focus and select title input when editing title
  useEffect(() => {
    if (editingTitle && titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, [editingTitle]);

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

    return () => {
      scrollContainer.removeEventListener("scroll", handleScroll);
    };
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
    // Reset to original content — editor syncs via value prop
    if (doc) {
      setEditedTitle(doc.title);
      setEditedContent(doc.content || "");
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

  const performCancelNew = () => {
    if (projectIdParam && folderIdParam) {
      navigate(
        `/projects/${projectIdParam}/doc-folders/${folderIdParam}`,
      );
    } else if (folderIdParam) {
      navigate(`/doc-folders/${folderIdParam}`);
    } else if (projectIdParam) {
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
    // Check for empty markdown content
    const textContent = newComment.trim();
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

  // Close on Escape key (must be before early return to maintain hook order)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !openThread && !isEditing) {
        navigateToParent();
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [openThread, isEditing]);

  if (!doc && !isNewDoc) {
    return null;
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
    navigateToParent();
  };

  const navigateToParent = () => {
    if (projectIdParam && folderId) {
      navigate(`/projects/${projectIdParam}/doc-folders/${folderId}`);
    } else if (folderId) {
      navigate(`/doc-folders/${folderId}`);
    } else if (projectIdParam) {
      navigate(`/projects/${projectIdParam}`);
    } else {
      navigate("/docs");
    }
  };

  const handleClose = async () => {
    if (isEditing && hasUnsavedChanges()) {
      // Trigger existing unsaved changes guard
      const { navigationGuard } = useUIStore.getState();
      if (navigationGuard) {
        const canNavigate = await navigationGuard();
        if (!canNavigate) return;
      }
    }
    navigateToParent();
  };

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      handleClose();
    }
  };

  return (
    <>
      <div
        className="fixed inset-0 bg-black/50 flex items-center justify-center p-0 md:p-4 z-50"
        onClick={handleBackdropClick}
      >
      <div
        className="w-full h-full md:h-auto md:max-w-[900px] md:min-h-[calc(100vh-2rem)] md:max-h-[calc(100vh-2rem)] bg-dark-bg md:border md:border-dark-border md:rounded-lg flex flex-col overflow-hidden relative"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="px-4 py-3 md:px-6 md:py-4 border-b border-dark-border w-full flex-shrink-0">
          <div className={`flex justify-between ${isNewDoc ? "items-center" : "items-start"}`}>
            <div className="flex-1 pr-4">
              {isNewDoc ? (
                <div>
                  <input
                    ref={titleInputRef}
                    type="text"
                    value={editedTitle}
                    onChange={(e) => setEditedTitle(e.target.value)}
                    className="text-xl font-semibold text-dark-text bg-transparent border-none outline-none w-full"
                    placeholder="Add a title..."
                  />
                </div>
              ) : editingTitle ? (
                <div className="flex items-center gap-2 mb-2">
                  <input
                    ref={titleInputRef}
                    type="text"
                    value={editedTitle}
                    onChange={(e) => setEditedTitle(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        handleSaveTitle();
                      } else if (e.key === "Escape") {
                        setEditedTitle(doc?.title || "");
                        setEditingTitle(false);
                      }
                    }}
                    className="flex-1 text-xl font-semibold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none pb-1"
                  />
                  <button
                    type="button"
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={handleSaveTitle}
                    className="p-1.5 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
                    title="Save title"
                  >
                    <Check size={18} />
                  </button>
                </div>
              ) : (
                <div className="mb-2">
                  {doc?.key && (
                    <span className="text-xs font-mono text-dark-text-muted block mb-1">
                      {doc.key}
                    </span>
                  )}
                  <h2
                    onClick={() => setEditingTitle(true)}
                    className="text-xl font-semibold text-dark-text cursor-pointer hover:text-blue-400 transition-colors"
                    title="Click to edit"
                  >
                    {doc?.title || "Untitled"}
                  </h2>
                </div>
              )}
              {!isNewDoc && doc && doc.createdBy && (
                <div className="text-sm text-dark-text-muted">
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
            <div className="flex items-center gap-1">
              {!hideMobileHeaderActions && (
                <>
                  {isEditing && !isNewDoc && hasUnsavedChanges() && (
                    <span
                      className="w-2 h-2 min-w-[0.5rem] min-h-[0.5rem] rounded-full bg-amber-500 animate-pulse mr-1"
                      title="Unsaved changes"
                    ></span>
                  )}
                  {isNewDoc ? (
                    <>
                      <button
                        onClick={handleSave}
                        disabled={!editedTitle.trim()}
                        className="text-green-500 hover:text-green-400 transition-colors p-1 hover:bg-dark-surface rounded disabled:opacity-50"
                        title="Save"
                      >
                        <Check size={18} strokeWidth={3} />
                      </button>
                    </>
                  ) : (
                    <>
                      {isEditing ? (
                        <>
                          <button
                            onClick={handleCancelEdit}
                            className="text-dark-text-muted hover:text-dark-text transition-colors p-1 hover:bg-dark-surface rounded"
                            title="Cancel editing"
                          >
                            <X size={18} />
                          </button>
                          <button
                            onClick={handleSave}
                            className="text-green-500 hover:text-green-400 transition-colors p-1 hover:bg-dark-surface rounded"
                            title="Save"
                          >
                            <Check size={18} strokeWidth={3} />
                          </button>
                        </>
                      ) : (
                        <button
                          onClick={handleEnterEditMode}
                          className="text-dark-text-muted hover:text-dark-text transition-colors p-1 hover:bg-dark-surface rounded"
                          title="Edit content"
                        >
                          <Edit3 size={18} />
                        </button>
                      )}
                      <button
                        onClick={handleToggleStar}
                        className="text-dark-text-muted hover:text-yellow-400 transition-colors p-1 hover:bg-dark-surface rounded"
                        title={doc?.starred ? "Unstar" : "Star"}
                      >
                        <Star
                          size={18}
                          className={
                            doc?.starred
                              ? "fill-yellow-400 text-yellow-400"
                              : ""
                          }
                        />
                      </button>
                      <button
                        onClick={() => setShowDeleteConfirm(true)}
                        className="text-dark-text-muted hover:text-red-400 transition-colors p-1 hover:bg-dark-surface rounded"
                        title="Delete doc"
                      >
                        <Trash2 size={18} />
                      </button>
                    </>
                  )}
                </>
              )}
              <button
                onClick={handleClose}
                className="text-dark-text-muted hover:text-dark-text transition-colors p-1 hover:bg-dark-surface rounded"
              >
                <X size={20} />
              </button>
            </div>
          </div>
        </div>

        <div
          className="flex-1 overflow-y-auto relative flex flex-col"
          ref={scrollContainerRef}
        >
          <div
            className="w-full bg-dark-bg"
          >
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
                  Open the menu and click Edit Content to start writing
                </p>
              </div>
            ) : (
              <RichTextEditor
                value={editedContent}
                onChange={(md) => {
                  if (isEditing) setEditedContent(md);
                }}
                editable={isEditing}
                placeholder="Start writing..."
                mentions={{ members: mentionMembers }}
                fileUpload={!isNewDoc && docId ? {
                  attachableType: "doc",
                  attachableId: docId,
                  onError: (msg) => error(msg),
                } : undefined}
                onReady={(handle) => {
                  editorHandleRef.current = handle;
                }}
                className="prose prose-invert prose-slate max-w-none [&_.milkdown_.editor]:p-4 [&_.milkdown_.editor]:md:p-6"
              />
            )}
          </div>

          {!isEditing && docId && !isNewDoc && (
            <div className="px-4 md:px-8 py-4 border-t border-dark-border">
              <SubscriptionSection itemType="doc" itemId={docId} />
            </div>
          )}

          {!isEditing && (
            <div className={`py-4 border-t border-dark-border w-full${topLevelComments.length === 0 ? " flex-1 flex flex-col justify-center" : ""}`}>
              {topLevelComments.length > 0 ? (
                <>
                  <h3 className="text-sm font-medium text-dark-text mb-4 px-4 md:px-6">
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
                            replyCount={replies.length}
                            onReplyCountClick={() => handleOpenThread(comment)}
                            fileUpload={docId ? {
                              attachableType: "doc",
                              attachableId: docId,
                              onError: (msg) => error(msg),
                            } : undefined}
                          />
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

        {!isEditing && (
          <div className="relative border-t border-dark-border bg-dark-surface w-full pb-[env(safe-area-inset-bottom)]">
            {showJumpToBottom && (
              <button
                onClick={handleJumpToBottom}
                className="absolute -top-12 right-4 p-2 rounded-full bg-dark-surface border border-dark-border text-dark-text-muted shadow-md hover:text-dark-text hover:bg-dark-hover transition-all z-10"
                title="Jump to bottom"
              >
                <ArrowDown size={16} />
              </button>
            )}
            <CommentEditor
              ref={commentEditorRef}
              value={newComment}
              onChange={setNewComment}
              onSubmit={handleAddComment}
              placeholder="Add a comment..."
              quotingMessage={quotingMessage}
              onCancelQuote={() => setQuotingMessage(null)}
              fileUpload={!isNewDoc && docId ? {
                attachableType: "doc",
                attachableId: docId,
                onError: (msg) => error(msg),
              } : undefined}
            />
          </div>
        )}
      </div>
      </div>

      {openThread && (
        <div className="fixed inset-0 z-[60] flex">
          <div className="flex-1 bg-black/20" onClick={handleCloseThread} />
          <DiscussionThread
            parentMessage={openThread}
            threadMessages={threadMessages}
            onClose={handleCloseThread}
            onSendReply={async (parentId, text, quoteId) => {
              if (!docId) return;
              await sendMessage("doc", docId, text, parentId, quoteId);
            }}
            fileUpload={docId ? {
              attachableType: "doc",
              attachableId: docId,
              onError: (msg) => error(msg),
            } : undefined}
          />
        </div>
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
    </>
  );
}
