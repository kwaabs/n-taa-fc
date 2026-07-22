import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Check, X } from "lucide-react";

export function FeaturesPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState("");
  const [page] = useState(0);

  const { data, isLoading } = useQuery({
    queryKey: ["features", projectId, page],
    queryFn: () => api.getProjectFeatures(projectId!, { limit: 50, offset: page * 50 }),
    enabled: !!projectId,
  });

  const features = Array.isArray(data) ? data : data?.data || [];
  const filtered = statusFilter ? features.filter((f: any) => f.status === statusFilter) : features;

  const reviewMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => api.updateFeatureStatus(projectId!, id, status),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["features", projectId] }),
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Features</h2>
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm">
          <option value="">All Statuses</option>
          <option value="draft">Draft</option>
          <option value="submitted">Submitted</option>
          <option value="under_review">Under Review</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      {isLoading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Client ID</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Status</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Collected</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((f: any) => (
                <tr key={f.id} className="border-b border-gray-100 hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs text-gray-600">{f.client_id?.slice(0, 8)}...</td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      f.status === "approved" ? "bg-green-50 text-green-600" :
                      f.status === "rejected" ? "bg-red-50 text-red-600" :
                      f.status === "submitted" ? "bg-blue-50 text-blue-600" :
                      "bg-gray-100 text-gray-500"
                    }`}>{f.status}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-500">{new Date(f.collected_at).toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      {f.status === "submitted" && (
                        <>
                          <button onClick={() => reviewMutation.mutate({ id: f.id, status: "approved" })} className="text-green-600 hover:text-green-800" title="Approve"><Check className="h-4 w-4" /></button>
                          <button onClick={() => reviewMutation.mutate({ id: f.id, status: "rejected" })} className="text-red-500 hover:text-red-700" title="Reject"><X className="h-4 w-4" /></button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-400">No features yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}