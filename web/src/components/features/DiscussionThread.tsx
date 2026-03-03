import { useState, useRef, useEffect } from "react";
import { X, Bell, BellOff } from "lucide-react";
import { Message } from "./Message";
import { CommentEditor } from "./CommentEditor";
import { useSubscriptionStore } from "@/stores/subscriptionStore";
import { Message as MessageType } from "@/types";

interface DiscussionThreadProps {
  parentMessage: MessageType;
  threadMessages: MessageType[];
  onClose: () => void;
  onSendReply: (
    parentId: string,
    text: string,
    quoteId?: string,
  ) => Promise<void>;
  fileUpload?: {
    attachableType: string;
    attachableId: string;
    onError: (msg: string) => void;
  };
}

function ThreadHeader({ parentMessageId, onClose }: { parentMessageId: string; onClose: () => void }) {
  const { subscriptionStatus, fetchStatus, subscribe, unsubscribe } = useSubscriptionStore();
  const k = `thread:${parentMessageId}`;
  const isSubscribed = subscriptionStatus[k] ?? false;

  useEffect(() => {
    fetchStatus("thread", parentMessageId);
  }, [parentMessageId, fetchStatus]);

  const handleToggle = async () => {
    if (isSubscribed) {
      await unsubscribe("thread", parentMessageId);
    } else {
      await subscribe("thread", parentMessageId);
    }
  };

  return (
    <div className="px-4 py-3 border-b border-dark-border flex items-center justify-between">
      <h3 className="font-semibold text-dark-text">Thread</h3>
      <div className="flex items-center gap-2">
        <button
          onClick={handleToggle}
          className={`p-1.5 rounded transition-colors ${
            isSubscribed
              ? "text-blue-400 hover:text-red-400 hover:bg-red-500/10"
              : "text-dark-text-muted hover:text-blue-400 hover:bg-blue-500/10"
          }`}
          title={isSubscribed ? "Unsubscribe from thread" : "Subscribe to thread"}
        >
          {isSubscribed ? <Bell size={16} /> : <BellOff size={16} />}
        </button>
        <button
          onClick={onClose}
          className="text-dark-text-muted hover:text-dark-text transition-colors"
        >
          <X size={20} />
        </button>
      </div>
    </div>
  );
}

export function DiscussionThread({
  parentMessage,
  threadMessages,
  onClose,
  onSendReply,
  fileUpload,
}: DiscussionThreadProps) {
  const [replyText, setReplyText] = useState("");
  const [quoteTarget, setQuoteTarget] = useState<MessageType | null>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const replyTextareaRef = useRef<HTMLTextAreaElement>(null);

  // Focus textarea when parent message changes (switching threads)
  useEffect(() => {
    setTimeout(() => {
      replyTextareaRef.current?.focus();
    }, 100);
  }, [parentMessage.id]);

  const handleSendReply = async () => {
    // Check for empty content - strip HTML tags to check actual text
    const textContent = replyText.replace(/<[^>]*>/g, "").trim();
    if (!textContent) return;

    try {
      await onSendReply(parentMessage.id, replyText, quoteTarget?.id);
      setReplyText("");
      setQuoteTarget(null);

      // Scroll to bottom after sending
      setTimeout(() => {
        if (scrollContainerRef.current) {
          scrollContainerRef.current.scrollTo({
            top: scrollContainerRef.current.scrollHeight,
            behavior: "smooth",
          });
        }
      }, 100);
    } catch (error) {
      console.error("Failed to send reply:", error);
    }
  };

  const allMessages = threadMessages.filter(
    (m) => m.parentId === parentMessage.id,
  );
  const quotedMessages = allMessages.reduce(
    (acc, msg) => {
      if (msg.quoteId) {
        const quoted = [parentMessage, ...allMessages].find(
          (m) => m.id === msg.quoteId,
        );
        if (quoted) {
          acc[msg.id] = quoted;
        }
      }
      return acc;
    },
    {} as Record<string, MessageType>,
  );

  return (
    <>
      {/* Backdrop for mobile/tablet */}
      <div
        className="absolute inset-0 bg-black/50 z-40 lg:hidden"
        onClick={onClose}
      />

      <div className="absolute lg:relative top-0 right-0 bottom-0 w-[calc(100%-15rem)] lg:w-[28rem] bg-dark-surface border-l border-dark-border flex flex-col z-50">
        <ThreadHeader parentMessageId={parentMessage.id} onClose={onClose} />

        <div className="flex-1 overflow-y-auto" ref={scrollContainerRef}>
          <Message
            message={parentMessage}
            className="border-b border-dark-border"
            fileUpload={fileUpload}
          />

          <div className="px-4 py-2 text-xs font-semibold text-dark-text-muted uppercase">
            {allMessages.length}{" "}
            {allMessages.length === 1 ? "Reply" : "Replies"}
          </div>

          {allMessages.map((message) => (
            <Message
              key={message.id}
              message={message}
              quotedMessage={quotedMessages[message.id]}
              onQuote={() => setQuoteTarget(message)}
              fileUpload={fileUpload}
            />
          ))}
        </div>

        <div className="p-4 border-t border-dark-border">
          <CommentEditor
            ref={replyTextareaRef}
            value={replyText}
            onChange={setReplyText}
            onSubmit={handleSendReply}
            placeholder="Reply to thread..."
            quotingMessage={quoteTarget}
            onCancelQuote={() => setQuoteTarget(null)}
            autoFocus
            variant="thread"
            fileUpload={fileUpload}
          />
        </div>
      </div>
    </>
  );
}
