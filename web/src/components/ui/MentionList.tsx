import { forwardRef, useEffect, useImperativeHandle, useState } from "react";
import { clsx } from "clsx";
import { Avatar } from "./Avatar";

export interface MentionMember {
  id: string;
  name: string;
  email?: string;
  avatar?: string;
  online?: boolean;
}

export interface MentionListProps {
  items: MentionMember[];
  onSelect: (member: MentionMember) => void;
}

export interface MentionListRef {
  onKeyDown: (event: KeyboardEvent) => boolean;
}

export const MentionList = forwardRef<MentionListRef, MentionListProps>(
  ({ items, onSelect }, ref) => {
    const [selectedIndex, setSelectedIndex] = useState(0);

    // Reset selection when items change
    useEffect(() => {
      setSelectedIndex(0);
    }, [items]);

    // Expose keyboard handler to parent
    useImperativeHandle(ref, () => ({
      onKeyDown: (event: KeyboardEvent) => {
        if (items.length === 0) return false;

        if (event.key === "ArrowUp") {
          setSelectedIndex((prev) => (prev <= 0 ? items.length - 1 : prev - 1));
          return true;
        }

        if (event.key === "ArrowDown") {
          setSelectedIndex((prev) => (prev >= items.length - 1 ? 0 : prev + 1));
          return true;
        }

        if (event.key === "Enter" || event.key === "Tab") {
          const member = items[selectedIndex];
          if (member) {
            onSelect(member);
          }
          return true;
        }

        if (event.key === "Escape") {
          return true;
        }

        return false;
      },
    }));

    if (items.length === 0) {
      return (
        <div className="bg-dark-surface border border-dark-border rounded-lg shadow-lg p-3">
          <p className="text-dark-text-muted text-sm">No members found</p>
        </div>
      );
    }

    return (
      <div className="bg-dark-surface border border-dark-border rounded-lg shadow-lg overflow-hidden max-h-64 overflow-y-auto">
        {items.map((member, index) => (
          <button
            key={member.id}
            onClick={() => onSelect(member)}
            className={clsx(
              "w-full flex items-center gap-3 px-3 py-2 text-left transition-colors",
              index === selectedIndex
                ? "bg-dark-border text-dark-text"
                : "text-dark-text hover:bg-dark-border/50",
            )}
          >
            <Avatar name={member.name} size="sm" online={member.online} />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{member.name}</p>
              {member.email && (
                <p className="text-xs text-dark-text-muted truncate">
                  {member.email}
                </p>
              )}
            </div>
          </button>
        ))}
      </div>
    );
  },
);

MentionList.displayName = "MentionList";
