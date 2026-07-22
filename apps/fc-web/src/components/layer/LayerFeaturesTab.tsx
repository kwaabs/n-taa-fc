import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Link2, Map as MapIcon } from "lucide-react";
import { api } from "@/lib/api";
import { LayerFeatureTable } from "./LayerFeatureTable";
import { LayerFeatureDrawer } from "./LayerFeatureDrawer";

interface Props {
  projectId: string;
  layerId: string;
  layer?: any;
}

type Feature = "linked" | "collected";

export function LayerFeaturesTab({ projectId, layerId, layer }: Props) {
  const [selectedFeature, setSelectedFeature] = useState<any | null>(null);
  const isLinked = layer?.source_type === "linked_table";
  const [viewer, setViewer] = useState<Viewer>("collected");

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

  const showingLinked = isLinked && viewer === "linked";

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
                  }.`
                : `Field collections synced to this layer${
                    collectedCount
                      ? ` · ${collectedCount.toLocaleString()} collected`
                      : ""
                  }.`
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
                viewer === "collected"
                  ? "bg-white text-gray-900 shadow-sm"
                  : "text-gray-600 hover:text-gray-900"
              }`}
            >
              Collected
              {collectedCount > 0 ? ` (${collectedCount})` : ""}
            </button>
            <button
              type="button"
              onClick={() => setViewer("linked")}
              className={`rounded-md px-3 py-1.5 text-xs font-medium ${
                viewer === "linked"
                  ? "bg-white text-gray-900 shadow-sm"
                  : "text-gray-600 hover:text-gray-900"
              }`}
            >
              Linked source
              {linkedCount != null ? ` (${linkedCount})` : ""}
            </button>
          </div>

          <div className="rounded-lg bg-blue-50 border border-blue-200 px-3 py-2 text-xs text-blue-800 flex items-start gap-2">
            <Link2 className="h-3.5 w-3.5 shrink-0 mt-0.5" />
            <span>
              {viewer === "collected" ? (
                <>
                  New / edited features from mobile sync land here in Field
                  Collector (<code className="bg-blue-100 px-1 rounded">public.features</code>
                  ). Linked dbo rows stay under <strong>Linked source</strong>
                  {insertedCount || updatedCount
                    ? ` — currently ${insertedCount} new, ${updatedCount} updated.`
                    : "."}
                </>
              ) : (
                <>
                  Live linked table from <strong className="font-mono">{tableLabel}</strong>.
                  New field collections do not change this count — switch to{" "}
                  <strong>Collected</strong> to see synced mobile captures.
                </>
              )}
            </span>
          </div>
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
