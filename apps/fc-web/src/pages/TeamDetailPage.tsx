import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { ArrowLeft, Plus, Trash2, Users2 } from "lucide-react";

export function TeamDetailPage() {
  const { teamId } = useParams();
  const queryClient = useQueryClient();
  const [showAdd, setShowAdd] = useState(false);
  const [selectedEmail, setSelectedEmail] = useState("");
  const [role, setRole] = useState("member");

  const { data: team } = useQuery({
    queryKey: ["team", teamId],
    queryFn: () => api.getTeam(teamId!),
    enabled: !!teamId,
  });

  const { data: members } = useQuery({
    queryKey: ["teamMembers", teamId],
    queryFn: () => api.getTeamMembers(teamId!),
    enabled: !!teamId,
  });

  const memberList = Array.isArray(members) ? members : [];

  // All users for the picker (excludes those already on this team)
  const { data: allUsers } = useQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
  });
  const userList = Array.isArray(allUsers) ? allUsers : [];
  const memberEmails = new Set(
    memberList.map((m: any) => m.user?.email).filter(Boolean)
  );
  const availableUsers = userList.filter(
    (u: any) => !memberEmails.has(u.email)
  );

  const addMutation = useMutation({
    mutationFn: () => api.addTeamMember(teamId!, selectedEmail, role),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["teamMembers", teamId] });
      setShowAdd(false);
      setSelectedEmail("");
    },
  });

  const roleMutation = useMutation({
    mutationFn: ({ userId, newRole }: { userId: string; newRole: string }) =>
      api.updateTeamMemberRole(teamId!, userId, newRole),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["teamMembers", teamId] }),
  });

  const removeMutation = useMutation({
    mutationFn: (userId: string) => api.removeTeamMember(teamId!, userId),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["teamMembers", teamId] }),
  });

  return (
    <div className="p-6 overflow-auto h-full">
      <div className="flex items-center gap-3 mb-6">
        <Link to="/teams" className="text-gray-400 hover:text-gray-600">
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex items-center gap-3">
          <div className="rounded-lg bg-green-50 p-2">
            <Users2 className="h-5 w-5 text-green-600" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900">
              {team?.name || "Loading..."}
            </h1>
            <p className="text-sm text-gray-500">{team?.description}</p>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-gray-900">
          Members ({memberList.length})
        </h2>
        <button
          onClick={() => setShowAdd(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add Member
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Email
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Name
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Role
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {memberList.map((m: any) => (
              <tr key={m.user_id} className="border-b border-gray-100">
                <td className="px-4 py-3 text-gray-900">
                  {m.user?.email || "—"}
                </td>
                <td className="px-4 py-3 text-gray-600">
                  {m.user?.full_name || "—"}
                </td>
                <td className="px-4 py-3">
                  <select
                    value={m.role}
                    onChange={(e) =>
                      roleMutation.mutate({
                        userId: m.user_id,
                        newRole: e.target.value,
                      })
                    }
                    className="rounded border border-gray-200 px-2 py-1 text-xs"
                  >
                    <option value="leader">Leader</option>
                    <option value="member">Member</option>
                  </select>
                </td>
                <td className="px-4 py-3">
                  <button
                    onClick={() => {
                      if (confirm("Remove this member?"))
                        removeMutation.mutate(m.user_id);
                    }}
                    className="text-red-500 hover:text-red-700"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </td>
              </tr>
            ))}
            {memberList.length === 0 && (
              <tr>
                <td
                  colSpan={4}
                  className="px-4 py-8 text-center text-gray-400"
                >
                  No members yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showAdd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div
            className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-lg font-semibold mb-4">Add Member</h2>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                addMutation.mutate();
              }}
              className="flex flex-col gap-4"
            >
                            <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  User
                </label>
                <select
                  value={selectedEmail}
                  onChange={(e) => setSelectedEmail(e.target.value)}
                  required
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="">Select a user…</option>
                  {availableUsers.map((u: any) => (
                    <option key={u.id} value={u.email}>
                      {u.email}{u.full_name ? ` — ${u.full_name}` : ""}
                    </option>
                  ))}
                </select>
                {availableUsers.length === 0 && (
                  <p className="text-xs text-gray-400 mt-1">
                    All users are already on this team.
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Role
                </label>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="leader">Leader</option>
                  <option value="member">Member</option>
                </select>
              </div>
              <div className="flex gap-3 justify-end">
                <button
                  type="button"
                  onClick={() => setShowAdd(false)}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={addMutation.isPending}
                  className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  Add
                </button>
              </div>
              {addMutation.isError && (
                <p className="text-sm text-red-600">
                  {(addMutation.error as Error).message}
                </p>
              )}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}