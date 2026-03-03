import { create } from "zustand";
import { User } from "@/types";
import { api } from "@/lib/api";

interface ItemWithCreator {
  createdById?: string;
  createdBy?: { id: string } | null;
}

interface Workspace {
  id: string;
  name: string;
  slug: string;
}

interface WorkspaceMember {
  id: string;
  name: string;
  email: string;
  avatar: string;
  online: boolean;
}

interface AuthState {
  user: User | null;
  workspace: Workspace | null;
  members: WorkspaceMember[];
  isAuthenticated: boolean;
  isLoading: boolean;
  needsEmailVerification: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
  fetchMembers: () => Promise<void>;
  updateProfile: (data: {
    name?: string;
    email?: string;
    avatar?: string;
  }) => Promise<void>;
  updateWorkspace: (data: { name?: string; slug?: string }) => Promise<void>;
  // Permission helpers
  isOwner: () => boolean;
  canEdit: (item: ItemWithCreator) => boolean;
  canDelete: (item: ItemWithCreator) => boolean;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  workspace: null,
  members: [],
  isAuthenticated: false,
  isLoading: true,
  needsEmailVerification: false,

  login: async (email: string, password: string) => {
    try {
      const data = await api.post<{
        user: User;
        workspace: Workspace;
        token: string;
      }>("/auth/login", {
        email,
        password,
      });
      api.setToken(data.token);
      set({
        user: data.user,
        workspace: data.workspace,
        isAuthenticated: true,
      });
    } catch (error) {
      console.error("Login failed:", error);
      throw error;
    }
  },

  logout: async () => {
    try {
      await api.post("/auth/logout");
    } catch (error) {
      console.error("Logout request failed:", error);
    } finally {
      api.clearToken();
      set({ user: null, workspace: null, members: [], isAuthenticated: false });
    }
  },

  checkAuth: async () => {
    try {
      const response = await fetch("/api/auth/me", {
        credentials: "include",
      });

      if (response.ok) {
        const data = await response.json();
        set({
          user: data.user,
          workspace: data.workspace,
          isAuthenticated: true,
          isLoading: false,
          needsEmailVerification: false,
        });
      } else if (response.status === 403) {
        const data = await response.json();
        if (data.error === "email_not_verified") {
          set({
            isAuthenticated: false,
            needsEmailVerification: true,
            isLoading: false,
          });
        } else {
          set({
            user: null,
            workspace: null,
            members: [],
            isAuthenticated: false,
            needsEmailVerification: false,
            isLoading: false,
          });
        }
      } else {
        set({
          user: null,
          workspace: null,
          members: [],
          isAuthenticated: false,
          needsEmailVerification: false,
          isLoading: false,
        });
      }
    } catch (error) {
      set({
        user: null,
        workspace: null,
        members: [],
        isAuthenticated: false,
        needsEmailVerification: false,
        isLoading: false,
      });
    }
  },

  fetchMembers: async () => {
    try {
      const members = await api.get<WorkspaceMember[]>("/workspace/members");
      set({ members });
    } catch (error) {
      console.error("Failed to fetch workspace members:", error);
    }
  },

  updateProfile: async (data: {
    name?: string;
    email?: string;
    avatar?: string;
  }) => {
    const response = await api.put<{ user: User }>("/auth/me", { user: data });
    set({ user: response.user });
  },

  updateWorkspace: async (data: { name?: string; slug?: string }) => {
    const response = await api.put<{ workspace: Workspace }>("/workspace", {
      workspace: data,
    });
    set({ workspace: response.workspace });
  },

  // Permission helpers
  isOwner: (): boolean => {
    return useAuthStore.getState().user?.role === "owner";
  },

  canEdit: (item: ItemWithCreator): boolean => {
    const user = useAuthStore.getState().user;
    if (!user) return false;
    if (user.role === "owner") return true;
    // Members and guests can only edit their own items
    const creatorId = item.createdBy?.id || item.createdById;
    return creatorId === user.id;
  },

  canDelete: (item: ItemWithCreator): boolean => {
    const user = useAuthStore.getState().user;
    if (!user) return false;
    if (user.role === "owner") return true;
    // Members and guests can only delete their own items
    const creatorId = item.createdBy?.id || item.createdById;
    return creatorId === user.id;
  },
}));
