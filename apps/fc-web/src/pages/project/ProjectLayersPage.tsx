import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, Trash2, Send, RotateCcw, Database } from "lucide-react";
import { ImportWizard } from "@/components/import-wizard/ImportWizard";

export function ProjectLayersPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState("");
  const [geomType, setGeomType] = useState("point");
  const navigate = useNavigate();
  const [showImportWizard, setShowImportWizard] = useState(false);
  const [busyLayerId, setBusyLayerId] = useState<string | null>(null);

  const { data: layers } = useQuery({
    queryKey: ["layers", projectId],
    queryFn: () => api.getProjectLayers(projectId!),
    enabled: !!projectId,
  });

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId!),
    enabled: !!projectId,
  });

  const layerList = Array.isArray(layers) ? layers : [];

  const invalidateLayers = () =>
    queryClient.invalidateQueries({ queryKey: ["layers", projectId] });

  const createMutation = useMutation({
    mutationFn: () =>
      api.createLayer(projectId!, {
        name,
        geometry_type: geomType,
        is_editable: true,
        is_visible_by_default: true,
      }),
    onSuccess: () => {
      invalidateLayers();
      setShowCreate(false);
      setName("");
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (layerId: string) => api.deleteLayer(projectId!, layerId),
    onSuccess: () => invalidateLayers(),
  });

  /** Publish (+ ensure form for linked layers that still lack one). */
  async function publishLayer(layer: any) {
    if (!projectId) return;
    setBusyLayerId(layer.id);
    try {
      if (
        layer.source_type === "linked_table" &&
        !layer.form_id
      ) {
        await api.ensureLayerForm(projectId, layer.id);
      }
      await api.publishLayer(projectId, layer.id);
      await invalidateLayers();
    } catch (e: any) {
      alert(e?.message || "Publish failed");
    } finally {
      setBusyLayerId(null);
    }
  }

  async function unpublishLayer(layer: any) {
    if (!projectId) return;
    if (
      !confirm(
        "Unpublishing will hide this layer from field workers. Continue?"
      )
    ) {
      return;
    }
    setBusyLayerId(layer.id);
    try {
      await api.unpublishLayer(projectId, layer.id);
      await invalidateLayers();
    } catch (e: any) {
      alert(e?.message || "Unpublish failed");
    } finally {
      setBusyLayerId(null);
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-semibold text-gray-900">Layers</h2>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowImportWizard(true)}
            className="flex items-center gap-2 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            <Database className="h-4 w-4" />
            Import from Database
          </button>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" />
            New Layer
          </button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Name
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Geometry
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Status
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Editable
              </th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {layerList.map((l: any) => {
              const published = l.status === "published";
              const busy = busyLayerId === l.id;
              return (
                <tr
                  key={l.id}
                  onClick={() =>
                    navigate(`/projects/${projectId}/layers/${l.id}`)
                  }
                  className="border-b border-gray-100 hover:bg-gray-50 cursor-pointer"
                >
                  <td className="px-4 py-3 font-medium text-gray-900">
                    {l.name}
                  </td>
                  <td className="px-4 py-3">
                    <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">
                      {l.geometry_type}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`rounded px-2 py-0.5 text-xs font-medium ${
                        published
                          ? "bg-green-100 text-green-800"
                          : "bg-yellow-100 text-yellow-800"
                      }`}
                    >
                      {published ? "Published" : "Draft"}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {l.is_editable
                      ? "Yes"
                      : project?.config?.aoi_layer_id === l.id
                        ? "No (AOI)"
                        : "No"}
                  </td>
                  <td
                    className="px-4 py-3"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <div className="flex items-center gap-2">
                      {published ? (
                        <button
                          type="button"
                          title="Unpublish"
                          disabled={busy}
                          onClick={() => unpublishLayer(l)}
                          className="inline-flex items-center gap-1 rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                        >
                          <RotateCcw className="h-3.5 w-3.5" />
                          {busy ? "…" : "Unpublish"}
                        </button>
                      ) : (
                        <button
                          type="button"
                          title="Publish"
                          disabled={busy}
                          onClick={() => publishLayer(l)}
                          className="inline-flex items-center gap-1 rounded bg-blue-600 px-2 py-1 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                        >
                          <Send className="h-3.5 w-3.5" />
                          {busy ? "…" : "Publish"}
                        </button>
                      )}
                      <button
                        type="button"
                        title="Delete"
                        onClick={() => {
                          if (confirm("Delete this layer?"))
                            deleteMutation.mutate(l.id);
                        }}
                        className="text-red-500 hover:text-red-700"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {layerList.length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-8 text-center text-gray-400"
                >
                  No layers yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showCreate && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div
            className="bg-white rounded-xl shadow-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-lg font-semibold mb-4">New Layer</h2>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                createMutation.mutate();
              }}
              className="flex flex-col gap-4"
            >
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name
                </label>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Geometry Type
                </label>
                <select
                  value={geomType}
                  onChange={(e) => setGeomType(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                >
                  <option value="point">Point</option>
                  <option value="line">Line</option>
                  <option value="polygon">Polygon</option>
                </select>
              </div>
              <div className="flex gap-3 justify-end">
                <button
                  type="button"
                  onClick={() => setShowCreate(false)}
                  className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isPending}
                  className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      {showImportWizard && (
        <ImportWizard
          projectId={projectId!}
          onClose={() => {
            setShowImportWizard(false);
            invalidateLayers();
          }}
        />
      )}
    </div>
  );
}
