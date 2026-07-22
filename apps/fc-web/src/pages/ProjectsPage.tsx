import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { MapProjectWizard } from "@/components/wizard/MapProjectWizard";
import { api } from "@/lib/api";
import { Plus, MapPin, FileText } from "lucide-react";

export function ProjectsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [mode, setMode] = useState("form_collection");
  const [showWizard, setShowWizard] = useState(false);
  

  const { data: projects, isLoading } = useQuery({ queryKey: ["projects"], queryFn: () => api.getProjects() });
  const projectList = Array.isArray(projects) ? projects : [];

  const createMutation = useMutation({
    mutationFn: () => api.createProject({ name, description, mode, config: {} }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["projects"] }); setShowCreate(false); setName(""); setDescription(""); },
  });

  return (
    <div className="p-6 overflow-auto h-full">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">All Projects</h1>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
          <Plus className="h-4 w-4" /> New Project
        </button>
      </div>

      {isLoading && <p className="text-gray-500">Loading...</p>}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {projectList.map((p: any) => (
          <div key={p.id} onClick={() => navigate(`/projects/${p.id}`)} className="cursor-pointer rounded-xl border border-gray-200 bg-white p-5 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between mb-3">
              <h3 className="font-semibold text-gray-900">{p.name}</h3>
              <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${p.mode === "map_based" ? "bg-blue-50 text-blue-700" : "bg-green-50 text-green-700"}`}>
                {p.mode === "map_based" ? <><MapPin className="h-3 w-3 mr-1" />Map</> : <><FileText className="h-3 w-3 mr-1" />Form</>}
              </span>
            </div>
            <p className="text-sm text-gray-500 mb-3 line-clamp-2">{p.description || "No description"}</p>
            <div className="flex items-center gap-3 text-xs text-gray-400">
              <span>v{p.version}</span>
              <span className={`rounded-full px-2 py-0.5 ${p.status === "active" ? "bg-green-50 text-green-600" : "bg-gray-100 text-gray-500"}`}>{p.status}</span>
            </div>
          </div>
        ))}
      </div>

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-semibold mb-4">New Project</h2>
            <form onSubmit={(e) => { e.preventDefault(); createMutation.mutate(); }} className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Project type</label>
                <select
                  value={mode}
                  onChange={(e) => {
                    const newMode = e.target.value;
                    if (newMode === "map_based") {
                      setShowCreate(false);
                      setShowWizard(true);
                    } else {
                      setMode(newMode);
                    }
                  }}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="form_collection">Form Collection</option>
                  <option value="map_based">Map Based</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} required className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
              </div>
              <div className="flex gap-3 justify-end">
                <button type="button" onClick={() => setShowCreate(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm">Cancel</button>
                <button type="submit" disabled={createMutation.isPending} className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50">{createMutation.isPending ? "Creating..." : "Create"}</button>
              </div>
              {createMutation.isError && <p className="text-sm text-red-600">{(createMutation.error as Error).message}</p>}
            </form>
          </div>
        </div>
      )}
      

{showWizard && (
  <MapProjectWizard onClose={() => setShowWizard(false)} />
)}

    </div>
  );
}