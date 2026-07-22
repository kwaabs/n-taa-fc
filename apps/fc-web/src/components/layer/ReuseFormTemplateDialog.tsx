import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { X, Copy } from "lucide-react";

interface Props {
  projectId: string;
  layerId: string;
  layerName?: string;
  onClose: () => void;
  /** Called after a form is linked/cloned onto the layer. */
  onApplied?: (layer: any) => void;
}

export function ReuseFormTemplateDialog({
  projectId,
  layerId,
  layerName,
  onClose,
  onApplied,
}: Props) {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState("");
  const [name, setName] = useState("");
  const [includeThisProject, setIncludeThisProject] = useState(false);

  const { data: templates, isLoading } = useQuery({
    queryKey: ["form-templates", projectId, includeThisProject],
    queryFn: () =>
      api.getFormTemplates(includeThisProject ? undefined : projectId),
  });

  const list = useMemo(() => {
    const rows = Array.isArray(templates) ? templates : [];
    if (includeThisProject) return rows;
    return rows.filter((t: any) => t.project_id !== projectId);
  }, [templates, includeThisProject, projectId]);

  const selected = list.find((t: any) => t.id === selectedId);

  const applyMutation = useMutation({
    mutationFn: () =>
      api.applyLayerFormTemplate(
        projectId,
        layerId,
        selectedId,
        name.trim() || undefined,
      ),
    onSuccess: (layer) => {
      queryClient.setQueryData(["layer", layerId], layer);
      queryClient.invalidateQueries({ queryKey: ["layer", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layers", projectId] });
      queryClient.invalidateQueries({ queryKey: ["forms", projectId] });
      if (layer?.form_id) {
        queryClient.invalidateQueries({ queryKey: ["form", layer.form_id] });
      }
      onApplied?.(layer);
      onClose();
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              Reuse form template
            </h2>
            {layerName && (
              <p className="text-xs text-gray-500 mt-0.5">For layer · {layerName}</p>
            )}
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 overflow-auto p-6 flex flex-col gap-4">
          <p className="text-sm text-gray-500">
            Pick a form from another project. It will be <strong>cloned</strong> into
            this project and linked to the layer (your original stays unchanged).
            Forms from this project are linked without cloning.
          </p>

          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={includeThisProject}
              onChange={(e) => {
                setIncludeThisProject(e.target.checked);
                setSelectedId("");
              }}
              className="rounded border-gray-300"
            />
            Also show forms from this project
          </label>

          {isLoading ? (
            <p className="text-sm text-gray-500">Loading templates…</p>
          ) : list.length === 0 ? (
            <p className="text-sm text-gray-500">
              No reusable forms found. Create a form in another project first.
            </p>
          ) : (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Source form
              </label>
              <select
                value={selectedId}
                onChange={(e) => {
                  setSelectedId(e.target.value);
                  const t = list.find((x: any) => x.id === e.target.value);
                  if (t && !name) setName(t.name);
                }}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">Select a form…</option>
                {list.map((t: any) => (
                  <option key={t.id} value={t.id}>
                    {t.project_name} · {t.name}
                    {t.version ? ` (v${t.version})` : ""}
                  </option>
                ))}
              </select>
            </div>
          )}

          {selected && selected.project_id !== projectId && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Name in this project{" "}
                <span className="text-gray-400 text-xs">(optional)</span>
              </label>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={selected.name}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              />
            </div>
          )}

          {applyMutation.isError && (
            <p className="text-sm text-red-600">
              {(applyMutation.error as Error).message}
            </p>
          )}
        </div>

        <div className="flex justify-end gap-2 px-6 py-4 border-t border-gray-200 shrink-0">
          <button
            onClick={onClose}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            disabled={!selectedId || applyMutation.isPending}
            onClick={() => applyMutation.mutate()}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Copy className="h-4 w-4" />
            {applyMutation.isPending ? "Applying…" : "Apply to layer"}
          </button>
        </div>
      </div>
    </div>
  );
}
