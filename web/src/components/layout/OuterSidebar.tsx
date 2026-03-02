import {
  Home,
  Briefcase,
  Kanban,
  Folder,
  Hash,
  MessageSquare,
  Settings,
  Search,
} from "lucide-react";
import { clsx } from "clsx";
import { useNavigate, useLocation } from "react-router-dom";
import { useUIStore } from "@/stores/uiStore";
import { useAuthStore } from "@/stores/authStore";
import { Category } from "@/types";
import { ProfileMenu } from "@/components/features/ProfileMenu";
import { NotificationBell } from "@/components/features/NotificationBell";
import { useSearchStore } from "@/stores/searchStore";

const categories: { id: Category; icon: any; label: string }[] = [
  { id: "home", icon: Home, label: "Home" },
  { id: "projects", icon: Briefcase, label: "Projects" },
  { id: "boards", icon: Kanban, label: "Boards" },
  { id: "docs", icon: Folder, label: "Folders" },
  { id: "channels", icon: Hash, label: "Channels" },
  { id: "dms", icon: MessageSquare, label: "Direct Messages" },
];

export function OuterSidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const { setActiveCategory, setSidebarOpen } = useUIStore();
  const { isOwner } = useAuthStore();

  const handleCategoryClick = async (category: Category) => {
    // Check navigation guard before navigating
    const { navigationGuard } = useUIStore.getState();
    if (navigationGuard) {
      const canNavigate = await navigationGuard();
      if (!canNavigate) return;
    }

    setActiveCategory(category);
    setSidebarOpen(true);

    // Navigate to the category route
    if (category === "home") {
      navigate("/");
    } else {
      navigate(`/${category}`);
    }
  };

  // Determine active category from URL
  const getCurrentCategory = (): Category => {
    const path = location.pathname;

    if (path === "/") return "home";
    // All /projects/* routes (including nested /projects/:id/docs/:docId) are projects
    if (path.startsWith("/projects")) return "projects";
    if (path.startsWith("/boards")) return "boards";
    if (path.startsWith("/doc-folders") || path.startsWith("/docs")) return "docs";
    if (path.startsWith("/channels")) return "channels";
    if (path.startsWith("/dms")) return "dms";
    return "home";
  };

  const currentCategory = getCurrentCategory();

  return (
    <div className="w-14 bg-dark-bg border-r border-dark-border flex flex-col items-center py-4">
      <div className="flex flex-col gap-2">
        {categories.map(({ id, icon: Icon, label }) => (
          <button
            key={id}
            onClick={() => handleCategoryClick(id)}
            className={clsx(
              "w-10 h-10 rounded-lg flex items-center justify-center transition-colors",
              currentCategory === id
                ? "bg-blue-600 text-white"
                : "text-dark-text-muted hover:bg-dark-surface hover:text-dark-text",
            )}
            title={label}
          >
            <Icon size={20} />
          </button>
        ))}
      </div>

      <div className="flex-1" />

      <button
        onClick={() => useSearchStore.getState().open()}
        className="w-10 h-10 rounded-lg flex items-center justify-center transition-colors text-dark-text-muted hover:bg-dark-surface hover:text-dark-text mb-1"
        title="Search (⌘K)"
      >
        <Search size={20} />
      </button>

      <NotificationBell />

      {isOwner() && (
        <button
          onClick={() => navigate("/settings")}
          className={clsx(
            "w-10 h-10 rounded-lg flex items-center justify-center transition-colors mb-2",
            location.pathname.startsWith("/settings")
              ? "bg-blue-600 text-white"
              : "text-dark-text-muted hover:bg-dark-surface hover:text-dark-text",
          )}
          title="Workspace Settings"
        >
          <Settings size={20} />
        </button>
      )}

      <ProfileMenu />
    </div>
  );
}
