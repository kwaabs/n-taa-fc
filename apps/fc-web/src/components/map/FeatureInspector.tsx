import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { X, Check, XCircle, ExternalLink, MapPin } from "lucide-react";
import { Link } from "react-router-dom";
import { AttachmentList } from "@/components/attachments/AttachmentList";

interface Props {
  projectId: string;
  feature: any;
  onClose: () => void;
}

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

function normalizeAttributes(raw: unknown): Record<string, unknown> {
  if (!raw) return {};
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw);
      return parsed && typeof parsed === "object" && !Array.isArray(parsed)
        ? parsed
        : {};
    } catch {
      return {};
    }
  }
  if (typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}

export function FeatureInspector({ projectId, feature, onClose }: Props) {
  const queryClient = useQueryClient();

  const reviewMutation = useMutation({
    mutationFn: (status: string) =>
      api.updateFeatureStatus(projectId, feature.id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["layerFeaturesAll"] });
      queryClient.invalidateQueries({ queryKey: ["layerFeatures"] });
    },
  });

  const attrs = normalizeAttributes(feature.attributes);
  const isLinked = feature._linked || feature.source === "linked";
  const attrLimit = isLinked ? 20 : 6;
  const allKeys = Object.keys(attrs);
  const attrKeys = allKeys.slice(0, attrLimit);

  let coords = "";
  try {
    const geom =
      typeof feature.geometry === "string"
        ? JSON.parse(feature.geometry)
        : feature.geometry;
    if (geom?.type === "Point") {
      coords = `${geom.coordinates[1].toFixed(5)}, ${geom.coordinates[0].toFixed(5)}`;
    }
  } catch {}

  const title =
    (attrs.name as string) ||
    (attrs.title as string) ||
    (attrs.transformer_name as string) ||
    (attrs.TRANSFORMER_NAME as string) ||
    feature.source_ref ||
    (typeof feature.client_id === "string"
      ? feature.client_id.slice(0, 8)
      : undefined) ||
    "Feature";

  return (
    <div className="flex flex-col gap-3">
      {/* Header */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-start gap-2 min-w-0">
          <MapPin className="h-4 w-4 text-blue-600 shrink-0 mt-0.5" />
          <div className="min-w-0">
            <p className="text-xs text-gray-500">{feature._layerName}</p>
            <p className="text-sm font-medium text-gray-900 truncate">{title}</p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="text-gray-400 hover:text-gray-600 shrink-0"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {/* Status + source */}
      <div className="flex items-center gap-1.5 flex-wrap">
        {feature.status && (
          <span
            className={`rounded-full px-2 py-0.5 text-xs ${
              feature.status === "approved"
                ? "bg-green-50 text-green-700"
                : feature.status === "rejected"
                ? "bg-red-50 text-red-700"
                : feature.status === "submitted"
                ? "bg-blue-50 text-blue-700"
                : "bg-gray-100 text-gray-600"
            }`}
          >
            {feature.status}
          </span>
        )}
        {feature.source && (
          <span
            className={`rounded-full px-2 py-0.5 text-xs ${
              feature.source === "reference" || feature.source === "linked"
                ? "bg-blue-50 text-blue-700"
                : "bg-green-50 text-green-700"
            }`}
          >
            {feature.source}
          </span>
        )}
      </div>

      {/* Coords */}
      {coords && (
        <p className="text-xs text-gray-500 font-mono">📍 {coords}</p>
      )}

      {/* Attributes */}
      <div className="flex flex-col gap-1 max-h-64 overflow-y-auto">
        {attrKeys.length === 0 ? (
          <p className="text-xs text-gray-400 italic">
            {feature._loading ? "Loading attributes…" : "No attributes"}
          </p>
        ) : (
          attrKeys.map((k) => (
            <div key={k} className="flex items-start gap-2 text-xs">
              <p className="text-gray-500 min-w-[80px] shrink-0">
                {humanize(k)}
              </p>
              <p
                className="text-gray-900 truncate"
                title={String(attrs[k] ?? "")}
              >
                {attrs[k] == null
                  ? "—"
                  : typeof attrs[k] === "object"
                  ? JSON.stringify(attrs[k])
                  : String(attrs[k])}
              </p>
            </div>
          ))
        )}
        {allKeys.length > attrLimit && (
          <p className="text-xs text-gray-400 italic mt-1">
            … and {allKeys.length - attrLimit} more
          </p>
        )}
      </div>

      {/* Attachments — only for FC-backed features */}
      {!isLinked && (
        <AttachmentList projectId={projectId} feature={feature} compact />
      )}

      {/* Actions */}
      <div className="flex flex-col gap-2 pt-2 border-t border-gray-100">
        {!isLinked && feature.status === "submitted" && (
          <div className="flex gap-2">
            <button
              onClick={() => reviewMutation.mutate("approved")}
              disabled={reviewMutation.isPending}
              className="flex-1 flex items-center justify-center gap-1 rounded bg-green-50 px-2 py-1.5 text-xs text-green-700 hover:bg-green-100 disabled:opacity-50"
            >
              <Check className="h-3 w-3" /> Approve
            </button>
            <button
              onClick={() => reviewMutation.mutate("rejected")}
              disabled={reviewMutation.isPending}
              className="flex-1 flex items-center justify-center gap-1 rounded bg-red-50 px-2 py-1.5 text-xs text-red-700 hover:bg-red-100 disabled:opacity-50"
            >
              <XCircle className="h-3 w-3" /> Reject
            </button>
          </div>
        )}

        <Link
          to={`/projects/${projectId}/layers/${feature._layerId}`}
          className="flex items-center justify-center gap-1.5 rounded border border-gray-300 px-2 py-1.5 text-xs text-gray-700 hover:bg-gray-50"
        >
          <ExternalLink className="h-3 w-3" />
          Open layer detail
        </Link>
      </div>
    </div>
  );
}