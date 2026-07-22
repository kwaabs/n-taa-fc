import { useState, type FormEvent } from "react";
import { Globe2, Loader2 } from "lucide-react";
import { useLogin, startAzureLogin } from "./hooks";

export function LoginScreen() {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [azureLoading, setAzureLoading] = useState(false);
  const login = useLogin();

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    login.mutate({ email, password });
  };

  const onAzure = () => {
    setAzureLoading(true);
    startAzureLogin();
  };

  return (
    <div className="flex h-screen w-screen items-center justify-center bg-slate-100">
      <div className="w-full max-w-sm space-y-4 rounded-xl bg-white p-6 shadow-lg">
        <div className="flex items-center gap-2">
          <Globe2 className="h-6 w-6 text-emerald-600" />
          <span className="text-lg font-semibold text-slate-800">Geo App</span>
        </div>

        <p className="text-xs text-slate-500">
          Sign in with the shared platform account (GoTrue / Azure AD).
        </p>

        <button
          onClick={onAzure}
          disabled={azureLoading}
          className="flex w-full items-center justify-center gap-2 rounded-md border border-slate-200 bg-white py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-50"
        >
          {azureLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <MicrosoftLogo className="h-4 w-4" />
          )}
          Sign in with Microsoft
        </button>

        <div className="flex items-center gap-2 text-xs text-slate-400">
          <div className="h-px flex-1 bg-slate-200" />
          or
          <div className="h-px flex-1 bg-slate-200" />
        </div>

        {!showPassword ? (
          <button
            onClick={() => setShowPassword(true)}
            className="w-full text-center text-xs text-slate-500 hover:text-slate-700 hover:underline"
          >
            Sign in with password
          </button>
        ) : (
          <form onSubmit={onSubmit} className="space-y-3">
            <div className="space-y-1">
              <label className="block text-sm font-medium text-slate-700">
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-md border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
                required
              />
            </div>

            <div className="space-y-1">
              <label className="block text-sm font-medium text-slate-700">
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-md border border-slate-200 px-3 py-2 text-sm outline-none focus:border-emerald-500"
                required
              />
            </div>

            {login.isError && (
              <div className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
                {(login.error as { message?: string })?.message ??
                  "Login failed"}
              </div>
            )}

            <button
              type="submit"
              disabled={login.isPending}
              className="flex w-full items-center justify-center gap-2 rounded-md bg-emerald-600 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-60"
            >
              {login.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
              Sign in
            </button>

            <button
              type="button"
              onClick={() => setShowPassword(false)}
              className="w-full text-center text-xs text-slate-500 hover:text-slate-700"
            >
              Back
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

function MicrosoftLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 21 21">
      <rect x="1" y="1" width="9" height="9" fill="#f25022" />
      <rect x="11" y="1" width="9" height="9" fill="#7fba00" />
      <rect x="1" y="11" width="9" height="9" fill="#00a4ef" />
      <rect x="11" y="11" width="9" height="9" fill="#ffb900" />
    </svg>
  );
}
