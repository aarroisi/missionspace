import { create } from "zustand";
import { Project, ProjectItem, PaginatedResponse } from "@/types";
import { api } from "@/lib/api";

interface CreateProjectParams {
  name: string;
  description?: string;
  memberIds?: string[];
}

interface ProjectState {
  projects: Project[];
  isLoading: boolean;
  hasMore: boolean;
  afterCursor: string | null;
  fetchProjects: (loadMore?: boolean) => Promise<void>;
  createProject: (params: CreateProjectParams) => Promise<Project>;
  updateProject: (id: string, data: Partial<Project>) => Promise<void>;
  deleteProject: (id: string) => Promise<void>;
  toggleStar: (id: string) => Promise<void>;
  addItem: (
    projectId: string,
    itemType: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => Promise<ProjectItem>;
  removeItem: (
    projectId: string,
    itemType: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => Promise<void>;
}

export const useProjectStore = create<ProjectState>((set, get) => ({
  projects: [],
  isLoading: false,
  hasMore: true,
  afterCursor: null,

  fetchProjects: async (loadMore = false) => {
    const { afterCursor, isLoading } = get();

    if (isLoading || (loadMore && !afterCursor)) return;

    set({ isLoading: true });
    try {
      const params: Record<string, string> = {};
      if (loadMore && afterCursor) {
        params.after = afterCursor;
      }

      const response = await api.get<PaginatedResponse<Project>>(
        "/projects",
        params,
      );

      set((state) => ({
        projects: loadMore
          ? [...state.projects, ...response.data]
          : response.data,
        afterCursor: response.metadata.after,
        hasMore: response.metadata.after !== null,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Failed to fetch projects:", error);
      set({ projects: [], isLoading: false, hasMore: false });
    }
  },

  createProject: async (params: CreateProjectParams) => {
    const project = await api.post<Project>("/projects", {
      name: params.name,
      description: params.description,
      member_ids: params.memberIds,
    });
    set((state) => ({
      projects: [
        ...(Array.isArray(state.projects) ? state.projects : []),
        project,
      ],
    }));
    return project;
  },

  updateProject: async (id: string, data: Partial<Project>) => {
    const project = await api.patch<Project>(`/projects/${id}`, data);
    set((state) => ({
      projects: state.projects.map((p) => (p.id === id ? project : p)),
    }));
  },

  deleteProject: async (id: string) => {
    await api.delete(`/projects/${id}`);
    set((state) => ({
      projects: state.projects.filter((p) => p.id !== id),
    }));
  },

  toggleStar: async (id: string) => {
    const project = get().projects.find((p) => p.id === id);
    if (project) {
      set((state) => ({
        projects: state.projects.map((p) =>
          p.id === id ? { ...p, starred: !p.starred } : p,
        ),
      }));
      await api.post("/stars/toggle", { type: "project", id });
    }
  },

  addItem: async (
    projectId: string,
    itemType: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => {
    const item = await api.post<ProjectItem>(`/projects/${projectId}/items`, {
      itemType,
      itemId,
    });
    // Update the project's items in state
    set((state) => ({
      projects: state.projects.map((p) =>
        p.id === projectId ? { ...p, items: [...(p.items || []), item] } : p,
      ),
    }));
    return item;
  },

  removeItem: async (
    projectId: string,
    itemType: "board" | "doc_folder" | "channel",
    itemId: string,
  ) => {
    await api.delete(`/projects/${projectId}/items/${itemType}:${itemId}`);
    // Remove the item from state
    set((state) => ({
      projects: state.projects.map((p) =>
        p.id === projectId
          ? {
              ...p,
              items: (p.items || []).filter(
                (i) => !(i.itemType === itemType && i.itemId === itemId),
              ),
            }
          : p,
      ),
    }));
  },
}));
