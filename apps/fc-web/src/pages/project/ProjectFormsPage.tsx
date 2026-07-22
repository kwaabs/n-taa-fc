import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus } from "lucide-react";

const defaultSchema = JSON.stringify({
  fields: [{ id: "name", type: "text", label: { en: "Name" }, required: true }],
  settings: { default_language: "en", languages: ["en"] }
}, null, 2);

export function ProjectFormsPage() {
  const { projectId } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [schema, setSchema] = useState(defaultSchema);

  const { data: forms, isLoading } = useQuery({ queryKey: ["forms", projectId], queryFn: () => api.getProjectForms(projectId!), enabled: !!projectId });
  const formList = Array.isArray(forms) ? forms : [];

  const createMutation = useMutation({
    mutationFn: () => api.createForm(projectId!, { name, description, schema: JSON.parse(schema) }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["forms", projectId] }); setShowCreate(false); setName(""); },
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Forms</h2>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Form
        </button>
      </div>

      {isLoading ? <p className="text-gray-500">Loading...</p> : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Version</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Active</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Created</th>
              </tr>
            </thead>
            <tbody>
              {formList.map((f: any) => (
                <tr key={f.id} onClick={() => navigate(`/projects/${projectId}/forms/${f.id}`)} className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer">
                  <td className="px-4 py-3 font-medium text-gray-900">{f.name}</td>
                  <td className="px-4 py-3 text-gray-600">v{f.version}</td>
                  <td className="px-4 py-3"><span className={`rounded-full px-2 py-0.5 text-xs ${f.is_active ? "bg-green-50 text-green-600" : "bg-gray-100 text-gray-500"}`}>{f.is_active ? "Active" : "Inactive"}</span></td>
                  <td className="px-4 py-3 text-gray-500">{new Date(f.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
              {formList.length === 0 && <tr><td colSpan={4} className="px-4 py-8 text-center text-gray-400">No forms yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-2xl max-h-[80vh] overflow-auto" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">New Form</h2>
            <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <input value={description} onChange={(e) => setDescription(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Schema (JSON)</label>
                <textarea value={schema} onChange={(e) => setSchema(e.target.value)} rows={12} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono" />
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowCreate(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={createMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">Create</button>
              </div>
              {createMutation.isError && <p className="text-sm text-red-600">{(createMutation.error as Error).message}</p>}
            </form>
          </div>
        </div>
      )}
    </div>
  );
}