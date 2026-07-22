import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, Trash2 } from "lucide-react";

export function MembersPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [showAdd, setShowAdd] = useState(false);
  const [email, setEmail] = useState("");
  const [role, setRole] = useState("field_worker");

  const { data: members, isLoading } = useQuery({ queryKey: ["members", projectId], queryFn: () => api.getProjectMembers(projectId!), enabled: !!projectId });

  const addMutation = useMutation({
    mutationFn: () => api.addMember(projectId!, email, role),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["members", projectId] }); setShowAdd(false); setEmail(""); },
  });

  const roleMutation = useMutation({
    mutationFn: ({ userId, newRole }: { userId: string; newRole: string }) => api.updateMemberRole(projectId!, userId, newRole),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["members", projectId] }),
  });

  const removeMutation = useMutation({
    mutationFn: (userId: string) => api.removeMember(projectId!, userId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["members", projectId] }),
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Members</h2>
        <button onClick={() => setShowAdd(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> Add Member
        </button>
      </div>

      {isLoading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Email</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Role</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {members?.map((m: any) => (
                <tr key={m.user_id} className="border-b border-gray-100">
                  <td className="px-4 py-3 text-gray-900">{m.user?.email || "—"}</td>
                  <td className="px-4 py-3 text-gray-600">{m.user?.full_name || "—"}</td>
                  <td className="px-4 py-3">
                    <select value={m.role} onChange={(e) => roleMutation.mutate({ userId: m.user_id, newRole: e.target.value })} className="rounded border border-gray-200 px-2 py-1 text-xs">
                      <option value="admin">Admin</option>
                      <option value="supervisor">Supervisor</option>
                      <option value="field_worker">Field Worker</option>
                    </select>
                  </td>
                  <td className="px-4 py-3">
                    <button onClick={() => { if (confirm("Remove this member?")) removeMutation.mutate(m.user_id); }} className="text-red-500 hover:text-red-700"><Trash2 className="h-4 w-4" /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {showAdd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">Add Member</h2>
            <form onSubmit={(e) => { e.preventDefault(); addMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="user@example.com" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
                <select value={role} onChange={(e) => setRole(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm">
                  <option value="admin">Admin</option>
                  <option value="supervisor">Supervisor</option>
                  <option value="field_worker">Field Worker</option>
                </select>
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowAdd(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={addMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Add</button>
              </div>
              {addMutation.isError && <p className="text-sm text-red-600">{(addMutation.error as Error).message}</p>}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}