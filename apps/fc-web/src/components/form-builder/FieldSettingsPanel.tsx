import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useParams } from "react-router-dom";
import { ExternalLink, ListTree } from "lucide-react";
import { ChoiceEditor } from "./ChoiceEditor";
import { api } from "@/lib/api";

interface Props {
  field: any;
  onChange: (updated: any) => void;
}

export function FieldSettingsPanel({ field, onChange }: Props) {
  const [tab, setTab] = useState("general");
  const { projectId } = useParams();

  const update = (key: string, value: any) => {
    const updated = { ...field };
    if (value === null || value === undefined || value === "") {
      delete updated[key];
    } else {
      updated[key] = value;
    }
    onChange(updated);
  };

  const updateLabel = (val: string) => {
    onChange({ ...field, label: { ...field.label, en: val } });
  };

  const updateDescription = (val: string) => {
    onChange({
      ...field,
      description: { ...(field.description || {}), en: val },
    });
  };

  const updateConstraint = (key: string, value: any) => {
    const constraints = { ...(field.constraints || {}) };
    if (value === null || value === undefined || value === "") {
      delete constraints[key];
    } else {
      constraints[key] = value;
    }
    onChange({ ...field, constraints });
  };

  const isSelect =
    field.type === "select_one" || field.type === "select_multiple";
  const isNumeric =
    field.type === "integer" || field.type === "decimal" || field.type === "number";
  const isText = field.type === "text";

  // Choice-list-attachment is shown for select (required), text/number (optional suggestions)
  const supportsChoiceList = isSelect || isText || isNumeric;

  // For SELECT fields: "inline" or "linked" is the source-of-choices mode.
  // For TEXT/NUMBER fields: there's only "linked" (or nothing).
  const linkedMode = !!field.choice_list_id;
  const sourceMode: "inline" | "linked" = linkedMode ? "linked" : "inline";

  const { data: choiceLists } = useQuery({
    queryKey: ["choiceLists", projectId],
    queryFn: () => api.getProjectChoiceLists(projectId!),
    enabled: !!projectId && supportsChoiceList,
  });

  const linkedList = (choiceLists ?? []).find(
    (cl: any) => cl.id === field.choice_list_id
  );

  const tabClass = (t: string) =>
    "px-3 py-1.5 text-xs font-medium rounded-lg transition-colors " +
    (tab === t
      ? "bg-blue-100 text-blue-700"
      : "text-gray-500 hover:bg-gray-100");

  return (
    <div className="overflow-y-auto">
      <div className="p-4 border-b border-gray-200">
        <h3 className="text-sm font-semibold text-gray-900">Field Settings</h3>
        <p className="text-xs text-gray-500 mt-0.5">
          {field.type} — {field.id}
        </p>
      </div>

      <div className="flex gap-1 p-3 border-b border-gray-100">
        <button className={tabClass("general")} onClick={() => setTab("general")}>
          General
        </button>
        <button
          className={tabClass("validation")}
          onClick={() => setTab("validation")}
        >
          Validation
        </button>
        <button className={tabClass("logic")} onClick={() => setTab("logic")}>
          Logic
        </button>
      </div>

      <div className="p-4 flex flex-col gap-4">
        {/* ── General Tab ────────────────────────── */}
        {tab === "general" && (
          <>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Field ID
              </label>
              <input
                value={field.id}
                onChange={(e) =>
                  update("id", e.target.value.replace(/\s/g, "_").toLowerCase())
                }
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Label
              </label>
              <input
                value={field.label?.en || ""}
                onChange={(e) => updateLabel(e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Description / Hint
              </label>
              <input
                value={field.description?.en || ""}
                onChange={(e) => updateDescription(e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                placeholder="Help text shown below the field"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={field.required || false}
                onChange={(e) => update("required", e.target.checked)}
                id="required-toggle"
                className="rounded border-gray-300"
              />
              <label htmlFor="required-toggle" className="text-sm text-gray-700">
                Required
              </label>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Appearance
              </label>
              <select
                value={field.appearance || ""}
                onChange={(e) => update("appearance", e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
              >
                <option value="">Default</option>
                {field.type === "text" && (
                  <option value="multiline">Multiline</option>
                )}
                {field.type === "select_one" && (
                  <>
                    <option value="radio">Radio Buttons</option>
                    <option value="dropdown">Dropdown</option>
                    <option value="likert">Likert Scale</option>
                  </>
                )}
                {field.type === "select_multiple" && (
                  <option value="checkbox">Checkboxes</option>
                )}
                {field.type === "photo" && (
                  <option value="multi">Multiple photos</option>
                )}
              </select>
              {field.type === "photo" && (
                <p className="text-[11px] text-gray-500 mt-1">
                  Field workers can capture up to 10 photos. Set the limit under
                  Validation.
                </p>
              )}
            </div>

            {/* ── Choice list attachment ─────────────── */}
            {supportsChoiceList && (
              <div className="rounded-lg border border-gray-200 bg-gray-50 p-3 flex flex-col gap-3">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-medium text-gray-700 flex items-center gap-1.5">
                    <ListTree className="h-3.5 w-3.5" />
                    {isSelect ? "Choices source" : "Suggestions (optional)"}
                  </label>
                  <a
                    href={`/projects/${projectId}/choice-lists`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[11px] text-blue-600 hover:text-blue-800 flex items-center gap-0.5"
                  >
                    Manage <ExternalLink className="h-2.5 w-2.5" />
                  </a>
                </div>

                {/* For SELECT fields: source toggle (inline vs linked) */}
                {isSelect && (
                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      onClick={() => update("choice_list_id", null)}
                      className={
                        "flex-1 rounded border px-2 py-1 text-xs font-medium transition-colors " +
                        (sourceMode === "inline"
                          ? "border-blue-500 bg-blue-50 text-blue-700"
                          : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
                      }
                    >
                      Inline
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        // Pick first list as a friendly default if any exist
                        const first = choiceLists?.[0];
                        if (first) update("choice_list_id", first.id);
                      }}
                      className={
                        "flex-1 rounded border px-2 py-1 text-xs font-medium transition-colors " +
                        (sourceMode === "linked"
                          ? "border-blue-500 bg-blue-50 text-blue-700"
                          : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
                      }
                    >
                      Use choice list
                    </button>
                  </div>
                )}

                {/* Linked dropdown — shown for select-linked AND text/number */}
                {(linkedMode || !isSelect) && (
                  <select
                    value={field.choice_list_id || ""}
                    onChange={(e) =>
                      update("choice_list_id", e.target.value || null)
                    }
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                  >
                    <option value="">— None —</option>
                    {(choiceLists ?? []).map((cl: any) => {
                      const n = Array.isArray(cl.choices)
                        ? cl.choices.length
                        : 0;
                      return (
                        <option key={cl.id} value={cl.id}>
                          {cl.name} ({n} options)
                        </option>
                      );
                    })}
                  </select>
                )}

                {/* Read-only preview when linked */}
                {linkedMode && linkedList && (
                  <div className="rounded bg-white border border-gray-200 p-2">
                    <p className="text-[10px] uppercase tracking-wide text-gray-400 mb-1">
                      Linked: {linkedList.name}
                    </p>
                    <div className="flex flex-wrap gap-1">
                      {(Array.isArray(linkedList.choices)
                        ? linkedList.choices
                        : []
                      )
                        .slice(0, 12)
                        .map((c: any) => (
                          <span
                            key={c.value}
                            className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[11px] text-gray-700"
                          >
                            {c?.label?.en || c.value}
                          </span>
                        ))}
                      {Array.isArray(linkedList.choices) &&
                        linkedList.choices.length > 12 && (
                          <span className="text-[11px] text-gray-400">
                            + {linkedList.choices.length - 12} more
                          </span>
                        )}
                    </div>
                  </div>
                )}

                {/* Inline editor only when select + inline mode */}
                {isSelect && !linkedMode && (
                  <ChoiceEditor
                    choices={field.choices || []}
                    onChange={(choices) => update("choices", choices)}
                  />
                )}
              </div>
            )}

            {field.type === "calculation" && (
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">
                  Expression
                </label>
                <input
                  value={field.calculation || ""}
                  onChange={(e) => update("calculation", e.target.value)}
                  className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
                  placeholder="${field_a} + ${field_b}"
                />
              </div>
            )}
          </>
        )}

        {/* ── Validation Tab ─────────────────────── */}
        {tab === "validation" && (
          <>
            {(field.type === "integer" || field.type === "decimal") && (
              <>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Minimum Value
                  </label>
                  <input
                    type="number"
                    value={field.constraints?.min ?? ""}
                    onChange={(e) =>
                      updateConstraint(
                        "min",
                        e.target.value ? Number(e.target.value) : null
                      )
                    }
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Maximum Value
                  </label>
                  <input
                    type="number"
                    value={field.constraints?.max ?? ""}
                    onChange={(e) =>
                      updateConstraint(
                        "max",
                        e.target.value ? Number(e.target.value) : null
                      )
                    }
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                  />
                </div>
              </>
            )}
            {field.type === "text" && (
              <>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Min Length
                  </label>
                  <input
                    type="number"
                    value={field.constraints?.min_length ?? ""}
                    onChange={(e) =>
                      updateConstraint(
                        "min_length",
                        e.target.value ? Number(e.target.value) : null
                      )
                    }
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Max Length
                  </label>
                  <input
                    type="number"
                    value={field.constraints?.max_length ?? ""}
                    onChange={(e) =>
                      updateConstraint(
                        "max_length",
                        e.target.value ? Number(e.target.value) : null
                      )
                    }
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Pattern (regex)
                  </label>
                  <input
                    value={field.constraints?.pattern || ""}
                    onChange={(e) => updateConstraint("pattern", e.target.value)}
                    className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
                    placeholder="^[A-Z]{3}-\d{4}$"
                  />
                </div>
              </>
            )}
            {field.type === "photo" && (
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">
                  Max photos
                </label>
                <input
                  type="number"
                  min={1}
                  max={10}
                  value={field.constraints?.max_length ?? 10}
                  onChange={(e) => {
                    const n = e.target.value ? Number(e.target.value) : 10;
                    const clamped = Math.min(10, Math.max(1, n));
                    updateConstraint("max_length", clamped);
                  }}
                  className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                />
                <p className="text-[11px] text-gray-500 mt-1">
                  Maximum 10 photos per field.
                </p>
              </div>
            )}
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Error Message
              </label>
              <input
                value={field.constraints?.message?.en || ""}
                onChange={(e) =>
                  updateConstraint(
                    "message",
                    e.target.value ? { en: e.target.value } : null
                  )
                }
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
                placeholder="Custom error message"
              />
            </div>
          </>
        )}

        {/* ── Logic Tab ──────────────────────────── */}
        {tab === "logic" && (
          <>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Show this field when
              </label>
              <input
                value={field.relevant || ""}
                onChange={(e) => update("relevant", e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm font-mono"
                placeholder="${status} = 'damaged'"
              />
              <p className="text-xs text-gray-400 mt-1">
                Leave empty to always show
              </p>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">
                Default Value
              </label>
              <input
                value={field.default || ""}
                onChange={(e) => update("default", e.target.value)}
                className="w-full rounded border border-gray-300 px-2 py-1.5 text-sm"
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}