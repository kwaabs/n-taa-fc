import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from 'react-router-dom';
import { api } from "@/lib/api";
import { ShieldCheck, User } from "lucide-react";

const ROLES = ["field_worker", "supervisor", "admin"];

export function UsersPage() {
  const queryClient = useQueryClient();

  const { data: users, isLoading } = useQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
  });

  const roleMutation = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: string }) =>
      api.updateUserRole(userId, role),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] }),
  });

  const userList = Array.isArray(users) ? users : [];

  return (
    <div className="max-w-5xl p-6">
      <div className="flex items-center gap-2 mb-6">
        <ShieldCheck className="h-6 w-6 text-blue-600" />
        <h1 className="text-2xl font-bold text-gray-900">Users & Roles</h1>
      </div>

      <p className="text-sm text-gray-500 mb-4">
        A user's role is fixed and applies across all projects they belong to.
        Only system administrators can change roles.
      </p>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="text-left px-4 py-3 font-medium text-gray-600">User</th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">Role</th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">System</th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr><td colSpan={3} className="px-4 py-8 text-center text-gray-400">Loading…</td></tr>
            )}
            {userList.map((u: any) => (
              <tr key={u.id} className="border-b border-gray-100">
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    <User className="h-4 w-4 text-gray-400" />
                    <div>
                      <div className="text-gray-900 font-medium"><Link to={`/users/${u.id}`} className="text-blue-600 hover:underline">
  {u.email}
</Link></div>
                      {u.full_name && (
                        <div className="text-xs text-gray-500">{u.full_name}</div>
                      )}
                    </div>
                  </div>
                </td>
                <td className="px-4 py-3">
                  <select
                    value={u.role || "field_worker"}
                    disabled={u.is_system_admin || roleMutation.isPending}
                    onChange={(e) =>
                      roleMutation.mutate({ userId: u.id, role: e.target.value })
                    }
                    className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm disabled:bg-gray-50 disabled:text-gray-400"
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {r.replace("_", " ")}
                      </option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-3">
                  {u.is_system_admin ? (
                    <span className="inline-flex items-center gap-1 rounded-full bg-amber-50 px-2 py-0.5 text-xs text-amber-700">
                      <ShieldCheck className="h-3 w-3" /> System Admin
                    </span>
                  ) : (
                    <span className="text-gray-300">—</span>
                  )}
                </td>
              </tr>
            ))}
            {!isLoading && userList.length === 0 && (
              <tr><td colSpan={3} className="px-4 py-8 text-center text-gray-400">No users</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {roleMutation.isError && (
        <p className="mt-3 text-sm text-red-600">
          {(roleMutation.error as Error).message}
        </p>
      )}
    </div>
  );
}