import { useState } from "react";
import {
  ChevronDown, ChevronRight, FileText, AlertTriangle, Layers as LayersIcon,
} from "lucide-react";
import type { DiscoveredTable, TableConfig } from "./types";
import { humanize } from "./types";

interface Props {
  tables: DiscoveredTable[];
  configs: Record<string, TableConfig>;
  importMode?: "link" | "copy";
}

function postgresTypeToFieldType(dataType: string, isEnum: boolean): string {
  if (isEnum) return "select_one";
  const dt = dataType.toLowerCase();
  if (["text", "varchar", "character varying", "character", "char", "citext"].includes(dt)) return "text";
  if (["integer", "bigint", "smallint", "int", "int2", "int4", "int8"].includes(dt)) return "integer";
  if (["numeric", "decimal", "real", "double precision", "float", "float4", "float8"].includes(dt)) return "decimal";
  if (["boolean", "bool"].includes(dt)) return "select_one";
  if (dt === "date") return "date";
  if (dt.startsWith("timestamp")) return "datetime";
  if (dt.startsWith("time")) return "time";
  return "text";
}

export function StepReview({ tables, configs, importMode = "copy" }: Props) {
  const [expandedQN, setExpandedQN] = useState<string | null>(null);

  const formCount = tables.filter((t) => configs[t.qualified_name]?.generate_form).length;
  const isLink = importMode === "link";

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-gray-600">
        {isLink
          ? "Review the layers that will be linked to live source tables (no row copy)."
          : "Review the layers and forms that will be created. You can edit forms later in the form builder."}
      </p>

      <div className={`rounded-lg border p-4 flex items-start gap-3 ${
        isLink ? "border-emerald-200 bg-emerald-50" : "border-blue-200 bg-blue-50"
      }`}>
        <FileText className={`h-5 w-5 shrink-0 ${isLink ? "text-emerald-600" : "text-blue-600"}`} />
        <div className={`text-sm ${isLink ? "text-emerald-900" : "text-blue-900"}`}>
          <p className="font-medium">
            About to {isLink ? "link" : "create"} {tables.length} layer
            {tables.length === 1 ? "" : "s"}
            {!isLink && formCount > 0 && (
              <> and {formCount} auto-generated form{formCount === 1 ? "" : "s"}</>
            )}
          </p>
          <p className={`text-xs mt-1 ${isLink ? "text-emerald-700" : "text-blue-700"}`}>
            {isLink
              ? "No features will be copied. The project map will read live Martin tiles for each table. Use Copy mode later if you need an offline snapshot."
              : "Each layer's data source will be configured for ongoing re-sync. Initial sync runs immediately in the next step."}
          </p>
        </div>
      </div>

      {tables.map((t) => {
        const c = configs[t.qualified_name];
        if (!c) return null;
        const isOpen = expandedQN === t.qualified_name;
        const formFields = c.generate_form
          ? t.columns.filter(
              (col) =>
                !col.is_geometry &&
                !col.is_primary_key &&
                c.included_columns.includes(col.name)
            )
          : [];

        return (
          <div
            key={t.qualified_name}
            className="border border-gray-200 rounded-lg overflow-hidden bg-white"
          >
            <button
              onClick={() => setExpandedQN(isOpen ? null : t.qualified_name)}
              className="w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-50 text-left"
            >
              {isOpen ? (
                <ChevronDown className="h-4 w-4 text-gray-400" />
              ) : (
                <ChevronRight className="h-4 w-4 text-gray-400" />
              )}
              <LayersIcon className="h-4 w-4 text-blue-600" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate">
                  {c.layer_name}
                </p>
                <p className="text-xs text-gray-500">
                  {isLink
                    ? `${c.geometry_type} · linked live table · ${c.schema}.${c.name}`
                    : `${c.geometry_type} · ${c.included_columns.length} attributes · ${
                        c.generate_form ? `${formFields.length}-field form` : "no form"
                      }`}
                </p>
              </div>
            </button>

            {isOpen && c.generate_form && (
              <div className="border-t border-gray-100 px-4 py-3 bg-gray-50/50">
                <p className="text-xs font-medium text-gray-600 mb-2">
                  Auto-generated form preview
                </p>
                <div className="flex flex-col gap-1">
                  {formFields.map((col) => {
                    const fieldType = postgresTypeToFieldType(col.data_type, col.is_enum);
                    return (
                      <div
                        key={col.name}
                        className="flex items-center gap-2 rounded border border-gray-200 px-3 py-1.5 bg-white"
                      >
                        <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs font-mono text-gray-600">
                          {fieldType}
                        </span>
                        <span className="text-sm text-gray-900 flex-1 truncate">
                          {humanize(col.name)}
                        </span>
                        {!col.is_nullable && (
                          <span className="text-xs text-red-500">*</span>
                        )}
                        {col.is_enum && (
                          <span className="text-xs text-purple-600">
                            {col.enum_values?.length} choices
                          </span>
                        )}
                      </div>
                    );
                  })}
                  {formFields.length === 0 && (
                    <p className="text-xs text-gray-400 italic">
                      No fields (all columns excluded)
                    </p>
                  )}
                </div>
                <p className="text-xs text-gray-400 mt-2">
                  <AlertTriangle className="h-3 w-3 inline mr-0.5" />
                  Form is published as v1 — you can edit and create v2 in the form builder.
                </p>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}