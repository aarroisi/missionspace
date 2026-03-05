import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, CheckCheck } from "lucide-react";
import { clsx } from "clsx";
import { formatDistanceToNow } from "date-fns";
import { useNotificationStore } from "@/stores/notificationStore";
import { useWebPush } from "@/hooks/useWebPush";
import { Avatar } from "@/components/ui/Avatar";
import { useMemberProfile } from "@/contexts/MemberProfileContext";
import { Notification } from "@/types";
import { BellOff, BellRing } from "lucide-react";

export function UpdatesPage() {
  const navigate = useNavigate();
  const { openMemberProfile } = useMemberProfile();
  const {
    notifications,
    unreadCount,
    isLoading,
    hasMore,
    fetchNotifications,
    fetchUnreadCount,
    markAsRead,
    markAllAsRead,
  } = useNotificationStore();

  useEffect(() => {
    fetchUnreadCount();
    fetchNotifications();
  }, [fetchUnreadCount, fetchNotifications]);

  const handleNotificationClick = async (notification: Notification) => {
    if (!notification.read) {
      await markAsRead(notification.id);
    }

    const context = notification.context as Record<string, string>;
    const messageId = notification.latestMessageId || notification.entityId;

    if (notification.itemType) {
      switch (notification.itemType) {
        case "channel":
          navigate(`/channels/${notification.itemId}?comment=${messageId}`);
          return;
        case "dm":
          navigate(`/dms/${notification.itemId}?comment=${messageId}`);
          return;
        case "task":
          if (context.boardId) {
            navigate(
              `/boards/${context.boardId}?task=${notification.itemId}&comment=${messageId}`,
            );
          }
          return;
        case "doc":
          navigate(`/docs/${notification.itemId}?comment=${messageId}`);
          return;
      }
    }

    switch (notification.entityType) {
      case "message":
        if (context.channelId) {
          navigate(`/channels/${context.channelId}?comment=${messageId}`);
        } else if (context.dmId) {
          navigate(`/dms/${context.dmId}?comment=${messageId}`);
        } else if (context.parentTaskId && context.taskId) {
          if (context.boardId) {
            navigate(
              `/boards/${context.boardId}?task=${context.parentTaskId}&comment=${messageId}`,
            );
          }
        } else if (context.taskId) {
          if (context.boardId) {
            navigate(
              `/boards/${context.boardId}?task=${context.taskId}&comment=${messageId}`,
            );
          }
        } else if (context.docId) {
          navigate(`/docs/${context.docId}?comment=${messageId}`);
        }
        break;
      case "doc":
        navigate(`/docs/${notification.entityId}?comment=${messageId}`);
        break;
      case "task":
        if (context.boardId) {
          navigate(
            `/boards/${context.boardId}?task=${context.taskId}&comment=${messageId}`,
          );
        }
        break;
    }
  };

  const getNotificationItemName = (notification: Notification): string => {
    const context = notification.context as Record<string, string>;

    if (notification.itemType) {
      switch (notification.itemType) {
        case "channel":
          return context.channelName ? `#${context.channelName}` : "a channel";
        case "task":
          return context.taskTitle || "a task";
        case "doc":
          return context.docTitle || "a document";
        case "dm":
          return context.dmName || "a conversation";
      }
    }

    if (notification.entityType === "message") {
      if (context.channelName) return `#${context.channelName}`;
      if (context.taskTitle) return context.taskTitle;
      if (context.docTitle) return context.docTitle;
      return "a message";
    } else if (notification.entityType === "doc") {
      return context.docTitle || "a document";
    } else if (notification.entityType === "task") {
      return context.taskTitle || "a task";
    }
    return "an item";
  };

  const getNotificationLabel = (notification: Notification): string => {
    const name = getNotificationItemName(notification);
    const count = notification.eventCount || 1;

    switch (notification.type) {
      case "mention":
        return `@mentioned you in ${name}`;
      case "comment":
        if (notification.itemType === "dm") {
          return count > 1
            ? `sent you ${count} messages`
            : `sent you a message`;
        }
        return count > 1
          ? `${count} new comments on ${name}`
          : `commented on ${name}`;
      case "thread_reply":
        return count > 1
          ? `${count} new replies in a thread`
          : `replied in a thread`;
      default:
        return name;
    }
  };

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-4 py-3 border-b border-dark-border flex-shrink-0">
        <h1 className="font-semibold text-dark-text">Updates</h1>
        <div className="flex items-center gap-2">
          <PushToggle />
          {unreadCount > 0 && (
            <button
              onClick={() => markAllAsRead()}
              className="text-xs text-blue-400 hover:text-blue-300 flex items-center gap-1"
            >
              <CheckCheck size={14} />
              Mark all read
            </button>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        {notifications.length === 0 && !isLoading ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <div className="w-12 h-12 rounded-full bg-dark-surface flex items-center justify-center mb-4">
              <Bell size={24} className="text-dark-text-muted" />
            </div>
            <p className="text-dark-text-muted text-sm">
              No notifications yet
            </p>
          </div>
        ) : (
          <>
            {notifications.map((notification) => (
              <button
                key={notification.id}
                onClick={() => handleNotificationClick(notification)}
                className={clsx(
                  "w-full flex items-start gap-3 px-4 py-3 text-left hover:bg-dark-border/50 transition-colors",
                  !notification.read && "bg-blue-500/5",
                )}
              >
                <div className="relative flex-shrink-0">
                  <span
                    className="inline-flex rounded-full"
                    onClick={(event) => {
                      event.stopPropagation();
                      if (notification.actorId) {
                        openMemberProfile(notification.actorId);
                      }
                    }}
                    title={`Open ${(notification.actorName || "member") + "'s"} profile`}
                  >
                    <Avatar
                      name={notification.actorName || "User"}
                      src={notification.actorAvatar}
                      size="sm"
                    />
                  </span>
                  {notification.type === "mention" && (
                    <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-yellow-500 rounded-full flex items-center justify-center text-[10px] font-bold text-black">
                      @
                    </div>
                  )}
                  {notification.type === "thread_reply" && (
                    <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-blue-500 rounded-full flex items-center justify-center text-[10px] font-bold text-white">
                      &#8617;
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-dark-text">
                    <span
                      className="font-medium hover:text-blue-400 transition-colors"
                      onClick={(event) => {
                        event.stopPropagation();
                        if (notification.actorId) {
                          openMemberProfile(notification.actorId);
                        }
                      }}
                      title={`Open ${(notification.actorName || "member") + "'s"} profile`}
                    >
                      {notification.actorName}
                    </span>{" "}
                    {getNotificationLabel(notification)}
                  </p>
                  <p className="text-xs text-dark-text-muted mt-1">
                    {formatDistanceToNow(new Date(notification.insertedAt), {
                      addSuffix: true,
                    })}
                  </p>
                </div>
                {!notification.read && (
                  <div className="w-2 h-2 rounded-full bg-blue-500 mt-2 flex-shrink-0" />
                )}
              </button>
            ))}

            {hasMore && (
              <button
                onClick={() => fetchNotifications(true)}
                disabled={isLoading}
                className="w-full px-4 py-3 text-sm text-blue-400 hover:text-blue-300 hover:bg-dark-border/50 transition-colors disabled:opacity-50"
              >
                {isLoading ? "Loading..." : "Load more"}
              </button>
            )}
          </>
        )}
      </div>
    </div>
  );
}

function PushToggle() {
  const { isSupported, isSubscribed, permission, isLoading, subscribe, unsubscribe } = useWebPush();

  if (!isSupported) return null;

  const handleClick = async () => {
    if (isSubscribed) {
      await unsubscribe();
    } else {
      await subscribe();
    }
  };

  const isDenied = permission === "denied";

  return (
    <button
      onClick={handleClick}
      disabled={isLoading || isDenied}
      className={clsx(
        "p-1 rounded transition-colors",
        isDenied
          ? "text-dark-text-muted/50 cursor-not-allowed"
          : isSubscribed
            ? "text-blue-400 hover:text-blue-300"
            : "text-dark-text-muted hover:text-dark-text",
      )}
      title={
        isDenied
          ? "Push notifications blocked in browser settings"
          : isSubscribed
            ? "Disable push notifications"
            : "Enable push notifications"
      }
    >
      {isSubscribed ? <BellRing size={14} /> : <BellOff size={14} />}
    </button>
  );
}
