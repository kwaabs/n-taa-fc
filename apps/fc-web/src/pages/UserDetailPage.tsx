import { useState } from "react";
import { useParams, Link } from "react-router-dom";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { ArrowLeft, Users2, FolderOpen, User, Plus, Trash2 } from "lucide-react";

const ROLES = ["field_worker", "supervisor", "admin"];

export function UserDetailPage() {
  const { userId } = useParams();
  const queryClient = useQueryClient();
  const [showAddTeam, setShowAddTeam] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["user", userId],
    queryFn: () => api.getUser(userId!),
    enabled: !!userId,
  });

  // All teams (for the "add to team" picker)
  const { data: allTeams } = useQuery({
    queryKey: ["teams"],
    queryFn: () => api.getTeams(),
  });

  const roleMutation = useMutation({
    mutationFn: (role: string) => api.updateUserRole(userId!, role),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["user", userId] }),
  });

  const addToTeamMutation = useMutation({
    mutationFn: (teamId: string) =>
      api.addTeamMember(teamId, profile.email, "member"),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["user", userId] });
      setShowAddTeam(false);
      setSelectedTeam("");
    },
  });

  const removeFromTeamMutation = useMutation({
    mutationFn: (teamId: string) =>
      api.removeTeamMember(teamId, userId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["user", userId] }),
  });

  if (isLoading) return <div className="p-6 text-gray-400">Loading…</div>;

  const profile = data?.profile ?? data?.data?.profile ?? {};
  const teams = data?.teams ?? data?.data?.teams ?? [];
  const projects = data?.projects ?? data?.data?.projects ?? [];

  const teamList = Array.isArray(allTeams) ? allTeams : [];
  const currentTeamIds = new Set(teams.map((t: any) => t.team_id));
  const availableTeams = teamList.filter((t: any) => !currentTeamIds.has(t.id));

  return (
    <div className="max-w-5xl p-6">
      <Link to="/users" className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4">
        <ArrowLeft className="h-4 w-4" /> Back to Users
      </Link>

      {/* Profile */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center">
            <User className="h-6 w-6 text-blue-600" />
          </div>
          <div>
            <div className="text-lg font-semibold text-gray-900">{profile.email}</div>
            {profile.full_name && <div className="text-sm text-gray-500">{profile.full_name}</div>}
          </div>
        </div>
        <div className="flex items-center gap-3">
          <label className="text-sm font-medium text-gray-700">Role:</label>
          <select
            value={profile.role || "field_worker"}
            disabled={profile.is_system_admin || roleMutation.isPending}
            onChange={(e) => roleMutation.mutate(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm disabled:bg-gray-50 disabled:text-gray-400"
          >
            {ROLES.map((r) => (
              <option key={r} value={r}>{r.replace("_", " ")}</option>
            ))}
          </select>
          {profile.is_system_admin && (
            <span className="rounded-full bg-amber-50 px-2 py-0.5 text-xs text-amber-700">
              System Admin
            </span>
          )}
        </div>
      </div>

      {/* Teams */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-sm font-semibold text-gray-700 flex items-center gap-2">
            <Users2 className="h-4 w-4" /> Teams ({teams.length})
          </h2>
          <button
            onClick={() => setShowAddTeam(true)}
            disabled={availableTeams.length === 0}
            className="flex items-center gap-1 rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Plus className="h-3.5 w-3.5" /> Add to Team
          </button>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
          {teams.length === 0 && (
            <div className="px-4 py-6 text-center text-gray-400 text-sm">Not on any team</div>
          )}
          {teams.map((t: any) => (
            <div key={t.team_id} className="px-4 py-3 flex items-center justify-between">
              <span className="text-gray-900">{t.team_name}</span>
              <div className="flex items-center gap-3">
                <span className={`rounded-full px-2 py-0.5 text-xs ${t.team_role === "leader" ? "bg-purple-50 text-purple-600" : "bg-gray-100 text-gray-600"}`}>
                  {t.team_role}
                </span>
                <button
                  onClick={() => {
                    if (confirm(`Remove from ${t.team_name}?`))
                      removeFromTeamMutation.mutate(t.team_id);
                  }}
                  className="text-red-500 hover:text-red-700"
                  title="Remove from team"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Projects */}
      <div>
        <h2 className="text-sm font-semibold text-gray-700 flex items-center gap-2 mb-2">
          <FolderOpen className="h-4 w-4" /> Projects with access ({projects.length})
        </h2>
        <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
          {projects.length === 0 && <div className="px-4 py-6 text-center text-gray-400 text-sm">No project access</div>}
          {projects.map((p: any, i: number) => (
            <div key={`${p.project_id}-${i}`} className="px-4 py-3 flex items-center justify-between">
              <div>
                <span className="text-gray-900">{p.name}</span>
                <span className="ml-2 text-xs text-gray-400">{p.status}</span>
              </div>
              <span className="text-xs text-gray-500">
                {p.source === "direct" ? "direct member" : `via ${p.team_name}`}
              </span>
            </div>
          ))}
        </div>
      </div>
            {/* Add to Team Dialog */}
            {showAddTeam && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">Add {profile.email} to a Team</h2>
            <form onSubmit={(e) => { e.preventDefault(); if (selectedTeam) addToTeamMutation.mutate(selectedTeam); }} className="flex flex-col gap-4">
              <select
                value={selectedTeam}
                onChange={(e) => setSelectedTeam(e.target.value)}
                required
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">Select team…</option>
                {availableTeams.map((t: any) => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowAddTeam(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={addToTeamMutation.isPending || !selectedTeam} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Add</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}