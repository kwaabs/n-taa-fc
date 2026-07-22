import { Plus, Trash2, Search, X } from "lucide-react";

export type FilterOp =
  | "eq"
  | "neq"
  | "gt"
  | "gte"
  | "lt"
  | "lte"
  | "contains"
  | "starts_with"
  | "is_null"
  | "is_not_null";

export interface QueryCondition {
  id: string;
  field: string;
  op: FilterOp;
  value: string;
}

export interface AppliedFilter {
  field: string;
  op: FilterOp;
  value: string;
}

const OPS: { value: FilterOp; label: string; needsValue: boolean }[] = [
  { value: "eq", label: "=", needsValue: true },
  { value: "neq", label: "≠", needsValue: true },
  { value: "gt", label: ">", needsValue: true },
  { value: "gte", label: "≥", needsValue: true },
  { value: "lt", label: "<", needsValue: true },
  { value: "lte", label: "≤", needsValue: true },
  { value: "contains", label: "contains", needsValue: true },
  { value: "starts_with", label: "starts with", needsValue: true },
  { value: "is_null", label: "is empty", needsValue: false },
  { value: "is_not_null", label: "is not empty", needsValue: false },
];

function newId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function emptyCondition(fields: string[]): QueryCondition {
  return {
    id: newId(),
    field: fields[0] || "",
    op: "eq",
    value: "",
  };
}

interface Props {
  fields: string[];
  draft: QueryCondition[];
  onDraftChange: (next: QueryCondition[]) => void;
  onApply: (filters: AppliedFilter[]) => void;
  onClear: () => void;
  appliedCount: number;
  busy?: boolean;
}

export function FeatureQueryBuilder({
  fields,
  draft,
  onDraftChange,
  onApply,
  onClear,
  appliedCount,
  busy,
}: Props) {
  if (fields.length === 0) {
    return (
      <p className="text-xs text-gray-500">
        No searchable columns yet — load the table first.
      </p>
    );
  }

  const update = (id: string, patch: Partial<QueryCondition>) => {
    onDraftChange(draft.map((c) => (c.id === id ? { ...c, ...patch } : c)));
  };

  const remove = (id: string) => {
    onDraftChange(draft.filter((c) => c.id !== id));
  };

  const add = () => {
    onDraftChange([...draft, emptyCondition(fields)]);
  };

  const apply = () => {
    const filters: AppliedFilter[] = [];
    for (const c of draft) {
      if (!c.field) continue;
      const meta = OPS.find((o) => o.value === c.op);
      if (!meta) continue;
      if (meta.needsValue && !c.value.trim()) continue;
      filters.push({
        field: c.field,
        op: c.op,
        value: meta.needsValue ? c.value : "",
      });
    }
    onApply(filters);
  };

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3 flex flex-col gap-2">
      <div className="flex items-center justify-between gap-2">
        <p className="text-xs font-medium text-gray-700">
          Query builder{" "}
          <span className="font-normal text-gray-500">
            (conditions combined with AND)
          </span>
        </p>
        {appliedCount > 0 && (
          <span className="text-[11px] rounded-full bg-blue-50 text-blue-700 px-2 py-0.5">
            {appliedCount} active
          </span>
        )}
      </div>

      {draft.length === 0 && (
        <p className="text-xs text-gray-500 py-1">
          Add a condition, e.g.{" "}
          <code className="bg-gray-100 px-1 rounded">ogc_fid = 2500</code> AND{" "}
          <code className="bg-gray-100 px-1 rounded">district = Accra East</code>
        </p>
      )}

      {draft.map((c, idx) => {
        const needsValue = OPS.find((o) => o.value === c.op)?.needsValue ?? true;
        return (
          <div key={c.id} className="flex flex-wrap items-center gap-1.5">
            {idx > 0 && (
              <span className="text-[10px] font-semibold uppercase text-gray-400 w-8">
                and
              </span>
            )}
            {idx === 0 && <span className="w-8" />}
            <select
              value={c.field}
              onChange={(e) => update(c.id, { field: e.target.value })}
              className="rounded border border-gray-300 px-2 py-1 text-xs min-w-[120px]"
            >
              {fields.map((f) => (
                <option key={f} value={f}>
                  {f}
                </option>
              ))}
            </select>
            <select
              value={c.op}
              onChange={(e) =>
                update(c.id, { op: e.target.value as FilterOp, value: "" })
              }
              className="rounded border border-gray-300 px-2 py-1 text-xs"
            >
              {OPS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
            {needsValue ? (
              <input
                value={c.value}
                onChange={(e) => update(c.id, { value: e.target.value })}
                onKeyDown={(e) => {
                  if (e.key === "Enter") apply();
                }}
                placeholder="value"
                className="rounded border border-gray-300 px-2 py-1 text-xs flex-1 min-w-[140px]"
              />
            ) : (
              <span className="text-xs text-gray-400 flex-1">—</span>
            )}
            <button
              type="button"
              onClick={() => remove(c.id)}
              className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-red-600"
              title="Remove condition"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        );
      })}

      <div className="flex items-center gap-2 pt-1">
        <button
          type="button"
          onClick={add}
          className="inline-flex items-center gap-1 rounded border border-gray-300 px-2 py-1 text-xs text-gray-700 hover:bg-gray-50"
        >
          <Plus className="h-3 w-3" />
          Add condition
        </button>
        <div className="flex-1" />
        {(draft.length > 0 || appliedCount > 0) && (
          <button
            type="button"
            onClick={onClear}
            className="inline-flex items-center gap-1 rounded border border-gray-300 px-2 py-1 text-xs text-gray-600 hover:bg-gray-50"
          >
            <Trash2 className="h-3 w-3" />
            Clear
          </button>
        )}
        <button
          type="button"
          onClick={apply}
          disabled={busy}
          className="inline-flex items-center gap-1 rounded bg-blue-600 px-3 py-1 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          <Search className="h-3 w-3" />
          {busy ? "Searching…" : "Search"}
        </button>
      </div>
    </div>
  );
}
