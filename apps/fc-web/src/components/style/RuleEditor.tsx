import type { StyleRule } from "@/lib/style-engine";
import { Trash2, ArrowUp, ArrowDown } from "lucide-react";

const OPERATORS = [
  { value: "eq", label: "equals" },
  { value: "neq", label: "not equals" },
  { value: "gt", label: ">" },
  { value: "lt", label: "<" },
  { value: "gte", label: "≥" },
  { value: "lte", label: "≤" },
  { value: "contains", label: "contains" },
  { value: "is_null", label: "is empty" },
  { value: "is_not_null", label: "is not empty" },
];

interface Props {
  rule: StyleRule;
  index: number;
  total: number;
  defaultStyle: any;
  onChange: (r: StyleRule) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onPickIcon: () => void;
}

export function RuleEditor({
  rule, index, total,
  onChange, onRemove, onMoveUp, onMoveDown, onPickIcon,
}: Props) {
  const updateWhen = (key: string, value: any) => {
    onChange({ ...rule, when: { ...rule.when, [key]: value } });
  };

  const updateStyle = (key: string, value: any) => {
    const next = { ...rule.style };
    if (value === "" || value === null || value === undefined) {
      delete (next as any)[key];
    } else {
      (next as any)[key] = value;
    }
    onChange({ ...rule, style: next });
  };

  const op = rule.when.op || "eq";
  const noValueOp = op === "is_null" || op === "is_not_null";

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      {/* Top row */}
      <div className="flex items-center gap-2 mb-3">
        <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-700">
          Rule {index + 1}
        </span>
        <input
          value={rule.name || ""}
          onChange={(e) => onChange({ ...rule, name: e.target.value })}
          placeholder="Rule name (optional)"
          className="flex-1 text-sm font-medium border-0 outline-none bg-transparent"
        />
        <button
          onClick={onMoveUp}
          disabled={index === 0}
          className="text-gray-400 hover:text-gray-700 disabled:opacity-20"
          title="Move up"
        >
          <ArrowUp className="h-4 w-4" />
        </button>
        <button
          onClick={onMoveDown}
          disabled={index === total - 1}
          className="text-gray-400 hover:text-gray-700 disabled:opacity-20"
          title="Move down"
        >
          <ArrowDown className="h-4 w-4" />
        </button>
        <button
          onClick={onRemove}
          className="text-gray-400 hover:text-red-500"
          title="Delete rule"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>

      {/* When clause */}
      <div className="bg-gray-50 rounded-lg p-3 mb-3">
        <p className="text-xs font-medium text-gray-600 mb-2">When</p>
        <div className="flex items-center gap-2 flex-wrap">
          <input
            value={rule.when.field || ""}
            onChange={(e) => updateWhen("field", e.target.value)}
            placeholder="field name"
            className="w-32 rounded border border-gray-300 px-2 py-1 text-xs font-mono"
          />
          <select
            value={op}
            onChange={(e) => updateWhen("op", e.target.value)}
            className="rounded border border-gray-300 px-2 py-1 text-xs"
          >
            {OPERATORS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
          {!noValueOp && (
            <input
              value={String(rule.when.value ?? "")}
              onChange={(e) => updateWhen("value", e.target.value)}
              placeholder="value"
              className="flex-1 min-w-32 rounded border border-gray-300 px-2 py-1 text-xs font-mono"
            />
          )}
        </div>
      </div>

      {/* Style override */}
      <div className="bg-blue-50 rounded-lg p-3">
        <p className="text-xs font-medium text-blue-700 mb-2">
          Apply style (only fields you set will override the default)
        </p>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-xs text-gray-600 mb-1">Color</label>
            <div className="flex items-center gap-1.5">
              <input
                type="color"
                value={rule.style.color || "#3b82f6"}
                onChange={(e) => updateStyle("color", e.target.value)}
                className="h-7 w-8 rounded cursor-pointer border border-gray-300"
              />
              <input
                value={rule.style.color || ""}
                onChange={(e) => updateStyle("color", e.target.value)}
                placeholder="inherit"
                className="flex-1 rounded border border-gray-300 px-2 py-1 text-xs font-mono"
              />
            </div>
          </div>
          <div>
            <div>
              <label className="block text-xs text-gray-600 mb-1">Size</label>
              <input
                type="number"
                value={rule.style.size ?? ""}
                onChange={(e) => updateStyle("size", e.target.value ? Number(e.target.value) : "")}
                placeholder="inherit"
                className="w-full rounded border border-gray-300 px-2 py-1 text-xs"
              />
            </div>
            <div>
              <label className="block text-xs text-gray-600 mb-1">Line Style</label>
              <select
                value={rule.style.line_style || ""}
                onChange={(e) => updateStyle("line_style", e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1 text-xs"
              >
                <option value="">inherit / solid</option>
                <option value="solid">Solid ─────</option>
                <option value="dashed">Dashed ─ ─ ─</option>
                <option value="dotted">Dotted · · · ·</option>
                <option value="dash_dot">Dash-dot ─·─·</option>
              </select>
            </div>
            <div className="col-span-2">
              <label className="block text-xs text-gray-600 mb-1">Icon</label>
              <button
                onClick={onPickIcon}
                className="w-full flex items-center gap-2 rounded border border-gray-300 px-2 py-1.5 text-xs hover:bg-white text-left"
              >
                <span className="font-mono text-gray-500">
                  {rule.style.icon || "inherit from default"}
                </span>
                <span className="ml-auto text-blue-600">Change</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

  );
}