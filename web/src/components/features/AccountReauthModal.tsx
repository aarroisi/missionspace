import { useEffect, useState } from "react";
import { DeviceAccount, useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Modal } from "@/components/ui/Modal";

interface AccountReauthModalProps {
  account: DeviceAccount | null;
  isOpen: boolean;
  onClose: () => void;
  onRemove: (account: DeviceAccount) => void;
}

export function AccountReauthModal({
  account,
  isOpen,
  onClose,
  onRemove,
}: AccountReauthModalProps) {
  const { reauthAccount } = useAuthStore();
  const { error: showError } = useToastStore();
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!isOpen) return;

    setPassword("");
    setError(null);
    setIsSubmitting(false);
  }, [isOpen, account?.user.id]);

  if (!isOpen || !account) return null;

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!password) {
      setError("Password is required");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await reauthAccount(account.user.id, password);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to sign in again";
      setError(message);
      showError(message);
      setIsSubmitting(false);
    }
  };

  return (
    <Modal title="Account signed out" onClose={onClose} size="md">
      <form onSubmit={handleSubmit} className="space-y-4 p-4">
        <div className="space-y-1">
          <p className="text-sm text-dark-text">
            {account.user.name} is signed out on this device.
          </p>
          <p className="text-sm text-dark-text-muted">
            Enter the password for this account to sign in again.
          </p>
        </div>

        <div className="rounded-lg border border-dark-border bg-dark-bg px-3 py-2">
          <p className="text-xs uppercase tracking-[0.08em] text-dark-text-muted">Account</p>
          <p className="mt-1 text-sm font-medium text-dark-text">{account.user.email}</p>
          <p className="text-xs text-dark-text-muted">{account.workspace.name}</p>
        </div>

        <div>
          <label
            htmlFor="reauth-account-password"
            className="mb-1 block text-sm font-medium text-dark-text"
          >
            Password
          </label>
          <input
            id="reauth-account-password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className="w-full rounded-lg border border-dark-border bg-dark-bg px-3 py-2 text-dark-text placeholder-dark-text-muted focus:border-transparent focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Enter password"
            autoComplete="current-password"
            required
          />
        </div>

        {error && <p className="text-sm text-red-400">{error}</p>}

        <div className="flex items-center justify-between gap-3 pt-2">
          <button
            type="button"
            onClick={() => onRemove(account)}
            className="text-sm text-red-400 transition-colors hover:text-red-300"
            disabled={isSubmitting}
          >
            Remove from device
          </button>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg bg-dark-bg px-4 py-2 text-dark-text transition-colors hover:bg-dark-border"
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="rounded-lg bg-blue-600 px-4 py-2 text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
              disabled={isSubmitting}
            >
              {isSubmitting ? "Signing in..." : "Sign in again"}
            </button>
          </div>
        </div>
      </form>
    </Modal>
  );
}
