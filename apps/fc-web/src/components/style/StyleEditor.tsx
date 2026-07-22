import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Palette, ListChecks, Type, Save, RotateCcw } from "lucide-react";
import { validateAndSanitizeSvg } from "@/lib/svg-validation";
import { api } from "@/lib/api";

interface Props {
  projectId: string;
  layerId: string;
}

function generateRuleId() {
  return "rule_" + Math.random().toString(36).slice(2, 9);
}

export function StyleEditor({ projectId, layerId }: Props) {
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<"default" | "rules" | "label">("default");
  const [style, setStyle] = useState<LayerStyle | null>(null);
  const [showIconPicker, setShowIconPicker] = useState<{ target: "default" | string } | null>(null);
  const [saved, setSaved] = useState(false);

  const { data: serverStyle, isLoading } = useQuery({
    queryKey: ["layerStyle", layerId],
    queryFn: () => api.getLayerStyle(projectId, layerId),
  });

  const { data: layer } = useQuery({
    queryKey: ["layer", layerId],
    queryFn: () => api.getLayer(projectId, layerId),
  });
  const geometryType: string = layer?.geometry_type ?? layer?.data?.geometry_type ?? "";

  useEffect(() => {
    if (serverStyle) setStyle(serverStyle);
  }, [serverStyle]);

  const saveMutation = useMutation({
    mutationFn: () => api.updateLayerStyle(projectId, layerId, style),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["layerStyle", layerId] });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    },
  });

  if (isLoading || !style) {
    return <p className="text-gray-500 p-4">Loading style…</p>;
  }

  // ── Default-style mutators ───────────────────────────
  const updateDefault = (key: string, value: any) => {
    setStyle({
      ...style,
      default: { ...style.default, [key]: value },
    });
  };

  // ── Rules mutators ───────────────────────────────────
  const addRule = () => {
    const newRule: StyleRule = {
      id: generateRuleId(),
      name: "New rule",
      when: { field: "", op: "eq", value: "" },
      style: { color: "#ef4444" },
    };
    setStyle({
      ...style,
      rules: [...(style.rules || []), newRule],
    });
  };

  const updateRule = (idx: number, updated: StyleRule) => {
    const next = [...(style.rules || [])];
    next[idx] = updated;
    setStyle({ ...style, rules: next });
  };

  const removeRule = (idx: number) => {
    setStyle({
      ...style,
      rules: (style.rules || []).filter((_, i) => i !== idx),
    });
  };

  const moveRule = (idx: number, dir: -1 | 1) => {
    const next = [...(style.rules || [])];
    const target = idx + dir;
    if (target < 0 || target >= next.length) return;
    [next[idx], next[target]] = [next[target], next[idx]];
    setStyle({ ...style, rules: next });
  };

  // ── Label mutators ───────────────────────────────────
  const updateLabel = (key: string, value: any) => {
    if (!value && key === "field") {
      const { label, ...rest } = style;
      setStyle(rest as LayerStyle);
      return;
    }
    setStyle({
      ...style,
      label: { ...(style.label || { field: "" }), [key]: value },
    });
  };

  // ── Visibility mutators ──────────────────────────────
  const updateVisibility = (key: string, value: any) => {
    setStyle({
      ...style,
      visibility: { ...(style.visibility || {}), [key]: value },
    });
  };

  const handleIconSelected = (iconRef: string) => {
    if (!showIconPicker) return;
    if (showIconPicker.target === "default") {
      updateDefault("icon", iconRef);
    } else {
      const idx = parseInt(showIconPicker.target);
      const rule = style.rules![idx];
      updateRule(idx, { ...rule, style: { ...rule.style, icon: iconRef } });
    }
    setShowIconPicker(null);
  };

  const tabBtn = (id: typeof tab, label: string, Icon: any) => (
    <button
      onClick={() => setTab(id)}
      className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${tab === id
        ? "border-blue-600 text-blue-600"
        : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
        }`}
    >
      <Icon className="h-4 w-4" />
      {label}
    </button>
  );

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6">
      <div className="bg-white rounded-xl border border-gray-200 flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-200">
          <h3 className="font-semibold text-gray-900">Style Editor</h3>
          <div className="flex items-center gap-2">
            {saved && <span className="text-xs text-green-600">Saved!</span>}
            <button
              onClick={() => serverStyle && setStyle(serverStyle)}
              className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50"
            >
              <RotateCcw className="h-3.5 w-3.5" /> Reset
            </button>
            <button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending}
              className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
            >
              <Save className="h-3.5 w-3.5" />
              {saveMutation.isPending ? "Saving…" : "Save Style"}
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 border-b border-gray-200 px-5">
          {tabBtn("default", "Default", Palette)}
          {tabBtn("rules", `Rules (${style.rules?.length || 0})`, ListChecks)}
          {tabBtn("label", "Label & Visibility", Type)}
        </div>

        {/* Tab bodies */}
        <div className="p-5 flex flex-col gap-4">
          {tab === "default" && (
            <DefaultStyleForm
              style={style.default}
              geometryType={geometryType}
              onChange={updateDefault}
              onPickIcon={() => setShowIconPicker({ target: "default" })}
            />
          )}

          {tab === "rules" && (
            <RulesList
              rules={style.rules || []}
              defaultStyle={style.default}
              onAdd={addRule}
              onUpdate={updateRule}
              onRemove={removeRule}
              onMove={moveRule}
              onPickIcon={(idx) => setShowIconPicker({ target: String(idx) })}
            />
          )}

          {tab === "label" && (
            <LabelVisibilityForm
              label={style.label}
              visibility={style.visibility}
              onLabelChange={updateLabel}
              onVisibilityChange={updateVisibility}
            />
          )}
        </div>

        {saveMutation.isError && (
          <p className="text-sm text-red-600 px-5 pb-3">
            {(saveMutation.error as Error).message}
          </p>
        )}
      </div>

      {/* Preview pane */}
      <div className="lg:sticky lg:top-4 lg:self-start">
        <StylePreview style={style} />
      </div>

      {showIconPicker && (
        <IconPicker
          projectId={projectId}
          currentIcon={
            showIconPicker.target === "default"
              ? style.default.icon
              : style.rules?.[parseInt(showIconPicker.target)]?.style?.icon
          }
          onSelect={handleIconSelected}
          onClose={() => setShowIconPicker(null)}
        />
      )}
    </div>
  );
}

// ── Default style form ─────────────────────────────────

function DefaultStyleForm({
  style,
  geometryType,
  onChange,
  onPickIcon,
}: {
  style: any;
  geometryType: string;
  onChange: (key: string, value: any) => void;
  onPickIcon: () => void;
}) {
  const isPoint = geometryType === "point";
  const isLineOrPoly = geometryType === "line" || geometryType === "polygon";
  const [svgError, setSvgError] = useState<string | null>(null);

  const handleSvgInput = (raw: string) => {
    const result = validateAndSanitizeSvg(raw);
    if (!result.valid) {
      setSvgError(result.error || "Invalid SVG");
      onChange("icon_svg", raw); // keep raw so the user can fix it
    } else {
      setSvgError(null);
      onChange("icon_svg", result.sanitized || "");
    }
  };

  return (
    <div className="grid grid-cols-2 gap-4">
            {isPoint && (
        <div className="col-span-2">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-gray-600">
              Custom SVG (optional — overrides icon)
            </label>
            <label className="cursor-pointer text-xs text-blue-600 hover:underline">
              Upload .svg
              <input
                type="file"
                accept=".svg,image/svg+xml"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (!file) return;
                  const reader = new FileReader();
                  reader.onload = () => {
                    handleSvgInput(String(reader.result || ""));
                  };
                  reader.readAsText(file);
                  e.target.value = "";
                }}
              />
            </label>
          </div>
          <textarea
            value={style.icon_svg || ""}
            onChange={(e) => onChange("icon_svg", e.target.value)}
            onBlur={(e) => handleSvgInput(e.target.value)}
            placeholder='<svg viewBox="0 0 24 24">...</svg>'
            rows={4}
            className={`w-full rounded border px-2 py-1.5 text-xs font-mono ${
              svgError ? "border-red-400" : "border-gray-300"
            }`}
          />
          {svgError && (
            <p className="mt-1 text-xs text-red-600">{svgError}</p>
          )}
          {!svgError && style.icon_svg && (
            <div className="mt-2 flex items-center gap-2">
              <span className="text-xs text-gray-500">Preview:</span>
              <div
                className="h-8 w-8 border border-gray-200 rounded bg-white p-1 flex items-center justify-center"
                dangerouslySetInnerHTML={{ __html: style.icon_svg }}
              />
              <button
                type="button"
                onClick={() => {
                  setSvgError(null);
                  onChange("icon_svg", "");
                }}
                className="text-xs text-red-500 hover:underline ml-auto"
              >
                Clear
              </button>
            </div>
          )}
        </div>
      )}

      <Field label="Color">
        <ColorInput
          value={style.color || "#3b82f6"}
          onChange={(v) => onChange("color", v)}
        />
      </Field>

      <Field label="Size (px)">
        <input
          type="number"
          value={style.size ?? 14}
          onChange={(e) => onChange("size", Number(e.target.value))}
          className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
        />
      </Field>

      {isLineOrPoly && (
        <Field label="Line Style">
          <select
            value={style.line_style || "solid"}
            onChange={(e) => onChange("line_style", e.target.value)}
            className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
          >
            <option value="solid">Solid ─────</option>
            <option value="dashed">Dashed ─ ─ ─</option>
            <option value="dotted">Dotted · · · ·</option>
            <option value="dash_dot">Dash-dot ─·─·</option>
          </select>
        </Field>
      )}
    </div>
  );
}

// ── Rules list ─────────────────────────────────────────

function RulesList({
  rules, defaultStyle, onAdd, onUpdate, onRemove, onMove, onPickIcon,
}: any) {
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Rules are evaluated in order. All matching rules merge into the final style.
        </p>
        <button
          onClick={onAdd}
          className="rounded-lg bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
        >
          + Add Rule
        </button>
      </div>

      {rules.length === 0 && (
        <div className="rounded-lg border-2 border-dashed border-gray-200 px-4 py-8 text-center text-gray-400">
          <p className="text-sm">No conditional rules yet</p>
          <p className="text-xs mt-1">
            Rules override the default style when a feature's attribute matches a condition.
          </p>
        </div>
      )}

      {rules.map((rule: StyleRule, idx: number) => (
        <RuleEditor
          key={rule.id}
          rule={rule}
          index={idx}
          total={rules.length}
          defaultStyle={defaultStyle}
          onChange={(r) => onUpdate(idx, r)}
          onRemove={() => onRemove(idx)}
          onMoveUp={() => onMove(idx, -1)}
          onMoveDown={() => onMove(idx, 1)}
          onPickIcon={() => onPickIcon(idx)}
        />
      ))}
    </div>
  );
}

// ── Label & visibility form ────────────────────────────

function LabelVisibilityForm({
  label, visibility, onLabelChange, onVisibilityChange,
}: any) {
  return (
    <div className="flex flex-col gap-5">
      <section>
        <h4 className="text-sm font-semibold text-gray-900 mb-3">Label</h4>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Attribute field to show">
            <input
              value={label?.field || ""}
              onChange={(e) => onLabelChange("field", e.target.value)}
              placeholder="e.g., name"
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
            />
          </Field>
          <Field label="Text color">
            <ColorInput
              value={label?.color || "#1f2937"}
              onChange={(v) => onLabelChange("color", v)}
            />
          </Field>
          <Field label="Halo color">
            <ColorInput
              value={label?.halo_color || "#ffffff"}
              onChange={(v) => onLabelChange("halo_color", v)}
            />
          </Field>
          <Field label="Halo width">
            <input
              type="number"
              step={0.5}
              value={label?.halo_width ?? 1.5}
              onChange={(e) => onLabelChange("halo_width", Number(e.target.value))}
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
            />
          </Field>
          <Field label="Font size">
            <input
              type="number"
              value={label?.size ?? 12}
              onChange={(e) => onLabelChange("size", Number(e.target.value))}
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
            />
          </Field>
          <Field label="Visible from zoom">
            <input
              type="number"
              value={label?.min_zoom ?? 14}
              onChange={(e) => onLabelChange("min_zoom", Number(e.target.value))}
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
            />
          </Field>
        </div>
      </section>

      <section className="border-t border-gray-100 pt-5">
        <h4 className="text-sm font-semibold text-gray-900 mb-3">Visibility</h4>
        <div className="grid grid-cols-3 gap-3">
          <Field label="Min zoom">
            <input
              type="number"
              value={visibility?.min_zoom ?? 0}
              onChange={(e) => onVisibilityChange("min_zoom", Number(e.target.value))}
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
            />
          </Field>
          <Field label="Max zoom">
            <input
              type="number"
              value={visibility?.max_zoom ?? 22}
              onChange={(e) => onVisibilityChange("max_zoom", Number(e.target.value))}
              className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
            />
          </Field>
          <Field label="Default visible">
            <label className="flex items-center gap-2 py-1.5">
              <input
                type="checkbox"
                checked={visibility?.visible_by_default !== false}
                onChange={(e) => onVisibilityChange("visible_by_default", e.target.checked)}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">Yes</span>
            </label>
          </Field>
        </div>
      </section>
    </div>
  );
}

function Field({ label, children }: { label: string; children: any }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-600 mb-1">{label}</label>
      {children}
    </div>
  );
}

function ColorInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <div className="flex items-center gap-2">
      <input
        type="color"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-8 w-10 rounded cursor-pointer border border-gray-300"
      />
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="flex-1 rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
      />
    </div>
  );
}
import { IconPicker } from "./IconPicker";
import { RuleEditor } from "./RuleEditor";
import { StylePreview } from "./StylePreview";
import type { LayerStyle, StyleRule } from "@/lib/style-engine";
