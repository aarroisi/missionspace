import { useChannel } from "./useChannel";
import { useNotificationStore } from "@/stores/notificationStore";
import { useChatStore } from "@/stores/chatStore";
import { useAuthStore } from "@/stores/authStore";
import { Notification } from "@/types";

/**
 * Hook to connect to the user's notification channel and receive real-time notifications.
 * Should be used once at the app level when the user is authenticated.
 */
export function useNotificationChannel() {
  const { user } = useAuthStore();
  const { addNotification } = useNotificationStore();
  const { addUnread } = useChatStore();

  const topic = user ? `notifications:${user.id}` : "";

  useChannel(topic, (event, payload) => {
    if (event === "new_notification") {
      // Convert snake_case to camelCase for the notification
      const notification: Notification = {
        id: payload.id,
        type: payload.type,
        itemType: payload.item_type,
        itemId: payload.item_id,
        threadId: payload.thread_id,
        latestMessageId: payload.latest_message_id,
        eventCount: payload.event_count,
        entityType: payload.entity_type,
        entityId: payload.entity_id,
        context: payload.context,
        read: payload.read,
        userId: payload.user_id,
        actorId: payload.actor_id,
        actorName: payload.actor_name,
        actorAvatar: payload.actor_avatar,
        insertedAt: payload.inserted_at,
        updatedAt: payload.updated_at,
      };
      addNotification(notification);

      // Update unread indicators for channels/DMs
      const itemType = payload.item_type;
      const itemId = payload.item_id;
      if (itemType === "channel" || itemType === "dm") {
        addUnread(itemType, itemId);
      }
    }
  });
}
