import { create } from "zustand";
import { Notification, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;

  // Operations
  fetchNotifications: (loadMore?: boolean) => Promise<void>;
  fetchUnreadCount: () => Promise<void>;
  markAsRead: (id: string) => Promise<void>;
  markAllAsRead: () => Promise<void>;
  addNotification: (notification: Notification) => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  notifications: [],
  unreadCount: 0,
  isLoading: false,
  hasMore: true,
  afterCursor: null,

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
    set((state) => ({
      notifications: [notification, ...state.notifications],
      unreadCount: state.unreadCount + (notification.read ? 0 : 1),
    }));
  },
}));
