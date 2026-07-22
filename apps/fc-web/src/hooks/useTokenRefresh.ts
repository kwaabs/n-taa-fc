import { useEffect } from "react";
import { api } from "@/lib/api";

const CHECK_INTERVAL = 60 * 1000;       // check every 60 seconds
const REFRESH_THRESHOLD = 5 * 60;       // refresh if expiry within 5 minutes

export function useTokenRefresh() {
  useEffect(() => {
    let cancelled = false;

    const check = async () => {
      const expiresAt = api.getTokenExpiry();
      if (!expiresAt) return;

      const now = Math.floor(Date.now() / 1000);
      const secondsUntilExpiry = expiresAt - now;

      if (secondsUntilExpiry <= REFRESH_THRESHOLD && secondsUntilExpiry > 0) {
        const ok = await api.tryRefresh();
        if (!ok && !cancelled) {
          // Refresh failed — let the next API call surface the 401
          console.warn("Token refresh failed; session may expire soon");
        }
      }
    };

    // Initial check
    check();

    // Periodic check
    const id = setInterval(check, CHECK_INTERVAL);

    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, []);
}