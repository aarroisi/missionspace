import { create } from "zustand";
import { Channel, DirectMessage, Message, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";
import { useAuthStore } from "@/stores/authStore";

interface RawDM {
  id: string;
  starred: boolean;
  user1Id: string;
  user2Id: string;
  user1: { id: string; name: string; email: string; avatar: string } | null;
  user2: { id: string; name: string; email: string; avatar: string } | null;
  insertedAt: string;
  updatedAt: string;
}

function transformDM(raw: RawDM): DirectMessage {
  const currentUser = useAuthStore.getState().user;
  const otherUser =
    raw.user1Id === currentUser?.id ? raw.user2 : raw.user1;
  return {
    id: raw.id,
    name: otherUser?.name || "Unknown",
    userId: otherUser?.id || "",
    avatar: otherUser?.avatar || "",
    online: false,
    starred: raw.starred,
    insertedAt: raw.insertedAt,
    updatedAt: raw.updatedAt,
  };
}

function upsertMessageList(messages: Message[], message: Message): Message[] {
  const existingIndex = messages.findIndex((item) => item.id === message.id);

  if (existingIndex === -1) {
    return [message, ...messages];
  }

  return messages.map((item) => (item.id === message.id ? message : item));
}

function upsertMessageRecord(
  messagesByKey: Record<string, Message[]>,
  message: Message,
): Record<string, Message[]> {
  const key = `${message.entityType}:${message.entityId}`;

  return {
    ...messagesByKey,
    [key]: upsertMessageList(messagesByKey[key] || [], message),
  };
}

function removeMessageFromRecord(
  messagesByKey: Record<string, Message[]>,
  messageId: string,
): Record<string, Message[]> {
  let changed = false;
  const next: Record<string, Message[]> = {};

  Object.entries(messagesByKey).forEach(([key, messages]) => {
    const filtered = messages.filter((message) => message.id !== messageId);

    if (filtered.length !== messages.length) {
      changed = true;
    }

    next[key] = filtered;
  });

  return changed ? next : messagesByKey;
}

interface ChatState {
  channels: Channel[];
  directMessages: DirectMessage[];
  messages: Record<string, Message[]>;
  messagesMetadata: Record<
    string,
    { before: string | null; after: string | null; limit: number }
  >;
  isLoading: boolean;
  hasMoreChannels: boolean;
  channelsAfterCursor: string | null;
  hasMoreDMs: boolean;
  dmsAfterCursor: string | null;

  // Channel operations
  fetchChannels: (loadMore?: boolean) => Promise<void>;
  createChannel: (name: string) => Promise<Channel>;
  updateChannel: (id: string, data: Partial<Channel>) => Promise<void>;
  deleteChannel: (id: string) => Promise<void>;
  toggleChannelStar: (id: string) => Promise<void>;

  // DM operations
  fetchDirectMessages: (loadMore?: boolean) => Promise<void>;
  createDirectMessage: (userId: string) => Promise<DirectMessage>;
  toggleDMStar: (id: string) => Promise<void>;

  // Message operations
  fetchMessages: (
    entityType: string,
    entityId: string,
    loadMore?: boolean,
  ) => Promise<void>;
  sendMessage: (
    entityType: string,
    entityId: string,
    text: string,
    parentId?: string,
    quoteId?: string,
  ) => Promise<Message>;
  updateMessage: (id: string, text: string) => Promise<void>;
  deleteMessage: (id: string) => Promise<void>;
  addMessage: (message: Message) => void;
  upsertMessage: (message: Message) => void;
  removeMessage: (id: string) => void;
  hasMoreMessages: (entityType: string, entityId: string) => boolean;

  // Unread state
  unreadChannelIds: Set<string>;
  unreadDmIds: Set<string>;
  fetchUnreadItems: () => Promise<void>;
  markAsRead: (itemType: string, itemId: string) => Promise<void>;
  addUnread: (itemType: string, itemId: string) => void;

  // Read position for "new messages" divider
  lastReadAt: Record<string, string | null>;
  fetchLastReadAt: (itemType: string, itemId: string) => Promise<void>;
  clearLastReadAt: (itemType: string, itemId: string) => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  channels: [],
  directMessages: [],
  messages: {},
  messagesMetadata: {},
  isLoading: false,
  hasMoreChannels: true,
  channelsAfterCursor: null,
  hasMoreDMs: true,
  dmsAfterCursor: null,

  // Channel operations
  fetchChannels: async (loadMore = false) => {
    const { channelsAfterCursor, isLoading } = get();

    if (isLoading || (loadMore && !channelsAfterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && channelsAfterCursor) {
        params.after = channelsAfterCursor;
      }

      const response = await api.get<PaginatedResponse<Channel>>(
        "/channels",
        params,
      );

      set((state) => ({
        channels: loadMore
          ? [...state.channels, ...response.data]
          : response.data,
        channelsAfterCursor: response.metadata.after,
        hasMoreChannels: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch channels:", error);
      set({ channels: [], isLoading: false, hasMoreChannels: false });
    }
  },

  createChannel: async (name: string) => {
    const channel = await api.post<Channel>("/channels", { name });
    set((state) => ({
      channels: [
        ...(Array.isArray(state.channels) ? state.channels : []),
        channel,
      ],
    }));
    return channel;
  },

  updateChannel: async (id: string, data: Partial<Channel>) => {
    const channel = await api.patch<Channel>(`/channels/${id}`, data);
    set((state) => ({
      channels: state.channels.map((c) => (c.id === id ? channel : c)),
    }));
  },

  deleteChannel: async (id: string) => {
    await api.delete(`/channels/${id}`);
    set((state) => ({
      channels: state.channels.filter((c) => c.id !== id),
    }));
  },

  toggleChannelStar: async (id: string) => {
    const channel = get().channels.find((c) => c.id === id);
    if (channel) {
      set((state) => ({
        channels: state.channels.map((c) =>
          c.id === id ? { ...c, starred: !c.starred } : c,
        ),
      }));
      await api.post("/stars/toggle", { type: "channel", id });
    }
  },

  // DM operations
  fetchDirectMessages: async (loadMore = false) => {
    const { dmsAfterCursor, isLoading } = get();

    if (isLoading || (loadMore && !dmsAfterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && dmsAfterCursor) {
        params.after = dmsAfterCursor;
      }

      const response = await api.get<PaginatedResponse<RawDM>>(
        "/direct_messages",
        params,
      );

      const transformed = response.data.map(transformDM);

      set((state) => ({
        directMessages: loadMore
          ? [...state.directMessages, ...transformed]
          : transformed,
        dmsAfterCursor: response.metadata.after,
        hasMoreDMs: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch DMs:", error);
      set({ directMessages: [], isLoading: false, hasMoreDMs: false });
    }
  },

  createDirectMessage: async (userId: string) => {
    const raw = await api.post<RawDM>("/direct_messages", { user2Id: userId });
    const dm = transformDM(raw);
    set((state) => {
      // Avoid duplicates if DM already exists (idempotent create)
      const exists = state.directMessages.some((d) => d.id === dm.id);
      return {
        directMessages: exists ? state.directMessages : [...state.directMessages, dm],
      };
    });
    return dm;
  },

  toggleDMStar: async (id: string) => {
    const dm = get().directMessages.find((d) => d.id === id);
    if (dm) {
      set((state) => ({
        directMessages: state.directMessages.map((d) =>
          d.id === id ? { ...d, starred: !d.starred } : d,
        ),
      }));
      await api.post("/stars/toggle", { type: "direct_message", id });
    }
  },

  // Message operations
  fetchMessages: async (
    entityType: string,
    entityId: string,
    loadMore = false,
  ) => {
    try {
      const key = `${entityType}:${entityId}`;
      const { messagesMetadata } = get();

      const params: Record<string, string> = {
        entity_type: entityType,
        entity_id: entityId,
      };

      // When loading more (older messages), use the 'after' cursor
      if (loadMore && messagesMetadata[key]?.after) {
        params.after = messagesMetadata[key].after;
      }

      const response = await api.get<PaginatedResponse<Message>>(
        `/messages`,
        params,
      );

      set((state) => ({
        messages: {
          ...state.messages,
          // For loadMore, prepend older messages; otherwise replace
          [key]:
            loadMore && state.messages[key]
              ? [...response.data, ...state.messages[key]]
              : response.data,
        },
        messagesMetadata: {
          ...state.messagesMetadata,
          [key]: response.metadata,
        },
      }));
    } catch (error) {
      console.error("Failed to fetch messages:", error);
    }
  },

  hasMoreMessages: (entityType: string, entityId: string) => {
    const key = `${entityType}:${entityId}`;
    const metadata = get().messagesMetadata[key];
    return metadata?.after !== null;
  },

  sendMessage: async (
    entityType: string,
    entityId: string,
    text: string,
    parentId?: string,
    quoteId?: string,
  ) => {
    const message = await api.post<Message>("/messages", {
      entityType,
      entityId,
      text,
      parentId,
      quoteId,
    });
    set((state) => ({
      messages: upsertMessageRecord(state.messages, message),
    }));
    return message;
  },

  updateMessage: async (id: string, text: string) => {
    const updatedMessage = await api.patch<Message>(`/messages/${id}`, {
      text,
    });
    set((state) => ({
      messages: upsertMessageRecord(state.messages, updatedMessage),
    }));
  },

  deleteMessage: async (id: string) => {
    await api.delete(`/messages/${id}`);
    set((state) => ({
      messages: removeMessageFromRecord(state.messages, id),
    }));
  },

  addMessage: (message: Message) => {
    set((state) => ({
      messages: upsertMessageRecord(state.messages, message),
    }));
  },

  upsertMessage: (message: Message) => {
    set((state) => ({
      messages: upsertMessageRecord(state.messages, message),
    }));
  },

  removeMessage: (id: string) => {
    set((state) => ({
      messages: removeMessageFromRecord(state.messages, id),
    }));
  },

  // Unread state
  unreadChannelIds: new Set<string>(),
  unreadDmIds: new Set<string>(),

  fetchUnreadItems: async () => {
    try {
      const response = await api.get<{
        channels: string[];
        dms: string[];
      }>("/read-positions/unread");
      set({
        unreadChannelIds: new Set(response.channels),
        unreadDmIds: new Set(response.dms),
      });
    } catch (error) {
      console.error("Failed to fetch unread items:", error);
    }
  },

  markAsRead: async (itemType: string, itemId: string) => {
    try {
      await api.post(`/read-positions/${itemType}/${itemId}`, {});
      set((state) => {
        if (itemType === "channel") {
          const next = new Set(state.unreadChannelIds);
          next.delete(itemId);
          return { unreadChannelIds: next };
        } else {
          const next = new Set(state.unreadDmIds);
          next.delete(itemId);
          return { unreadDmIds: next };
        }
      });
    } catch (error) {
      console.error("Failed to mark as read:", error);
    }
  },

  addUnread: (itemType: string, itemId: string) => {
    set((state) => {
      if (itemType === "channel") {
        const next = new Set(state.unreadChannelIds);
        next.add(itemId);
        return { unreadChannelIds: next };
      } else {
        const next = new Set(state.unreadDmIds);
        next.add(itemId);
        return { unreadDmIds: next };
      }
    });
  },

  // Read position for "new messages" divider
  lastReadAt: {},

  fetchLastReadAt: async (itemType: string, itemId: string) => {
    try {
      const response = await api.get<{ lastReadAt: string | null }>(
        `/read-positions/${itemType}/${itemId}`,
      );
      const key = `${itemType}:${itemId}`;
      set((state) => ({
        lastReadAt: { ...state.lastReadAt, [key]: response.lastReadAt },
      }));
    } catch (error) {
      console.error("Failed to fetch last read position:", error);
    }
  },

  clearLastReadAt: (itemType: string, itemId: string) => {
    const key = `${itemType}:${itemId}`;
    set((state) => {
      const next = { ...state.lastReadAt };
      delete next[key];
      return { lastReadAt: next };
    });
  },
}));
