import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, Trash2 } from "lucide-react";

export function LayersPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [geomType, setGeomType] = useState("point");

  const { data: layers, isLoading } = useQuery({ queryKey: ["layers", projectId], queryFn: () => api.getProjectLayers(projectId!), enabled: !!projectId });

  const createMutation = useMutation({
    mutationFn: () => api.createLayer(projectId!, { name, geometry_type: geomType, is_editable: true, is_visible_by_default: true }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["layers", projectId] }); setShowCreate(false); setName(""); },
  });

  const deleteMutation = useMutation({
    mutationFn: (layerId: string) => api.deleteLayer(projectId!, layerId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["layers", projectId] }),
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Layers</h2>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Layer
        </button>
      </div>

      {isLoading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Geometry</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Editable</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {layers?.map((l: any) => (
                <tr key={l.id} className="border-b border-gray-100">
                  <td className="px-4 py-3 font-medium text-gray-900">{l.name}</td>
                  <td className="px-4 py-3"><span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{l.geometry_type}</span></td>
                  <td className="px-4 py-3">{l.is_editable ? "Yes" : "No"}</td>
                  <td className="px-4 py-3">
                    <button onClick={() => { if (confirm("Delete this layer?")) deleteMutation.mutate(l.id); }} className="text-red-500 hover:text-red-700"><Trash2 className="h-4 w-4" /></button>
                  </td>
                </tr>
              ))}
              {layers?.length === 0 && <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-400">No layers yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">New Layer</h2>
            <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Geometry Type</label>
                <select value={geomType} onChange={(e) => setGeomType(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm">
                  <option value="point">Point</option>
                  <option value="line">Line</option>
                  <option value="polygon">Polygon</option>
                </select>
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