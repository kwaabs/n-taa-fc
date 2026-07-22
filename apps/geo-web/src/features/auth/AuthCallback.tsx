import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { api, completeOAuth, clearAuthTokens } from "@/lib/api";
import { useAuthStore } from "./store";
import type { User } from "./types";
import { toastError, toastSuccess } from "@/features/notifications/store";
import { queryClient } from "@/lib/queryClient";

/**
 * Handles GoTrue OAuth redirect:
 *   /auth/callback#access_token=...&refresh_token=...&expires_at=...
 */
export function AuthCallback() {
  const setUser = useAuthStore((s) => s.setUser);
  const setStatus = useAuthStore((s) => s.setStatus);
  const [message, setMessage] = useState("Completing sign-in…");

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const hash = window.location.hash.startsWith("#")
        ? window.location.hash.slice(1)
        : window.location.hash;
      const params = new URLSearchParams(hash || window.location.search);

      const oauthError = params.get("error");
      if (oauthError) {
        const desc = params.get("error_description") || oauthError;
        toastError("Sign-in failed", desc);
        setStatus("anonymous");
        window.history.replaceState({}, "", "/");
        return;
      }

      const accessToken = params.get("access_token");
      const refreshToken = params.get("refresh_token");
      const expiresAtRaw = params.get("expires_at");

      if (!accessToken || !refreshToken) {
        toastError("Sign-in failed", "Missing tokens from identity provider");
        setStatus("anonymous");
        window.history.replaceState({}, "", "/");
        return;
      }

      await completeOAuth({
        accessToken,
        refreshToken,
        expiresAt: expiresAtRaw ? Number(expiresAtRaw) : undefined,
      });

      try {
        const user = await api<User>("/api/v1/auth/me");
        if (cancelled) return;
        setUser(user);
        setStatus("authenticated");
        queryClient.setQueryData(["me"], user);
        toastSuccess("Welcome", user.display_name);
        window.history.replaceState({}, "", "/");
      } catch (err) {
        if (cancelled) return;
        const apiErr = err as { message?: string; status?: number };
        clearAuthTokens();
        setStatus("anonymous");
        setMessage(apiErr.message ?? "Sign-in failed");
        toastError(
          apiErr.status === 403 ? "Awaiting approval" : "Sign-in failed",
          apiErr.message ?? "Could not load geo profile",
        );
        window.history.replaceState({}, "", "/");
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [setUser, setStatus]);

  return (
    <div className="flex h-screen w-screen flex-col items-center justify-center gap-3 bg-slate-100">
      <Loader2 className="h-6 w-6 animate-spin text-slate-400" />
      <p className="text-sm text-slate-500">{message}</p>
    </div>
  );
}
