import { useEffect, useMemo, useState } from "react";
import { LogOut } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { AvatarUpload } from "@/components/ui/AvatarUpload";
import { getAssetUrl } from "@/lib/asset-cache";
import { Modal } from "@/components/ui/Modal";
import { useIsMobile } from "@/hooks/useIsMobile";

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const FALLBACK_TIMEZONES = [
  "UTC",
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "Europe/London",
  "Europe/Berlin",
  "Asia/Dubai",
  "Asia/Kolkata",
  "Asia/Tokyo",
  "Australia/Sydney",
];

const SELECT_CHEVRON_CLASS =
  "appearance-none bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2216%22%20height%3D%2216%22%20viewBox%3D%220%200%2024%2024%22%20fill%3D%22none%22%20stroke%3D%22%239ca3af%22%20stroke-width%3D%222%22%20stroke-linecap%3D%22round%22%20stroke-linejoin%3D%22round%22%3E%3Cpolyline%20points%3D%226%209%2012%2015%2018%209%22%3E%3C%2Fpolyline%3E%3C%2Fsvg%3E')] bg-[position:right_0.75rem_center] bg-no-repeat";

function getTimezoneOffsetLabel(timezone: string): string | null {
  try {
    const now = new Date();
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).formatToParts(now);

    const getPartValue = (type: Intl.DateTimeFormatPart["type"]) => {
      const value = parts.find((part) => part.type === type)?.value;
      if (!value) return null;

      const parsed = Number(value);
      return Number.isNaN(parsed) ? null : parsed;
    };

    const year = getPartValue("year");
    const month = getPartValue("month");
    const day = getPartValue("day");
    const hour = getPartValue("hour");
    const minute = getPartValue("minute");
    const second = getPartValue("second");

    if (
      year === null ||
      month === null ||
      day === null ||
      hour === null ||
      minute === null ||
      second === null
    ) {
      return null;
    }

    const timezoneAsUtc = Date.UTC(year, month - 1, day, hour, minute, second);
    const offsetMinutes = Math.round((timezoneAsUtc - now.getTime()) / 60000);
    const sign = offsetMinutes >= 0 ? "+" : "-";
    const absoluteMinutes = Math.abs(offsetMinutes);
    const offsetHours = Math.floor(absoluteMinutes / 60);
    const offsetRemainderMinutes = absoluteMinutes % 60;

    return offsetRemainderMinutes === 0
      ? `GMT${sign}${offsetHours}`
      : `GMT${sign}${offsetHours}:${offsetRemainderMinutes.toString().padStart(2, "0")}`;
  } catch {
    return null;
  }
}

function formatTimezoneLabel(timezone: string): string {
  const offset = getTimezoneOffsetLabel(timezone);
  return offset ? `${timezone} (${offset})` : timezone;
}

export function ProfileModal({ isOpen, onClose }: ProfileModalProps) {
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const { user, updateProfile, logout } = useAuthStore();
  const { success, error: showError } = useToastStore();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [timezone, setTimezone] = useState("");
  const [avatarAssetId, setAvatarAssetId] = useState<string | null>(null);
  const [avatarDisplayUrl, setAvatarDisplayUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const timezoneOptions = useMemo(() => {
    const intlWithSupportedValues = Intl as typeof Intl & {
      supportedValuesOf?: (key: string) => string[];
    };

    const supported = intlWithSupportedValues.supportedValuesOf?.("timeZone");
    const resolved = supported && supported.length > 0 ? supported : FALLBACK_TIMEZONES;

    return resolved.map((timezoneValue) => ({
      value: timezoneValue,
      label: formatTimezoneLabel(timezoneValue),
    }));
  }, []);

  const hasCustomTimezoneOption =
    timezone.length > 0 && !timezoneOptions.some((option) => option.value === timezone);

  useEffect(() => {
    if (isOpen && user) {
      setName(user.name);
      setEmail(user.email);
      setTimezone(user.timezone || "");
      setAvatarAssetId(user.avatar || null);
      setError(null);
    }
  }, [isOpen, user]);

  useEffect(() => {
    if (avatarAssetId) {
      getAssetUrl(avatarAssetId).then(setAvatarDisplayUrl).catch(() => setAvatarDisplayUrl(null));
    } else {
      setAvatarDisplayUrl(null);
    }
  }, [avatarAssetId]);

  if (!isOpen || !user) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      const updates: {
        name?: string;
        email?: string;
        avatar?: string;
        timezone?: string;
      } = {};

      if (name !== user.name) updates.name = name;
      if (email !== user.email) updates.email = email;
      if (timezone !== (user.timezone || "")) updates.timezone = timezone;
      if (avatarAssetId !== user.avatar) updates.avatar = avatarAssetId || "";

      await updateProfile(updates);
      success("Profile updated successfully");
      onClose();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to update profile";
      setError(message);
      showError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAvatarUpload = (asset: { id: string; url: string }) => {
    setAvatarAssetId(asset.id);
    if (asset.url) setAvatarDisplayUrl(asset.url);
  };

  const handleLogout = async () => {
    await logout();
    onClose();
    navigate("/login");
  };

  const hasChanges =
    name !== user.name ||
    email !== user.email ||
    timezone !== (user.timezone || "") ||
    avatarAssetId !== user.avatar;

  return (
    <Modal title="Edit Profile" onClose={onClose} size="md">
      <form onSubmit={handleSubmit} className="space-y-4 p-4">
        <div className="flex justify-center">
          <AvatarUpload
            name={name || user.name}
            currentAvatarUrl={avatarDisplayUrl}
            onUploadComplete={handleAvatarUpload}
            onRemove={() => {
              setAvatarAssetId(null);
              setAvatarDisplayUrl(null);
            }}
            onError={(msg) => showError(msg)}
            size="lg"
            attachableType="user"
            attachableId={user.id}
          />
        </div>

        <div>
          <label htmlFor="profile-name" className="mb-1 block text-sm font-medium text-dark-text">
            Name
          </label>
          <input
            id="profile-name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full rounded-lg border border-dark-border bg-dark-bg px-3 py-2 text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Your name"
            required
          />
        </div>

        <div>
          <label htmlFor="profile-email" className="mb-1 block text-sm font-medium text-dark-text">
            Email
          </label>
          <input
            id="profile-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-lg border border-dark-border bg-dark-bg px-3 py-2 text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="your@email.com"
            required
          />
        </div>

        <div>
          <label
            htmlFor="profile-timezone"
            className="mb-1 block text-sm font-medium text-dark-text"
          >
            Time zone
          </label>
          <select
            id="profile-timezone"
            value={timezone}
            onChange={(e) => setTimezone(e.target.value)}
            className={`w-full rounded-lg border border-dark-border bg-dark-bg px-3 py-2 pr-10 text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${SELECT_CHEVRON_CLASS}`}
          >
            <option value="">Not set</option>
            {hasCustomTimezoneOption && <option value={timezone}>{formatTimezoneLabel(timezone)}</option>}
            {timezoneOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        {error && <p className="text-sm text-red-400">{error}</p>}

        <div className="flex justify-end gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg bg-dark-bg px-4 py-2 text-dark-text transition-colors hover:bg-dark-border"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={!hasChanges || isLoading}
            className="rounded-lg bg-blue-600 px-4 py-2 text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isLoading ? "Saving..." : "Save Changes"}
          </button>
        </div>

        {isMobile && (
          <button
            type="button"
            onClick={() => void handleLogout()}
            disabled={isLoading}
            className="flex w-full items-center justify-center gap-2 rounded-lg px-4 py-2 text-red-400 transition-colors hover:bg-red-500/10 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <LogOut size={16} />
            <span>Sign Out</span>
          </button>
        )}
      </form>
    </Modal>
  );
}
