import { useState, useRef, useEffect } from "react";
import { Columns3, Check } from "lucide-react";

interface Props {
  allColumns: Array<{ id: string; label: string; isMedia?: boolean }>;
  visible: Set<string>;
  onToggle: (id: string) => void;
  onSelectAll: () => void;
  onReset: () => void;
}

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

export function ColumnPicker({
  allColumns,
  visible,
  onToggle,
  onSelectAll,
  onReset,
}: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    if (open) {
      document.addEventListener("mousedown", onDocClick);
    }
    return () => document.removeEventListener("mousedown", onDocClick);
  }, [open]);

  const visibleCount = visible.size;
  const totalCount = allColumns.length;

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50"
      >
        <Columns3 className="h-4 w-4" />
        Columns ({visibleCount}/{totalCount})
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-1 w-64 bg-white rounded-lg border border-gray-200 shadow-lg z-20 max-h-96 overflow-hidden flex flex-col">
          <div className="flex items-center justify-between px-3 py-2 border-b border-gray-100">
            <p className="text-xs font-medium text-gray-700">Visible columns</p>
            <div className="flex gap-2 text-xs">
              <button onClick={onSelectAll} className="text-blue-600 hover:underline">
                All
              </button>
              <button onClick={onReset} className="text-gray-500 hover:underline">
                Reset
              </button>
            </div>
          </div>

          <div className="overflow-y-auto flex-1 py-1">
            {allColumns.length === 0 ? (
              <p className="text-xs text-gray-400 italic px-3 py-2">No attribute columns yet</p>
            ) : (
              allColumns.map((col) => {
                const isVisible = visible.has(col.id);
                return (
                  <button
                    key={col.id}
                    onClick={() => onToggle(col.id)}
                    className="w-full flex items-center gap-2 px-3 py-1.5 text-sm hover:bg-gray-50 text-left"
                  >
                    <span
                      className={`flex items-center justify-center w-4 h-4 rounded border ${
                        isVisible
                          ? "bg-blue-600 border-blue-600"
                          : "bg-white border-gray-300"
                      }`}
                    >
                      {isVisible && <Check className="h-3 w-3 text-white" />}
                    </span>
                    <span className="text-gray-800 truncate flex-1">
                      {humanize(col.id)}
                    </span>
                    {col.isMedia && (
                      <span className="text-[10px] uppercase text-gray-400">media</span>
                    )}
                  </button>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
}