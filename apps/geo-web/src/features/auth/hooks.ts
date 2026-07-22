import { useMutation, useQuery } from "@tanstack/react-query";
import {
  api,
  bootRefresh,
  buildGoTrueOAuthUrl,
  clearAuthTokens,
  gotruePasswordLogin,
  setAccessToken,
} from "@/lib/api";
import { queryClient } from "@/lib/queryClient";
import { useAuthStore } from "./store";
import type { User } from "./types";
import { toastSuccess, toastError } from "@/features/notifications/store";

export function useMe() {
  return useQuery({
    queryKey: ["me"],
    queryFn: () => api<User>("/api/v1/auth/me"),
    retry: false,
  });
}

export function useLogin() {
  const setUser = useAuthStore((s) => s.setUser);
  const setStatus = useAuthStore((s) => s.setStatus);

  return useMutation({
    mutationFn: async (creds: { email: string; password: string }) => {
      await gotruePasswordLogin(creds.email, creds.password);
      return api<User>("/api/v1/auth/me");
    },
    onSuccess: (user) => {
      setUser(user);
      setStatus("authenticated");
      queryClient.setQueryData(["me"], user);
      toastSuccess("Welcome back", user.display_name);
    },
    onError: (err) => {
      const apiErr = err as { message?: string; status?: number };
      if (apiErr.status === 403) {
        toastError(
          "Awaiting approval",
          apiErr.message ?? "Your account is pending admin approval",
        );
        clearAuthTokens();
        return;
      }
      toastError(
        "Sign-in failed",
        apiErr?.message ?? "Check your credentials",
      );
    },
  });
}

export function useLogout() {
  const setUser = useAuthStore((s) => s.setUser);
  const setStatus = useAuthStore((s) => s.setStatus);

  return useMutation({
    mutationFn: async () => {
      clearAuthTokens();
      setAccessToken(null);
    },
    onSettled: () => {
      setUser(null);
      setStatus("anonymous");
      queryClient.clear();
      toastSuccess("Signed out");
    },
  });
}

export async function bootstrapAuth(): Promise<User | null> {
  const token = await bootRefresh();
  if (!token) return null;
  try {
    return await api<User>("/api/v1/auth/me");
  } catch (err) {
    const apiErr = err as { status?: number };
    if (apiErr.status === 403) {
      clearAuthTokens();
    }
    return null;
  }
}

export function startAzureLogin() {
  window.location.href = buildGoTrueOAuthUrl("azure");
}
