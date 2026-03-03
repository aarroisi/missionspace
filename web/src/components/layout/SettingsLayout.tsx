import { ReactNode, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { Settings, Users, ChevronRight, ArrowLeft } from "lucide-react";
import { clsx } from "clsx";
import { useAuthStore } from "@/stores/authStore";
import { useIsMobile } from "@/hooks/useIsMobile";
import { ProfileMenu } from "@/components/features/ProfileMenu";

interface SettingsLayoutProps {
  children: ReactNode;
}

const settingsNavItems = [
  { path: "/settings/general", label: "General", icon: Settings },
  { path: "/settings/members", label: "Members", icon: Users },
];

export function SettingsLayout({ children }: SettingsLayoutProps) {
  const navigate = useNavigate();
  const location = useLocation();
  const { isOwner, isAuthenticated, user } = useAuthStore();
  const isMobile = useIsMobile();

  // Redirect non-owners to home
  useEffect(() => {
    if (isAuthenticated && !isOwner()) {
      navigate("/dashboard");
    }
  }, [isAuthenticated, isOwner, navigate]);

  if (!isOwner()) {
    return null;
  }

  const isSettingsRoot = location.pathname === "/settings";

  // Mobile: drill-down pattern
  if (isMobile) {
    // Show nav list on /settings, content on sub-pages
    if (isSettingsRoot) {
      return (
        <div className="flex-1 flex flex-col overflow-hidden">
          <div className="px-4 py-3 border-b border-dark-border flex items-center gap-3">
            <button
              onClick={() => navigate("/dashboard")}
              className="p-1.5 rounded-lg text-dark-text-muted hover:text-dark-text transition-colors"
            >
              <ArrowLeft size={20} />
            </button>
            <h1 className="text-lg font-semibold text-dark-text">
              Settings
            </h1>
          </div>
          <div className="flex-1 overflow-y-auto">
            {settingsNavItems.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  key={item.path}
                  onClick={() => navigate(item.path)}
                  className="w-full px-4 py-3.5 flex items-center gap-3 text-sm text-dark-text hover:bg-dark-surface transition-colors border-b border-dark-border"
                >
                  <Icon size={18} className="text-dark-text-muted" />
                  <span className="flex-1 text-left">{item.label}</span>
                  <ChevronRight size={16} className="text-dark-text-muted" />
                </button>
              );
            })}
          </div>
        </div>
      );
    }

    // Sub-page: show content with back button
    return (
      <div className="flex-1 flex flex-col overflow-hidden">
        <div className="px-4 py-3 border-b border-dark-border flex items-center gap-3">
          <button
            onClick={() => navigate("/settings")}
            className="p-1.5 rounded-lg text-dark-text-muted hover:text-dark-text transition-colors"
          >
            <ArrowLeft size={20} />
          </button>
          <h1 className="text-lg font-semibold text-dark-text">
            {settingsNavItems.find((i) => i.path === location.pathname)?.label || "Settings"}
          </h1>
        </div>
        <div className="flex-1 overflow-auto">{children}</div>
      </div>
    );
  }

  // Desktop: side-by-side layout
  return (
    <div className="flex h-screen bg-dark-bg">
      {/* Settings Sidebar */}
      <div className="w-64 bg-dark-surface border-r border-dark-border flex flex-col">
        {/* Header */}
        <div className="p-4 border-b border-dark-border">
          <button
            onClick={() => navigate("/dashboard")}
            className="text-sm text-dark-text-muted hover:text-dark-text transition-colors"
          >
            &larr; Back to workspace
          </button>
          <h1 className="text-lg font-semibold text-dark-text mt-2">
            Workspace Settings
          </h1>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-2">
          {settingsNavItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;

            return (
              <button
                key={item.path}
                onClick={() => navigate(item.path)}
                className={clsx(
                  "w-full px-3 py-2 rounded-lg flex items-center gap-3 text-sm transition-colors",
                  isActive
                    ? "bg-blue-600 text-white"
                    : "text-dark-text-muted hover:bg-dark-hover hover:text-dark-text",
                )}
              >
                <Icon size={18} />
                {item.label}
              </button>
            );
          })}
        </nav>

        {/* Profile at bottom */}
        <div className="p-4 border-t border-dark-border flex items-center gap-3">
          <ProfileMenu />
          <div className="flex-1 min-w-0">
            <div className="text-sm font-medium text-dark-text truncate">
              {user?.name}
            </div>
            <div className="text-xs text-dark-text-muted truncate">
              {user?.email}
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 overflow-auto">{children}</div>
    </div>
  );
}
