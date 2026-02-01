import { useEffect, useState } from "react";
import {
  useParams,
  useLocation,
  useNavigate,
  useSearchParams,
} from "react-router-dom";
import { MoreHorizontal, Star, Trash2 } from "lucide-react";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { DiscussionView } from "@/components/features/DiscussionView";
import { DiscussionThread } from "@/components/features/DiscussionThread";
import { useChatStore } from "@/stores/chatStore";
import { useUIStore } from "@/stores/uiStore";
import { useChannel } from "@/hooks/useChannel";
import { Message as MessageType } from "@/types";

export function ChatView() {
  const { id, projectId } = useParams<{ id: string; projectId?: string }>();
  const location = useLocation();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const highlightCommentId = searchParams.get("comment");
  const { setActiveItem } = useUIStore();
  const [openThread, setOpenThread] = useState<MessageType | null>(null);
  const {
    channels,
    directMessages,
    messages,
    fetchMessages,
    sendMessage,
    addMessage,
    hasMoreMessages,
    deleteChannel,
    toggleChannelStar,
  } = useChatStore();
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  // Determine entity type from URL path
  const entityType = location.pathname.startsWith("/channels")
    ? "channel"
    : "dm";
  const entityId = id;
  const item =
    entityType === "channel"
      ? Array.isArray(channels)
        ? channels.find((c) => c.id === entityId)
        : undefined
      : Array.isArray(directMessages)
        ? directMessages.find((d) => d.id === entityId)
        : undefined;

  // Set active item when component mounts or ID changes
  useEffect(() => {
    if (entityId && item) {
      setActiveItem({
        type: entityType === "channel" ? "channels" : "dms",
        id: entityId,
      });
    }
  }, [entityId, entityType, item, setActiveItem]);

  const rawChatMessages = entityId
    ? messages[`${entityType}:${entityId}`]
    : undefined;
  const validMessages = Array.isArray(rawChatMessages) ? rawChatMessages : [];
  // Backend returns messages in desc order (newest first), reverse for chat display (oldest first)
  const chatMessages = [...validMessages].reverse();

  // Subscribe to channel for real-time updates
  useChannel(entityId ? `${entityType}:${entityId}` : "", (event, payload) => {
    if (event === "new_message") {
      addMessage(payload);
    }
  });

  useEffect(() => {
    if (entityId) {
      fetchMessages(entityType, entityId);
    }
  }, [entityId, entityType, fetchMessages]);

  const handleSendMessage = async (text: string, quoteId?: string) => {
    if (!entityId) return;
    await sendMessage(entityType, entityId, text, undefined, quoteId);
  };

  const handleSendReply = async (
    parentId: string,
    text: string,
    quoteId?: string,
  ) => {
    if (!entityId) return;
    await sendMessage(entityType, entityId, text, parentId, quoteId);
  };

  const handleLoadMore = async () => {
    if (!entityId || isLoadingMore) return;
    setIsLoadingMore(true);
    try {
      await fetchMessages(entityType, entityId, true);
    } finally {
      setIsLoadingMore(false);
    }
  };

  const handleToggleStar = async () => {
    if (!item || entityType !== "channel") return;
    await toggleChannelStar(item.id);
  };

  const handleDeleteChannel = async () => {
    if (!item || entityType !== "channel") return;
    await deleteChannel(item.id);
    // Navigate back to project if channel was inside a project, otherwise to channels list
    if (projectId) {
      navigate(`/projects/${projectId}`);
    } else {
      navigate("/channels");
    }
  };

  if (!item) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <p className="text-dark-text-muted">
          Select a {entityType === "channel" ? "channel" : "conversation"} to
          view messages
        </p>
      </div>
    );
  }

  const threadMessages = chatMessages.filter((m) => m.parentId);

  return (
    <div className="flex-1 flex overflow-hidden">
      <div className="flex-1 flex flex-col overflow-hidden">
        <div className="px-6 py-4 border-b border-dark-border flex items-center justify-between">
          <h1 className="text-2xl font-bold text-dark-text">
            {entityType === "channel" ? "#" : ""} {item.name}
          </h1>
          {entityType === "channel" && (
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
                      "starred" in item && item.starred
                        ? "fill-yellow-400 text-yellow-400"
                        : ""
                    }
                  />
                  {"starred" in item && item.starred ? "Unstar" : "Star"}
                </span>
              </DropdownItem>
              <DropdownItem
                variant="danger"
                onClick={() => setShowDeleteConfirm(true)}
              >
                <span className="flex items-center gap-2">
                  <Trash2 size={16} />
                  Delete Channel
                </span>
              </DropdownItem>
            </Dropdown>
          )}
        </div>

        <DiscussionView
          messages={chatMessages}
          onSendMessage={handleSendMessage}
          onSendReply={handleSendReply}
          placeholder={`Message ${item.name}`}
          emptyStateTitle={`No messages in ${entityType === "channel" ? "#" : ""}${item.name} yet`}
          emptyStateDescription="Be the first to send a message."
          openThread={openThread}
          onOpenThread={setOpenThread}
          hasMoreMessages={
            entityId ? hasMoreMessages(entityType, entityId) : false
          }
          onLoadMore={handleLoadMore}
          isLoadingMore={isLoadingMore}
          highlightCommentId={highlightCommentId}
        />
      </div>

      {openThread && (
        <DiscussionThread
          parentMessage={openThread}
          threadMessages={threadMessages}
          onClose={() => setOpenThread(null)}
          onSendReply={handleSendReply}
        />
      )}

      {/* Delete Confirmation Modal */}
      <ConfirmModal
        isOpen={showDeleteConfirm}
        title="Delete Channel"
        message={`Are you sure you want to delete "#${item?.name}"? This action cannot be undone.`}
        confirmText="Delete"
        confirmVariant="danger"
        onConfirm={handleDeleteChannel}
        onCancel={() => setShowDeleteConfirm(false)}
      />
    </div>
  );
}
