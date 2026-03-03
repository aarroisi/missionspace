import { useState, useEffect } from "react";
import {
  Home,
  Bell,
  Briefcase,
  Kanban,
  MessageSquare,
  Menu,
  Folder,
  Search,
  Settings,
  User,
  LogOut,
} from "lucide-react";
import { clsx } from "clsx";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuthStore } from "@/stores/authStore";
import { useSearchStore } from "@/stores/searchStore";
import { useNotificationStore } from "@/stores/notificationStore";
import { ProfileModal } from "@/components/features/ProfileModal";

export function MobileTabBar() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user, logout } = useAuthStore();
  const [showMoreDrawer, setShowMoreDrawer] = useState(false);
  const [showProfileModal, setShowProfileModal] = useState(false);

  const unreadCount = useNotificationStore((s) => s.unreadCount);
  const isOwner = user?.role === "owner";

  const getActiveTab = (): string => {
    const path = location.pathname;
    if (path === "/dashboard") return "home";
    if (path === "/updates") return "updates";
    if (path.startsWith("/channels") || path.startsWith("/dms")) return "chat";
    return "";
  };

  const activeTab = getActiveTab();

  // Close drawer on any route change (e.g. notification click, search result, etc.)
  useEffect(() => {
    setShowMoreDrawer(false);
  }, [location.pathname]);

  const handleTabPress = (tabId: string) => {
    if (tabId === "more") {
      setShowMoreDrawer((prev) => !prev);
      return;
    }

    setShowMoreDrawer(false);

    switch (tabId) {
      case "home":
        navigate("/dashboard");
        break;
      case "updates":
        navigate("/updates");
        break;
      case "chat":
        navigate("/channels");
        break;
      case "search":
        useSearchStore.getState().open();
        break;
    }
  };

  const handleMoreAction = (action: string) => {
    setShowMoreDrawer(false);
    switch (action) {
      case "projects":
        navigate("/projects");
        break;
      case "boards":
        navigate("/boards");
        break;
      case "folders":
        navigate("/doc-folders");
        break;
      case "settings":
        navigate("/settings");
        break;
      case "profile":
        setShowProfileModal(true);
        break;
      case "logout":
        logout().then(() => navigate("/login"));
        break;
    }
  };

  const tabs = [
    { id: "home", icon: Home, label: "Home" },
    { id: "updates", icon: Bell, label: "Updates" },
    { id: "chat", icon: MessageSquare, label: "Chat" },
    { id: "search", icon: Search, label: "Search" },
    { id: "more", icon: Menu, label: "More" },
  ];

  return (
    <>
      {/* More drawer backdrop */}
      {showMoreDrawer && (
        <div
          className="fixed inset-0 z-30 bg-black/30"
          onClick={() => setShowMoreDrawer(false)}
        />
      )}

      {/* More drawer panel */}
      {showMoreDrawer && (
        <div className="fixed bottom-14 left-0 right-0 z-40 bg-dark-surface border-t border-dark-border rounded-t-xl pb-[env(safe-area-inset-bottom)]">
          <div className="grid grid-cols-4 gap-1 p-3">
            <button
              onClick={() => handleMoreAction("projects")}
              className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-dark-text-muted hover:bg-dark-border/50 transition-colors"
            >
              <Briefcase size={20} />
              <span className="text-[10px] leading-tight">Projects</span>
            </button>

            <button
              onClick={() => handleMoreAction("boards")}
              className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-dark-text-muted hover:bg-dark-border/50 transition-colors"
            >
              <Kanban size={20} />
              <span className="text-[10px] leading-tight">Boards</span>
            </button>

            <button
              onClick={() => handleMoreAction("folders")}
              className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-dark-text-muted hover:bg-dark-border/50 transition-colors"
            >
              <Folder size={20} />
              <span className="text-[10px] leading-tight">Folders</span>
            </button>

            {isOwner && (
              <button
                onClick={() => handleMoreAction("settings")}
                className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-dark-text-muted hover:bg-dark-border/50 transition-colors"
              >
                <Settings size={20} />
                <span className="text-[10px] leading-tight">Settings</span>
              </button>
            )}

            <button
              onClick={() => handleMoreAction("profile")}
              className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-dark-text-muted hover:bg-dark-border/50 transition-colors"
            >
              <User size={20} />
              <span className="text-[10px] leading-tight">Profile</span>
            </button>

            <button
              onClick={() => handleMoreAction("logout")}
              className="flex flex-col items-center justify-center gap-1 py-3 rounded-lg text-red-400 hover:bg-dark-border/50 transition-colors"
            >
              <LogOut size={20} />
              <span className="text-[10px] leading-tight">Logout</span>
            </button>
          </div>
        </div>
      )}

      {/* Tab bar */}
      <div className="fixed bottom-0 left-0 right-0 z-40 bg-dark-surface border-t border-dark-border pb-[env(safe-area-inset-bottom)]">
        <div className="flex items-center justify-around h-14">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = showMoreDrawer
              ? tab.id === "more"
              : activeTab === tab.id;

            return (
              <button
                key={tab.id}
                onClick={() => handleTabPress(tab.id)}
                className={clsx(
                  "flex flex-col items-center justify-center flex-1 h-full gap-0.5 transition-colors relative",
                  isActive ? "text-blue-400" : "text-dark-text-muted",
                )}
              >
                <Icon size={20} />
                <span className="text-[10px] leading-tight">{tab.label}</span>
                {tab.id === "updates" && unreadCount > 0 && (
                  <span className="absolute top-2 right-1/4 w-2 h-2 bg-red-500 rounded-full" />
                )}
              </button>
            );
          })}
        </div>
      </div>

      <ProfileModal
        isOpen={showProfileModal}
        onClose={() => setShowProfileModal(false)}
      />
    </>
  );
}
