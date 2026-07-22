import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * Handles the OAuth redirect from GoTrue after Microsoft/Google login.
 *
 * GoTrue sends the browser here with tokens in the URL hash fragment:
 *   /auth/callback#access_token=...&refresh_token=...&expires_at=...
 *
 * We parse the hash, store tokens via api client, then rehydrate auth state
 * and navigate home.
 */
export function AuthCallback() {
  const navigate = useNavigate();
  const { hydrate } = useAuth();

  useEffect(() => {
    async function handle() {
      const hash = window.location.hash.startsWith("#")
        ? window.location.hash.slice(1)
        : window.location.hash;

      const params = new URLSearchParams(hash);
      const accessToken = params.get("access_token");
      const refreshToken = params.get("refresh_token");
      const expiresAt = params.get("expires_at");
      const oauthError = params.get("error");
      const oauthErrorDesc = params.get("error_description");

      if (oauthError) {
        console.error("[OAuth] error:", oauthError, oauthErrorDesc);
        navigate(
          `/login?error=${encodeURIComponent(oauthErrorDesc || oauthError)}`,
          { replace: true }
        );
        return;
      }

      if (!accessToken || !refreshToken) {
        console.error("[OAuth] missing tokens in callback hash");
        navigate("/login?error=missing_tokens", { replace: true });
        return;
      }

      try {
        await api.completeOAuth({
          accessToken,
          refreshToken,
          expiresAt: expiresAt ? Number(expiresAt) : undefined,
        });
        hydrate(); // rebuild AuthProvider state from localStorage
        navigate("/", { replace: true });
      } catch (err: any) {
        console.error("[OAuth] failed to complete session:", err);
        navigate(
          `/login?error=${encodeURIComponent(err.message || "session_error")}`,
          { replace: true }
        );
      }
    }
    handle();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
        <p className="text-gray-600">Completing sign-in…</p>
      </div>
    </div>
  );
}