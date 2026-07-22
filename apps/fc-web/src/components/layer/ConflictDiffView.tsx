import { useState } from "react";

interface Props {
  conflict: any;
}

export function ConflictDiffView({ conflict }: Props) {
  const [showAll, setShowAll] = useState(false);

  const origAttrs = conflict.original_attrs ?? {};
  const fieldAttrs = conflict.field_attrs ?? {};
  const sourceAttrs = conflict.source_attrs ?? {};
  const conflicting = new Set<string>(conflict.conflicting_fields ?? []);
  const changeType = conflict.change_type as string;

  // Union of all keys across the 3 sides
  const allKeys = Array.from(
    new Set<string>([
      ...Object.keys(origAttrs),
      ...Object.keys(fieldAttrs),
      ...Object.keys(sourceAttrs),
    ])
  ).sort();

  const visibleKeys = showAll
    ? allKeys
    : allKeys.filter((k) => conflicting.has(k));

  return (
    <div className="flex flex-col gap-3">
      {/* Filter toggle */}
      <div className="flex items-center justify-between">
        <p className="text-xs text-gray-500">
          Showing {visibleKeys.length} of {allKeys.length} fields
        </p>
        <button
          onClick={() => setShowAll(!showAll)}
          className="text-xs text-blue-600 hover:underline"
        >
          {showAll ? "Show only conflicting" : "Show all fields"}
        </button>
      </div>

      {/* Diff table */}
      <div className="rounded-lg border border-gray-200 overflow-hidden">
        <table className="w-full text-xs">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-1/4">
                Field
              </th>
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-1/4">
                Original snapshot
              </th>
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-1/4">
                {changeType === "deleted" ? "(tombstone)" : "Field-collected edit"}
              </th>
              <th className="text-left px-3 py-2 font-medium text-gray-600 w-1/4">
                Source DB (current)
              </th>
            </tr>
          </thead>
          <tbody>
            {visibleKeys.length === 0 ? (
              <tr>
                <td
                  colSpan={4}
                  className="px-3 py-6 text-center text-gray-400 italic"
                >
                  No fields match current filter
                </td>
              </tr>
            ) : (
              visibleKeys.map((k) => {
                const isConflict = conflicting.has(k);
                return (
                  <tr
                    key={k}
                    className={
                      "border-t border-gray-100 " +
                      (isConflict ? "bg-amber-50/50" : "")
                    }
                  >
                    <td className="px-3 py-1.5 font-mono text-gray-900 align-top">
                      {k}
                      {isConflict && (
                        <span className="ml-1 text-[10px] text-amber-700 font-sans">
                          ●
                        </span>
                      )}
                    </td>
                    <Cell value={origAttrs[k]} />
                    <Cell value={fieldAttrs[k]} muted={changeType === "deleted"} />
                    <Cell value={sourceAttrs[k]} />
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Cell({ value, muted }: { value: any; muted?: boolean }) {
  let display: string;
  let className = "px-3 py-1.5 align-top break-all";

  if (value === undefined) {
    display = "—";
    className += " text-gray-300 italic font-sans";
  } else if (value === null) {
    display = "null";
    className += " text-gray-400 italic font-sans";
  } else if (typeof value === "string") {
    display = value;
    className += " text-gray-700 font-mono";
  } else if (typeof value === "number" || typeof value === "boolean") {
    display = String(value);
    className += " text-blue-700 font-mono";
  } else {
    display = JSON.stringify(value);
    className += " text-gray-700 font-mono";
  }

  if (muted) {
    className += " opacity-40";
  }

  return <td className={className}>{display}</td>;
}