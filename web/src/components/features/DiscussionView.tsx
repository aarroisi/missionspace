import { useState, useRef, useEffect } from "react";
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

  // Backend returns messages in desc order (newest first), reverse for chat display (oldest first)
  const sortedMessages = [...messages].reverse();
  const topLevelMessages = sortedMessages.filter((m) => !m.parentId);
  const threadMessages = sortedMessages.filter((m) => m.parentId);

  // Scroll to and highlight comment if highlightCommentId is provided
  useEffect(() => {
    if (highlightCommentId && sortedMessages.length > 0) {
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
  }, [highlightCommentId, sortedMessages.length]);

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
        <div className="px-8 py-6 max-w-7xl mx-auto w-full">
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
              {topLevelMessages.map((message) => {
                const replies = getThreadReplies(message.id);
                return (
                  <div key={message.id} id={`message-${message.id}`}>
                    <Message
                      message={message}
                      onReply={() => setOpenThread(message)}
                      onQuote={() => handleQuote(message)}
                      onQuotedClick={handleQuotedClick}
                    />
                    {replies.length > 0 && (
                      <button
                        onClick={() => setOpenThread(message)}
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

      {/* Jump to bottom button */}
      {showJumpToBottom && showJumpButton && (
        <button
          onClick={handleJumpToBottom}
          className="absolute right-8 p-3 rounded-full bg-blue-600 text-white shadow-lg hover:bg-blue-700 transition-all z-10"
          style={{ bottom: quotingMessage ? "200px" : "140px" }}
          title="Jump to bottom"
        >
          <ArrowDown size={20} />
        </button>
      )}

      <div className="border-t border-dark-border bg-dark-bg p-4 max-w-7xl mx-auto w-full">
        <CommentEditor
          value={newComment}
          onChange={setNewComment}
          onSubmit={handleAddComment}
          placeholder={placeholder}
          quotingMessage={quotingMessage}
          onCancelQuote={() => setQuotingMessage(null)}
        />
      </div>
    </div>
  );
}
