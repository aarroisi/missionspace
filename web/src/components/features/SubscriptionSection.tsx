import { useEffect } from "react";
import { Bell, BellOff } from "lucide-react";
import { SubscriptionItemType } from "@/types";
import { useSubscriptionStore } from "@/stores/subscriptionStore";
import { Avatar } from "@/components/ui/Avatar";

interface SubscriptionSectionProps {
  itemType: SubscriptionItemType;
  itemId: string;
}

export function SubscriptionSection({
  itemType,
  itemId,
}: SubscriptionSectionProps) {
  const {
    subscribers,
    subscriptionStatus,
    isLoading,
    fetchSubscribers,
    fetchStatus,
    subscribe,
    unsubscribe,
  } = useSubscriptionStore();

  const k = `${itemType}:${itemId}`;
  const subs = subscribers[k] || [];
  const visibleSubs = subs.slice(0, 5);
  const isSubscribed = subscriptionStatus[k] ?? false;
  const loading = isLoading[k] ?? false;

  useEffect(() => {
    fetchSubscribers(itemType, itemId);
    fetchStatus(itemType, itemId);
  }, [itemType, itemId, fetchSubscribers, fetchStatus]);

  const handleToggle = async () => {
    if (isSubscribed) {
      await unsubscribe(itemType, itemId);
    } else {
      await subscribe(itemType, itemId);
    }
    // Re-fetch subscribers list
    fetchSubscribers(itemType, itemId);
  };

  return (
    <div className="flex items-center gap-3">
      <div className="flex items-center gap-1">
        <span className="text-xs text-dark-text-muted mr-1">
          Subscribers ({subs.length})
        </span>
        <div className="flex -space-x-1.5">
          {visibleSubs.map((sub, index) => (
            <div
              key={sub.id}
              className="relative"
              style={{ zIndex: visibleSubs.length - index }}
            >
              <Avatar
                name={sub.user?.name || "User"}
                src={sub.user?.avatar}
                size="xs"
                className="rounded-full overflow-hidden ring-1 ring-dark-bg bg-dark-bg"
              />
            </div>
          ))}
          {subs.length > 5 && (
            <div className="w-5 h-5 rounded-full bg-dark-surface border border-dark-border flex items-center justify-center text-[9px] text-dark-text-muted">
              +{subs.length - 5}
            </div>
          )}
        </div>
      </div>

      <button
        onClick={handleToggle}
        disabled={loading}
        className={`flex items-center gap-1.5 px-2.5 py-1 rounded text-xs transition-colors ${
          isSubscribed
            ? "bg-dark-surface text-dark-text hover:bg-red-500/10 hover:text-red-400"
            : "bg-blue-600/20 text-blue-400 hover:bg-blue-600/30"
        } disabled:opacity-50`}
      >
        {isSubscribed ? (
          <>
            <BellOff size={12} />
            Unsubscribe
          </>
        ) : (
          <>
            <Bell size={12} />
            Subscribe
          </>
        )}
      </button>
    </div>
  );
}
