import { useState, useEffect } from "react";
import { Plus, MoreVertical, Pencil, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import { User, Role } from "@/types";
import { useAuthStore } from "@/stores/authStore";
import { RoleBadge } from "@/components/ui/RoleBadge";
import { Avatar } from "@/components/ui/Avatar";
import { ConfirmModal } from "@/components/ui/ConfirmModal";
import { useMemberProfile } from "@/contexts/MemberProfileContext";
import {
  Dropdown,
  DropdownItem,
  DropdownDivider,
} from "@/components/ui/Dropdown";
import { toast } from "@/components/ui/Toast";

interface WorkspaceMember extends User {
  role: Role;
}

export function WorkspaceMembersPage() {
  const { user: currentUser } = useAuthStore();
  const { openMemberProfile } = useMemberProfile();
  const [members, setMembers] = useState<WorkspaceMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [memberToEdit, setMemberToEdit] = useState<WorkspaceMember | null>(
    null,
  );
  const [memberToDelete, setMemberToDelete] = useState<WorkspaceMember | null>(
    null,
  );

  // Fetch members
  useEffect(() => {
    const fetchMembers = async () => {
      try {
        const response = await api.get<WorkspaceMember[]>("/workspace/members");
        setMembers(response);
      } catch (error) {
        console.error("Failed to fetch members:", error);
        toast.error("Failed to load workspace members");
      } finally {
        setLoading(false);
      }
    };

    fetchMembers();
  }, []);

  const handleUpdateMember = async (
    memberId: string,
    data: { name?: string; role?: Role },
  ) => {
    try {
      await api.patch(`/workspace/members/${memberId}`, data);
      setMembers((prev) =>
        prev.map((m) => (m.id === memberId ? { ...m, ...data } : m)),
      );
      setMemberToEdit(null);
      toast.success("Member updated successfully");
    } catch (error) {
      console.error("Failed to update member:", error);
      toast.error("Failed to update member");
    }
  };

  const handleDeleteMember = async () => {
    if (!memberToDelete) return;

    try {
      await api.delete(`/workspace/members/${memberToDelete.id}`);
      setMembers((prev) => prev.filter((m) => m.id !== memberToDelete.id));
      setMemberToDelete(null);
      toast.success("Member removed successfully");
    } catch (error) {
      console.error("Failed to remove member:", error);
      toast.error("Failed to remove member");
    }
  };

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="text-dark-text-muted">Loading...</div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-4 md:p-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-semibold text-dark-text">
            Workspace Members
          </h1>
          <p className="text-dark-text-muted mt-1">
            Manage who has access to your workspace
          </p>
        </div>
        <button
          onClick={() => setShowInviteModal(true)}
          className="flex items-center gap-2 p-2 md:px-4 md:py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus size={18} />
          <span className="hidden md:inline">Invite Member</span>
        </button>
      </div>

      <div className="bg-dark-surface rounded-lg border border-dark-border">
        <div className="grid grid-cols-12 gap-4 px-4 py-3 border-b border-dark-border text-sm font-medium text-dark-text-muted">
          <div className="col-span-5">Member</div>
          <div className="col-span-3">Role</div>
          <div className="col-span-3">Joined</div>
          <div className="col-span-1"></div>
        </div>

        {members.map((member) => (
          <div
            key={member.id}
            className="grid grid-cols-12 gap-4 px-4 py-3 border-b border-dark-border last:border-b-0 items-center"
          >
            <button
              type="button"
              onClick={() => openMemberProfile(member.id)}
              className="col-span-5 flex items-center gap-3 text-left rounded-lg -m-1 p-1 hover:bg-dark-hover transition-colors bg-transparent border-0"
              title={`Open ${member.name}'s profile`}
            >
              <Avatar name={member.name} src={member.avatar} size="md" />
              <div>
                <div className="text-dark-text font-medium flex items-center gap-2">
                  {member.name}
                  {member.id === currentUser?.id && (
                    <span className="text-xs text-dark-text-muted">(you)</span>
                  )}
                </div>
                <div className="text-sm text-dark-text-muted">
                  {member.email}
                </div>
              </div>
            </button>

            <div className="col-span-3">
              <RoleBadge role={member.role} />
            </div>

            <div className="col-span-3 text-sm text-dark-text-muted">
              {new Date(member.insertedAt).toLocaleDateString()}
            </div>

            <div className="col-span-1 flex justify-end">
              {member.id !== currentUser?.id && (
                <Dropdown
                  trigger={
                    <button className="p-2 text-dark-text-muted hover:text-dark-text hover:bg-dark-hover rounded transition-colors">
                      <MoreVertical size={16} />
                    </button>
                  }
                  align="right"
                >
                  <DropdownItem onClick={() => setMemberToEdit(member)}>
                    <span className="flex items-center gap-2">
                      <Pencil size={14} />
                      Edit
                    </span>
                  </DropdownItem>
                  <DropdownDivider />
                  <DropdownItem
                    variant="danger"
                    onClick={() => setMemberToDelete(member)}
                  >
                    <span className="flex items-center gap-2">
                      <Trash2 size={14} />
                      Remove
                    </span>
                  </DropdownItem>
                </Dropdown>
              )}
            </div>
          </div>
        ))}

        {members.length === 0 && (
          <div className="px-4 py-8 text-center text-dark-text-muted">
            No members found
          </div>
        )}
      </div>

      {showInviteModal && (
        <InviteMemberModal
          onClose={() => setShowInviteModal(false)}
          onInvite={(newMember) => {
            setMembers((prev) => [...prev, newMember]);
            setShowInviteModal(false);
          }}
        />
      )}

      {memberToEdit && (
        <EditMemberModal
          member={memberToEdit}
          onClose={() => setMemberToEdit(null)}
          onSave={(data) => handleUpdateMember(memberToEdit.id, data)}
        />
      )}

      <ConfirmModal
        isOpen={!!memberToDelete}
        onCancel={() => setMemberToDelete(null)}
        onConfirm={handleDeleteMember}
        title="Remove Member"
        message={`Are you sure you want to remove ${memberToDelete?.name} from this workspace? They will lose access to all workspace content.`}
        confirmText="Remove"
        confirmVariant="danger"
      />
    </div>
  );
}

interface InviteMemberModalProps {
  onClose: () => void;
  onInvite: (member: WorkspaceMember) => void;
}

function InviteMemberModal({ onClose, onInvite }: InviteMemberModalProps) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("member");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const response = await api.post<WorkspaceMember>("/workspace/members", {
        name,
        email,
        password,
        role,
      });
      onInvite(response);
      toast.success("Member invited successfully");
    } catch (err: any) {
      const errorMessage =
        err?.errors?.email?.[0] || err?.message || "Failed to invite member";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-dark-surface border border-dark-border rounded-lg w-full max-w-md p-6">
        <h2 className="text-xl font-semibold text-dark-text mb-4">
          Invite New Member
        </h2>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="invite-name"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Name
            </label>
            <input
              id="invite-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>

          <div>
            <label
              htmlFor="invite-email"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Email
            </label>
            <input
              id="invite-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>

          <div>
            <label
              htmlFor="invite-password"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Password
            </label>
            <input
              id="invite-password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
              minLength={6}
            />
          </div>

          <div>
            <label
              htmlFor="invite-role"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Role
            </label>
            <select
              id="invite-role"
              value={role}
              onChange={(e) => setRole(e.target.value as Role)}
              className="w-full px-3 py-2 pr-10 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2216%22%20height%3D%2216%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%239ca3af%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Cpolyline%20points%3D%226%209%2012%2015%2018%209%22%3E%3C%2Fpolyline%3E%3C%2Fsvg%3E')] bg-[position:right_0.75rem_center] bg-no-repeat"
            >
              <option value="owner">Owner - Full access</option>
              <option value="member">Member - Assigned projects only</option>
              <option value="guest">Guest - One project only</option>
            </select>
          </div>

          {error && <div className="text-red-400 text-sm">{error}</div>}

          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-dark-text hover:bg-dark-hover rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
            >
              {loading ? "Inviting..." : "Invite"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

interface EditMemberModalProps {
  member: WorkspaceMember;
  onClose: () => void;
  onSave: (data: { name?: string; role?: Role }) => void;
}

function EditMemberModal({ member, onClose, onSave }: EditMemberModalProps) {
  const [role, setRole] = useState<Role>(member.role);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      await onSave({ role });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-dark-surface border border-dark-border rounded-lg w-full max-w-md p-6">
        <h2 className="text-xl font-semibold text-dark-text mb-4">
          Edit Member
        </h2>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="edit-name"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Name
            </label>
            <input
              id="edit-name"
              type="text"
              value={member.name}
              disabled
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text-muted cursor-not-allowed"
            />
          </div>

          <div>
            <label
              htmlFor="edit-email"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Email
            </label>
            <input
              id="edit-email"
              type="email"
              value={member.email}
              disabled
              className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text-muted cursor-not-allowed"
            />
          </div>

          <div>
            <label
              htmlFor="edit-role"
              className="block text-sm font-medium text-dark-text mb-1"
            >
              Role
            </label>
            <select
              id="edit-role"
              value={role}
              onChange={(e) => setRole(e.target.value as Role)}
              className="w-full px-3 py-2 pr-10 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2216%22%20height%3D%2216%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%239ca3af%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Cpolyline%20points%3D%226%209%2012%2015%2018%209%22%3E%3C%2Fpolyline%3E%3C%2Fsvg%3E')] bg-[position:right_0.75rem_center] bg-no-repeat"
            >
              <option value="owner">Owner - Full access</option>
              <option value="member">Member - Assigned projects only</option>
              <option value="guest">Guest - One project only</option>
            </select>
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-dark-text hover:bg-dark-hover rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
            >
              {loading ? "Saving..." : "Save"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
