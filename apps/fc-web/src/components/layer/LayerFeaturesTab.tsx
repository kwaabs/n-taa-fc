import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Link2, Map as MapIcon, ArrowRight } from "lucide-react";
import { api } from "@/lib/api";
import { LayerFeatureTable } from "./LayerFeatureTable";
import { LayerFeatureDrawer } from "./LayerFeatureDrawer";

interface Props {
  projectId: string;
  layerId: string;
  layer?: any;
}

type Viewer = "linked" | "collected";

export function LayerFeaturesTab({ projectId, layerId, layer }: Props) {
  const [selectedFeature, setSelectedFeature] = useState<any | null>(null);
  const isLinked = layer?.source_type === "linked_table";
  const [viewer, setViewer] = useState<Viewer | null>(null);

  let tableLabel = "source table";
  let linkedCount: number | null =
    typeof layer?.feature_count === "number" ? layer.feature_count : null;
  let searchColumns: string[] = [];
  try {
    const cfg =
      typeof layer?.source_config === "string"
        ? JSON.parse(layer.source_config)
        : layer?.source_config;
    if (cfg?.schema && cfg?.table) tableLabel = `${cfg.schema}.${cfg.table}`;
    if (linkedCount == null && typeof cfg?.feature_count === "number") {
      linkedCount = cfg.feature_count;
    }
    if (Array.isArray(cfg?.included_columns)) {
      searchColumns = cfg.included_columns.filter(
        (c: unknown) => typeof c === "string" && c !== cfg.geometry_column
      );
    }
  } catch {
    /* ignore */
  }

  // Field-collected rows live in public.features even for linked layers.
  const { data: collectedSummary } = useQuery({
    queryKey: ["layerSummary", layerId, "collected"],
    queryFn: () => api.getLayerChangeSummary(projectId, layerId),
    enabled: !!layerId && isLinked,
    refetchInterval: 15000,
  });
  const collectedCount = collectedSummary?.collected_count ?? 0;
  const insertedCount = collectedSummary?.new_count ?? 0;
  const updatedCount = collectedSummary?.updated_count ?? 0;
  const deletedCount = collectedSummary?.deleted_count ?? 0;
  const pendingWriteBack =
    insertedCount + updatedCount + deletedCount;

  // Smart default: Field changes when anything pending/collected; else Live source.
  useEffect(() => {
    if (!isLinked || viewer != null) return;
    setViewer(pendingWriteBack > 0 || collectedCount > 0 ? "collected" : "linked");
  }, [isLinked, viewer, pendingWriteBack, collectedCount]);

  const activeViewer: Viewer = viewer ?? "collected";
  const showingLinked = isLinked && activeViewer === "linked";

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Features</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            {isLinked
              ? showingLinked
                ? `Live rows from ${tableLabel}${
                    linkedCount != null
                      ? ` · ${linkedCount.toLocaleString()} total`
                      : ""
                  }. Read-only here — edits sync into Field changes.`
                : `Field changes synced from mobile into Field Collector${
                    collectedCount
                      ? ` · ${collectedCount.toLocaleString()} rows`
                      : ""
                  }. Reconcile writes these to the live source.`
              : "All features collected or imported into this layer."}
          </p>
        </div>
        {isLinked && (
          <Link
            to={`/projects/${projectId}?focus=${layerId}`}
            className="inline-flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-xs text-gray-700 hover:bg-gray-50 shrink-0"
          >
            <MapIcon className="h-3.5 w-3.5" />
            View on map
          </Link>
        )}
      </div>

      {isLinked && (
        <>
          <div className="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-0.5 self-start">
            <button
              type="button"
              onClick={() => setViewer("collected")}
              className={`rounded-md px-3 py-1.5 text-xs font-medium ${
                activeViewer === "collected"
                  ? "bg-white text-gray-900 shadow-sm"
                  : "text-gray-600 hover:text-gray-900"
              }`}
            >
              Field changes (FC)
              {collectedCount > 0 ? ` (${collectedCount})` : ""}
            </button>
            <button
              type="button"
              onClick={() => setViewer("linked")}
              className={`rounded-md px-3 py-1.5 text-xs font-medium ${
                activeViewer === "linked"
                  ? "bg-white text-gray-900 shadow-sm"
                  : "text-gray-600 hover:text-gray-900"
              }`}
            >
              Live source
              {linkedCount != null ? ` (${linkedCount})` : ""}
            </button>
          </div>

          <div className="rounded-lg bg-blue-50 border border-blue-200 px-3 py-2 text-xs text-blue-800 flex items-start gap-2">
            <Link2 className="h-3.5 w-3.5 shrink-0 mt-0.5" />
            <span>
              {activeViewer === "collected" ? (
                <>
                  These are <strong>pending overlays</strong> in{" "}
                  <code className="bg-blue-100 px-1 rounded">public.features</code>
                  — not the live dbo table. Use{" "}
                  <strong>Data Sources → Reconcile</strong> to push inserts/updates/deletes
                  to <strong className="font-mono">{tableLabel}</strong>
                  {pendingWriteBack
                    ? ` (${insertedCount} new · ${updatedCount} updated · ${deletedCount} deleted).`
                    : "."}
                </>
              ) : (
                <>
                  Live linked table <strong className="font-mono">{tableLabel}</strong>.
                  Field workers’ edits do not change these counts until reconcile —
                  switch to <strong>Field changes (FC)</strong> for synced mobile captures.
                </>
              )}
            </span>
          </div>

          {pendingWriteBack > 0 && (
            <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 flex items-center justify-between gap-3 flex-wrap">
              <p className="text-xs text-amber-950">
                <strong>{pendingWriteBack}</strong> change
                {pendingWriteBack === 1 ? "" : "s"} waiting to write back to the source table.
              </p>
              <Link
                to={`/projects/${projectId}/layers/${layerId}?tab=sources`}
                className="inline-flex items-center gap-1 text-xs font-medium text-amber-900 underline hover:no-underline"
              >
                Open Data Sources to Reconcile
                <ArrowRight className="h-3.5 w-3.5" />
              </Link>
            </div>
          )}
        </>
      )}

      <LayerFeatureTable
        projectId={projectId}
        layerId={layerId}
        linked={showingLinked}
        columns={showingLinked ? searchColumns : []}
        onSelectFeature={setSelectedFeature}
      />

      {selectedFeature && (
        <LayerFeatureDrawer
          feature={selectedFeature}
          layerId={layerId}
          onClose={() => setSelectedFeature(null)}
        />
      )}
    </div>
  );
}
