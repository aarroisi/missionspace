import { create } from "zustand";
import { Subscription, SubscriptionItemType } from "@/types";
import { api } from "@/lib/api";

interface SubscriptionState {
  // Per-item subscribers keyed by `${itemType}:${itemId}`
  subscribers: Record<string, Subscription[]>;
  // Current user subscription status keyed by `${itemType}:${itemId}`
  subscriptionStatus: Record<string, boolean>;
  isLoading: Record<string, boolean>;

  fetchSubscribers: (
    itemType: SubscriptionItemType,
    itemId: string,
  ) => Promise<void>;
  fetchStatus: (
    itemType: SubscriptionItemType,
    itemId: string,
  ) => Promise<boolean>;
  subscribe: (
    itemType: SubscriptionItemType,
    itemId: string,
  ) => Promise<void>;
  unsubscribe: (
    itemType: SubscriptionItemType,
    itemId: string,
  ) => Promise<void>;
}

function key(itemType: string, itemId: string) {
  return `${itemType}:${itemId}`;
}

export const useSubscriptionStore = create<SubscriptionState>((set) => ({
  subscribers: {},
  subscriptionStatus: {},
  isLoading: {},

  fetchSubscribers: async (itemType, itemId) => {
    const k = key(itemType, itemId);
    set((s) => ({ isLoading: { ...s.isLoading, [k]: true } }));
    try {
      const response = await api.get<Subscription[]>(
        `/subscriptions/${itemType}/${itemId}`,
      );
      set((s) => ({
        subscribers: { ...s.subscribers, [k]: response },
        isLoading: { ...s.isLoading, [k]: false },
      }));
    } catch (error) {
      console.error("Failed to fetch subscribers:", error);
      set((s) => ({ isLoading: { ...s.isLoading, [k]: false } }));
    }
  },

  fetchStatus: async (itemType, itemId) => {
    const k = key(itemType, itemId);
    try {
      const response = await api.get<{ subscribed: boolean }>(
        `/subscriptions/${itemType}/${itemId}/status`,
      );
      set((s) => ({
        subscriptionStatus: {
          ...s.subscriptionStatus,
          [k]: response.subscribed,
        },
      }));
      return response.subscribed;
    } catch (error) {
      console.error("Failed to fetch subscription status:", error);
      return false;
    }
  },

  subscribe: async (itemType, itemId) => {
    const k = key(itemType, itemId);
    try {
      const response = await api.post<Subscription>(
        `/subscriptions/${itemType}/${itemId}`,
        {},
      );
      set((s) => ({
        subscriptionStatus: { ...s.subscriptionStatus, [k]: true },
        subscribers: {
          ...s.subscribers,
          [k]: [...(s.subscribers[k] || []), response],
        },
      }));
    } catch (error) {
      console.error("Failed to subscribe:", error);
    }
  },

  unsubscribe: async (itemType, itemId) => {
    const k = key(itemType, itemId);
    const currentUserId =
      (await import("@/stores/authStore")).useAuthStore.getState().user?.id;
    try {
      await api.delete(`/subscriptions/${itemType}/${itemId}`);
      set((s) => ({
        subscriptionStatus: { ...s.subscriptionStatus, [k]: false },
        subscribers: {
          ...s.subscribers,
          [k]: (s.subscribers[k] || []).filter(
            (sub) => sub.userId !== currentUserId,
          ),
        },
      }));
    } catch (error) {
      console.error("Failed to unsubscribe:", error);
    }
  },
}));
