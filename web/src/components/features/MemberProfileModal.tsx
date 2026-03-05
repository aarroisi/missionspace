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

function formatTimezoneLabel(timezone: string): string {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      timeZoneName: "shortOffset",
    }).formatToParts(new Date());

    const offset = parts.find((part) => part.type === "timeZoneName")?.value;
    return offset ? `${timezone} (${offset})` : timezone;
  } catch {
    return timezone;
  }
}

function formatLocalTime(now: Date, timezone: string): string {
  try {
    return new Intl.DateTimeFormat("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZone: timezone,
    }).format(now);
  } catch {
    return "Unavailable";
  }
}

export function MemberProfileModal({
  isOpen,
  onClose,
  memberId,
}: MemberProfileModalProps) {
  const [member, setMember] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

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

  useEffect(() => {
    if (!isOpen) return;

    setNow(new Date());

    const interval = window.setInterval(() => {
      setNow(new Date());
    }, 1_000);

    return () => window.clearInterval(interval);
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <Modal title="Member Profile" onClose={onClose} size="sm" zIndex={80}>
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
                <Avatar name={member.name} src={member.avatar} size="lg" />
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

            {/* Timezone */}
            <div className="pt-4 border-t border-dark-border space-y-1">
              <p className="text-sm text-dark-text-muted">
                Time zone{" "}
                <span className="text-dark-text">
                  {member.timezone
                    ? formatTimezoneLabel(member.timezone)
                    : "Not set"}
                </span>
              </p>
              <p className="text-sm text-dark-text-muted">
                Local time{" "}
                <span className="text-dark-text">
                  {member.timezone
                    ? formatLocalTime(now, member.timezone)
                    : "Unavailable"}
                </span>
              </p>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}
