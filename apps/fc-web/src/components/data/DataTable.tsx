import { useMemo, useState, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { ColumnPicker } from "./ColumnPicker";
import { getVisibleColumns, setVisibleColumns } from "@/lib/column-prefs";
import { Check, X, Search } from "lucide-react";

interface Props {
  projectId: string;
  features: any[];
  onSelectFeature: (feature: any) => void;
  onReview: (id: string, status: string) => void;
}

const MEDIA_PREFIXES = ["photo_", "audio_", "video_", "signature_", "barcode_image_"];
const MEDIA_TYPES = ["geopoint", "geotrace", "geoshape"];

function isMediaField(fieldId: string): boolean {
  return MEDIA_PREFIXES.some((p) => fieldId.startsWith(p)) ||
         MEDIA_TYPES.some((t) => fieldId === t || fieldId.startsWith(t + "_"));
}

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

function statusPill(status: string): string {
  if (status === "approved") return "bg-green-50 text-green-700";
  if (status === "rejected") return "bg-red-50 text-red-700";
  if (status === "submitted") return "bg-blue-50 text-blue-700";
  if (status === "under_review") return "bg-purple-50 text-purple-700";
  return "bg-gray-100 text-gray-600";
}

export function DataTable({ projectId, features, onSelectFeature, onReview }: Props) {
  const [search, setSearch] = useState("");

  // Discover all attribute columns from the first 50 features
  const allColumns = useMemo(() => {
    const seen = new Map<string, { id: string; label: string; isMedia: boolean }>();
    for (const f of features.slice(0, 50)) {
      for (const k of Object.keys(f.attributes || {})) {
        if (!seen.has(k)) {
          seen.set(k, { id: k, label: humanize(k), isMedia: isMediaField(k) });
        }
      }
    }
    return Array.from(seen.values());
  }, [features]);

  // Visibility state — load from prefs, default to first 6 non-media
  const [visible, setVisibleState] = useState<Set<string>>(new Set());

  useEffect(() => {
    const saved = getVisibleColumns(projectId);
    if (saved && saved.length > 0) {
      // Apply saved prefs, filter to columns that still exist
      const existing = new Set(allColumns.map((c) => c.id));
      const filtered = saved.filter((id) => existing.has(id));
      setVisibleState(new Set(filtered));
    } else if (allColumns.length > 0) {
      // Default: top 6 non-media columns
      const defaults = allColumns
        .filter((c) => !c.isMedia)
        .slice(0, 6)
        .map((c) => c.id);
      setVisibleState(new Set(defaults));
    }
  }, [allColumns, projectId]);

  const toggleColumn = (id: string) => {
    const next = new Set(visible);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setVisibleState(next);
    setVisibleColumns(projectId, Array.from(next));
  };

  const selectAllColumns = () => {
    const next = new Set(allColumns.map((c) => c.id));
    setVisibleState(next);
    setVisibleColumns(projectId, Array.from(next));
  };

  const resetColumns = () => {
    const defaults = allColumns
      .filter((c) => !c.isMedia)
      .slice(0, 6)
      .map((c) => c.id);
    const next = new Set(defaults);
    setVisibleState(next);
    setVisibleColumns(projectId, Array.from(next));
  };

  // Filter rows by search
  const filtered = useMemo(() => {
    if (!search.trim()) return features;
    const q = search.toLowerCase();
    return features.filter((f) => {
      const haystack = JSON.stringify(f.attributes || {}).toLowerCase();
      return haystack.includes(q);
    });
  }, [features, search]);

  const visibleColumns = allColumns.filter((c) => visible.has(c.id));

  return (
    <div className="flex flex-col gap-3 h-full">
      {/* Toolbar */}
      <div className="flex items-center justify-between gap-3 shrink-0">
        <div className="relative w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Filter rows by attribute…"
            className="w-full rounded-lg border border-gray-300 pl-9 pr-3 py-1.5 text-sm"
          />
        </div>

        <ColumnPicker
          allColumns={allColumns}
          visible={visible}
          onToggle={toggleColumn}
          onSelectAll={selectAllColumns}
          onReset={resetColumns}
        />
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-auto flex-1">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200 sticky top-0 z-10">
            <tr>
              <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs whitespace-nowrap">
                Status
              </th>
              <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs whitespace-nowrap">
                📎
              </th>
              {visibleColumns.map((c) => (
                <th
                  key={c.id}
                  className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs whitespace-nowrap"
                >
                  {c.label}
                </th>
              ))}
              <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs whitespace-nowrap">
                Collected
              </th>
              <th className="text-right px-3 py-2.5 font-medium text-gray-600 text-xs whitespace-nowrap">
                Review
              </th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((f) => (
              <tr
                key={f.id}
                onClick={() => onSelectFeature(f)}
                className="border-b border-gray-100 hover:bg-blue-50/30 cursor-pointer"
              >
                <td className="px-3 py-2 whitespace-nowrap">
                  <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusPill(f.status)}`}>
                    {f.status}
                  </span>
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  <AttachmentBadge projectId={projectId} featureId={f.id} />
                </td>
                {visibleColumns.map((c) => {
                  const value = f.attributes?.[c.id];
                  return (
                    <td
                      key={c.id}
                      className="px-3 py-2 text-gray-700 text-xs max-w-[200px] truncate"
                      title={String(value ?? "")}
                    >
                      {renderCell(c, value)}
                    </td>
                  );
                })}
                <td className="px-3 py-2 text-xs text-gray-500 whitespace-nowrap">
                  {f.collected_at
                    ? new Date(f.collected_at).toLocaleString()
                    : "—"}
                </td>
                <td className="px-3 py-2 text-right whitespace-nowrap" onClick={(e) => e.stopPropagation()}>
                  {f.status === "submitted" && (
                    <div className="inline-flex items-center gap-1.5">
                      <button
                        onClick={() => onReview(f.id, "approved")}
                        className="rounded bg-green-50 px-2 py-1 text-xs text-green-700 hover:bg-green-100 flex items-center gap-1"
                      >
                        <Check className="h-3 w-3" />
                        Approve
                      </button>
                      <button
                        onClick={() => onReview(f.id, "rejected")}
                        className="rounded bg-red-50 px-2 py-1 text-xs text-red-700 hover:bg-red-100 flex items-center gap-1"
                      >
                        <X className="h-3 w-3" />
                        Reject
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td
                  colSpan={visibleColumns.length + 4}
                  className="px-4 py-12 text-center text-gray-400"
                >
                  {search ? "No matches for your filter." : "No data collected yet."}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function renderCell(col: { id: string; isMedia: boolean }, value: any): string {
  if (value == null) return "—";
  if (col.isMedia) {
    // Show short summary for media attributes
    if (typeof value === "string" && value.length < 40) return value;
    return "📎 attachment";
  }
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

// Attachment count badge per row
function AttachmentBadge({ projectId, featureId }: { projectId: string; featureId: string }) {
  const { data } = useQuery({
    queryKey: ["attachments", featureId],
    queryFn: () => api.listFeatureAttachments(projectId, featureId),
    enabled: !!featureId,
  });
  const list = Array.isArray(data) ? data : [];
  if (list.length === 0) {
    return <span className="text-xs text-gray-300">—</span>;
  }
  return (
    <span className="inline-flex items-center rounded bg-blue-50 px-1.5 py-0.5 text-xs text-blue-700">
      {list.length}
    </span>
  );
}