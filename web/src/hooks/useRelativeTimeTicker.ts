import { useEffect, useState } from "react";

export function useRelativeTimeTicker(
  enabled = true,
  intervalMs = 30_000,
): void {
  const [, setTick] = useState(0);

  useEffect(() => {
    if (!enabled) {
      return;
    }

    const refresh = () => {
      setTick((tick) => tick + 1);
    };

    const interval = window.setInterval(refresh, intervalMs);

    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        refresh();
      }
    };

    refresh();
    document.addEventListener("visibilitychange", handleVisibilityChange);
    window.addEventListener("focus", refresh);

    return () => {
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      window.removeEventListener("focus", refresh);
    };
  }, [enabled, intervalMs]);
}
