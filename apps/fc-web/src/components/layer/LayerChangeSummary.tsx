import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "@/lib/api";
import {
  Database,
  CheckCircle2,
  Edit,
  Trash2,
  Plus,
  AlertCircle,
  Link2,
  Map as MapIcon,
} from "lucide-react";

interface Props {
  projectId: string;
  layerId: string;
  layer?: any;
}

function linkedFeatureCount(layer: any): number | null {
  if (typeof layer?.feature_count === "number") return layer.feature_count;
  try {
    const cfg =
      typeof layer?.source_config === "string"
        ? JSON.parse(layer.source_config)
        : layer?.source_config;
    return typeof cfg?.feature_count === "number" ? cfg.feature_count : null;
  } catch {
    return null;
  }
}

function linkedTableLabel(layer: any): string {
  try {
    const cfg =
      typeof layer?.source_config === "string"
        ? JSON.parse(layer.source_config)
        : layer?.source_config;
    if (cfg?.schema && cfg?.table) return `${cfg.schema}.${cfg.table}`;
  } catch {
    /* ignore */
  }
  return "source table";
}

export function LayerChangeSummary({ projectId, layerId, layer }: Props) {
  const isLinked = layer?.source_type === "linked_table";

  const { data: summary, isLoading } = useQuery({
    queryKey: ["layerSummary", layerId],
    queryFn: () => api.getLayerChangeSummary(projectId, layerId),
    enabled: !!layerId,
    refetchInterval: 15000,
  });

  if (isLinked) {
    const count = linkedFeatureCount(layer);
    const table = linkedTableLabel(layer);
    const collectedCount = summary?.collected_count || 0;
    const insertedCount = summary?.new_count || 0;
    const updatedCount = summary?.updated_count || 0;
    return (
      <div className="flex flex-col gap-4">
        <div className="rounded-lg bg-blue-50 border border-blue-200 p-4 flex items-start gap-3">
          <Link2 className="h-5 w-5 text-blue-600 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-blue-900">Linked table</p>
            <p className="text-xs text-blue-700 mt-0.5">
              Reference features are read live from{" "}
              <strong className="font-mono">{table}</strong> (not copied). Field
              collections synced from mobile are stored separately in Field
              Collector — see the <strong>Collected</strong> card and the Features
              tab.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="rounded-lg p-1.5 bg-blue-50 text-blue-700">
                <Database className="h-4 w-4 text-blue-600" />
              </div>
              <span className="text-xs font-medium text-gray-600">
                Linked source
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {count != null ? count.toLocaleString() : "—"}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">Rows in {table}</p>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="rounded-lg p-1.5 bg-green-50 text-green-700">
                <Plus className="h-4 w-4 text-green-600" />
              </div>
              <span className="text-xs font-medium text-gray-600">
                Collected
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">
              {isLoading ? "…" : collectedCount.toLocaleString()}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">
              Synced from mobile
              {!isLoading && (insertedCount > 0 || updatedCount > 0)
                ? ` · ${insertedCount} new · ${updatedCount} updated`
                : ""}
            </p>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col justify-between">
            <div>
              <p className="text-sm font-medium text-gray-900 mb-1">
                View on map
              </p>
              <p className="text-xs text-gray-500">
                Linked tiles via Martin; collected points from Field Collector.
              </p>
            </div>
            <Link
              to={`/projects/${projectId}?focus=${layerId}`}
              className="mt-3 inline-flex items-center gap-1.5 self-start rounded-lg border border-gray-300 px-3 py-1.5 text-xs text-gray-700 hover:bg-gray-50"
            >
              <MapIcon className="h-3.5 w-3.5" />
              Open project map
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return <p className="text-gray-500">Loading summary...</p>;
  }

  const total = summary?.total_features || 0;
  const refCount = summary?.reference_count || 0;
  const collectedCount = summary?.collected_count || 0;
  const updated = summary?.updated_count || 0;
  const deleted = summary?.deleted_count || 0;
  const newCount = summary?.new_count || 0;
  const unchanged = summary?.unchanged_count || 0;

  const stats = [
    {
      label: "Total Features",
      value: total,
      icon: Database,
      color: "bg-gray-50 text-gray-700",
      iconColor: "text-gray-600",
    },
    {
      label: "Reference",
      value: refCount,
      icon: Database,
      color: "bg-blue-50 text-blue-700",
      iconColor: "text-blue-600",
      sub: "Imported from sources",
    },
    {
      label: "Collected",
      value: collectedCount,
      icon: Plus,
      color: "bg-green-50 text-green-700",
      iconColor: "text-green-600",
      sub: "Added by field workers",
    },
    {
      label: "Unchanged",
      value: unchanged,
      icon: CheckCircle2,
      color: "bg-gray-50 text-gray-700",
      iconColor: "text-gray-500",
      sub: "Reference data, untouched",
    },
    {
      label: "Updated",
      value: updated,
      icon: Edit,
      color: "bg-yellow-50 text-yellow-700",
      iconColor: "text-yellow-600",
      sub: "Modified by workers",
    },
    {
      label: "Deleted",
      value: deleted,
      icon: Trash2,
      color: "bg-red-50 text-red-700",
      iconColor: "text-red-600",
      sub: "Marked as removed",
    },
    {
      label: "New",
      value: newCount,
      icon: Plus,
      color: "bg-purple-50 text-purple-700",
      iconColor: "text-purple-600",
      sub: "Newly inserted",
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      {total === 0 && (
        <div className="rounded-lg bg-blue-50 border border-blue-200 p-4 flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-blue-600 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-blue-900">No features yet</p>
            <p className="text-xs text-blue-700 mt-0.5">
              Go to <strong>Data Sources</strong> tab to import data, or wait for field workers
              to collect features in the mobile app.
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {stats.map((s) => (
          <div
            key={s.label}
            className="bg-white rounded-xl border border-gray-200 p-4"
          >
            <div className="flex items-center gap-2 mb-2">
              <div className={`rounded-lg p-1.5 ${s.color}`}>
                <s.icon className={`h-4 w-4 ${s.iconColor}`} />
              </div>
              <span className="text-xs font-medium text-gray-600 truncate">
                {s.label}
              </span>
            </div>
            <p className="text-2xl font-bold text-gray-900">{s.value}</p>
            {s.sub && (
              <p className="text-xs text-gray-400 mt-0.5">{s.sub}</p>
            )}
          </div>
        ))}
      </div>

      {refCount > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-semibold text-gray-900 mb-3">
            Reference Data Status
          </h3>
          <div className="space-y-2">
            <ProgressRow label="Unchanged" value={unchanged} total={refCount} color="bg-gray-400" />
            <ProgressRow label="Updated by workers" value={updated} total={refCount} color="bg-yellow-500" />
            <ProgressRow label="Marked deleted" value={deleted} total={refCount} color="bg-red-500" />
          </div>
          <p className="text-xs text-gray-500 mt-3">
            {refCount} reference features tracked. Changes are captured so mobile sync only
            transmits the delta.
          </p>
        </div>
      )}
    </div>
  );
}

function ProgressRow({ label, value, total, color }: { label: string; value: number; total: number; color: string }) {
  const pct = total > 0 ? (value / total) * 100 : 0;
  return (
    <div>
      <div className="flex items-center justify-between text-xs text-gray-600 mb-1">
        <span>{label}</span>
        <span>
          {value} ({pct.toFixed(0)}%)
        </span>
      </div>
      <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
        <div
          className={`h-full ${color}`}
          style={{ width: `${Math.min(pct, 100)}%` }}
        />
      </div>
    </div>
  );
}
