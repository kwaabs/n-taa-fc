import { useState } from "react";
import { Loader2, Search } from "lucide-react";
import { useLoginHistory } from "@/features/users/hooks";
import type { Role } from "@/features/users/types";

export function AuditTab() {
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const limit = 50;

  const { data, isLoading, isError } = useLoginHistory({ q, page, limit });

  const events = data?.events ?? [];
  const total = data?.total ?? 0;
  const hasNextPage = page * limit < total;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="text-sm font-medium text-slate-700">
          {total.toLocaleString()} logins
        </div>

        <div className="relative ml-auto max-w-sm flex-1">
          <Search className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setPage(1);
            }}
            placeholder="Search email…"
            className="w-full rounded-md border border-slate-200 bg-white py-1.5 pl-7 pr-2 text-sm outline-none focus:border-emerald-500"
          />
        </div>
      </div>

      {isLoading && (
        <div className="flex items-center gap-2 rounded-md border border-slate-200 bg-slate-50 p-4 text-sm text-slate-500">
          <Loader2 className="h-4 w-4 animate-spin" />
          Loading login history…
        </div>
      )}

      {isError && (
        <div className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
          Failed to load login history.
        </div>
      )}

      {!isLoading && !isError && (
        <>
          <div className="overflow-hidden rounded-lg border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs text-slate-500">
                <tr>
                  <th className="px-3 py-2 font-medium">User</th>
                  <th className="px-3 py-2 font-medium">Role</th>
                  <th className="px-3 py-2 font-medium">IP address</th>
                  <th className="px-3 py-2 font-medium">Signed in</th>
                </tr>
              </thead>
              <tbody>
                {events.map((ev) => (
                  <tr
                    key={ev.id}
                    className="border-t border-slate-100 hover:bg-slate-50"
                  >
                    <td className="px-3 py-2">
                      <div className="font-medium text-slate-800">
                        {ev.display_name || ev.email}
                      </div>
                      {ev.display_name && (
                        <div className="truncate text-xs text-slate-500">
                          {ev.email}
                        </div>
                      )}
                    </td>
                    <td className="px-3 py-2">
                      {ev.role ? (
                        <span
                          className={[
                            "inline-flex rounded-full px-2 py-0.5 text-xs font-medium",
                            roleBadgeClass(ev.role),
                          ].join(" ")}
                        >
                          {ev.role}
                        </span>
                      ) : (
                        <span className="text-xs text-slate-400">—</span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-xs text-slate-500">
                      {ev.ip_address || "—"}
                    </td>
                    <td className="px-3 py-2 text-xs text-slate-500">
                      {new Date(ev.created_at).toLocaleString()}
                    </td>
                  </tr>
                ))}
                {events.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="px-3 py-8 text-center text-sm text-slate-400"
                    >
                      No logins match your filters.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {(page > 1 || hasNextPage) && (
            <div className="flex items-center justify-end gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="rounded-md border border-slate-200 bg-white px-2 py-1 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-40"
              >
                Previous
              </button>
              <span className="text-xs text-slate-500">Page {page}</span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={!hasNextPage}
                className="rounded-md border border-slate-200 bg-white px-2 py-1 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-40"
              >
                Next
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function roleBadgeClass(role: Role): string {
  switch (role) {
    case "superuser":
      return "bg-purple-100 text-purple-700";
    case "supervisor":
      return "bg-amber-100 text-amber-800";
    case "editor":
      return "bg-blue-100 text-blue-700";
    case "viewer":
    default:
      return "bg-slate-100 text-slate-600";
  }
}
