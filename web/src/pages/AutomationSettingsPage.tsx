import { useCallback, useEffect, useState } from "react";
import { Loader2, Link2, RefreshCw, Unplug } from "lucide-react";
import { useLocation, useNavigate } from "react-router-dom";
import { api } from "@/lib/api";
import { useToastStore } from "@/stores/toastStore";

interface AutomationRepository {
  id?: string;
  provider: string;
  repoOwner: string;
  repoName: string;
  defaultBranch: string;
  enabled: boolean;
}

interface WorkspaceAutomationSettings {
  id: string;
  provider: string;
  githubAppInstallationId: string | null;
  executionEnvironment: string;
  autonomousExecutionEnabled: boolean;
  autoOpenPrs: boolean;
  codexApiKeyConfigured: boolean;
  codexApiKeyLast4: string | null;
  codexApiKeyUpdatedAt: string | null;
  codexAuthMethod: "api_key" | "chatgpt_oauth" | null;
  codexOauthAccountId: string | null;
  codexOauthPlanType: string | null;
  repositories: AutomationRepository[];
}

interface CodexConnection {
  provider: "codex";
  status: "connected" | "not_connected";
  connected: boolean;
  authMethod: "api_key" | "chatgpt_oauth" | null;
  connectUrl: string | null;
  keyLast4: string | null;
  keyUpdatedAt: string | null;
  oauthAccountId: string | null;
  oauthPlanType: string | null;
}

interface CodexDeviceAuthorization {
  deviceAuthId: string;
  userCode: string;
  intervalSeconds: number;
  expiresAt: string | null;
  verificationUrl: string;
  status?: "pending";
}

interface GitHubConnection {
  provider: "github_app";
  status: "connected" | "not_connected";
  connected: boolean;
  installationId: string | null;
  connectUrl: string | null;
  repositoryCount: number;
  accountLogin: string | null;
  accountType: string | null;
  accountAvatarUrl: string | null;
  accountUrl: string | null;
  appSlug: string | null;
  repositorySelection: "all" | "selected" | null;
}

const DEFAULT_SETTINGS: WorkspaceAutomationSettings = {
  id: "",
  provider: "codex",
  githubAppInstallationId: null,
  executionEnvironment: "isolated",
  autonomousExecutionEnabled: false,
  autoOpenPrs: true,
  codexApiKeyConfigured: false,
  codexApiKeyLast4: null,
  codexApiKeyUpdatedAt: null,
  codexAuthMethod: null,
  codexOauthAccountId: null,
  codexOauthPlanType: null,
  repositories: [],
};

const DEFAULT_CODEX_CONNECTION: CodexConnection = {
  provider: "codex",
  status: "not_connected",
  connected: false,
  authMethod: null,
  connectUrl: null,
  keyLast4: null,
  keyUpdatedAt: null,
  oauthAccountId: null,
  oauthPlanType: null,
};

const DEFAULT_GITHUB_CONNECTION: GitHubConnection = {
  provider: "github_app",
  status: "not_connected",
  connected: false,
  installationId: null,
  connectUrl: null,
  repositoryCount: 0,
  accountLogin: null,
  accountType: null,
  accountAvatarUrl: null,
  accountUrl: null,
  appSlug: null,
  repositorySelection: null,
};

export function AutomationSettingsPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { success, error } = useToastStore();
  const [settings, setSettings] =
    useState<WorkspaceAutomationSettings>(DEFAULT_SETTINGS);
  const [githubConnection, setGithubConnection] = useState<GitHubConnection>(
    DEFAULT_GITHUB_CONNECTION,
  );
  const [codexConnection, setCodexConnection] = useState<CodexConnection>(
    DEFAULT_CODEX_CONNECTION,
  );
  const [codexApiKey, setCodexApiKey] = useState("");
  const [clearCodexApiKey, setClearCodexApiKey] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isSyncingGithubConnection, setIsSyncingGithubConnection] = useState(false);
  const [isSyncingCodexConnection, setIsSyncingCodexConnection] = useState(false);
  const [isSyncingRepositories, setIsSyncingRepositories] = useState(false);
  const [codexDeviceAuthorization, setCodexDeviceAuthorization] =
    useState<CodexDeviceAuthorization | null>(null);

  const loadSettings = useCallback(async () => {
    try {
      const response = await api.get<{ automation: WorkspaceAutomationSettings }>(
        "/workspace/automation",
      );
      setSettings(response.automation);
    } catch (err) {
      error(`Failed to load automation settings: ${(err as Error).message}`);
    }
  }, [error]);

  const loadGitHubConnection = useCallback(async () => {
    try {
      const response = await api.get<{ githubConnection: GitHubConnection }>(
        "/workspace/automation/github-connection",
      );
      setGithubConnection(response.githubConnection);
    } catch (err) {
      error(`Failed to load GitHub connection status: ${(err as Error).message}`);
    }
  }, [error]);

  const loadCodexConnection = useCallback(async () => {
    try {
      const response = await api.get<{ codexConnection: CodexConnection }>(
        "/workspace/automation/codex-connection",
      );
      setCodexConnection(response.codexConnection);
    } catch (err) {
      error(`Failed to load Codex connection status: ${(err as Error).message}`);
    }
  }, [error]);

  useEffect(() => {
    let isMounted = true;

    const loadData = async () => {
      await Promise.all([
        loadSettings(),
        loadGitHubConnection(),
        loadCodexConnection(),
      ]);

      if (isMounted) {
        setIsLoading(false);
      }
    };

    loadData();

    return () => {
      isMounted = false;
    };
  }, [loadSettings, loadGitHubConnection, loadCodexConnection]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const installationId = params.get("installation_id");
    const state = params.get("state");

    if (!installationId || !state) {
      setIsSyncingGithubConnection(false);
      return;
    }

    let isMounted = true;

    const linkInstallation = async () => {
      setIsSyncingGithubConnection(true);

      try {
        const response = await api.put<{ automation: WorkspaceAutomationSettings }>(
          "/workspace/automation/github-connection",
          { installationId, state },
        );

        setSettings(response.automation);
        await loadGitHubConnection();
        success("GitHub App connected successfully");

        params.delete("installation_id");
        params.delete("setup_action");
        params.delete("state");
        params.delete("code");

        const nextSearch = params.toString();
        navigate(
          {
            pathname: location.pathname,
            search: nextSearch === "" ? "" : `?${nextSearch}`,
          },
          { replace: true },
        );
      } catch (err) {
        error(`Failed to connect GitHub App: ${(err as Error).message}`);
      } finally {
        if (isMounted) {
          setIsSyncingGithubConnection(false);
        }
      }
    };

    linkInstallation();

    return () => {
      isMounted = false;
    };
  }, [location.pathname, location.search, navigate, loadGitHubConnection, success, error]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const installationId = params.get("installation_id");
    const code = params.get("code");
    const state = params.get("state");

    if (installationId || !code || !state) {
      setIsSyncingCodexConnection(false);
      return;
    }

    let isMounted = true;

    const linkCodexConnection = async () => {
      setIsSyncingCodexConnection(true);

      try {
        const response = await api.put<{ automation: WorkspaceAutomationSettings }>(
          "/workspace/automation/codex-connection",
          { code, state },
        );

        setSettings(response.automation);
        await loadCodexConnection();
        success("Codex connected with ChatGPT subscription");

        params.delete("code");
        params.delete("state");

        const nextSearch = params.toString();
        navigate(
          {
            pathname: location.pathname,
            search: nextSearch === "" ? "" : `?${nextSearch}`,
          },
          { replace: true },
        );
      } catch (err) {
        error(`Failed to connect Codex with ChatGPT: ${(err as Error).message}`);
      } finally {
        if (isMounted) {
          setIsSyncingCodexConnection(false);
        }
      }
    };

    linkCodexConnection();

    return () => {
      isMounted = false;
    };
  }, [location.pathname, location.search, navigate, loadCodexConnection, success, error]);

  const handleSave = async (event: React.FormEvent) => {
    event.preventDefault();
    setIsSaving(true);

    try {
      const response = await api.put<{ automation: WorkspaceAutomationSettings }>(
        "/workspace/automation",
        {
          automation: {
            provider: settings.provider,
            autonomousExecutionEnabled: settings.autonomousExecutionEnabled,
            autoOpenPrs: settings.autoOpenPrs,
            codexApiKey: codexApiKey.trim() === "" ? undefined : codexApiKey.trim(),
            clearCodexApiKey,
          },
        },
      );

      setSettings(response.automation);
      await loadCodexConnection();
      setCodexApiKey("");
      setClearCodexApiKey(false);
      success("Automation settings saved");
    } catch (err) {
      error(`Failed to save settings: ${(err as Error).message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const connectCodexOAuth = async () => {
    setIsSyncingCodexConnection(true);

    try {
      const response = await api.post<{ codexDeviceAuthorization: CodexDeviceAuthorization }>(
        "/workspace/automation/codex-connection/device",
      );

      setCodexDeviceAuthorization(response.codexDeviceAuthorization);
      window.open(response.codexDeviceAuthorization.verificationUrl, "_blank", "noopener,noreferrer");
      success("Opened ChatGPT device authorization. Enter the shown code to continue.");
    } catch (err) {
      error(`Failed to start ChatGPT device authorization: ${(err as Error).message}`);
    } finally {
      setIsSyncingCodexConnection(false);
    }
  };

  const completeCodexDeviceAuthorization = async () => {
    if (!codexDeviceAuthorization) {
      return;
    }

    setIsSyncingCodexConnection(true);

    try {
      const response = await api.post<
        | { automation: WorkspaceAutomationSettings }
        | { codexDeviceAuthorization: CodexDeviceAuthorization }
      >("/workspace/automation/codex-connection/device/complete", {
        deviceAuthId: codexDeviceAuthorization.deviceAuthId,
        userCode: codexDeviceAuthorization.userCode,
      });

      if ("automation" in response) {
        setSettings(response.automation);
        setCodexDeviceAuthorization(null);
        await loadCodexConnection();
        success("Codex connected with ChatGPT subscription");
      } else {
        setCodexDeviceAuthorization((prev) =>
          prev
            ? {
                ...prev,
                status: "pending",
                intervalSeconds: response.codexDeviceAuthorization.intervalSeconds,
              }
            : prev,
        );

        error("Authorization is still pending. Complete the ChatGPT verification and try again.");
      }
    } catch (err) {
      error(`Failed to complete ChatGPT device authorization: ${(err as Error).message}`);
    } finally {
      setIsSyncingCodexConnection(false);
    }
  };

  const disconnectCodexConnection = async () => {
    setIsSyncingCodexConnection(true);

    try {
      const response = await api.delete<{ automation: WorkspaceAutomationSettings }>(
        "/workspace/automation/codex-connection",
      );

      setSettings(response.automation);
      await loadCodexConnection();
      setCodexDeviceAuthorization(null);
      success("Codex credentials disconnected");
    } catch (err) {
      error(`Failed to disconnect Codex credentials: ${(err as Error).message}`);
    } finally {
      setIsSyncingCodexConnection(false);
    }
  };

  const connectGitHub = () => {
    if (!githubConnection.connectUrl) {
      error("GitHub App install URL is not configured yet");
      return;
    }

    window.location.assign(githubConnection.connectUrl);
  };

  const configureGitHub = () => {
    if (!githubConnection.connectUrl) {
      error("GitHub App configure URL is not configured yet");
      return;
    }

    window.location.assign(githubConnection.connectUrl);
  };

  const disconnectGitHub = async () => {
    setIsSyncingGithubConnection(true);

    try {
      const response = await api.delete<{ automation: WorkspaceAutomationSettings }>(
        "/workspace/automation/github-connection",
      );

      setSettings(response.automation);
      await loadGitHubConnection();
      success("GitHub App disconnected");
    } catch (err) {
      error(`Failed to disconnect GitHub App: ${(err as Error).message}`);
    } finally {
      setIsSyncingGithubConnection(false);
    }
  };

  const syncGitHubRepositories = async () => {
    setIsSyncingRepositories(true);

    try {
      const response = await api.post<{ automation: WorkspaceAutomationSettings }>(
        "/workspace/automation/github-connection/sync",
      );

      setSettings(response.automation);
      await loadGitHubConnection();
      success("Repositories synced from GitHub")
    } catch (err) {
      error(`Failed to sync repositories from GitHub: ${(err as Error).message}`);
    } finally {
      setIsSyncingRepositories(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex min-h-[70vh] w-full items-center justify-center">
        <div className="inline-flex items-center gap-3 rounded-lg border border-dark-border bg-dark-surface px-4 py-3 text-dark-text-muted">
          <Loader2 size={18} className="animate-spin text-blue-400" />
          <span className="text-sm">Loading automation settings...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-4 md:p-8">
      <h1 className="text-2xl font-semibold text-dark-text mb-2">Automation</h1>
      <p className="text-dark-text-muted mb-8">
        Configure autonomous Codex execution and sync repository targets from
        your connected GitHub App installation.
      </p>

      <form onSubmit={handleSave} className="space-y-8">
        <section className="bg-dark-surface border border-dark-border rounded-lg p-5 space-y-3">
          <h2 className="text-lg font-medium text-dark-text">Execution Environment</h2>
          <p className="text-sm text-dark-text-muted">
            Agent runs execute in an isolated MissionSpace-managed environment.
            Infrastructure setup and billing details are handled internally.
          </p>
        </section>

        <section className="bg-dark-surface border border-dark-border rounded-lg p-5 space-y-4">
          <h2 className="text-lg font-medium text-dark-text">Execution Defaults</h2>

          <label className="flex items-center justify-between gap-4 py-1">
            <div>
              <div className="text-sm font-medium text-dark-text">
                Enable autonomous execution
              </div>
              <div className="text-xs text-dark-text-muted">
                Allow task runs to execute without step-by-step human
                approvals.
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.autonomousExecutionEnabled}
              onChange={(event) =>
                setSettings((prev) => ({
                  ...prev,
                  autonomousExecutionEnabled: event.target.checked,
                }))
              }
              className="h-4 w-4 rounded border-dark-border bg-dark-bg text-blue-600"
            />
          </label>

          <label className="flex items-center justify-between gap-4 py-1">
            <div>
              <div className="text-sm font-medium text-dark-text">Auto-open PRs</div>
              <div className="text-xs text-dark-text-muted">
                Open pull requests automatically after successful autonomous runs.
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.autoOpenPrs}
              onChange={(event) =>
                setSettings((prev) => ({
                  ...prev,
                  autoOpenPrs: event.target.checked,
                }))
              }
              className="h-4 w-4 rounded border-dark-border bg-dark-bg text-blue-600"
            />
          </label>
        </section>

        <section className="bg-dark-surface border border-dark-border rounded-lg p-5 space-y-4">
          <h2 className="text-lg font-medium text-dark-text">Codex Connection</h2>

          <div className="border border-dark-border rounded-lg p-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-dark-text">
                Status: {codexConnection.connected ? "Connected" : "Not connected"}
              </p>
              <p className="text-xs text-dark-text-muted mt-1">
                {codexConnection.connected
                  ? codexConnection.authMethod === "chatgpt_oauth"
                    ? "Connected with ChatGPT subscription OAuth"
                    : "Connected with manual Codex API key"
                  : "Connect using ChatGPT device authorization or enter a Codex API key manually."}
              </p>

              {codexConnection.connected && codexConnection.keyLast4 && (
                <p className="text-xs text-dark-text-muted mt-1">
                  Stored credential ending in {codexConnection.keyLast4}
                </p>
              )}

              {codexConnection.authMethod === "chatgpt_oauth" &&
                codexConnection.oauthAccountId && (
                  <p className="text-xs text-dark-text-muted mt-1">
                    ChatGPT account: {codexConnection.oauthAccountId}
                    {codexConnection.oauthPlanType
                      ? ` (${codexConnection.oauthPlanType})`
                      : ""}
                  </p>
                )}
            </div>

            <div className="flex items-center gap-2">
              {!codexConnection.connected && (
                <button
                  type="button"
                  onClick={connectCodexOAuth}
                  disabled={isSyncingCodexConnection}
                  className="px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
                >
                  {isSyncingCodexConnection ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Link2 size={14} />
                  )}
                  Connect ChatGPT
                </button>
              )}

              {codexConnection.connected && (
                <button
                  type="button"
                  onClick={disconnectCodexConnection}
                  disabled={isSyncingCodexConnection}
                  className="px-3 py-2 text-sm bg-dark-hover text-dark-text rounded-lg hover:bg-dark-border disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
                >
                  <Unplug size={14} />
                  Disconnect
                </button>
              )}
            </div>
          </div>

          {!codexConnection.connected && codexDeviceAuthorization && (
            <div className="rounded-lg border border-dark-border bg-dark-bg/50 p-4 space-y-2">
              <p className="text-xs text-dark-text-muted">
                Step 1: Open ChatGPT device authorization and enter this code.
              </p>
              <p className="text-lg font-semibold tracking-wide text-dark-text">
                {codexDeviceAuthorization.userCode}
              </p>
              <p className="text-xs text-dark-text-muted">
                Step 2: After authorizing, click "Complete Connection" below.
              </p>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() =>
                    window.open(
                      codexDeviceAuthorization.verificationUrl,
                      "_blank",
                      "noopener,noreferrer",
                    )
                  }
                  className="px-3 py-2 text-xs bg-dark-hover text-dark-text rounded-lg hover:bg-dark-border transition-colors"
                >
                  Open Verification Page
                </button>
                <button
                  type="button"
                  onClick={completeCodexDeviceAuthorization}
                  disabled={isSyncingCodexConnection}
                  className="px-3 py-2 text-xs bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
                >
                  {isSyncingCodexConnection ? (
                    <Loader2 size={12} className="animate-spin" />
                  ) : null}
                  Complete Connection
                </button>
              </div>
            </div>
          )}

          {!codexConnection.connected && (
            <div className="pt-1 border-t border-dark-border/60 space-y-3">
              <p className="text-xs text-dark-text-muted">
                Prefer API key auth? Enter a Codex API key and save settings to use it instead of
                OAuth.
              </p>

              <div>
                <label
                  htmlFor="codex-api-key"
                  className="block text-sm font-medium text-dark-text mb-2"
                >
                  Codex API Key
                </label>
                <input
                  id="codex-api-key"
                  type="password"
                  value={codexApiKey}
                  onChange={(event) => setCodexApiKey(event.target.value)}
                  className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="sk-..."
                  autoComplete="off"
                />
                <p className="text-xs text-dark-text-muted mt-2">
                  {settings.codexApiKeyConfigured
                    ? `Stored key ending in ${settings.codexApiKeyLast4 || "****"}`
                    : "No Codex key stored yet"}
                </p>
              </div>

              <label className="flex items-center gap-2 text-sm text-dark-text-muted">
                <input
                  type="checkbox"
                  checked={clearCodexApiKey}
                  onChange={(event) => setClearCodexApiKey(event.target.checked)}
                  className="h-4 w-4 rounded border-dark-border bg-dark-bg text-blue-600"
                />
                Remove stored Codex key on save
              </label>
            </div>
          )}
        </section>

        <section className="bg-dark-surface border border-dark-border rounded-lg p-5 space-y-4">
          <h2 className="text-lg font-medium text-dark-text">GitHub Connection</h2>

          <div className="border border-dark-border rounded-lg p-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-dark-text">
                Status: {githubConnection.connected ? "Connected" : "Not connected"}
              </p>
              <p className="text-xs text-dark-text-muted mt-1">
                {githubConnection.connected
                  ? `GitHub App installation ${githubConnection.installationId}`
                  : "Connect your GitHub App installation to enable repository-backed automation."}
              </p>

              {githubConnection.connected && githubConnection.accountLogin && (
                <p className="text-xs text-dark-text-muted mt-1 inline-flex items-center gap-2">
                  {githubConnection.accountAvatarUrl ? (
                    <img
                      src={githubConnection.accountAvatarUrl}
                      alt={`${githubConnection.accountLogin} avatar`}
                      className="h-4 w-4 rounded-full"
                    />
                  ) : null}
                  Connected account:
                  {githubConnection.accountUrl ? (
                    <a
                      href={githubConnection.accountUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="text-blue-400 hover:text-blue-300"
                    >
                      {githubConnection.accountLogin}
                    </a>
                  ) : (
                    <span>{githubConnection.accountLogin}</span>
                  )}
                  {githubConnection.accountType ? `(${githubConnection.accountType})` : ""}
                </p>
              )}

              {githubConnection.connected && (
                <p className="text-xs text-dark-text-muted mt-1">
                  Synced repositories: {githubConnection.repositoryCount}
                </p>
              )}
            </div>

            {githubConnection.connected ? (
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={configureGitHub}
                  disabled={
                    isSyncingGithubConnection ||
                    isSyncingRepositories ||
                    !githubConnection.connectUrl
                  }
                  className="px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
                >
                  <Link2 size={14} />
                  Configure GitHub
                </button>

                <button
                  type="button"
                  onClick={disconnectGitHub}
                  disabled={isSyncingGithubConnection || isSyncingRepositories}
                  className="px-3 py-2 text-sm bg-dark-hover text-dark-text rounded-lg hover:bg-dark-border disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
                >
                  {isSyncingGithubConnection ? (
                    <Loader2 size={14} className="animate-spin" />
                  ) : (
                    <Unplug size={14} />
                  )}
                  Disconnect GitHub
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={connectGitHub}
                disabled={isSyncingGithubConnection || !githubConnection.connectUrl}
                className="px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
              >
                {isSyncingGithubConnection ? (
                  <Loader2 size={14} className="animate-spin" />
                ) : (
                  <Link2 size={14} />
                )}
                Connect GitHub
              </button>
            )}
          </div>

          {!githubConnection.connectUrl && (
            <p className="text-xs text-dark-text-muted">
              GitHub App connect URL is not configured on the server.
            </p>
          )}
        </section>

        <section className="bg-dark-surface border border-dark-border rounded-lg p-5 space-y-4">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-lg font-medium text-dark-text">Connected Repositories</h2>
            <button
              type="button"
              onClick={syncGitHubRepositories}
              disabled={
                isSyncingRepositories ||
                isSyncingGithubConnection ||
                !githubConnection.connected
              }
              className="px-3 py-2 text-sm bg-dark-hover text-dark-text rounded-lg hover:bg-dark-border disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
            >
              {isSyncingRepositories ? (
                <Loader2 size={14} className="animate-spin" />
              ) : (
                <RefreshCw size={14} />
              )}
              Sync From GitHub
            </button>
          </div>

          <p className="text-xs text-dark-text-muted">
            Repositories are managed from your GitHub App installation and synced into MissionSpace.
            Manual edits are disabled.
          </p>

          <div className="overflow-x-auto border border-dark-border rounded-lg">
            <table className="min-w-full text-sm">
              <thead className="bg-dark-hover/50">
                <tr>
                  <th className="text-left px-4 py-3 text-dark-text-muted font-medium">Owner</th>
                  <th className="text-left px-4 py-3 text-dark-text-muted font-medium">Repository</th>
                  <th className="text-left px-4 py-3 text-dark-text-muted font-medium">Base Branch</th>
                  <th className="text-left px-4 py-3 text-dark-text-muted font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {settings.repositories.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="px-4 py-4 text-dark-text-muted">
                      No repositories synced yet. Connect GitHub and use "Sync From GitHub".
                    </td>
                  </tr>
                ) : (
                  settings.repositories.map((repository, index) => (
                    <tr key={`${repository.id || "synced"}-${index}`} className="border-t border-dark-border">
                      <td className="px-4 py-3 text-dark-text">{repository.repoOwner}</td>
                      <td className="px-4 py-3 text-dark-text">{repository.repoName}</td>
                      <td className="px-4 py-3 text-dark-text">{repository.defaultBranch}</td>
                      <td className="px-4 py-3">
                        <span
                          className={repository.enabled ? "text-emerald-400" : "text-dark-text-muted"}
                        >
                          {repository.enabled ? "Enabled" : "Disabled"}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </section>

        <div className="flex justify-end">
          <button
            type="submit"
            disabled={isSaving}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors inline-flex items-center gap-2"
          >
            {isSaving && <Loader2 size={16} className="animate-spin" />}
            {isSaving ? "Saving..." : "Save Automation Settings"}
          </button>
        </div>
      </form>
    </div>
  );
}
