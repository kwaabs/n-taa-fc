import { env } from "./env";

type Json = Record<string, unknown> | unknown[];

export interface ApiError {
  status: number;
  code: string;
  message: string;
}

const GOTRUE_URL = "/gotrue";

let refreshInFlight: Promise<string | null> | null = null;

export function setAccessToken(token: string | null) {
  if (token) localStorage.setItem("access_token", token);
  else localStorage.removeItem("access_token");
}

export function getAccessToken(): string | null {
  return localStorage.getItem("access_token");
}

export function setRefreshToken(token: string | null) {
  if (token) localStorage.setItem("refresh_token", token);
  else localStorage.removeItem("refresh_token");
}

export function getRefreshToken(): string | null {
  return localStorage.getItem("refresh_token");
}

export function clearAuthTokens() {
  localStorage.removeItem("access_token");
  localStorage.removeItem("refresh_token");
  localStorage.removeItem("token_expires_at");
}

export async function gotruePasswordLogin(email: string, password: string) {
  const res = await fetch(`${GOTRUE_URL}/token?grant_type=password`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw {
      status: res.status,
      code: "login_failed",
      message: err.error_description || err.msg || "Login failed",
    } satisfies ApiError;
  }
  const data = await res.json();
  setAccessToken(data.access_token);
  setRefreshToken(data.refresh_token);
  if (data.expires_at) {
    localStorage.setItem("token_expires_at", String(data.expires_at));
  }
  return data;
}

export async function completeOAuth(tokens: {
  accessToken: string;
  refreshToken: string;
  expiresAt?: number;
}) {
  setAccessToken(tokens.accessToken);
  setRefreshToken(tokens.refreshToken);
  if (tokens.expiresAt) {
    localStorage.setItem("token_expires_at", String(tokens.expiresAt));
  }
}

export function buildGoTrueOAuthUrl(provider: "azure" | "google"): string {
  const redirectTo = `${window.location.origin}/auth/callback`;
  const scopes =
    provider === "azure" ? "openid email profile" : "openid email profile";
  return `${env.gotrueExternalUrl}/authorize?provider=${provider}&redirect_to=${encodeURIComponent(redirectTo)}&scopes=${encodeURIComponent(scopes)}`;
}

async function refreshAccessToken(): Promise<string | null> {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    try {
      const refresh = getRefreshToken();
      if (!refresh) return null;
      const res = await fetch(`${GOTRUE_URL}/token?grant_type=refresh_token`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refresh }),
      });
      if (!res.ok) {
        clearAuthTokens();
        return null;
      }
      const data = await res.json();
      setAccessToken(data.access_token);
      if (data.refresh_token) setRefreshToken(data.refresh_token);
      if (data.expires_at) {
        localStorage.setItem("token_expires_at", String(data.expires_at));
      }
      return data.access_token as string;
    } catch {
      return null;
    } finally {
      refreshInFlight = null;
    }
  })();

  return refreshInFlight;
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: Json;
  signal?: AbortSignal;
  auth?: boolean;
}

async function doFetch(
  path: string,
  opts: RequestOptions,
  token: string | null,
): Promise<Response> {
  const headers: Record<string, string> = {};
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  if (opts.auth !== false && token)
    headers["Authorization"] = `Bearer ${token}`;

  return fetch(`${env.apiUrl}${path}`, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    signal: opts.signal,
  });
}

export async function api<T>(
  path: string,
  opts: RequestOptions = {},
): Promise<T> {
  let res = await doFetch(path, opts, getAccessToken());

  if (res.status === 401 && opts.auth !== false) {
    const fresh = await refreshAccessToken();
    if (fresh) {
      res = await doFetch(path, opts, fresh);
    }
  }

  if (res.status === 204) {
    return undefined as T;
  }

  const text = await res.text();
  const body = text ? (JSON.parse(text) as unknown) : null;

  if (!res.ok) {
    const b = body as { error?: { code?: string; message?: string } } | null;
    const err: ApiError = {
      status: res.status,
      code: b?.error?.code ?? "unknown",
      message: b?.error?.message ?? res.statusText,
    };
    throw err;
  }

  return body as T;
}

export async function bootRefresh(): Promise<string | null> {
  if (getAccessToken()) return getAccessToken();
  return refreshAccessToken();
}

export async function downloadFile(
  path: string,
  body: Json,
  suggestedFilename: string,
): Promise<void> {
  const token = getAccessToken();

  let res = await fetch(`${env.apiUrl}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });

  if (res.status === 401) {
    const fresh = await bootRefresh();
    if (fresh) {
      res = await fetch(`${env.apiUrl}${path}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${fresh}`,
        },
        body: JSON.stringify(body),
      });
    }
  }

  if (!res.ok) {
    let message = `download failed: ${res.status}`;
    try {
      const errBody = await res.json();
      if (errBody?.error?.message) {
        message = errBody.error.message;
      }
    } catch {
      // keep generic
    }
    throw new Error(message);
  }

  const disposition = res.headers.get("Content-Disposition") ?? "";
  const match = /filename="?([^"]+)"?/i.exec(disposition);
  const filename = match?.[1] ?? suggestedFilename;

  const fsAccess = (
    window as unknown as {
      showSaveFilePicker?: (opts?: unknown) => Promise<{
        createWritable: () => Promise<{
          write: (chunk: unknown) => Promise<void>;
          close: () => Promise<void>;
        }>;
      }>;
    }
  ).showSaveFilePicker;

  if (fsAccess && res.body) {
    try {
      const handle = await fsAccess({ suggestedName: filename });
      const writable = await handle.createWritable();
      const reader = res.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        await writable.write(value);
      }
      await writable.close();
      return;
    } catch (e) {
      if ((e as { name?: string })?.name === "AbortError") return;
      console.warn("File System Access failed, falling back to blob", e);
    }
  }

  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
