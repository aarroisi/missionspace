import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, CheckCheck } from "lucide-react";
import { clsx } from "clsx";
import { formatDistanceToNow } from "date-fns";
import { useNotificationStore } from "@/stores/notificationStore";
import { Avatar } from "@/components/ui/Avatar";
import { Notification } from "@/types";

export function NotificationBell() {
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);

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

  // Fetch unread count on mount
  useEffect(() => {
    fetchUnreadCount();
  }, [fetchUnreadCount]);

  // Fetch notifications when menu opens
  useEffect(() => {
    if (isOpen) {
      fetchNotifications();
    }
  }, [isOpen, fetchNotifications]);

  // Handle click outside to close menu
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (
        menuRef.current &&
        !menuRef.current.contains(event.target as Node) &&
        buttonRef.current &&
        !buttonRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
      return () =>
        document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [isOpen]);

  const handleNotificationClick = async (notification: Notification) => {
    // Mark as read if unread
    if (!notification.read) {
      await markAsRead(notification.id);
    }

    // Navigate to the relevant item based on entity type and context
    // The entityId for mention notifications is the message ID
    const context = notification.context as Record<string, string>;
    const messageId = notification.entityId;

    switch (notification.entityType) {
      case "message":
        // Messages have context with the parent entity info
        if (context.channelId) {
          navigate(`/channels/${context.channelId}?comment=${messageId}`);
        } else if (context.dmId) {
          navigate(`/dms/${context.dmId}?comment=${messageId}`);
        } else if (context.subtaskId && context.taskId) {
          if (context.boardId) {
            navigate(
              `/boards/${context.boardId}?task=${context.taskId}&subtask=${context.subtaskId}&comment=${messageId}`,
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
      case "subtask":
        if (context.boardId && context.taskId) {
          navigate(
            `/boards/${context.boardId}?task=${context.taskId}&subtask=${context.subtaskId}&comment=${messageId}`,
          );
        }
        break;
    }

    setIsOpen(false);
  };

  const getNotificationItemName = (notification: Notification): string => {
    const context = notification.context as Record<string, string>;

    if (notification.entityType === "message") {
      if (context.channelName) {
        return `#${context.channelName}`;
      } else if (context.subtaskTitle) {
        return context.subtaskTitle;
      } else if (context.taskTitle) {
        return context.taskTitle;
      } else if (context.docTitle) {
        return context.docTitle;
      }
      return "a message";
    } else if (notification.entityType === "doc") {
      return context.docTitle || "a document";
    } else if (notification.entityType === "task") {
      return context.taskTitle || "a task";
    } else if (notification.entityType === "subtask") {
      return context.subtaskTitle || "a subtask";
    }
    return "an item";
  };

  return (
    <div className="relative">
      <button
        ref={buttonRef}
        onClick={() => setIsOpen(!isOpen)}
        className={clsx(
          "w-10 h-10 rounded-lg flex items-center justify-center transition-colors relative",
          isOpen
            ? "bg-dark-surface text-dark-text"
            : "text-dark-text-muted hover:bg-dark-surface hover:text-dark-text",
        )}
        title="Notifications"
      >
        <Bell size={20} />
        {unreadCount > 0 && (
          <span className="absolute top-1 right-1 w-2.5 h-2.5 bg-red-500 rounded-full" />
        )}
      </button>

      {isOpen && (
        <div
          ref={menuRef}
          className="absolute left-full ml-2 bottom-0 w-80 bg-dark-surface border border-dark-border rounded-lg shadow-xl z-50 overflow-hidden"
        >
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-dark-border">
            <h3 className="font-medium text-dark-text">Notifications</h3>
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

          {/* Notification list */}
          <div className="max-h-96 overflow-y-auto">
            {notifications.length === 0 && !isLoading ? (
              <div className="px-4 py-8 text-center text-dark-text-muted">
                No notifications yet
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
                      <Avatar
                        name={notification.actorName || "User"}
                        size="sm"
                      />
                      {notification.type === "mention" && (
                        <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-yellow-500 rounded-full flex items-center justify-center text-[10px] font-bold text-black">
                          @
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        {notification.type === "mention" && (
                          <span className="px-2 py-0.5 bg-yellow-500/20 text-yellow-400 text-xs font-medium rounded">
                            @mentioned you in:
                          </span>
                        )}
                        <span className="text-sm font-medium text-dark-text truncate">
                          {getNotificationItemName(notification)}
                        </span>
                      </div>
                      <p className="text-xs text-dark-text-muted mt-1">
                        {notification.actorName} &middot;{" "}
                        {formatDistanceToNow(
                          new Date(notification.insertedAt),
                          {
                            addSuffix: true,
                          },
                        )}
                      </p>
                    </div>
                    {!notification.read && (
                      <div className="w-2 h-2 rounded-full bg-blue-500 mt-2 flex-shrink-0" />
                    )}
                  </button>
                ))}

                {/* Load more */}
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
      )}
    </div>
  );
}
