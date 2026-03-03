import { useState, useRef, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import { Quote, ArrowDown } from "lucide-react";
import { Message } from "./Message";
import { CommentEditor } from "./CommentEditor";
import { Message as MessageType } from "@/types";

interface DiscussionViewProps {
  messages: MessageType[];
  onSendMessage: (text: string, quoteId?: string) => Promise<void>;
  onSendReply: (
    parentId: string,
    text: string,
    quoteId?: string,
  ) => Promise<void>;
  placeholder?: string;
  emptyStateTitle?: string;
  emptyStateDescription?: string;
  showJumpToBottom?: boolean;
  className?: string;
  openThread?: MessageType | null;
  onOpenThread?: (message: MessageType | null) => void;
  hasMoreMessages?: boolean;
  onLoadMore?: () => void;
  isLoadingMore?: boolean;
  highlightCommentId?: string | null;
  lastReadAt?: string | null;
  fileUpload?: {
    attachableType: string;
    attachableId: string;
    onError: (msg: string) => void;
  };
}

export function DiscussionView({
  messages,
  onSendMessage,
  onSendReply: _onSendReply,
  placeholder = "Add a comment...",
  emptyStateTitle = "No comments yet",
  emptyStateDescription = "Be the first to add one below.",
  showJumpToBottom = true,
  className: _className = "",
  openThread: _externalOpenThread,
  onOpenThread,
  hasMoreMessages = false,
  onLoadMore,
  isLoadingMore = false,
  highlightCommentId,
  lastReadAt,
  fileUpload,
}: DiscussionViewProps) {
  const [_internalOpenThread, _setInternalOpenThread] =
    useState<MessageType | null>(null);
  const setOpenThread = onOpenThread || _setInternalOpenThread;
  const [quotingMessage, setQuotingMessage] = useState<MessageType | null>(
    null,
  );
  const [newComment, setNewComment] = useState("");
  const [showJumpButton, setShowJumpButton] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement>(null);

  // Messages are expected in asc order (oldest first) for display
  const topLevelMessages = messages.filter((m) => !m.parentId);
  const threadMessages = messages.filter((m) => m.parentId);

  // Find index of first unread message for the "new messages" divider
  const newMessagesDividerRef = useRef<HTMLDivElement>(null);
  const firstUnreadIndex = (() => {
    if (!lastReadAt) return -1;
    const readTime = new Date(lastReadAt).getTime();
    return topLevelMessages.findIndex(
      (m) => new Date(m.insertedAt).getTime() > readTime,
    );
  })();

  // Scroll to divider or bottom on initial load
  const hasScrolledRef = useRef(false);
  useEffect(() => {
    if (topLevelMessages.length > 0 && !hasScrolledRef.current) {
      hasScrolledRef.current = true;
      setTimeout(() => {
        if (newMessagesDividerRef.current) {
          newMessagesDividerRef.current.scrollIntoView({ block: "center" });
        } else if (scrollContainerRef.current) {
          scrollContainerRef.current.scrollTop =
            scrollContainerRef.current.scrollHeight;
        }
      }, 50);
    }
  }, [topLevelMessages.length]);

  // Scroll to and highlight comment if highlightCommentId is provided
  const [, setSearchParams] = useSearchParams();
  const highlightedRef = useRef<string | null>(null);

  useEffect(() => {
    if (highlightCommentId && messages.length > 0 && highlightedRef.current !== highlightCommentId) {
      highlightedRef.current = highlightCommentId;
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
        // Clear the comment param from the URL so it doesn't re-trigger
        setSearchParams((prev) => {
          const next = new URLSearchParams(prev);
          next.delete("comment");
          return next;
        }, { replace: true });
      }, 300);
    }
  }, [highlightCommentId, messages.length, setSearchParams]);

  const getThreadReplies = (messageId: string) => {
    return threadMessages.filter((m) => m.parentId === messageId);
  };

  const handleQuotedClick = (messageId: string) => {
    const messageElement = document.getElementById(`message-${messageId}`);
    if (messageElement) {
      messageElement.scrollIntoView({ behavior: "smooth", block: "center" });
      messageElement.classList.add("ring-2", "ring-blue-500/50");
      setTimeout(() => {
        messageElement.classList.remove("ring-2", "ring-blue-500/50");
      }, 2000);
    }
  };

  const handleQuote = (message: MessageType) => {
    setQuotingMessage(message);
  };

  const handleAddComment = async () => {
    // Check for empty content - strip HTML tags to check actual text
    const textContent = newComment.replace(/<[^>]*>/g, "").trim();
    if (!textContent) return;
    try {
      await onSendMessage(newComment, quotingMessage?.id);
      setNewComment("");
      setQuotingMessage(null);

      // Scroll to bottom after comment is added
      setTimeout(() => {
        if (scrollContainerRef.current) {
          scrollContainerRef.current.scrollTo({
            top: scrollContainerRef.current.scrollHeight,
            behavior: "smooth",
          });
        }
      }, 100);
    } catch (err) {
      console.error("Failed to add comment:", err);
    }
  };

  const handleJumpToBottom = () => {
    if (scrollContainerRef.current) {
      scrollContainerRef.current.scrollTo({
        top: scrollContainerRef.current.scrollHeight,
        behavior: "smooth",
      });
    }
  };

  // Monitor scroll position
  useEffect(() => {
    if (!showJumpToBottom) return;

    const scrollContainer = scrollContainerRef.current;
    if (!scrollContainer) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
      const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
      setShowJumpButton(distanceFromBottom > 200);
    };

    scrollContainer.addEventListener("scroll", handleScroll);
    handleScroll();

    return () => scrollContainer.removeEventListener("scroll", handleScroll);
  }, [messages, showJumpToBottom]);

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="flex-1 overflow-y-auto relative" ref={scrollContainerRef}>
        <div className={`py-2 max-w-7xl mx-auto w-full ${topLevelMessages.length === 0 ? "min-h-full flex flex-col justify-center" : ""}`}>
          {hasMoreMessages && onLoadMore && (
            <div className="mb-4 flex justify-center">
              <button
                onClick={onLoadMore}
                disabled={isLoadingMore}
                className="px-4 py-2 text-sm text-blue-400 hover:text-blue-300 hover:bg-dark-surface rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isLoadingMore ? "Loading..." : "Load older messages"}
              </button>
            </div>
          )}
          {topLevelMessages.length > 0 ? (
            <div className="space-y-1">
              {topLevelMessages.map((message, index) => {
                const replies = getThreadReplies(message.id);
                const showDivider = index === firstUnreadIndex && index > 0;
                return (
                  <div key={message.id}>
                    {showDivider && (
                      <div
                        ref={newMessagesDividerRef}
                        className="flex items-center gap-3 my-3"
                      >
                        <div className="flex-1 h-px bg-red-500/40" />
                        <span className="text-xs text-red-400 font-medium whitespace-nowrap">
                          New messages
                        </span>
                        <div className="flex-1 h-px bg-red-500/40" />
                      </div>
                    )}
                    <div id={`message-${message.id}`}>
                      <Message
                        message={message}
                        onReply={() => setOpenThread(message)}
                        onQuote={() => handleQuote(message)}
                        onQuotedClick={handleQuotedClick}
                        replyCount={replies.length}
                        onReplyCountClick={() => setOpenThread(message)}
                        fileUpload={fileUpload}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <div className="w-12 h-12 rounded-full bg-dark-surface flex items-center justify-center mb-4">
                <Quote size={24} className="text-dark-text-muted" />
              </div>
              <p className="text-dark-text-muted text-sm font-medium mb-1">
                {emptyStateTitle}
              </p>
              <p className="text-dark-text-muted text-sm">
                {emptyStateDescription}
              </p>
            </div>
          )}
        </div>
      </div>

      <div className="relative border-t border-dark-border bg-dark-bg max-w-7xl mx-auto w-full">
        {showJumpToBottom && showJumpButton && (
          <button
            onClick={handleJumpToBottom}
            className="absolute -top-12 right-4 p-2 rounded-full bg-dark-surface border border-dark-border text-dark-text-muted shadow-md hover:text-dark-text hover:bg-dark-hover transition-all z-10"
            title="Jump to bottom"
          >
            <ArrowDown size={16} />
          </button>
        )}
        <CommentEditor
          value={newComment}
          onChange={setNewComment}
          onSubmit={handleAddComment}
          placeholder={placeholder}
          quotingMessage={quotingMessage}
          onCancelQuote={() => setQuotingMessage(null)}
          fileUpload={fileUpload}
        />
      </div>
    </div>
  );
}
