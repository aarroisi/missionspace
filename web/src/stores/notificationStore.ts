import { create } from "zustand";
import { Notification, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;
  isOpen: boolean;

  // Operations
  open: () => void;
  close: () => void;
  fetchNotifications: (loadMore?: boolean) => Promise<void>;
  fetchUnreadCount: () => Promise<void>;
  markAsRead: (id: string) => Promise<void>;
  markAllAsRead: () => Promise<void>;
  addNotification: (notification: Notification) => void;
}

function upsertNotification(
  notifications: Notification[],
  notification: Notification,
): Notification[] {
  return [
    notification,
    ...notifications.filter((existing) => existing.id !== notification.id),
  ];
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  notifications: [],
  unreadCount: 0,
  isLoading: false,
  hasMore: true,
  afterCursor: null,
  isOpen: false,

  open: () => set({ isOpen: true }),
  close: () => set({ isOpen: false }),

  fetchNotifications: async (loadMore = false) => {
    const { afterCursor, isLoading } = get();

    if (isLoading || (loadMore && !afterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && afterCursor) {
        params.after = afterCursor;
      }

      const response = await api.get<PaginatedResponse<Notification>>(
        "/notifications",
        params,
      );

      set((state) => ({
        notifications: loadMore
          ? [...state.notifications, ...response.data]
          : response.data,
        afterCursor: response.metadata.after,
        hasMore: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch notifications:", error);
      set({ isLoading: false, hasMore: false });
    }
  },

  fetchUnreadCount: async () => {
    try {
      const response = await api.get<{ count: number }>(
        "/notifications/unread-count",
      );
      set({ unreadCount: response.count });
    } catch (error) {
      console.error("Failed to fetch unread count:", error);
    }
  },

  markAsRead: async (id: string) => {
    try {
      await api.patch(`/notifications/${id}/read`, {});
      set((state) => ({
        notifications: state.notifications.map((n) =>
          n.id === id ? { ...n, read: true } : n,
        ),
        unreadCount: Math.max(0, state.unreadCount - 1),
      }));
    } catch (error) {
      console.error("Failed to mark notification as read:", error);
    }
  },

  markAllAsRead: async () => {
    try {
      await api.post("/notifications/read-all", {});
      set((state) => ({
        notifications: state.notifications.map((n) => ({ ...n, read: true })),
        unreadCount: 0,
      }));
    } catch (error) {
      console.error("Failed to mark all notifications as read:", error);
    }
  },

  addNotification: (notification: Notification) => {
    set((state) => {
      const existingNotification = state.notifications.find(
        (item) => item.id === notification.id,
      );

      let unreadCount = state.unreadCount;

      if (!existingNotification) {
        unreadCount += notification.read ? 0 : 1;
      } else if (existingNotification.read && !notification.read) {
        unreadCount += 1;
      } else if (!existingNotification.read && notification.read) {
        unreadCount = Math.max(0, unreadCount - 1);
      }

      return {
        notifications: upsertNotification(state.notifications, notification),
        unreadCount,
      };
    });
  },
}));
