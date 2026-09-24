import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, Trash2, Users2, UserPlus } from "lucide-react";

export function ProjectAccessPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [showAssignTeam, setShowAssignTeam] = useState(false);
  const [showAddMember, setShowAddMember] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState("");
  const [teamRole] = useState("field_worker");
  const [memberEmail, setMemberEmail] = useState("");
  const [memberRole, setMemberRole] = useState("field_worker");

  const { data: projectTeams } = useQuery({ queryKey: ["projectTeams", projectId], queryFn: () => api.getProjectTeams(projectId!), enabled: !!projectId });
  const { data: members } = useQuery({ queryKey: ["members", projectId], queryFn: () => api.getProjectMembers(projectId!), enabled: !!projectId });
  const { data: allTeams } = useQuery({ queryKey: ["teams"], queryFn: () => api.getTeams() });

  const ptList = Array.isArray(projectTeams) ? projectTeams : [];
  const memberList = Array.isArray(members) ? members : [];
  const teamList = Array.isArray(allTeams) ? allTeams : [];

  const { data: me } = useQuery({
    queryKey: ["me"],
    queryFn: () => api.getMe(),
  });
  const myMembership = memberList.find((m: any) => m.user_id === me?.id);
  const canManageMembers = me?.is_system_admin || myMembership?.role === "admin";

  const roleBadgeClass = (role: string) => {
    if (role === "admin") return "bg-red-50 text-red-600";
    if (role === "supervisor") return "bg-purple-50 text-purple-600";
    return "bg-blue-50 text-blue-600";
  };

  const roleLabel = (role: string) => {
    if (role === "admin") return "Admin";
    if (role === "supervisor") return "Supervisor";
    return "Field worker";
  };

  // All users for the picker (excludes those already direct members)
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

  const assignMutation = useMutation({
    mutationFn: () => api.assignTeamToProject(projectId!, selectedTeam, teamRole),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["projectTeams", projectId] }); setShowAssignTeam(false); },
  });

  const removeTeamMutation = useMutation({
    mutationFn: (teamId: string) => api.removeTeamFromProject(projectId!, teamId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["projectTeams", projectId] }),
  });

  const addMemberMutation = useMutation({
    mutationFn: () => api.addMember(projectId!, memberEmail, memberRole),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["members", projectId] }); setShowAddMember(false); setMemberEmail(""); setMemberRole("field_worker"); },
  });

  const roleMutation = useMutation({
    mutationFn: ({ userId, newRole }: { userId: string; newRole: string }) =>
      api.updateMemberRole(projectId!, userId, newRole),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["members", projectId] }),
  });

  const removeMemberMutation = useMutation({
    mutationFn: (userId: string) => api.removeMember(projectId!, userId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["members", projectId] }),
  });

  return (
    <div className="space-y-8">
      {/* Teams */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2"><Users2 className="h-5 w-5" /> Assigned Teams</h2>
          <button onClick={() => setShowAssignTeam(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
            <Plus className="h-4 w-4" /> Assign Team
          </button>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Team</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Members</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {ptList.map((pt: any) => (
                <tr key={pt.team_id} className="border-b border-gray-100">
                  <td className="px-4 py-3 font-medium text-gray-900">{pt.team?.name || pt.team_id}</td>
                  <td className="px-4 py-3 text-gray-600">{pt.member_count ?? pt.team?.member_count ?? "—"}</td>
                  <td className="px-4 py-3">
                    <button onClick={() => { if (confirm("Remove team?")) removeTeamMutation.mutate(pt.team_id); }} className="text-red-500 hover:text-red-700"><Trash2 className="h-4 w-4" /></button>
                  </td>
                </tr>
              ))}
              {ptList.length === 0 && <tr><td colSpan={3} className="px-4 py-8 text-center text-gray-400">No teams assigned</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {/* Individual Members */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2"><UserPlus className="h-5 w-5" /> Individual Members</h2>
          <button onClick={() => setShowAddMember(true)} disabled={!canManageMembers} className="flex items-center gap-2 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">
            <Plus className="h-4 w-4" /> Add Member
          </button>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Email</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Role</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {memberList.map((m: any) => (
                <tr key={m.user_id} className="border-b border-gray-100">
                  <td className="px-4 py-3 text-gray-900">{m.user?.email || m.user_id}</td>
                  <td className="px-4 py-3">
                    {canManageMembers ? (
                      <select
                        value={m.role ?? "field_worker"}
                        disabled={roleMutation.isPending}
                        onChange={(e) =>
                          roleMutation.mutate({
                            userId: m.user_id,
                            newRole: e.target.value,
                          })
                        }
                        className="rounded border border-gray-200 px-2 py-1 text-xs"
                      >
                        <option value="admin">Admin</option>
                        <option value="supervisor">Supervisor</option>
                        <option value="field_worker">Field worker</option>
                      </select>
                    ) : (
                      <span
                        className={`rounded-full px-2 py-0.5 text-xs ${roleBadgeClass(m.role ?? "field_worker")}`}
                      >
                        {roleLabel(m.role ?? "field_worker")}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {canManageMembers && (
                      <button onClick={() => { if (confirm("Remove member?")) removeMemberMutation.mutate(m.user_id); }} className="text-red-500 hover:text-red-700"><Trash2 className="h-4 w-4" /></button>
                    )}
                  </td>
                </tr>
              ))}
              {memberList.length === 0 && <tr><td colSpan={3} className="px-4 py-8 text-center text-gray-400">No individual members</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {/* Assign Team Dialog */}
      {showAssignTeam && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">Assign Team</h2>
            <form onSubmit={(e) => { e.preventDefault(); assignMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Team</label>
                <select value={selectedTeam} onChange={(e) => setSelectedTeam(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm">
                  <option value="">Select team...</option>
                  {teamList.map((t: any) => <option key={t.id} value={t.id}>{t.name}</option>)}
                </select>
              </div>

              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowAssignTeam(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={assignMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Assign</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Member Dialog */}
      {showAddMember && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">Add Member</h2>
            <form onSubmit={(e) => { e.preventDefault(); addMemberMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">User</label>
                <select
                  value={memberEmail}
                  onChange={(e) => setMemberEmail(e.target.value)}
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
                    All users are already members.
                  </p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
                <select
                  value={memberRole}
                  onChange={(e) => setMemberRole(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="field_worker">Field worker</option>
                  <option value="supervisor">Supervisor</option>
                  <option value="admin">Admin</option>
                </select>
              </div>

              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowAddMember(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={addMemberMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Add</button>
              </div>
              {addMemberMutation.isError && <p className="text-sm text-red-600">{(addMemberMutation.error as Error).message}</p>}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}