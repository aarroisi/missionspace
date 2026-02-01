import { useEffect, useState } from "react";
import { Mail, Circle } from "lucide-react";
import { Avatar } from "@/components/ui/Avatar";
import { Modal } from "@/components/ui/Modal";
import { RoleBadge } from "@/components/ui/RoleBadge";
import { api } from "@/lib/api";
import { User } from "@/types";

interface MemberProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  memberId: string | null;
}

export function MemberProfileModal({
  isOpen,
  onClose,
  memberId,
}: MemberProfileModalProps) {
  const [member, setMember] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen && memberId) {
      setIsLoading(true);
      setError(null);

      api
        .get<User>(`/workspace/members/${memberId}`)
        .then((data) => {
          setMember(data);
        })
        .catch((err) => {
          console.error("Failed to fetch member:", err);
          setError("Failed to load member profile");
        })
        .finally(() => {
          setIsLoading(false);
        });
    } else {
      setMember(null);
    }
  }, [isOpen, memberId]);

  if (!isOpen) return null;

  return (
    <Modal title="Member Profile" onClose={onClose} size="sm">
      <div className="p-6">
        {isLoading && (
          <div className="flex items-center justify-center py-8">
            <div className="text-dark-text-muted">Loading...</div>
          </div>
        )}

        {error && (
          <div className="flex items-center justify-center py-8">
            <div className="text-red-400">{error}</div>
          </div>
        )}

        {member && !isLoading && (
          <div className="space-y-6">
            {/* Avatar and name */}
            <div className="flex flex-col items-center text-center">
              <div className="relative">
                <Avatar name={member.name} size="lg" />
                {member.online && (
                  <div className="absolute bottom-1 right-1 w-4 h-4 bg-green-500 rounded-full border-2 border-dark-surface" />
                )}
              </div>
              <h2 className="mt-4 text-xl font-semibold text-dark-text">
                {member.name}
              </h2>
              <div className="mt-1 flex items-center gap-2">
                <RoleBadge role={member.role} />
                <span className="flex items-center gap-1 text-sm text-dark-text-muted">
                  <Circle
                    size={8}
                    className={
                      member.online
                        ? "fill-green-500 text-green-500"
                        : "fill-gray-500 text-gray-500"
                    }
                  />
                  {member.online ? "Online" : "Offline"}
                </span>
              </div>
            </div>

            {/* Contact info */}
            <div className="space-y-3 pt-4 border-t border-dark-border">
              <div className="flex items-center gap-3 text-dark-text-muted">
                <Mail size={18} />
                <a
                  href={`mailto:${member.email}`}
                  className="text-blue-400 hover:text-blue-300 hover:underline"
                >
                  {member.email}
                </a>
              </div>
            </div>

            {/* Joined date */}
            <div className="pt-4 border-t border-dark-border">
              <p className="text-sm text-dark-text-muted">
                Member since{" "}
                {new Date(member.insertedAt).toLocaleDateString("en-US", {
                  month: "long",
                  day: "numeric",
                  year: "numeric",
                })}
              </p>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}
