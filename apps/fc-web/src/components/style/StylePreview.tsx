import type { LayerStyle } from "@/lib/style-engine";
import { computeFeatureStyle } from "@/lib/style-engine";

interface Props {
  style: LayerStyle;
}

export function StylePreview({ style }: Props) {
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
          const iconSvg = computed.icon_svg;
          return (
            <div key={i} className="flex items-center gap-3 rounded-lg bg-gray-50 px-3 py-2">
              {iconSvg ? (
                <div
                  className="flex items-center justify-center bg-white rounded border border-gray-200"
                  style={{
                    width: size + 12,
                    height: size + 12,
                    padding: 2,
                    opacity: computed.opacity ?? 1,
                    flexShrink: 0,
                  }}
                  dangerouslySetInnerHTML={{ __html: iconSvg }}
                />
              ) : (
                <div
                  style={{
                    width: size + 6,
                    height: size + 6,
                    background: color,
                    border: `${strokeW}px solid ${stroke}`,
                    borderRadius: "50%",
                    boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
                    opacity: computed.opacity ?? 1,
                    flexShrink: 0,
                  }}
                />
              )}
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