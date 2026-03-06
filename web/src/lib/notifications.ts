import { Notification } from "@/types";

export function getNotificationActivityAt(notification: Notification): string {
  return notification.updatedAt || notification.insertedAt;
}
