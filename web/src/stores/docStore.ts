import { create } from "zustand";
import { Doc, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";

interface DocState {
  docs: Doc[];
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;

  fetchDocs: (loadMore?: boolean, docFolderId?: string) => Promise<void>;
  getDoc: (id: string) => Promise<Doc>;
  createDoc: (title: string, content: string, docFolderId: string) => Promise<Doc>;
  updateDoc: (id: string, data: Partial<Doc>) => Promise<void>;
  deleteDoc: (id: string) => Promise<void>;
  toggleDocStar: (id: string) => Promise<void>;
}

export const useDocStore = create<DocState>((set, get) => ({
  docs: [],
  isLoading: false,
  hasMore: true,
  afterCursor: null,

  fetchDocs: async (loadMore = false, docFolderId?: string) => {
    const { afterCursor, isLoading } = get();

    if (isLoading || (loadMore && !afterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && afterCursor) {
        params.after = afterCursor;
      }
      if (docFolderId) {
        params.doc_folder_id = docFolderId;
      }

      const response = await api.get<PaginatedResponse<Doc>>("/docs", params);

      set((state) => ({
        docs: loadMore ? [...state.docs, ...response.data] : response.data,
        afterCursor: response.metadata.after,
        hasMore: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch docs:", error);
      set({ docs: [], isLoading: false, hasMore: false });
    }
  },

  getDoc: async (id: string) => {
    try {
      const doc = await api.get<Doc>(`/docs/${id}`);
      set((state) => ({
        docs: state.docs.some((d) => d.id === id)
          ? state.docs.map((d) => (d.id === id ? doc : d))
          : [...state.docs, doc],
      }));
      return doc;
    } catch (error) {
      console.error("Failed to fetch doc:", error);
      throw error;
    }
  },

  createDoc: async (title: string, content: string, docFolderId: string) => {
    const doc = await api.post<Doc>("/docs", { title, content, doc_folder_id: docFolderId });
    set((state) => ({
      docs: [...(Array.isArray(state.docs) ? state.docs : []), doc],
    }));
    return doc;
  },

  updateDoc: async (id: string, data: Partial<Doc>) => {
    const doc = await api.patch<Doc>(`/docs/${id}`, data);
    set((state) => ({
      docs: state.docs.map((d) => (d.id === id ? doc : d)),
    }));
  },

  deleteDoc: async (id: string) => {
    await api.delete(`/docs/${id}`);
    set((state) => ({
      docs: state.docs.filter((d) => d.id !== id),
    }));
  },

  toggleDocStar: async (id: string) => {
    const doc = get().docs.find((d) => d.id === id);
    if (doc) {
      set((state) => ({
        docs: state.docs.map((d) =>
          d.id === id ? { ...d, starred: !d.starred } : d,
        ),
      }));
      await api.post("/stars/toggle", { type: "doc", id });
    }
  },
}));
