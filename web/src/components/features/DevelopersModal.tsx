import { useEffect, useState } from "react";
import { clsx } from "clsx";
import { Code2, Webhook } from "lucide-react";
import { api } from "@/lib/api";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { Modal } from "@/components/ui/Modal";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { ApiKey, CreatedApiKey } from "@/types";

interface DevelopersModalProps {
  isOpen: boolean;
  onClose: () => void;
}

type DevelopersSection = "api-keys" | "webhooks";

const sectionItems = [
  {
    id: "api-keys" as const,
    title: "API Keys",
    description: "Create and manage credentials for automation.",
    icon: Code2,
  },
  {
    id: "webhooks" as const,
    title: "Webhooks",
    description: "Prepare outbound integrations and delivery settings.",
    icon: Webhook,
  },
];

export function DevelopersModal({ isOpen, onClose }: DevelopersModalProps) {
  const { user } = useAuthStore();
  const { success, error: showError } = useToastStore();
  const [activeSection, setActiveSection] = useState<DevelopersSection>("api-keys");
  const [apiKeys, setApiKeys] = useState<ApiKey[]>([]);
  const [availableScopes, setAvailableScopes] = useState<string[]>([]);
  const [selectedScopes, setSelectedScopes] = useState<string[]>([]);
  const [apiKeyName, setApiKeyName] = useState("");
  const [apiKeysLoading, setApiKeysLoading] = useState(false);
  const [isCreatingApiKey, setIsCreatingApiKey] = useState(false);
  const [createdApiKey, setCreatedApiKey] = useState<CreatedApiKey | null>(null);
  const [createError, setCreateError] = useState<string | null>(null);
  const [apiKeyPendingRevoke, setApiKeyPendingRevoke] = useState<ApiKey | null>(null);
  const [isRevokingApiKey, setIsRevokingApiKey] = useState(false);

  useEffect(() => {
    if (!isOpen || !user) return;

    setActiveSection("api-keys");
    setApiKeyName("");
    setCreatedApiKey(null);
    setCreateError(null);
    setApiKeyPendingRevoke(null);
    setIsRevokingApiKey(false);

    let isMounted = true;

    const loadApiKeys = async () => {
      setApiKeysLoading(true);

      try {
        const [keys, scopeData] = await Promise.all([
          api.get<ApiKey[]>("/api-keys"),
          api.get<{ scopes: string[] }>("/api-keys/scopes"),
        ]);

        if (!isMounted) return;

        const roleScopes = (scopeData.scopes || []).slice().sort();
        setApiKeys(keys);
        setAvailableScopes(roleScopes);
        setSelectedScopes(roleScopes);
      } catch (err) {
        if (isMounted) {
          showError(err instanceof Error ? err.message : "Failed to load API keys");
        }
      } finally {
        if (isMounted) {
          setApiKeysLoading(false);
        }
      }
    };

    void loadApiKeys();

    return () => {
      isMounted = false;
    };
  }, [isOpen, user, showError]);

  if (!isOpen || !user) return null;

  const toggleScope = (scope: string) => {
    setSelectedScopes((prev) => {
      if (prev.includes(scope)) {
        return prev.filter((selectedScope) => selectedScope !== scope);
      }

      return [...prev, scope].sort();
    });
  };

  const buildVerifyCommand = (apiKey: CreatedApiKey) => {
    const verifyEndpoint = apiKey.verifyEndpoint || "/api/api-keys/verify";

    return [
      `export MISSIONSPACE_API_KEY="${apiKey.key}"`,
      `curl -s "${verifyEndpoint}" \\`,
      '  -H "Accept: application/json" \\',
      '  -H "X-API-Key: $MISSIONSPACE_API_KEY"',
    ].join("\n");
  };

  const handleCreateApiKey = async () => {
    const trimmedName = apiKeyName.trim();

    if (!trimmedName) {
      setCreateError("API key name is required");
      return;
    }

    setIsCreatingApiKey(true);
    setCreateError(null);

    try {
      const created = await api.post<CreatedApiKey>("/api-keys", {
        name: trimmedName,
        scopes: selectedScopes,
      });

      setApiKeys((prev) => [created, ...prev]);
      setCreatedApiKey(created);
      setApiKeyName("");
      success("API key created");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to create API key";
      setCreateError(message);
      showError(message);
    } finally {
      setIsCreatingApiKey(false);
    }
  };

  const handleCopyApiKey = async (apiKey: CreatedApiKey) => {
    try {
      await navigator.clipboard.writeText(apiKey.key);
      success("API key copied to clipboard");
    } catch {
      showError("Failed to copy API key");
    }
  };

  const handleCopyVerifyCommand = async (apiKey: CreatedApiKey) => {
    try {
      await navigator.clipboard.writeText(buildVerifyCommand(apiKey));
      success("Verify command copied to clipboard");
    } catch {
      showError("Failed to copy verify command");
    }
  };

  const handleRevokeApiKey = async () => {
    if (!apiKeyPendingRevoke) return;

    setIsRevokingApiKey(true);

    try {
      await api.delete(`/api-keys/${apiKeyPendingRevoke.id}`);
      setApiKeys((prev) => prev.filter((key) => key.id !== apiKeyPendingRevoke.id));
      setCreatedApiKey((prev) => (prev?.id === apiKeyPendingRevoke.id ? null : prev));
      setApiKeyPendingRevoke(null);
      success("API key revoked");
    } catch (err) {
      showError(err instanceof Error ? err.message : "Failed to revoke API key");
    } finally {
      setIsRevokingApiKey(false);
    }
  };

  const formatApiKeyTimestamp = (value?: string | null) => {
    if (!value) return "Never";

    return new Date(value).toLocaleString();
  };

  return (
    <Modal
      title="Developers"
      onClose={onClose}
      size="full"
      className="h-[calc(100vh-4rem)]"
      maxHeight="calc(100vh - 4rem)"
    >
      <div className="flex min-h-0 flex-1 flex-col overflow-hidden md:flex-row">
        <aside className="border-b border-dark-border bg-dark-surface/40 p-3 md:w-72 md:flex-shrink-0 md:border-b-0 md:border-r md:p-4">
          <div className="mb-3 px-1 md:mb-4">
            <p className="text-sm font-semibold text-dark-text">Developer Settings</p>
            <p className="mt-1 text-xs text-dark-text-muted">
              Keep integration tools grouped here as this area grows.
            </p>
          </div>

          <nav className="flex gap-2 overflow-x-auto pb-1 md:flex-col md:overflow-visible md:pb-0">
            {sectionItems.map((section) => {
              const Icon = section.icon;
              const isActive = activeSection === section.id;

              return (
                <button
                  key={section.id}
                  type="button"
                  onClick={() => setActiveSection(section.id)}
                  className={clsx(
                    "flex min-w-0 flex-shrink-0 items-center gap-3 rounded-lg border px-3 py-2.5 text-left transition-colors md:w-full",
                    isActive
                      ? "border-blue-500/50 bg-blue-600/15 text-dark-text"
                      : "border-dark-border bg-dark-bg/40 text-dark-text-muted hover:bg-dark-hover hover:text-dark-text",
                  )}
                >
                  <Icon size={18} className={clsx(isActive ? "text-blue-300" : "text-dark-text-muted")} />
                  <div className="min-w-0">
                    <p className="text-sm font-medium">{section.title}</p>
                    <p className="hidden text-xs md:block">{section.description}</p>
                  </div>
                </button>
              );
            })}
          </nav>
        </aside>

        <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4 sm:px-6 sm:py-5">
          {activeSection === "api-keys" && (
            <div className="space-y-6">
              <div>
                <h3 className="text-base font-semibold text-dark-text">API Keys</h3>
                <p className="mt-1 max-w-3xl text-sm text-dark-text-muted">
                  Create personal API keys for automation. We only show the raw key once, and each
                  key can only use scopes your current role allows.
                </p>
              </div>

              <div className="rounded-lg border border-dark-border bg-dark-bg/60 p-4 sm:p-5 space-y-4">
                <div className="grid gap-3 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-end">
                  <div className="space-y-2">
                    <label htmlFor="api-key-name" className="block text-sm font-medium text-dark-text">
                      Key name
                    </label>
                    <input
                      id="api-key-name"
                      type="text"
                      value={apiKeyName}
                      onChange={(e) => setApiKeyName(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          e.preventDefault();
                          void handleCreateApiKey();
                        }
                      }}
                      className="w-full rounded-lg border border-dark-border bg-dark-bg px-3 py-2 text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      placeholder="CI integration"
                    />
                  </div>

                  <button
                    type="button"
                    onClick={() => void handleCreateApiKey()}
                    disabled={isCreatingApiKey || !apiKeyName.trim()}
                    className="h-11 rounded-lg bg-blue-600 px-4 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {isCreatingApiKey ? "Creating..." : "Create API key"}
                  </button>
                </div>

                <div className="space-y-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-medium text-dark-text">
                      Scopes ({selectedScopes.length}/{availableScopes.length})
                    </p>
                    <button
                      type="button"
                      onClick={() => setSelectedScopes(availableScopes)}
                      className="text-xs font-medium text-blue-300 transition-colors hover:text-blue-200"
                    >
                      Select all
                    </button>
                  </div>

                  <div className="grid grid-cols-1 gap-2 xl:grid-cols-2">
                    {availableScopes.map((scope) => (
                      <label
                        key={scope}
                        className="flex min-w-0 items-start gap-3 rounded-lg border border-dark-border bg-dark-surface px-3 py-2 text-sm text-dark-text"
                      >
                        <input
                          type="checkbox"
                          checked={selectedScopes.includes(scope)}
                          onChange={() => toggleScope(scope)}
                          className="mt-0.5 shrink-0 rounded border-dark-border bg-dark-bg"
                        />
                        <span className="min-w-0 break-all font-mono leading-5">{scope}</span>
                      </label>
                    ))}
                  </div>
                </div>

                {!createdApiKey && createError && <p className="text-sm text-red-300">{createError}</p>}

                {createdApiKey && (
                  <div className="space-y-3 rounded-lg border border-blue-500/40 bg-blue-500/10 p-4">
                    <p className="text-sm font-semibold text-blue-200">
                      New API key (copy it now, it will not be shown again)
                    </p>
                    <code className="block break-all rounded border border-blue-500/20 bg-dark-bg px-3 py-3 text-sm text-blue-100">
                      {createdApiKey.key}
                    </code>
                    <div className="space-y-2">
                      <p className="text-sm font-medium text-blue-100">
                        Verify it manually in your terminal
                      </p>
                      <pre className="overflow-x-auto rounded border border-blue-500/20 bg-dark-bg px-3 py-3 text-xs text-blue-100">
                        <code>{buildVerifyCommand(createdApiKey)}</code>
                      </pre>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        onClick={() => void handleCopyApiKey(createdApiKey)}
                        className="rounded bg-dark-surface px-3 py-2 text-sm text-dark-text transition-colors hover:bg-dark-border"
                      >
                        Copy key
                      </button>
                      <button
                        type="button"
                        onClick={() => void handleCopyVerifyCommand(createdApiKey)}
                        className="rounded bg-blue-600 px-3 py-2 text-sm text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        Copy verify command
                      </button>
                    </div>

                    <p className="text-sm text-blue-100/80">
                      Run the command yourself to confirm the key works from your own environment.
                    </p>
                  </div>
                )}
              </div>

              <div className="space-y-3">
                <div>
                  <h3 className="text-sm font-semibold text-dark-text">Active keys</h3>
                  <p className="mt-1 text-sm text-dark-text-muted">
                    Manage the keys your automations currently use.
                  </p>
                </div>

                {apiKeysLoading && <p className="text-sm text-dark-text-muted">Loading keys...</p>}

                {!apiKeysLoading && apiKeys.length === 0 && (
                  <div className="rounded-lg border border-dashed border-dark-border bg-dark-bg/30 px-4 py-6 text-sm text-dark-text-muted">
                    No API keys created yet.
                  </div>
                )}

                {!apiKeysLoading && apiKeys.length > 0 && (
                  <div className="grid gap-3 xl:grid-cols-2">
                    {apiKeys.map((apiKey) => (
                      <div
                        key={apiKey.id}
                        className="flex min-w-0 items-start justify-between gap-4 rounded-lg border border-dark-border bg-dark-surface px-4 py-3"
                      >
                        <div className="min-w-0 space-y-1">
                          <p className="text-sm font-medium text-dark-text">{apiKey.name}</p>
                          <p className="break-all font-mono text-xs text-dark-text-muted">
                            {apiKey.keyPrefix}
                          </p>
                          <p className="text-xs text-dark-text-muted">Scopes: {apiKey.scopes.length}</p>
                          <p className="text-xs text-dark-text-muted">
                            Last used: {formatApiKeyTimestamp(apiKey.lastUsedAt)}
                          </p>
                        </div>
                        <button
                          type="button"
                          onClick={() => setApiKeyPendingRevoke(apiKey)}
                          className="shrink-0 text-sm text-red-300 transition-colors hover:text-red-200"
                        >
                          Revoke
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {activeSection === "webhooks" && (
            <div className="space-y-6">
              <div>
                <h3 className="text-base font-semibold text-dark-text">Webhooks</h3>
                <p className="mt-1 max-w-3xl text-sm text-dark-text-muted">
                  This area is reserved for outbound webhook configuration so future developer
                  tools stay grouped in one place.
                </p>
              </div>

              <div className="rounded-lg border border-dashed border-dark-border bg-dark-bg/30 px-5 py-6">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-dark-text">Webhook settings</p>
                    <p className="mt-1 max-w-2xl text-sm text-dark-text-muted">
                      We can add delivery endpoints, event subscriptions, retries, and signing
                      secrets here without changing the Developers menu structure again.
                    </p>
                  </div>
                  <span className="rounded-full border border-dark-border bg-dark-surface px-2.5 py-1 text-xs font-medium text-dark-text-muted">
                    Coming later
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      <ConfirmModal
        isOpen={apiKeyPendingRevoke !== null}
        title="Revoke API Key"
        message={apiKeyPendingRevoke
          ? `Are you sure you want to revoke "${apiKeyPendingRevoke.name}"? This action cannot be undone.`
          : "Are you sure you want to revoke this API key? This action cannot be undone."}
        confirmText={isRevokingApiKey ? "Revoking..." : "Revoke"}
        confirmVariant="danger"
        onConfirm={handleRevokeApiKey}
        onCancel={() => {
          if (isRevokingApiKey) return;
          setApiKeyPendingRevoke(null);
        }}
      />
    </Modal>
  );
}
