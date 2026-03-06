import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { DeviceAccount, useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Avatar } from "@/components/ui/Avatar";
import { AccountReauthModal } from "@/components/features/AccountReauthModal";
import { ConfirmModal } from "@/components/ui/ConfirmModal";

export function LoginPage() {
  const navigate = useNavigate();
  const { login, switchAccount, fetchAccounts, accounts, removeAccount } = useAuthStore();
  const { success, error: showError } = useToastStore();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [switchingAccountId, setSwitchingAccountId] = useState<string | null>(null);
  const [showCredentialForm, setShowCredentialForm] = useState(false);
  const [reauthAccount, setReauthAccount] = useState<DeviceAccount | null>(null);
  const [accountToRemove, setAccountToRemove] = useState<DeviceAccount | null>(null);
  const [isRemovingAccount, setIsRemovingAccount] = useState(false);

  useEffect(() => {
    void fetchAccounts();
  }, [fetchAccounts]);

  useEffect(() => {
    setShowCredentialForm(accounts.length === 0);
  }, [accounts.length]);

  const handleSwitchAccount = async (userId: string) => {
    setError("");
    setSwitchingAccountId(userId);

    try {
      await switchAccount(userId);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to switch account";
      setError(errorMessage);
      showError(errorMessage);
    } finally {
      setSwitchingAccountId(null);
    }
  };

  const handleRemoveAccount = async () => {
    if (!accountToRemove) return;

    setIsRemovingAccount(true);

    try {
      await removeAccount(accountToRemove.user.id);
      setAccountToRemove(null);
      setReauthAccount(null);
      success("Account removed from this device");
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to remove account";
      setError(errorMessage);
      showError(errorMessage);
    } finally {
      setIsRemovingAccount(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      await login(email, password);
      success("Signed in successfully!");
      navigate("/dashboard");
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Login failed";

      if (errorMessage === "email_not_verified") {
        navigate("/verify-email");
        return;
      }

      setError(errorMessage);
      showError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const showAccountChooser = accounts.length > 0 && !showCredentialForm;

  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-bg px-4">
      <div className="max-w-md w-full">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-dark-text mb-2">
            Welcome Back
          </h1>
          <p className="text-dark-text-muted">
            {showAccountChooser ? "Choose an account" : "Sign in to your workspace"}
          </p>
        </div>

        {error && (
          <div className="mb-4 bg-red-900/20 border border-red-500 text-red-200 px-4 py-3 rounded">
            {error}
          </div>
        )}

        {showAccountChooser ? (
          <div className="space-y-3">
            {accounts.map((account) => {
              const isSwitching = switchingAccountId === account.user.id;
              const isSignedOut = account.state === "signed_out";

              return (
                <button
                  key={account.user.id}
                  type="button"
                  onClick={() => {
                    if (isSignedOut) {
                      setReauthAccount(account);
                      return;
                    }

                    void handleSwitchAccount(account.user.id);
                  }}
                  disabled={switchingAccountId !== null}
                  className="w-full rounded-lg border border-dark-border bg-dark-surface px-4 py-3 text-left transition-colors hover:border-blue-500/50 hover:bg-dark-hover disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <div className="flex items-center gap-3">
                    <Avatar name={account.user.name} src={account.user.avatar} size="md" />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-medium text-dark-text">{account.user.name}</p>
                        {isSignedOut && (
                          <span className="rounded-full bg-dark-bg px-2 py-0.5 text-[10px] font-medium uppercase tracking-[0.08em] text-dark-text-muted">
                            Signed out
                          </span>
                        )}
                      </div>
                      <p className="truncate text-xs text-dark-text-muted">{account.user.email}</p>
                      <p className="truncate text-xs text-dark-text-muted/80">
                        {account.workspace.name}
                      </p>
                    </div>
                    {isSwitching && !isSignedOut && (
                      <span className="text-xs text-dark-text-muted">Signing in...</span>
                    )}
                  </div>
                </button>
              );
            })}

            <button
              type="button"
              onClick={() => setShowCredentialForm(true)}
              className="w-full rounded-lg border border-dark-border px-4 py-3 text-sm text-dark-text-muted transition-colors hover:bg-dark-surface"
            >
              Use another account
            </button>

            <p className="text-center text-sm text-dark-text-muted">
              Need a new workspace?{" "}
              <button
                type="button"
                onClick={() => navigate("/register")}
                className="text-blue-400 hover:underline"
              >
                Create workspace
              </button>
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-dark-text mb-2">
                Email
              </label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="john@example.com"
                required
                className="w-full px-4 py-3 bg-dark-surface border border-dark-border rounded-lg text-dark-text placeholder:text-dark-text-muted focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-dark-text mb-2">
                Password
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="w-full px-4 py-3 bg-dark-surface border border-dark-border rounded-lg text-dark-text placeholder:text-dark-text-muted focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="flex justify-between">
              {accounts.length > 0 ? (
                <button
                  type="button"
                  onClick={() => setShowCredentialForm(false)}
                  className="text-sm text-dark-text-muted hover:text-blue-400 transition-colors"
                >
                  Back to accounts
                </button>
              ) : (
                <span />
              )}
              <button
                type="button"
                onClick={() => navigate("/forgot-password")}
                className="text-sm text-dark-text-muted hover:text-blue-400 transition-colors"
              >
                Forgot password?
              </button>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>

            <p className="text-center text-sm text-dark-text-muted">
              Don't have an account?{" "}
              <button
                type="button"
                onClick={() => navigate("/register")}
                className="text-blue-400 hover:underline"
              >
                Create workspace
              </button>
            </p>
          </form>
        )}

        <AccountReauthModal
          account={reauthAccount}
          isOpen={reauthAccount !== null}
          onClose={() => setReauthAccount(null)}
          onRemove={(account) => setAccountToRemove(account)}
        />
        <ConfirmModal
          isOpen={accountToRemove !== null}
          title="Remove account from device"
          message={
            accountToRemove
              ? `Remove ${accountToRemove.user.email} from this device? You will need to sign in again to add it back.`
              : ""
          }
          confirmText={isRemovingAccount ? "Removing..." : "Remove"}
          confirmVariant="danger"
          onConfirm={() => void handleRemoveAccount()}
          onCancel={() => setAccountToRemove(null)}
        />
      </div>
    </div>
  );
}
