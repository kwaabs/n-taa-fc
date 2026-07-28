import type { LayerStyle } from "@/lib/style-engine";
import { computeFeatureStyle } from "@/lib/style-engine";

interface Props {
  style: LayerStyle;
  geometryType?: string;
}

function dashArray(lineStyle?: string): string | undefined {
  switch (lineStyle) {
    case "dashed":
      return "6 4";
    case "dotted":
      return "2 3";
    case "dash_dot":
      return "8 3 2 3";
    default:
      return undefined;
  }
}

function Swatch({
  geometryType,
  color,
  size,
  stroke,
  strokeW,
  opacity,
  lineStyle,
  iconSvg,
}: {
  geometryType?: string;
  color: string;
  size: number;
  stroke: string;
  strokeW: number;
  opacity: number;
  lineStyle?: string;
  iconSvg?: string;
}) {
  if (iconSvg && geometryType === "point") {
    return (
      <div
        className="flex items-center justify-center bg-white rounded border border-gray-200"
        style={{
          width: size + 12,
          height: size + 12,
          padding: 2,
          opacity,
          flexShrink: 0,
        }}
        dangerouslySetInnerHTML={{ __html: iconSvg }}
      />
    );
  }

  if (geometryType === "line") {
    const w = Math.max(size, 1.5);
    return (
      <svg width={48} height={16} style={{ flexShrink: 0, opacity }} aria-hidden>
        <line
          x1={2}
          y1={8}
          x2={46}
          y2={8}
          stroke={color}
          strokeWidth={w}
          strokeDasharray={dashArray(lineStyle)}
          strokeLinecap="round"
        />
      </svg>
    );
  }

  if (geometryType === "polygon") {
    return (
      <svg width={28} height={22} style={{ flexShrink: 0, opacity }} aria-hidden>
        <rect
          x={2}
          y={2}
          width={24}
          height={18}
          rx={2}
          fill={color}
          fillOpacity={0.35}
          stroke={stroke || color}
          strokeWidth={Math.max(strokeW, 1)}
        />
      </svg>
    );
  }

  // point (default)
  return (
    <div
      style={{
        width: size + 6,
        height: size + 6,
        background: color,
        border: `${strokeW}px solid ${stroke}`,
        borderRadius: "50%",
        boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
        opacity,
        flexShrink: 0,
      }}
    />
  );
}

export function StylePreview({ style, geometryType }: Props) {
  // Sample features: default, plus one that matches each rule
  const samples = [{ label: "Default", attrs: {} as any }];

  for (const rule of style.rules || []) {
    if (rule.when.field) {
      const a: any = {};
      if (rule.when.op === "eq") a[rule.when.field] = rule.when.value;
      else if (rule.when.op === "gt") a[rule.when.field] = Number(rule.when.value) + 1;
      else if (rule.when.op === "lt") a[rule.when.field] = Number(rule.when.value) - 1;
      else if (rule.when.op === "contains") a[rule.when.field] = String(rule.when.value);
      samples.push({
        label: rule.name || rule.id,
        attrs: a,
      });
    }
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4">
      <h3 className="text-sm font-semibold text-gray-900 mb-3">Preview</h3>
      <p className="text-xs text-gray-500 mb-4">
        How a feature looks with each rule applied:
      </p>

      <div className="flex flex-col gap-3">
        {samples.map((s, i) => {
          const computed = computeFeatureStyle(style, s.attrs);
          const size = computed.size || 14;
          const color = computed.color || "#3b82f6";
          const stroke = computed.stroke_color || "#ffffff";
          const strokeW = computed.stroke_width || 2;
          return (
            <div key={i} className="flex items-center gap-3 rounded-lg bg-gray-50 px-3 py-2">
              <Swatch
                geometryType={geometryType}
                color={color}
                size={size}
                stroke={stroke}
                strokeW={strokeW}
                opacity={computed.opacity ?? 1}
                lineStyle={computed.line_style}
                iconSvg={computed.icon_svg}
              />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-medium text-gray-700 truncate">{s.label}</p>
                {Object.keys(s.attrs).length > 0 && (
                  <p className="text-xs text-gray-400 font-mono truncate">
                    {Object.entries(s.attrs).map(([k, v]) => `${k}=${v}`).join(", ")}
                  </p>
                )}
              </div>
            </div>
          );
        })}
      </div>


      {/* Label preview */}
      {style.label?.field && (
        <div className="mt-4 pt-3 border-t border-gray-100">
          <p className="text-xs font-medium text-gray-600 mb-1">Label preview</p>
          <p
            style={{
              fontSize: style.label.size || 12,
              color: style.label.color || "#1f2937",
              textShadow: `0 0 ${style.label.halo_width || 1.5}px ${style.label.halo_color || "#ffffff"}`,
            }}
          >
            (value from <code className="bg-gray-100 px-1 rounded">{style.label.field}</code>)
          </p>
          <p className="text-xs text-gray-400 mt-1">
            Shown at zoom ≥ {style.label.min_zoom ?? 14}
          </p>
        </div>
      )}
    </div>
  );
}
