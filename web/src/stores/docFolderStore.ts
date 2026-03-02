import { create } from "zustand";
import { DocFolder, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";

interface DocFolderState {
  folders: DocFolder[];
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;

  fetchFolders: (loadMore?: boolean) => Promise<void>;
  createFolder: (name: string, prefix: string) => Promise<DocFolder>;
  updateFolder: (id: string, data: Partial<DocFolder>) => Promise<void>;
  deleteFolder: (id: string) => Promise<void>;
  toggleFolderStar: (id: string) => Promise<void>;
  suggestPrefix: (name: string) => Promise<string>;
  checkPrefix: (prefix: string) => Promise<boolean>;
}

export const useDocFolderStore = create<DocFolderState>((set, get) => ({
  folders: [],
  isLoading: false,
  hasMore: true,
  afterCursor: null,

  fetchFolders: async (loadMore = false) => {
    const { afterCursor, isLoading } = get();

    if (isLoading || (loadMore && !afterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && afterCursor) {
        params.after = afterCursor;
      }

      const response = await api.get<PaginatedResponse<DocFolder>>(
        "/doc-folders",
        params,
      );

      set((state) => ({
        folders: loadMore
          ? [...state.folders, ...response.data]
          : response.data,
        afterCursor: response.metadata.after,
        hasMore: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch doc folders:", error);
      set({ folders: [], isLoading: false, hasMore: false });
    }
  },

  createFolder: async (name: string, prefix: string) => {
    const folder = await api.post<DocFolder>("/doc-folders", { name, prefix });
    set((state) => ({
      folders: [...(Array.isArray(state.folders) ? state.folders : []), folder],
    }));
    return folder;
  },

  updateFolder: async (id: string, data: Partial<DocFolder>) => {
    const folder = await api.patch<DocFolder>(`/doc-folders/${id}`, data);
    set((state) => ({
      folders: state.folders.map((f) => (f.id === id ? folder : f)),
    }));
  },

  deleteFolder: async (id: string) => {
    await api.delete(`/doc-folders/${id}`);
    set((state) => ({
      folders: state.folders.filter((f) => f.id !== id),
    }));
  },

  toggleFolderStar: async (id: string) => {
    const folder = get().folders.find((f) => f.id === id);
    if (folder) {
      set((state) => ({
        folders: state.folders.map((f) =>
          f.id === id ? { ...f, starred: !f.starred } : f,
        ),
      }));
      await api.post("/stars/toggle", { type: "doc_folder", id });
    }
  },

  suggestPrefix: async (name: string) => {
    const res = await api.get<{ prefix: string }>(
      "/doc-folders/suggest-prefix",
      { name },
    );
    return res.prefix;
  },

  checkPrefix: async (prefix: string) => {
    const res = await api.get<{ available: boolean }>(
      "/doc-folders/check-prefix",
      { prefix },
    );
    return res.available;
  },
}));
