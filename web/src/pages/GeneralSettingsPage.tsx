import { useState, useEffect } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { StorageUsage } from "@/components/features/StorageUsage";

export function GeneralSettingsPage() {
  const { workspace, updateWorkspace } = useAuthStore();
  const { success, error } = useToastStore();

  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  // Initialize form with workspace data
  useEffect(() => {
    if (workspace) {
      setName(workspace.name);
      setSlug(workspace.slug);
    }
  }, [workspace]);

  // Track changes
  useEffect(() => {
    if (workspace) {
      setHasChanges(name !== workspace.name || slug !== workspace.slug);
    }
  }, [name, slug, workspace]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!hasChanges) return;

    setIsLoading(true);
    try {
      await updateWorkspace({ name, slug });
      success("Workspace settings updated");
    } catch (err) {
      error("Failed to update settings: " + (err as Error).message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSlugChange = (value: string) => {
    // Sanitize slug: lowercase, replace spaces with hyphens, remove invalid chars
    const sanitized = value
      .toLowerCase()
      .replace(/\s+/g, "-")
      .replace(/[^a-z0-9-]/g, "");
    setSlug(sanitized);
  };

  return (
    <div className="max-w-2xl mx-auto p-8">
      <h1 className="text-2xl font-bold text-dark-text mb-2">
        General Settings
      </h1>
      <p className="text-dark-text-muted mb-8">
        Manage your workspace's basic information.
      </p>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Workspace Name */}
        <div>
          <label
            htmlFor="name"
            className="block text-sm font-medium text-dark-text mb-2"
          >
            Workspace Name
          </label>
          <input
            type="text"
            id="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-3 py-2 bg-dark-surface border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="My Workspace"
            required
          />
          <p className="mt-1 text-sm text-dark-text-muted">
            This is the display name for your workspace.
          </p>
        </div>

        {/* Subdomain / Slug */}
        <div>
          <label
            htmlFor="slug"
            className="block text-sm font-medium text-dark-text mb-2"
          >
            Subdomain
          </label>
          <div className="flex items-center">
            <input
              type="text"
              id="slug"
              value={slug}
              onChange={(e) => handleSlugChange(e.target.value)}
              className="flex-1 px-3 py-2 bg-dark-surface border border-dark-border rounded-l-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="my-org"
              required
              minLength={3}
              maxLength={30}
            />
            <span className="px-3 py-2 bg-dark-hover border border-l-0 border-dark-border rounded-r-lg text-dark-text-muted">
              .bridge.app
            </span>
          </div>
          <p className="mt-1 text-sm text-dark-text-muted">
            URL-friendly identifier. Only lowercase letters, numbers, and
            hyphens allowed.
          </p>
        </div>

        {/* Submit Button */}
        <div className="flex justify-end pt-4">
          <button
            type="submit"
            disabled={!hasChanges || isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isLoading ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </form>

      {/* Storage Usage Section */}
      <div className="mt-12">
        <h2 className="text-lg font-semibold text-dark-text mb-2">
          Storage Usage
        </h2>
        <p className="text-dark-text-muted mb-4">
          Track how much storage your workspace is using for uploaded files and
          images.
        </p>
        <StorageUsage />
      </div>
    </div>
  );
}
