import { useEffect, useState } from "react";
import {
  ChevronDown,
  ChevronRight,
  AlertTriangle,
  Eye,
  EyeOff,
  Settings as Cog,
} from "lucide-react";
import type {
  DiscoveredTable,
  TableConfig,
  DiscoveredColumn,
} from "./types";
import { humanize, normalizeGeometryType } from "./types";

interface Props {
  tables: DiscoveredTable[];
  configs: Record<string, TableConfig>;
  importMode: "link" | "copy";
  onImportModeChange: (mode: "link" | "copy") => void;
  onConfigsChange: (configs: Record<string, TableConfig>) => void;
}

const PII_HINTS = [
  "phone",
  "mobile",
  "email",
  "ssn",
  "national_id",
  "passport",
  "address",
  "street",
  "dob",
  "birth_date",
  "ip_address",
];

function looksLikePII(colName: string): boolean {
  const lower = colName.toLowerCase();
  return PII_HINTS.some((h) => lower.includes(h));
}

function autoIdColumn(cols: DiscoveredColumn[]): string {
  const pk = cols.find((c) => c.is_primary_key);
  if (pk) return pk.name;
  const idCol = cols.find((c) => c.name.toLowerCase() === "id");
  if (idCol) return idCol.name;
  return "";
}

function defaultConfig(t: DiscoveredTable): TableConfig {
  const allCols = t.columns || [];
  const included = allCols
    .filter((c) => !c.is_geometry && !c.is_primary_key && !looksLikePII(c.name))
    .map((c) => c.name);
  const excluded = allCols
    .filter((c) => !c.is_geometry && !c.is_primary_key && looksLikePII(c.name))
    .map((c) => c.name);

  return {
    qualified_name: t.qualified_name,
    schema: t.schema,
    name: t.name,
    layer_name: humanize(t.name),
    geometry_type: normalizeGeometryType(t.geometry_type),
    geometry_column: t.geometry_column,
    id_column: autoIdColumn(allCols),
    editable: true,
    included_columns: included,
    excluded_columns: excluded,
    filter_clause: "",
    generate_form: true,
    schedule_minutes: 0,
  };
}

export function StepConfigure({
  tables,
  configs,
  importMode,
  onImportModeChange,
  onConfigsChange,
}: Props) {
  const [expandedQN, setExpandedQN] = useState<string | null>(null);

  useEffect(() => {
    let dirty = false;
    const next = { ...configs };

    for (const t of tables) {
      if (!next[t.qualified_name]) {
        next[t.qualified_name] = defaultConfig(t);
        dirty = true;
      }
    }
    for (const qn of Object.keys(next)) {
      if (!tables.find((t) => t.qualified_name === qn)) {
        delete next[qn];
        dirty = true;
      }
    }

    if (dirty) onConfigsChange(next);

    if (!expandedQN && tables.length > 0) {
      setExpandedQN(tables[0].qualified_name);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tables]);

  const updateConfig = (qn: string, patch: Partial<TableConfig>) => {
    const current = configs[qn];
    if (!current) return;
    const updated = { ...configs };
    updated[qn] = { ...current, ...patch };
    onConfigsChange(updated);
  };

  const toggleColumn = (qn: string, colName: string) => {
    const c = configs[qn];
    if (!c) return;
    const isIncluded = c.included_columns.includes(colName);
    let included = c.included_columns;
    let excluded = c.excluded_columns;
    if (isIncluded) {
      included = included.filter((x) => x !== colName);
      excluded = [...excluded, colName];
    } else {
      excluded = excluded.filter((x) => x !== colName);
      included = [...included, colName];
    }
    updateConfig(qn, {
      included_columns: included,
      excluded_columns: excluded,
    });
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
        <p className="text-sm font-medium text-gray-800 mb-2">
          How should these tables be added?
        </p>
        <div className="flex flex-col sm:flex-row gap-2">
          <button
            type="button"
            onClick={() => onImportModeChange("link")}
            className={`flex-1 rounded-lg border px-3 py-2 text-left text-sm ${
              importMode === "link"
                ? "border-blue-600 bg-blue-50 text-blue-900"
                : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50"
            }`}
          >
            <div className="font-medium">Link (recommended)</div>
            <div className="text-xs text-gray-500 mt-0.5">
              Register the live table — no row copy. Map uses Martin tiles from
              the source. Best for shared-DB dbo layers.
            </div>
          </button>
          <button
            type="button"
            onClick={() => onImportModeChange("copy")}
            className={`flex-1 rounded-lg border px-3 py-2 text-left text-sm ${
              importMode === "copy"
                ? "border-blue-600 bg-blue-50 text-blue-900"
                : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50"
            }`}
          >
            <div className="font-medium">Copy / materialize</div>
            <div className="text-xs text-gray-500 mt-0.5">
              Snapshot rows into Field Collector (current behavior). Use for
              offline bundles or external databases.
            </div>
          </button>
        </div>
      </div>

      <p className="text-sm text-gray-600">
        Configure each selected table. Sensible defaults are pre-filled —
        {importMode === "link"
          ? " link mode only needs a layer name and id column."
          : " adjust columns and forms as needed."}
      </p>

      {tables.length === 0 && (
        <p className="text-sm text-gray-400 italic">No tables selected.</p>
      )}

      {tables.map((t) => {
        const c = configs[t.qualified_name];
        const isOpen = expandedQN === t.qualified_name;
        if (!c) return null;

        return (
          <div
            key={t.qualified_name}
            className="border border-gray-200 rounded-lg overflow-hidden"
          >
            <button
              onClick={() => setExpandedQN(isOpen ? null : t.qualified_name)}
              className="w-full flex items-center gap-3 px-4 py-3 bg-white hover:bg-gray-50 text-left"
            >
              {isOpen ? (
                <ChevronDown className="h-4 w-4 text-gray-400 shrink-0" />
              ) : (
                <ChevronRight className="h-4 w-4 text-gray-400 shrink-0" />
              )}
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate">
                  {c.layer_name}
                </p>
                <p className="text-xs text-gray-500 font-mono truncate">
                  {t.qualified_name} · {c.geometry_type} ·{" "}
                  {c.included_columns.length}/{t.columns.length - 1} columns
                  included
                </p>
              </div>
              {!c.id_column && (
                <span className="rounded-full bg-yellow-50 px-2 py-0.5 text-xs text-yellow-700 flex items-center gap-1">
                  <AlertTriangle className="h-3 w-3" /> Pick an ID column
                </span>
              )}
            </button>

            {isOpen && (
              <div className="border-t border-gray-100 p-4 flex flex-col gap-4 bg-gray-50/50">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Layer name
                    </label>
                    <input
                      value={c.layer_name}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          layer_name: e.target.value,
                        })
                      }
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Geometry type{" "}
                      <span className="text-gray-400 text-xs">
                        (detected: {t.geometry_type || "none"})
                      </span>
                    </label>
                    <select
                      value={c.geometry_type}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          geometry_type: e.target.value,
                        })
                      }
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white"
                    >
                      <option value="point">Point</option>
                      <option value="line">Line</option>
                      <option value="polygon">Polygon</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      ID column <span className="text-gray-400">(for dedup)</span>
                    </label>
                    <select
                      value={c.id_column}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          id_column: e.target.value,
                        })
                      }
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white font-mono"
                    >
                      <option value="">— pick a column —</option>
                      {t.columns
                        .filter((col) => !col.is_geometry)
                        .map((col) => (
                          <option key={col.name} value={col.name}>
                            {col.name}
                            {col.is_primary_key ? " (PK)" : ""}
                          </option>
                        ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Editable mode
                    </label>
                    <select
                      value={c.editable ? "edit" : "inspect"}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          editable: e.target.value === "edit",
                        })
                      }
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white"
                    >
                      <option value="edit">
                        Workers can collect new features
                      </option>
                      <option value="inspect">
                        Inspect-only (read-only reference)
                      </option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Filter{" "}
                    <span className="text-gray-400">
                      (optional SQL WHERE clause)
                    </span>
                  </label>
                  <input
                    value={c.filter_clause}
                    onChange={(e) =>
                      updateConfig(t.qualified_name, {
                        filter_clause: e.target.value,
                      })
                    }
                    placeholder={'WHERE region = "north"'}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white font-mono"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <label className="flex items-center gap-2 text-sm rounded-lg border border-gray-200 px-3 py-2 bg-white cursor-pointer">
                    <input
                      type="checkbox"
                      checked={c.generate_form}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          generate_form: e.target.checked,
                        })
                      }
                    />
                    <span>Auto-generate form from columns</span>
                  </label>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Re-sync schedule
                    </label>
                    <select
                      value={c.schedule_minutes}
                      onChange={(e) =>
                        updateConfig(t.qualified_name, {
                          schedule_minutes: Number(e.target.value),
                        })
                      }
                      className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white"
                    >
                      <option value={0}>Manual only</option>
                      <option value={60}>Every hour</option>
                      <option value={360}>Every 6 hours</option>
                      <option value={1440}>Daily</option>
                    </select>
                  </div>
                </div>

                <div>
                  <p className="text-xs font-medium text-gray-600 mb-2">
                    Columns to import
                  </p>
                  <div className="max-h-56 overflow-y-auto border border-gray-200 rounded-lg bg-white">
                    {t.columns
                      .filter((col) => !col.is_geometry)
                      .map((col) => {
                        const isIncluded = c.included_columns.includes(col.name);
                        const isPK = col.is_primary_key;
                        const isPII = looksLikePII(col.name);
                        return (
                          <label
                            key={col.name}
                            className={`flex items-center gap-3 px-3 py-2 border-b border-gray-100 last:border-0 cursor-pointer hover:bg-gray-50 ${isIncluded ? "" : "bg-gray-50/50"}`}
                          >
                            <input
                              type="checkbox"
                              checked={isIncluded}
                              onChange={() =>
                                toggleColumn(t.qualified_name, col.name)
                              }
                              disabled={isPK}
                            />
                            {isIncluded ? (
                              <Eye className="h-3.5 w-3.5 text-blue-500 shrink-0" />
                            ) : (
                              <EyeOff className="h-3.5 w-3.5 text-gray-300 shrink-0" />
                            )}
                            <div className="flex-1 min-w-0">
                              <span className="text-sm font-mono">
                                {col.name}
                              </span>
                              <span className="text-xs text-gray-400 ml-2">
                                {col.is_enum
                                  ? `enum (${col.enum_values?.length || 0})`
                                  : col.data_type}
                              </span>
                            </div>
                            {isPK && (
                              <span className="text-xs rounded bg-yellow-50 text-yellow-700 px-1.5 py-0.5">
                                PK
                              </span>
                            )}
                            {isPII && (
                              <span className="text-xs rounded bg-red-50 text-red-700 px-1.5 py-0.5">
                                possible PII
                              </span>
                            )}
                            {col.is_enum && (
                              <span className="text-xs rounded bg-purple-50 text-purple-700 px-1.5 py-0.5">
                                ENUM
                              </span>
                            )}
                          </label>
                        );
                      })}
                  </div>
                  <p className="text-xs text-gray-400 mt-1">
                    <Cog className="h-3 w-3 inline mr-0.5" />
                    Geometry and primary key are handled automatically.
                  </p>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
