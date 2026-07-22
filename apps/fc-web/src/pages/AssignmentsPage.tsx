import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus } from "lucide-react";

export function AssignmentsPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [assignedTo, setAssignedTo] = useState("");
  const [instructions, setInstructions] = useState("");
  const [targetCount, setTargetCount] = useState(0);

  const { data: assignments, isLoading } = useQuery({ queryKey: ["assignments", projectId], queryFn: () => api.getProjectAssignments(projectId!), enabled: !!projectId });
  const { data: members } = useQuery({ queryKey: ["members", projectId], queryFn: () => api.getProjectMembers(projectId!), enabled: !!projectId });

  const createMutation = useMutation({
    mutationFn: () => api.createAssignment(projectId!, { assigned_to: assignedTo, instructions, target_count: targetCount }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["assignments", projectId] }); setShowCreate(false); },
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Assignments</h2>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Assignment
        </button>
      </div>

      {isLoading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Assigned To</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Target</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Instructions</th>
              </tr>
            </thead>
            <tbody>
              {assignments?.map((a: any) => (
                <tr key={a.id} className="border-b border-gray-100">
                  <td className="px-4 py-3 font-mono text-xs">{a.assigned_to?.slice(0, 8)}...</td>
                  <td className="px-4 py-3">{a.target_count || "-"}</td>
                  <td className="px-4 py-3"><span className={`rounded-full px-2 py-0.5 text-xs ${a.status === "completed" ? "bg-green-50 text-green-600" : a.status === "in_progress" ? "bg-blue-50 text-blue-600" : "bg-gray-100 text-gray-500"}`}>{a.status}</span></td>
                  <td className="px-4 py-3 text-gray-500 truncate max-w-xs">{a.instructions || "-"}</td>
                </tr>
              ))}
              {assignments?.length === 0 && <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-400">No assignments yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">New Assignment</h2>
            <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Assign To</label>
                <select value={assignedTo} onChange={(e) => setAssignedTo(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm">
                  <option value="">Select member</option>
                  {members?.map((m: any) => <option key={m.user_id} value={m.user_id}>{m.user?.email || m.user_id} ({m.role})</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Target Count</label>
                <input type="number" value={targetCount} onChange={(e) => setTargetCount(Number(e.target.value))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Instructions</label>
                <textarea value={instructions} onChange={(e) => setInstructions(e.target.value)} rows={3} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowCreate(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={createMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Create</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}