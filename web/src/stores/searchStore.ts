import { create } from "zustand";
import { api } from "@/lib/api";
import { SearchResults } from "@/types";

const emptyResults: SearchResults = {
  projects: [],
  boards: [],
  tasks: [],
  docFolders: [],
  docs: [],
  channels: [],
  members: [],
};

interface SearchState {
  isOpen: boolean;
  query: string;
  results: SearchResults;
  isLoading: boolean;
  selectedIndex: number;

  open: () => void;
  close: () => void;
  setQuery: (query: string) => void;
  fetchResults: (query: string) => Promise<void>;
  setSelectedIndex: (index: number) => void;
}

export const useSearchStore = create<SearchState>((set, get) => ({
  isOpen: false,
  query: "",
  results: emptyResults,
  isLoading: false,
  selectedIndex: 0,

  open: () => set({ isOpen: true, query: "", results: emptyResults, selectedIndex: 0 }),

  close: () => set({ isOpen: false, query: "", results: emptyResults, selectedIndex: 0 }),

  setQuery: (query: string) => set({ query }),

  fetchResults: async (query: string) => {
    if (query.trim().length === 0) {
      set({ results: emptyResults, isLoading: false });
      return;
    }

    set({ isLoading: true });
    try {
      const results = await api.get<SearchResults>("/search", { q: query });
      if (get().query === query) {
        set({ results, isLoading: false, selectedIndex: 0 });
      }
    } catch {
      set({ isLoading: false });
    }
  },

  setSelectedIndex: (index: number) => set({ selectedIndex: index }),
}));
