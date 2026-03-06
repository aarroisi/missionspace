import { create } from "zustand";
import { User } from "@/types";
import { api, API_URL } from "@/lib/api";
import { disconnectSocket } from "@/hooks/useChannel";

interface ItemWithCreator {
  createdById?: string;
  createdBy?: { id: string } | null;
}

interface Workspace {
  id: string;
  name: string;
  slug: string;
  logo: string | null;
}

interface WorkspaceMember {
  id: string;
  name: string;
  email: string;
  avatar: string;
  timezone?: string | null;
  online: boolean;
}

export interface DeviceAccount {
  user: User;
  workspace: Workspace;
  current: boolean;
  state: "available" | "signed_out";
}

interface AuthState {
  user: User | null;
  workspace: Workspace | null;
  members: WorkspaceMember[];
  accounts: DeviceAccount[];
  isAuthenticated: boolean;
  isLoading: boolean;
  needsEmailVerification: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  checkAuth: () => Promise<void>;
  fetchAccounts: () => Promise<void>;
  switchAccount: (userId: string) => Promise<void>;
  addAccount: (email: string, password: string) => Promise<void>;
  reauthAccount: (userId: string, password: string) => Promise<void>;
  signOutAccount: (userId: string) => Promise<void>;
  removeAccount: (userId: string) => Promise<void>;
  fetchMembers: () => Promise<void>;
  updateProfile: (data: {
    name?: string;
    email?: string;
    avatar?: string;
    timezone?: string;
  }) => Promise<void>;
  updateWorkspace: (data: { name?: string; slug?: string; logo?: string | null }) => Promise<void>;
  // Permission helpers
  isOwner: () => boolean;
  canEdit: (item: ItemWithCreator) => boolean;
  canDelete: (item: ItemWithCreator) => boolean;
}

const AUTH_ME_RETRY_ATTEMPTS = 1;
const AUTH_ME_RETRY_DELAY_MS = 300;
const RETRIABLE_AUTH_STATUS_CODES = [408, 429, 500, 502, 503, 504];

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchAuthMeWithRetry(): Promise<Response> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= AUTH_ME_RETRY_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(`${API_URL}/auth/me`, {
        credentials: "include",
      });

      const shouldRetry =
        RETRIABLE_AUTH_STATUS_CODES.includes(response.status) &&
        attempt < AUTH_ME_RETRY_ATTEMPTS;

      if (shouldRetry) {
        await delay(AUTH_ME_RETRY_DELAY_MS);
        continue;
      }

      return response;
    } catch (error) {
      lastError = error;

      if (attempt < AUTH_ME_RETRY_ATTEMPTS) {
        await delay(AUTH_ME_RETRY_DELAY_MS);
        continue;
      }
    }
  }

  throw lastError instanceof Error ? lastError : new Error("Auth check failed");
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  workspace: null,
  members: [],
  accounts: [],
  isAuthenticated: false,
  isLoading: true,
  needsEmailVerification: false,

  login: async (email: string, password: string) => {
    try {
      const data = await api.post<{
        user: User;
        workspace: Workspace;
        token?: string;
      }>("/auth/login", {
        email,
        password,
      });
      api.setToken(data.token);
      localStorage.setItem("logged_in", "1");
      set({
        user: data.user,
        workspace: data.workspace,
        isAuthenticated: true,
        needsEmailVerification: false,
      });

      await get().fetchAccounts();
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
      disconnectSocket();
      api.clearToken();
      localStorage.removeItem("logged_in");
      set({
        user: null,
        workspace: null,
        members: [],
        isAuthenticated: false,
        needsEmailVerification: false,
      });
      window.location.assign("/login");
    }
  },

  checkAuth: async () => {
    try {
      const response = await fetchAuthMeWithRetry();

      if (response.ok) {
        const data = await response.json();
        api.setToken(data.token);
        localStorage.setItem("logged_in", "1");
        set({
          user: data.user,
          workspace: data.workspace,
          isAuthenticated: true,
          isLoading: false,
          needsEmailVerification: false,
        });
      } else if (response.status === 403) {
        const data = await response.json();
        disconnectSocket();
        api.clearToken();
        localStorage.removeItem("logged_in");
        if (data.error === "email_not_verified") {
          set({
            user: null,
            workspace: null,
            members: [],
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
      } else if (response.status === 401) {
        disconnectSocket();
        api.clearToken();
        localStorage.removeItem("logged_in");
        set({
          user: null,
          workspace: null,
          members: [],
          isAuthenticated: false,
          needsEmailVerification: false,
          isLoading: false,
        });
      } else {
        console.warn(`Unexpected /auth/me status: ${response.status}`);
        set((state) => ({
          ...state,
          isLoading: false,
        }));
      }
    } catch (error) {
      console.warn("Auth check failed after retry:", error);
      disconnectSocket();
      set((state) => ({
        ...state,
        isLoading: false,
      }));
    }

    await get().fetchAccounts();
  },

  fetchAccounts: async () => {
    try {
      const accounts = await api.get<DeviceAccount[]>("/auth/accounts");
      set({ accounts });
    } catch (error) {
      console.warn("Failed to fetch remembered accounts:", error);
      set({ accounts: [] });
    }
  },

  switchAccount: async (userId: string) => {
    const data = await api.post<{ user: User; workspace: Workspace; token: string }>("/auth/switch-account", {
      userId,
    });

    disconnectSocket();
    api.setToken(data.token);
    localStorage.setItem("logged_in", "1");
    set({
      user: data.user,
      workspace: data.workspace,
      members: [],
      isAuthenticated: true,
      needsEmailVerification: false,
      isLoading: false,
    });

    window.location.assign("/dashboard");
  },

  addAccount: async (email: string, password: string) => {
    await api.post("/auth/add-account", { email, password });
    await get().fetchAccounts();
  },

  reauthAccount: async (userId: string, password: string) => {
    const data = await api.post<{ user: User; workspace: Workspace; token: string }>("/auth/reauth-account", {
      userId,
      password,
    });

    disconnectSocket();
    api.setToken(data.token);
    localStorage.setItem("logged_in", "1");
    set({
      user: data.user,
      workspace: data.workspace,
      members: [],
      isAuthenticated: true,
      needsEmailVerification: false,
      isLoading: false,
    });

    window.location.assign("/dashboard");
  },

  signOutAccount: async (userId: string) => {
    await api.post<{ data: DeviceAccount }>("/auth/sign-out-account", { userId });

    const state = get();
    const isCurrentUser = state.user?.id === userId;

    if (isCurrentUser) {
      disconnectSocket();
      api.clearToken();
      localStorage.removeItem("logged_in");
      set({
        user: null,
        workspace: null,
        members: [],
        isAuthenticated: false,
        needsEmailVerification: false,
      });
      window.location.assign("/login");
      return;
    }

    await get().fetchAccounts();
  },

  removeAccount: async (userId: string) => {
    await api.delete(`/auth/accounts/${userId}`);

    const state = get();
    const isCurrentUser = state.user?.id === userId;

    if (isCurrentUser) {
      disconnectSocket();
      api.clearToken();
      localStorage.removeItem("logged_in");
      set({
        user: null,
        workspace: null,
        members: [],
        isAuthenticated: false,
        needsEmailVerification: false,
      });
      window.location.assign("/login");
      return;
    }

    await get().fetchAccounts();
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
    timezone?: string;
  }) => {
    const response = await api.put<{ user: User }>("/auth/me", { user: data });
    set({ user: response.user });
  },

  updateWorkspace: async (data: { name?: string; slug?: string; logo?: string | null }) => {
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
