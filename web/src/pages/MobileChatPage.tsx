import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Hash, Plus, Star } from "lucide-react";
import { clsx } from "clsx";
import { useChatStore } from "@/stores/chatStore";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Avatar } from "@/components/ui/Avatar";
import { CreateChannelModal } from "@/components/features/CreateChannelModal";

export function MobileChatPage() {
  const navigate = useNavigate();
  const channels = useChatStore((s) => s.channels) || [];
  const directMessages = useChatStore((s) => s.directMessages) || [];
  const unreadChannelIds = useChatStore((s) => s.unreadChannelIds);
  const unreadDmIds = useChatStore((s) => s.unreadDmIds);
  const createChannel = useChatStore((s) => s.createChannel);
  const createDirectMessage = useChatStore((s) => s.createDirectMessage);
  const currentUser = useAuthStore((s) => s.user);
  const workspaceMembers = useAuthStore((s) => s.members) || [];
  const { success, error } = useToastStore();
  const [showCreateChannelModal, setShowCreateChannelModal] = useState(false);

  // Build DM members list (existing DMs + other workspace members)
  const dmMembers = directMessages.map((dm) => ({
    id: dm.userId,
    name: dm.name,
    avatar: dm.avatar,
    online: dm.online,
    dmId: dm.id as string | null,
    starred: dm.starred,
  }));
  const dmUserIds = new Set(dmMembers.map((m) => m.id));
  const otherMembers = workspaceMembers
    .filter((m) => m.id !== currentUser?.id && !dmUserIds.has(m.id))
    .map((m) => ({
      id: m.id,
      name: m.name,
      avatar: m.avatar,
      online: m.online,
      dmId: null as string | null,
      starred: false,
    }));
  const allDmMembers = [...dmMembers, ...otherMembers];

  const handleStartDM = async (userId: string) => {
    try {
      const dm = await createDirectMessage(userId);
      navigate(`/dms/${dm.id}`);
    } catch (err) {
      error("Error: " + (err as Error).message);
    }
  };

  const handleCreateChannel = async (name: string) => {
    try {
      const channel = await createChannel(name);
      success("Channel created successfully");
      setShowCreateChannelModal(false);
      navigate(`/channels/${channel.id}`);
    } catch (err) {
      error("Error: " + (err as Error).message);
    }
  };

  const starredChannels = channels.filter((c) => c.starred);

  return (
    <div className="flex-1 flex flex-col">
      <div className="px-4 py-3 border-b border-dark-border flex items-center justify-between">
        <h1 className="text-lg font-semibold text-dark-text">Chat</h1>
        <button
          onClick={() => setShowCreateChannelModal(true)}
          className="p-2 text-dark-text-muted hover:text-dark-text transition-colors"
        >
          <Plus size={20} />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto">
        {/* Starred channels */}
        {starredChannels.length > 0 && (
          <>
            <div className="px-4 pt-3 pb-1 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center gap-1.5">
              <Star size={12} />
              Starred
            </div>
            {starredChannels.map((channel) => {
              const isUnread = unreadChannelIds.has(channel.id);
              return (
                <button
                  key={`starred-${channel.id}`}
                  onClick={() => navigate(`/channels/${channel.id}`)}
                  className={clsx(
                    "w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-dark-surface transition-colors",
                    isUnread && "font-semibold",
                  )}
                >
                  <Hash size={18} className="text-dark-text-muted flex-shrink-0" />
                  <span className="flex-1 truncate text-sm text-dark-text">{channel.name}</span>
                  {isUnread && (
                    <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
                  )}
                </button>
              );
            })}
          </>
        )}

        {/* Channels */}
        <div className="px-4 pt-3 pb-1 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
          Channels
        </div>
        {channels.length === 0 && (
          <div className="px-4 py-3 text-sm text-dark-text-muted">No channels yet</div>
        )}
        {channels.map((channel) => {
          const isUnread = unreadChannelIds.has(channel.id);
          return (
            <button
              key={channel.id}
              onClick={() => navigate(`/channels/${channel.id}`)}
              className={clsx(
                "w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-dark-surface transition-colors",
                isUnread && "font-semibold",
              )}
            >
              <Hash size={18} className="text-dark-text-muted flex-shrink-0" />
              <span className="flex-1 truncate text-sm text-dark-text">{channel.name}</span>
              {isUnread && (
                <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
              )}
            </button>
          );
        })}

        {/* Direct Messages */}
        <div className="px-4 pt-4 pb-1 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
          Direct Messages
        </div>
        {allDmMembers.length === 0 && (
          <div className="px-4 py-3 text-sm text-dark-text-muted">No conversations yet</div>
        )}
        {allDmMembers.map((member) => {
          const isUnread = member.dmId ? unreadDmIds.has(member.dmId) : false;
          return (
            <button
              key={member.id}
              onClick={() => {
                if (member.dmId) {
                  navigate(`/dms/${member.dmId}`);
                } else {
                  handleStartDM(member.id);
                }
              }}
              className={clsx(
                "w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-dark-surface transition-colors",
                isUnread && "font-semibold",
              )}
            >
              <Avatar name={member.name} src={member.avatar} size="xs" online={member.online} />
              <span className="flex-1 truncate text-sm text-dark-text">{member.name}</span>
              {isUnread && (
                <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
              )}
            </button>
          );
        })}
      </div>
      <CreateChannelModal
        isOpen={showCreateChannelModal}
        onClose={() => setShowCreateChannelModal(false)}
        onSubmit={handleCreateChannel}
      />
    </div>
  );
}
