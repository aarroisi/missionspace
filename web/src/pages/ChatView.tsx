import { useEffect, useState, useRef } from "react";
import {
  useParams,
  useLocation,
  useNavigate,
  useSearchParams,
} from "react-router-dom";
import { MoreHorizontal, Star, Trash2, Pencil, Check, Users } from "lucide-react";
import { MobileBackButton } from "@/components/ui/MobileBackButton";
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { DiscussionView } from "@/components/features/DiscussionView";
import { DiscussionThread } from "@/components/features/DiscussionThread";
import { ManageMembersModal } from "@/components/features/ManageMembersModal";
import { Avatar } from "@/components/ui/Avatar";
import { useChatStore } from "@/stores/chatStore";
import { useUIStore } from "@/stores/uiStore";
import { useToastStore } from "@/stores/toastStore";
import { useChannel } from "@/hooks/useChannel";
import { SubscriptionSection } from "@/components/features/SubscriptionSection";
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
    fetchChannels,
    fetchDirectMessages,
    fetchMessages,
    sendMessage,
    addMessage,
    hasMoreMessages,
    deleteChannel,
    updateChannel,
    toggleChannelStar,
    markAsRead,
    lastReadAt,
    fetchLastReadAt,
    clearLastReadAt,
  } = useChatStore();
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showMembersModal, setShowMembersModal] = useState(false);
  const [isRenaming, setIsRenaming] = useState(false);
  const [renameValue, setRenameValue] = useState("");
  const renameInputRef = useRef<HTMLInputElement>(null);
  const { success, error: toastError } = useToastStore();

  // Determine entity type from URL path
  const entityType = location.pathname.includes("/channels")
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

  // Fetch channels/DMs if not loaded (e.g. direct URL navigation)
  useEffect(() => {
    if (entityType === "channel" && (!Array.isArray(channels) || channels.length === 0)) {
      fetchChannels();
    }
    if (entityType === "dm" && (!Array.isArray(directMessages) || directMessages.length === 0)) {
      fetchDirectMessages();
    }
  }, [entityType, channels, directMessages, fetchChannels, fetchDirectMessages]);

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
      // Fetch last read position BEFORE marking as read, so we know where to show the divider
      fetchLastReadAt(entityType, entityId).then(() => {
        markAsRead(entityType, entityId);
      });
    }
    return () => {
      if (entityId) {
        clearLastReadAt(entityType, entityId);
      }
    };
  }, [entityId, entityType, fetchMessages, fetchLastReadAt, markAsRead, clearLastReadAt]);

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

  const slugify = (text: string): string => {
    return text
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "");
  };

  const handleStartRename = () => {
    if (!item) return;
    setRenameValue(item.name);
    setIsRenaming(true);
    setTimeout(() => renameInputRef.current?.focus(), 50);
  };

  const handleRename = async () => {
    if (!item || !entityId) return;
    const slugged = slugify(renameValue);
    if (!slugged) {
      setIsRenaming(false);
      return;
    }
    if (slugged !== item.name) {
      try {
        await updateChannel(entityId, { name: slugged });
        success("Channel renamed");
      } catch (err) {
        toastError("Error: " + (err as Error).message);
      }
    }
    setIsRenaming(false);
  };

  const handleRenameKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      handleRename();
    } else if (e.key === "Escape") {
      setIsRenaming(false);
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
    <>
      <div className="flex-1 flex flex-col overflow-hidden">
        <div className="px-4 py-3 md:px-6 md:py-4 border-b border-dark-border flex items-center justify-between">
          <div className="flex items-center gap-2 min-w-0">
          <MobileBackButton to={projectId ? `/projects/${projectId}` : "/channels"} />
          {isRenaming ? (
            <div className="flex items-center gap-2">
              <span className="text-lg md:text-2xl font-bold text-dark-text-muted">#</span>
              <input
                ref={renameInputRef}
                type="text"
                value={renameValue}
                onChange={(e) => setRenameValue(slugify(e.target.value))}
                onKeyDown={handleRenameKeyDown}
                onBlur={handleRename}
                className="text-lg md:text-2xl font-bold text-dark-text bg-transparent border-b-2 border-blue-500 focus:outline-none"
              />
              <button
                onClick={handleRename}
                className="p-1.5 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
                title="Save"
              >
                <Check size={18} />
              </button>
            </div>
          ) : entityType === "dm" ? (
            <div className="flex items-center gap-3">
              <Avatar name={item.name} src={"avatar" in item ? item.avatar : undefined} size="sm" online={"online" in item && item.online} />
              <h1 className="text-lg md:text-2xl font-bold text-dark-text">
                {item.name}
              </h1>
            </div>
          ) : (
            <h1
              className="text-lg md:text-2xl font-bold text-dark-text cursor-pointer hover:text-blue-400 transition-colors"
              onClick={handleStartRename}
              title="Click to rename"
            >
              # {item.name}
            </h1>
          )}
          </div>
          <div className="flex items-center gap-3">
            {entityType === "channel" && entityId && (
              <SubscriptionSection itemType="channel" itemId={entityId} />
            )}
          {entityType === "channel" && !isRenaming && (
            <Dropdown
              align="right"
              trigger={
                <button className="p-2 rounded transition-colors text-dark-text-muted hover:bg-dark-surface">
                  <MoreHorizontal size={18} />
                </button>
              }
            >
              {!projectId && (
                <DropdownItem onClick={() => setShowMembersModal(true)}>
                  <span className="flex items-center gap-2">
                    <Users size={16} />
                    Members
                  </span>
                </DropdownItem>
              )}
              <DropdownItem onClick={handleStartRename}>
                <span className="flex items-center gap-2">
                  <Pencil size={16} />
                  Rename
                </span>
              </DropdownItem>
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
          lastReadAt={entityId ? lastReadAt[`${entityType}:${entityId}`] : undefined}
          fileUpload={entityId ? {
            attachableType: entityType,
            attachableId: entityId,
            onError: (msg) => toastError(msg),
          } : undefined}
        />
      </div>

      {openThread && (
        <div className="fixed inset-0 z-[60] flex">
          <div className="flex-1 bg-black/20" onClick={() => setOpenThread(null)} />
          <DiscussionThread
            parentMessage={openThread}
            threadMessages={threadMessages}
            onClose={() => setOpenThread(null)}
            onSendReply={handleSendReply}
            fileUpload={entityId ? {
              attachableType: entityType,
              attachableId: entityId,
              onError: (msg) => toastError(msg),
            } : undefined}
          />
        </div>
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

      {/* Members Modal (standalone channels only, not project items) */}
      {entityType === "channel" && !projectId && entityId && (
        <ManageMembersModal
          itemKind="channel"
          itemId={entityId}
          isOpen={showMembersModal}
          onClose={() => setShowMembersModal(false)}
        />
      )}
    </>
  );
}
