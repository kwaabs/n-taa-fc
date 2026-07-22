export const env = {
  apiUrl: import.meta.env.VITE_API_URL ?? "http://localhost:5442",
  gotrueExternalUrl:
    (import.meta.env.VITE_GOTRUE_EXTERNAL_URL as string) ||
    "http://localhost:5354",
} as const;
