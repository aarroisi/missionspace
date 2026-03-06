import { useState } from "react";
import { Code2, LogOut, MoreHorizontal, User, UserPlus } from "lucide-react";
import { DeviceAccount, useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { Avatar } from "@/components/ui/Avatar";
import { Dropdown, DropdownDivider, DropdownItem } from "@/components/ui/Dropdown";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { DevelopersModal } from "./DevelopersModal";
import { ProfileModal } from "./ProfileModal";
import { AddAccountModal } from "./AddAccountModal";
import { AccountReauthModal } from "./AccountReauthModal";

export function ProfileMenu() {
  const { user, accounts, logout, switchAccount, signOutAccount, removeAccount } = useAuthStore();
  const { success, error: showError } = useToastStore();
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [isDevelopersModalOpen, setIsDevelopersModalOpen] = useState(false);
  const [isAddAccountModalOpen, setIsAddAccountModalOpen] = useState(false);
  const [switchingAccountId, setSwitchingAccountId] = useState<string | null>(null);
  const [reauthAccount, setReauthAccount] = useState<DeviceAccount | null>(null);
  const [accountToRemove, setAccountToRemove] = useState<DeviceAccount | null>(null);
  const [isRemovingAccount, setIsRemovingAccount] = useState(false);

  if (!user) return null;

  const otherAccounts = accounts.filter((account) => account.user.id !== user.id);

  const handleLogout = async () => {
    await logout();
  };

  const handleSwitchAccount = async (userId: string) => {
    setSwitchingAccountId(userId);

    try {
      await switchAccount(userId);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to switch account";
      showError(message);
    } finally {
      setSwitchingAccountId(null);
    }
  };

  const handleAccountSignOut = async (userId: string) => {
    try {
      await signOutAccount(userId);
      success("Account signed out on this device");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to sign out account";
      showError(message);
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
      const message = err instanceof Error ? err.message : "Failed to remove account";
      showError(message);
    } finally {
      setIsRemovingAccount(false);
    }
  };

  return (
    <>
      <Dropdown
        trigger={
          <button
            className="w-10 h-10 rounded-lg flex items-center justify-center hover:bg-dark-surface transition-colors"
            title={user.name}
          >
            <Avatar name={user.name} src={user.avatar} size="md" online />
          </button>
        }
        position="top"
        align="left"
      >
        <div className="px-4 py-3 border-b border-dark-border">
          <div className="flex items-center gap-3">
            <Avatar name={user.name} src={user.avatar} size="lg" />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-dark-text truncate">
                {user.name}
              </p>
              <p className="text-xs text-dark-text-muted truncate">
                {user.email}
              </p>
            </div>
          </div>
        </div>

        {otherAccounts.length > 0 && (
          <div className="border-b border-dark-border px-3 py-2">
            <p className="px-1 text-[11px] font-semibold uppercase tracking-[0.08em] text-dark-text-muted">
              Switch account
            </p>
            <div className="mt-2 space-y-1">
              {otherAccounts.map((account) => {
                const isSwitching = switchingAccountId === account.user.id;
                const isSignedOut = account.state === "signed_out";

                return (
                  <div key={account.user.id} className="flex items-start gap-2 rounded-md px-2 py-2 transition-colors hover:bg-dark-border/60">
                    <button
                      type="button"
                      onClick={() => {
                        if (isSignedOut) {
                          setReauthAccount(account);
                          return;
                        }

                        void handleSwitchAccount(account.user.id);
                      }}
                      disabled={switchingAccountId !== null}
                      className="flex min-w-0 flex-1 items-center gap-2 text-left text-dark-text disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      <Avatar name={account.user.name} src={account.user.avatar} size="sm" />
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <p className="truncate text-sm font-medium">{account.user.name}</p>
                          {isSignedOut && (
                            <span className="rounded-full bg-dark-bg px-2 py-0.5 text-[10px] font-medium uppercase tracking-[0.08em] text-dark-text-muted">
                              Signed out
                            </span>
                          )}
                        </div>
                        <p className="truncate text-xs text-dark-text-muted">{account.user.email}</p>
                      </div>
                      {isSwitching && !isSignedOut && (
                        <span className="text-xs text-dark-text-muted">Switching...</span>
                      )}
                    </button>

                    <Dropdown
                      align="right"
                      className="shrink-0"
                      trigger={
                        <button
                          type="button"
                          className="rounded-md p-1 text-dark-text-muted transition-colors hover:bg-dark-bg hover:text-dark-text"
                          aria-label={`Account actions for ${account.user.email}`}
                        >
                          <MoreHorizontal size={16} />
                        </button>
                      }
                    >
                      {!isSignedOut && (
                        <DropdownItem onClick={() => void handleAccountSignOut(account.user.id)}>
                          Sign out
                        </DropdownItem>
                      )}
                      <DropdownItem
                        onClick={() => setAccountToRemove(account)}
                        variant="danger"
                      >
                        Remove
                      </DropdownItem>
                    </Dropdown>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        <div className="pt-1">
          <DropdownItem onClick={() => setIsProfileModalOpen(true)}>
            <div className="flex items-center gap-2">
              <User size={16} />
              <span>Edit Profile</span>
            </div>
          </DropdownItem>
          <DropdownItem onClick={() => setIsAddAccountModalOpen(true)}>
            <div className="flex items-center gap-2">
              <UserPlus size={16} />
              <span>Add account</span>
            </div>
          </DropdownItem>
          <DropdownItem onClick={() => setIsDevelopersModalOpen(true)}>
            <div className="flex items-center gap-2">
              <Code2 size={16} />
              <span>Developers</span>
            </div>
          </DropdownItem>
          <DropdownDivider />
          <DropdownItem onClick={() => void handleLogout()} variant="danger">
            <div className="flex items-center gap-2">
              <LogOut size={16} />
              <span>Log out</span>
            </div>
          </DropdownItem>
        </div>
      </Dropdown>

      <ProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
      />
      <DevelopersModal
        isOpen={isDevelopersModalOpen}
        onClose={() => setIsDevelopersModalOpen(false)}
      />
      <AddAccountModal
        isOpen={isAddAccountModalOpen}
        onClose={() => setIsAddAccountModalOpen(false)}
      />
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
    </>
  );
}
