import { useState, useEffect, useMemo } from "react";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { AvatarUpload } from "@/components/ui/AvatarUpload";
import { getAssetUrl } from "@/lib/asset-cache";
import { Modal } from "@/components/ui/Modal";

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
      : `GMT${sign}${offsetHours}:${offsetRemainderMinutes
          .toString()
          .padStart(2, "0")}`;
  } catch {
    return null;
  }
}

function formatTimezoneLabel(timezone: string): string {
  const offset = getTimezoneOffsetLabel(timezone);
  return offset ? `${timezone} (${offset})` : timezone;
}

export function ProfileModal({ isOpen, onClose }: ProfileModalProps) {
  const { user, updateProfile } = useAuthStore();
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

  // Resolve avatar asset ID to presigned URL
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
      const message =
        err instanceof Error ? err.message : "Failed to update profile";
      setError(message);
      showError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAvatarUpload = (asset: { id: string; url: string }) => {
    setAvatarAssetId(asset.id);
    // Set display URL immediately from the upload response
    if (asset.url) setAvatarDisplayUrl(asset.url);
  };

  const hasChanges =
    name !== user.name ||
    email !== user.email ||
    timezone !== (user.timezone || "") ||
    avatarAssetId !== user.avatar;

  return (
    <Modal title="Edit Profile" onClose={onClose} size="md">
      <form onSubmit={handleSubmit} className="p-4 space-y-4">
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
          <label
            htmlFor="profile-name"
            className="block text-sm font-medium text-dark-text mb-1"
          >
            Name
          </label>
          <input
            id="profile-name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="Your name"
            required
          />
        </div>

        <div>
          <label
            htmlFor="profile-email"
            className="block text-sm font-medium text-dark-text mb-1"
          >
            Email
          </label>
          <input
            id="profile-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-3 py-2 bg-dark-bg border border-dark-border rounded-lg text-dark-text placeholder-dark-text-muted focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="your@email.com"
            required
          />
        </div>

        <div>
          <label
            htmlFor="profile-timezone"
            className="block text-sm font-medium text-dark-text mb-1"
          >
            Time zone
          </label>
          <select
            id="profile-timezone"
            value={timezone}
            onChange={(e) => setTimezone(e.target.value)}
            className={`w-full px-3 py-2 pr-10 bg-dark-bg border border-dark-border rounded-lg text-dark-text focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${SELECT_CHEVRON_CLASS}`}
          >
            <option value="">Not set</option>
            {hasCustomTimezoneOption && (
              <option value={timezone}>{formatTimezoneLabel(timezone)}</option>
            )}
            {timezoneOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        {error && <p className="text-sm text-red-400">{error}</p>}

        <div className="flex gap-3 justify-end pt-2">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-lg bg-dark-bg hover:bg-dark-border text-dark-text transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={!hasChanges || isLoading}
            className="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoading ? "Saving..." : "Save Changes"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
