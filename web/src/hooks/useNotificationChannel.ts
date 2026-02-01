import { useChannel } from "./useChannel";
import { useNotificationStore } from "@/stores/notificationStore";
import { useAuthStore } from "@/stores/authStore";
import { Notification } from "@/types";

/**
 * Hook to connect to the user's notification channel and receive real-time notifications.
 * Should be used once at the app level when the user is authenticated.
 */
export function useNotificationChannel() {
  const { user } = useAuthStore();
  const { addNotification } = useNotificationStore();

  const topic = user ? `notifications:${user.id}` : "";

  useChannel(topic, (event, payload) => {
    if (event === "new_notification") {
      // Convert snake_case to camelCase for the notification
      const notification: Notification = {
        id: payload.id,
        type: payload.type,
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
    }
  });
}
