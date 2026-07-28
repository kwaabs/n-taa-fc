import { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { BasemapPicker } from "@/components/wizard/BasemapPicker";
import { AreaDrawer } from "@/components/assignments/AreaDrawer";
import { AoiPreviewMap } from "@/components/map/AoiPreviewMap";
import { AoiFromTableModal } from "@/components/map/AoiFromTableModal";
import { Package } from "lucide-react";
import { BundleDialog } from "@/components/bundle/BundleDialog";
import {
  Save,
  Send,
  Archive,
  Pentagon,
  Table2,
  AlertCircle,
  CheckCircle2,
} from "lucide-react";

export function ProjectSettingsTab() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId!),
    enabled: !!projectId,
  });

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [basemapId, setBasemapId] = useState("osm");
  const [basemapCustomUrl, setBasemapCustomUrl] = useState("");
  const [area, setArea] = useState<any | null>(null);
  const [aoiLayerId, setAoiLayerId] = useState<string | null>(null);
  const [showAreaDrawer, setShowAreaDrawer] = useState(false);
  const [showAoiFromTable, setShowAoiFromTable] = useState(false);
  const [bufferMeters, setBufferMeters] = useState<number>(20);
  const [saved, setSaved] = useState(false);
  const [showBundleDialog, setShowBundleDialog] = useState(false);

  useEffect(() => {
    if (!project) return;
    setName(project.name || "");
    setDescription(project.description || "");
    setBasemapId(project.config?.basemap_id || "osm");
    setBasemapCustomUrl(project.config?.basemap_custom_url || "");
    setBufferMeters(project.config?.aoi_buffer_meters ?? 20);
    setAoiLayerId(project.config?.aoi_layer_id || null);
    if (project.area_of_interest) {
      try {
        const geom =
          typeof project.area_of_interest === "string"
            ? JSON.parse(project.area_of_interest)
            : project.area_of_interest;
        setArea(geom);
      } catch {
        setArea(null);
      }
    } else {
      setArea(null);
    }
  }, [project]);

  const saveMutation = useMutation({
    mutationFn: () => {
      // Preserve unrelated config keys (e.g. aoi_source_refs) while updating known fields.
      const config: any = { ...(project?.config || {}), basemap_id: basemapId };
      if (basemapId === "custom") {
        config.basemap_custom_url = basemapCustomUrl;
      } else {
        delete config.basemap_custom_url;
      }
      if (bufferMeters !== 20) {
        config.aoi_buffer_meters = bufferMeters;
      } else {
        delete config.aoi_buffer_meters;
      }
      if (aoiLayerId) {
        config.aoi_layer_id = aoiLayerId;
      } else {
        delete config.aoi_layer_id;
        delete config.aoi_source_refs;
      }
      return api.updateProject(projectId!, {
        name,
        description,
        config,
        area_of_interest: area,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["project", projectId] });
      queryClient.invalidateQueries({ queryKey: ["projects"] });
      queryClient.invalidateQueries({ queryKey: ["projectLayers", projectId] });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    },
  });

  const dispatchMutation = useMutation({
    mutationFn: () => api.dispatchProject(projectId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["project", projectId] });
      queryClient.invalidateQueries({ queryKey: ["projects"] });
    },
  });

  const archiveMutation = useMutation({
    mutationFn: () => api.archiveProject(projectId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["project", projectId] });
      queryClient.invalidateQueries({ queryKey: ["projects"] });
    },
  });

  if (!project) {
    return <p className="text-gray-500 p-4">Loading...</p>;
  }

  const isArchived = project.status === "archived";
  const isActive = project.status === "active";
  const isEditable = !isArchived && !isActive;

  return (
    <div className="h-full overflow-y-auto">
      <div className="max-w-3xl flex flex-col gap-5 pb-8">
        <StatusBanner
          status={project.status}
          onDispatch={() => dispatchMutation.mutate()}
          dispatching={dispatchMutation.isPending}
          dispatchError={dispatchMutation.error as Error | null}
        />
        {isActive && (
          <div className="rounded-lg bg-blue-50 border border-blue-200 p-3 text-sm text-blue-900">
            This project is dispatched. Edits are locked — archive the project first to make changes.
          </div>
        )}

        <section className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-base font-semibold text-gray-900 mb-4">
            Project Details
          </h2>
          <div className="flex flex-col gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Name
              </label>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={!isEditable}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:bg-gray-50 disabled:text-gray-500"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Description
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
                disabled={!isEditable}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:bg-gray-50"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <InfoRow
                label="Mode"
                value={project.mode === "map_based" ? "Map-based" : "Form Collection"}
              />
              <InfoRow label="Version" value={"v" + project.version} />
            </div>
          </div>
        </section>

        {project.mode === "map_based" && (
          <>

            <section className="bg-white rounded-xl border border-gray-200 p-5">
              <h2 className="text-base font-semibold text-gray-900 mb-1">Basemap</h2>
              <p className="text-sm text-gray-500 mb-4">
                Used everywhere a map renders in this project.
              </p>
              <BasemapPicker
                selectedId={basemapId}
                customUrl={basemapCustomUrl}
                onChange={(id, custom) => {
                  if (id === "custom" && custom !== undefined) {
                    setBasemapId("custom");
                    setBasemapCustomUrl(custom);
                  } else {
                    setBasemapId(id);
                  }
                }}
              />
            </section>


            <section className="bg-white rounded-xl border border-gray-200 p-5">
              <h2 className="text-base font-semibold text-gray-900 mb-1">Project Area</h2>
              <p className="text-sm text-gray-500 mb-3">
                Defines the default map extent and default assignment boundary. Optional —
                recommended for offline bundles so reference data can be clipped.
                Draw a polygon, or select one or more polygons from a linked table
                (e.g. districts).
              </p>

              {area ? (
                <div className="mb-3 overflow-hidden rounded-lg border border-gray-200">
                  <AoiPreviewMap geometry={area} className="h-52 w-full" />
                </div>
              ) : (
                <div className="mb-3 rounded-lg border border-dashed border-gray-200 bg-gray-50 px-4 py-6 text-center text-sm text-gray-500">
                  No project area defined yet. Draw one or select districts from a
                  polygon layer.
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <button
                  onClick={() => setShowAreaDrawer(true)}
                  disabled={!isEditable}
                  className={`flex items-center justify-center gap-2 rounded-lg border-2 border-dashed px-4 py-3 text-sm transition-colors ${area
                    ? "border-green-300 bg-green-50 text-green-700"
                    : "border-gray-300 text-gray-600 hover:border-blue-300 hover:bg-blue-50"
                    } disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  <Pentagon className="h-4 w-4" />
                  {area
                    ? isEditable
                      ? "Draw / edit area"
                      : "View drawn area"
                    : "Draw project area"}
                </button>
                <button
                  onClick={() => setShowAoiFromTable(true)}
                  disabled={!isEditable}
                  className="flex items-center justify-center gap-2 rounded-lg border-2 border-dashed border-gray-300 px-4 py-3 text-sm text-gray-600 hover:border-blue-300 hover:bg-blue-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Table2 className="h-4 w-4" />
                  Select from table
                </button>
              </div>
              {!isEditable && (
                <p className="text-xs text-gray-500 mt-2">
                  Project is active — archive it first to draw or change the area.
                </p>
              )}
              {area && isEditable && (
                <button
                  onClick={() => {
                    setArea(null);
                    setAoiLayerId(null);
                  }}
                  className="text-xs text-red-500 hover:underline mt-2"
                >
                  Remove area
                </button>
              )}

              {aoiLayerId && (
                <p className="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2 mt-3">
                  This area was built from a polygon layer. That layer is locked
                  for field users — insert, update, and delete are disabled.
                </p>
              )}

              {area && (
                <div className="mt-4">
                  <label className="text-sm font-medium text-gray-700 block mb-1">
                    Capture buffer (meters)
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={5000}
                    value={bufferMeters}
                    disabled={!isEditable}
                    onChange={(e) => setBufferMeters(Number(e.target.value))}
                    className="w-32 rounded border border-gray-300 px-3 py-2 text-sm disabled:bg-gray-50 disabled:text-gray-500"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    Features captured within this many meters outside the AOI are still accepted.
                    Default: 20m.
                  </p>
                </div>
              )}
            </section>

          </>
        )}

        {/* Download Bundle */}
        <section className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-base font-semibold text-gray-900 mb-1 flex items-center gap-2">
            <Package className="h-4 w-4 text-blue-600" />
            Project Bundle
          </h2>
          <p className="text-sm text-gray-500 mb-3">
            Download a self-contained bundle of this project for mobile clients and
            offline use.
          </p>
          <button
            onClick={() => setShowBundleDialog(true)}
            className="flex items-center gap-2 rounded-lg bg-blue-600 text-white text-sm font-medium px-4 py-2 hover:bg-blue-700"
          >
            <Package className="h-4 w-4" />
            Download Bundle...
          </button>
        </section>





        {isEditable && (
          <section className="flex items-center justify-between bg-gray-50 rounded-xl border border-gray-200 p-4 sticky bottom-0">
            <p className="text-xs">
              {saveMutation.isError && (
                <span className="text-red-600">
                  {(saveMutation.error as Error).message}
                </span>
              )}
              {saved && (
                <span className="text-green-600 flex items-center gap-1">
                  <CheckCircle2 className="h-3.5 w-3.5" /> Saved
                </span>
              )}
            </p>
            <button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending}
              className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
            >
              <Save className="h-4 w-4" />
              {saveMutation.isPending ? "Saving..." : "Save Changes"}
            </button>
          </section>
        )}

        {!isArchived && (
          <section className="bg-white rounded-xl border border-red-200 p-5">
            <h2 className="text-base font-semibold text-gray-900 mb-1">Archive</h2>
            <p className="text-sm text-gray-500 mb-3">
              Archived projects are hidden from active lists and mobile sync. You can no
              longer dispatch or edit. This cannot be undone via the UI.
            </p>
            <button
              onClick={() => {
                if (confirm("Archive this project? It will be hidden from active lists."))
                  archiveMutation.mutate();
              }}
              disabled={archiveMutation.isPending}
              className="flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-700 hover:bg-red-100 disabled:opacity-50"
            >
              <Archive className="h-4 w-4" />
              {archiveMutation.isPending ? "Archiving..." : "Archive Project"}
            </button>
          </section>
        )}
      </div>

      {showAreaDrawer && (
        <AreaDrawer
          initialPolygon={area}
          onSave={(geom) => {
            setArea(geom);
            // Drawn AOI is not tied to a layer — clear AOI-layer lock marker.
            setAoiLayerId(null);
            setShowAreaDrawer(false);
          }}
          onClose={() => setShowAreaDrawer(false)}
        />
      )}

      {showAoiFromTable && (
        <AoiFromTableModal
          projectId={projectId!}
          onApply={(geom, layerId) => {
            setArea(geom);
            setAoiLayerId(layerId);
            setShowAoiFromTable(false);
            queryClient.invalidateQueries({ queryKey: ["project", projectId] });
            queryClient.invalidateQueries({
              queryKey: ["projectLayers", projectId],
            });
          }}
          onClose={() => setShowAoiFromTable(false)}
        />
      )}

      {showBundleDialog && (
        <BundleDialog
          projectId={projectId!}
          projectName={project?.name}
          onClose={() => setShowBundleDialog(false)}
        />
      )}
    </div>
  );
}

function StatusBanner({
  status,
  onDispatch,
  dispatching,
  dispatchError,
}: {
  status: string;
  onDispatch: () => void;
  dispatching: boolean;
  dispatchError: Error | null;
}) {
  if (status === "active") {
    return (
      <div className="rounded-xl border border-green-200 bg-green-50 p-4 flex items-start gap-3">
        <CheckCircle2 className="h-5 w-5 text-green-700 shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-medium text-green-900">Project Active</p>
          <p className="text-xs text-green-700 mt-0.5">
            Field workers can see and sync this project. Published layers are visible
            on mobile.
          </p>
        </div>
      </div>
    );
  }

  if (status === "archived") {
    return (
      <div className="rounded-xl border border-gray-200 bg-gray-50 p-4 flex items-start gap-3">
        <Archive className="h-5 w-5 text-gray-500 shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-medium text-gray-700">Project Archived</p>
          <p className="text-xs text-gray-500 mt-0.5">
            Hidden from active project lists. Cannot be dispatched or edited.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-yellow-200 bg-yellow-50 p-4 flex items-start gap-3">
      <AlertCircle className="h-5 w-5 text-yellow-700 shrink-0 mt-0.5" />
      <div className="flex-1">
        <p className="text-sm font-medium text-yellow-900">Project in Draft</p>
        <p className="text-xs text-yellow-700 mt-0.5">
          Dispatch this project to make it visible to field workers. You can still
          edit forms and layers after dispatching.
        </p>
        {dispatchError && (
          <p className="text-xs text-red-600 mt-2">{dispatchError.message}</p>
        )}
      </div>
      <button
        onClick={onDispatch}
        disabled={dispatching}
        className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 shrink-0"
      >
        <Send className="h-3.5 w-3.5" />
        {dispatching ? "Dispatching..." : "Dispatch Project"}
      </button>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-gray-500">{label}</p>
      <p className="text-sm text-gray-900">{value}</p>
    </div>
  );
}