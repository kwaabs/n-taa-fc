import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "@/lib/api";
import { Eye, EyeOff, Focus, ExternalLink, Layers as LayersIcon } from "lucide-react";

interface Props {
  projectId: string;
  layers: any[];
  visibleLayers: Record<string, boolean>;
  focusedLayerId: string | null;
  onToggle: (layerId: string) => void;
  onFocus: (layerId: string | null) => void;
}

export function LayersPanel({
  projectId,
  layers,
  visibleLayers,
  focusedLayerId,
  onToggle,
  onFocus,
}: Props) {
  return (
    <div className="flex flex-col gap-1 p-3">
      <div className="flex items-center gap-2 mb-2 px-2">
        <LayersIcon className="h-4 w-4 text-gray-500" />
        <p className="text-xs font-semibold text-gray-600 uppercase tracking-wider">
          Layers ({layers.length})
        </p>
      </div>

      {layers.map((layer) => (
        <LayerRow
          key={layer.id}
          projectId={projectId}
          layer={layer}
          isVisible={!!visibleLayers[layer.id]}
          isFocused={focusedLayerId === layer.id}
          isDimmed={focusedLayerId !== null && focusedLayerId !== layer.id}
          onToggle={() => onToggle(layer.id)}
          onFocus={() => onFocus(layer.id)}
        />
      ))}

      {focusedLayerId !== null && (
        <button
          onClick={() => onFocus(null)}
          className="mt-2 text-xs text-blue-600 hover:underline self-start px-2"
        >
          Clear focus
        </button>
      )}
    </div>
  );
}

function LayerRow({
  projectId,
  layer,
  isVisible,
  isFocused,
  isDimmed,
  onToggle,
  onFocus,
}: {
  projectId: string;
  layer: any;
  isVisible: boolean;
  isFocused: boolean;
  isDimmed: boolean;
  onToggle: () => void;
  onFocus: () => void;
}) {
  // Feature count: linked tables have no rows in public.features — use
  // layer.feature_count from the API (live/source_config count).
  const isLinked = layer.source_type === "linked_table";
  const { data } = useQuery({
    queryKey: ["layerFeaturesCount", layer.id],
    queryFn: () => api.getLayerFeatures(projectId, layer.id, { limit: 1 }),
    enabled: !isLinked,
  });
  const count = isLinked
    ? layer.feature_count ??
      (() => {
        try {
          const cfg =
            typeof layer.source_config === "string"
              ? JSON.parse(layer.source_config)
              : layer.source_config;
          return typeof cfg?.feature_count === "number" ? cfg.feature_count : null;
        } catch {
          return null;
        }
      })()
    : data?.meta?.total ?? (Array.isArray(data) ? data.length : 0);

  const countLabel = isLinked
    ? count != null
      ? `${Number(count).toLocaleString()} features · linked`
      : "Linked table"
    : `${count} features`;

  // Try to read primary color from style for the little color chip
  const color = (() => {
    try {
      const style =
        typeof layer.style === "string" ? JSON.parse(layer.style) : layer.style;
      return style?.default?.color || "#3b82f6";
    } catch {
      return "#3b82f6";
    }
  })();

  return (
    <div
      className={`group flex items-center gap-2 rounded-lg border px-2 py-2 transition-all ${isFocused
          ? "border-blue-300 bg-blue-50"
          : isDimmed
            ? "border-gray-200 bg-gray-50/50 opacity-60"
            : "border-gray-200 bg-white"
        }`}
    >
      {/* Visibility toggle */}
      <button
        onClick={onToggle}
        className="text-gray-400 hover:text-blue-600 shrink-0"
        title={isVisible ? "Hide" : "Show"}
      >
        {isVisible ? (
          <Eye className="h-4 w-4" />
        ) : (
          <EyeOff className="h-4 w-4 text-gray-300" />
        )}
      </button>

      {/* Geometry-aware swatch (dot / line / dashed / polygon / SVG) */}
      <div className="w-6 flex items-center justify-center shrink-0">
        <LegendSwatch style={layer.style} geometryType={layer.geometry_type} />
      </div>

      {/* Name and count */}
      <button
        onClick={onFocus}
        className="flex-1 min-w-0 text-left"
        title={isFocused ? "Unfocus" : "Focus on this layer"}
      >
        <p
          className={`text-sm truncate ${isVisible ? "text-gray-900" : "text-gray-400"
            }`}
        >
          {layer.name}
        </p>
        <p className="text-xs text-gray-500">{countLabel}</p>
      </button>

      {/* Focus indicator */}
      {isFocused && (
        <Focus className="h-3.5 w-3.5 text-blue-600 shrink-0" />
      )}

      {/* Open in detail page */}
      <Link
        to={`/projects/${projectId}/layers/${layer.id}`}
        className="text-gray-400 hover:text-gray-700 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity"
        title="Open layer details"
      >
        <ExternalLink className="h-3.5 w-3.5" />
      </Link>
    </div>
  );
}

function LegendSwatch({ style, geometryType }: { style: any; geometryType: string }) {
  // style may be a JSON string or object
  let parsed: any = style;
  if (typeof style === "string") {
    try { parsed = JSON.parse(style); } catch { parsed = {}; }
  }
  const def = parsed?.default || parsed || {};
  const color = def.color || "#3b82f6";
  const lineStyle = def.line_style;
  const iconSvg = def.icon_svg;

  // Point with custom SVG
  if (geometryType === "point" && iconSvg) {
    return (
      <div
        className="h-4 w-4 shrink-0 flex items-center justify-center"
        dangerouslySetInnerHTML={{
          __html: String(iconSvg).replace(/<svg/i, '<svg width="16" height="16"'),
        }}
      />
    );
  }
  // Point → colored dot
  if (geometryType === "point") {
    return (
      <span
        className="inline-block w-3 h-3 rounded-full shrink-0 border border-white"
        style={{ background: color, boxShadow: "0 0 0 1px #d1d5db" }}
      />
    );
  }
  // Line → line sample (dashed if styled)
  if (geometryType === "line") {
    const dash =
      lineStyle === "dashed" ? "4,3"
        : lineStyle === "dotted" ? "1,3"
          : lineStyle === "dash_dot" ? "5,2,1,2"
            : undefined;
    return (
      <svg width="22" height="10" className="shrink-0">
        <line x1="1" y1="5" x2="21" y2="5" stroke={color} strokeWidth="2.5" strokeDasharray={dash} />
      </svg>
    );
  }
  // Polygon → filled square with border
  return (
    <span
      className="inline-block w-4 h-4 rounded-sm shrink-0 border"
      style={{ background: `${color}55`, borderColor: color }}
    />
  );
}