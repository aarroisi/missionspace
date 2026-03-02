import { useState, useEffect, useMemo } from "react";
import { Search, X, UserPlus } from "lucide-react";
import { Modal } from "@/components/ui/Modal";
import { Avatar } from "@/components/ui/Avatar";
import { RoleBadge } from "@/components/ui/RoleBadge";
import { api } from "@/lib/api";
import { useToastStore } from "@/stores/toastStore";
import { User, ProjectMember, ItemMember, Role } from "@/types";

type ItemKind = "project" | "list" | "doc_folder" | "channel";

interface ManageMembersModalProps {
  itemKind: ItemKind;
  itemId: string;
  isOpen: boolean;
  onClose: () => void;
}

interface MemberEntry {
  userId: string;
  name: string;
  email: string;
  role: Role;
}

export function ManageMembersModal({
  itemKind,
  itemId,
  isOpen,
  onClose,
}: ManageMembersModalProps) {
  const [members, setMembers] = useState<MemberEntry[]>([]);
  const [workspaceUsers, setWorkspaceUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const { success, error } = useToastStore();

  useEffect(() => {
    if (!isOpen) return;

    const fetchData = async () => {
      setIsLoading(true);
      try {
        const [users, currentMembers] = await Promise.all([
          api.get<User[]>("/workspace/members"),
          fetchCurrentMembers(),
        ]);
        setWorkspaceUsers(users);
        setMembers(currentMembers);
      } catch (err) {
        console.error("Failed to fetch members:", err);
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, [isOpen, itemKind, itemId]);

  const fetchCurrentMembers = async (): Promise<MemberEntry[]> => {
    if (itemKind === "project") {
      const data = await api.get<ProjectMember[]>(
        `/projects/${itemId}/members`,
      );
      return data.map((m) => ({
        userId: m.userId,
        name: m.user?.name || "Unknown",
        email: m.user?.email || "",
        role: "member" as Role,
      }));
    } else {
      const data = await api.get<ItemMember[]>(
        `/item-members/${itemKind}/${itemId}`,
      );
      return data.map((m) => ({
        userId: m.userId,
        name: m.user?.name || "Unknown",
        email: m.user?.email || "",
        role: "member" as Role,
      }));
    }
  };

  const memberUserIds = useMemo(
    () => new Set(members.map((m) => m.userId)),
    [members],
  );

  const availableUsers = useMemo(() => {
    const filtered = workspaceUsers.filter(
      (u) => !memberUserIds.has(u.id),
    );
    if (!search.trim()) return filtered;
    const q = search.toLowerCase();
    return filtered.filter(
      (u) =>
        u.name.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q),
    );
  }, [workspaceUsers, memberUserIds, search]);

  const handleAddMember = async (user: User) => {
    try {
      if (itemKind === "project") {
        await api.post(`/projects/${itemId}/members`, {
          userId: user.id,
        });
      } else {
        await api.post(`/item-members/${itemKind}/${itemId}`, {
          userId: user.id,
        });
      }
      setMembers((prev) => [
        ...prev,
        {
          userId: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      ]);
      success("Member added");
    } catch (err) {
      error("Failed to add member: " + (err as Error).message);
    }
  };

  const handleRemoveMember = async (userId: string) => {
    try {
      if (itemKind === "project") {
        await api.delete(`/projects/${itemId}/members/${userId}`);
      } else {
        await api.delete(
          `/item-members/${itemKind}/${itemId}/${userId}`,
        );
      }
      setMembers((prev) => prev.filter((m) => m.userId !== userId));
      success("Member removed");
    } catch (err) {
      error("Failed to remove member: " + (err as Error).message);
    }
  };

  // Get the workspace role for a member
  const getWorkspaceRole = (userId: string): Role => {
    const wsUser = workspaceUsers.find((u) => u.id === userId);
    return wsUser?.role || "member";
  };

  if (!isOpen) return null;

  return (
    <Modal
      title="Members"
      size="md"
      onClose={onClose}
      maxHeight="80vh"
    >
      <div className="flex flex-col overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <p className="text-dark-text-muted text-sm">Loading...</p>
          </div>
        ) : (
          <>
            {/* Current Members */}
            <div className="px-6 py-3">
              <h4 className="text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
                Current Members ({members.length})
              </h4>
            </div>
            <div className="px-6 max-h-[200px] overflow-y-auto">
              {members.length === 0 ? (
                <p className="text-sm text-dark-text-muted py-2">
                  No members yet
                </p>
              ) : (
                <div className="space-y-1">
                  {members.map((member) => (
                    <div
                      key={member.userId}
                      className="flex items-center gap-3 py-2 group"
                    >
                      <Avatar name={member.name} size="sm" />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium text-dark-text truncate">
                            {member.name}
                          </span>
                          <RoleBadge role={getWorkspaceRole(member.userId)} />
                        </div>
                        <span className="text-xs text-dark-text-muted truncate block">
                          {member.email}
                        </span>
                      </div>
                      <button
                        onClick={() => handleRemoveMember(member.userId)}
                        className="p-1 rounded hover:bg-dark-hover text-dark-text-muted hover:text-red-400 transition-colors opacity-0 group-hover:opacity-100"
                        title="Remove member"
                      >
                        <X size={16} />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Divider */}
            <div className="border-t border-dark-border mx-6 my-2" />

            {/* Add Members */}
            <div className="px-6 py-3">
              <h4 className="text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
                Add Members
              </h4>
            </div>
            <div className="px-6 pb-2">
              <div className="relative">
                <Search
                  size={16}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-dark-text-muted"
                />
                <input
                  type="text"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search by name or email..."
                  className="w-full pl-9 pr-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-sm text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>
            <div className="px-6 pb-4 max-h-[200px] overflow-y-auto">
              {availableUsers.length === 0 ? (
                <p className="text-sm text-dark-text-muted py-2">
                  {search.trim()
                    ? "No matching users found"
                    : "All workspace members have been added"}
                </p>
              ) : (
                <div className="space-y-1">
                  {availableUsers.map((user) => (
                    <div
                      key={user.id}
                      className="flex items-center gap-3 py-2"
                    >
                      <Avatar name={user.name} size="sm" />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium text-dark-text truncate">
                            {user.name}
                          </span>
                          <RoleBadge role={user.role} />
                        </div>
                        <span className="text-xs text-dark-text-muted truncate block">
                          {user.email}
                        </span>
                      </div>
                      <button
                        onClick={() => handleAddMember(user)}
                        className="flex items-center gap-1 px-2 py-1 text-xs font-medium text-blue-400 hover:bg-blue-500/10 rounded transition-colors"
                      >
                        <UserPlus size={14} />
                        Add
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
