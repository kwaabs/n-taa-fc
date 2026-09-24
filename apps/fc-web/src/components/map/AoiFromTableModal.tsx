import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { X, Search, Loader2 } from "lucide-react";

interface Props {
  projectId: string;
  onApply: (geometry: any, layerId: string) => void;
  onClose: () => void;
}

const ID_COLS = new Set([
  "ogc_fid",
  "objectid",
  "globalid",
  "fid",
  "gid",
  "id",
]);

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

function formatCell(v: unknown): string {
  if (v == null) return "—";
  if (typeof v === "object") return JSON.stringify(v);
  const s = String(v);
  return s.trim() === "" ? "—" : s;
}

export function AoiFromTableModal({ projectId, onApply, onClose }: Props) {
  const [layerId, setLayerId] = useState("");
  const [search, setSearch] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [page, setPage] = useState(0);
  const [building, setBuilding] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const pageSize = 50;

  useEffect(() => {
    const t = window.setTimeout(() => setDebouncedQ(search.trim()), 300);
    return () => window.clearTimeout(t);
  }, [search]);

  useEffect(() => {
    setPage(0);
    setSelected(new Set());
  }, [layerId, debouncedQ]);

  const { data: layers = [], isLoading: layersLoading } = useQuery({
    queryKey: ["projectLayers", projectId],
    queryFn: () => api.getProjectLayers(projectId),
  });

  const polygonLayers = useMemo(
    () =>
      (Array.isArray(layers) ? layers : []).filter(
        (l: any) =>
          l.source_type === "linked_table" &&
          String(l.geometry_type || "").toLowerCase() === "polygon",
      ),
    [layers],
  );

  const selectedLayer = polygonLayers.find((l: any) => l.id === layerId);

  const configuredCols = useMemo(() => {
    try {
      const cfg =
        typeof selectedLayer?.source_config === "string"
          ? JSON.parse(selectedLayer.source_config)
          : selectedLayer?.source_config;
      const geom = cfg?.geometry_column;
      const cols = Array.isArray(cfg?.included_columns)
        ? cfg.included_columns.filter(
            (c: string) => typeof c === "string" && c !== geom,
          )
        : [];
      return cols as string[];
    } catch {
      return [] as string[];
    }
  }, [selectedLayer]);

  const { data: rowsResp, isLoading: rowsLoading, isFetching } = useQuery({
    queryKey: ["aoiLayerRows", projectId, layerId, page, debouncedQ],
    queryFn: () =>
      api.getLinkedLayerRows(projectId, layerId, {
        limit: pageSize,
        offset: page * pageSize,
        q: debouncedQ || undefined,
      }),
    enabled: !!layerId,
  });

  const rows = Array.isArray(rowsResp?.data)
    ? rowsResp.data
    : Array.isArray(rowsResp)
      ? rowsResp
      : [];

  // Prefer configured columns; fall back to keys present on the page (skip geom-ish).
  const columns = useMemo(() => {
    if (configuredCols.length > 0) {
      // Put human-friendly cols first (name/district/region), ids last.
      const nice = configuredCols.filter((c) => !ID_COLS.has(c.toLowerCase()));
      const ids = configuredCols.filter((c) => ID_COLS.has(c.toLowerCase()));
      return [...nice, ...ids];
    }
    const keys = new Set<string>();
    for (const r of rows.slice(0, 30)) {
      for (const k of Object.keys(r?.attributes || {})) keys.add(k);
    }
    const all = Array.from(keys);
    const nice = all.filter((c) => !ID_COLS.has(c.toLowerCase())).sort();
    const ids = all.filter((c) => ID_COLS.has(c.toLowerCase())).sort();
    return [...nice, ...ids];
  }, [configuredCols, rows]);

  const hasNext = rows.length >= pageSize;
  const pageLabel = `Page ${page + 1}`;

  const toggle = (ref: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(ref)) next.delete(ref);
      else next.add(ref);
      return next;
    });
  };

  const togglePage = () => {
    const refs = rows
      .map((r: any) => String(r.source_ref || r.id || ""))
      .filter(Boolean);
    const allOn = refs.every((r: string) => selected.has(r));
    setSelected((prev) => {
      const next = new Set(prev);
      for (const r of refs) {
        if (allOn) next.delete(r);
        else next.add(r);
      }
      return next;
    });
  };

  const handleApply = async () => {
    if (!layerId || selected.size === 0) return;
    setBuilding(true);
    setError(null);
    try {
      const res = await api.buildAOIFromLayer(projectId, {
        layer_id: layerId,
        source_refs: [...selected],
      });
      const geom = res?.geometry ?? res;
      if (!geom || typeof geom !== "object") {
        throw new Error("Server returned empty geometry");
      }
      // Server persists AOI + locks the layer; pass layerId so Settings keeps aoi_layer_id.
      onApply(geom, res?.layer_id || layerId);
    } catch (e: any) {
      setError(e?.message || "Failed to build AOI from selection");
    } finally {
      setBuilding(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[85vh] flex flex-col">
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              Select from polygon table
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">
              Pick one or more polygons (e.g. districts). They are unioned into the
              project AOI. The chosen layer is locked for field insert, update, and
              delete.
            </p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="px-5 py-4 flex flex-col gap-3 flex-1 min-h-0 overflow-hidden">
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">
              Polygon layer
            </label>
            {layersLoading ? (
              <p className="text-sm text-gray-500">Loading layers…</p>
            ) : polygonLayers.length === 0 ? (
              <p className="text-sm text-amber-800 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
                No linked polygon layers in this project. Link a districts (or similar)
                table first, then return here.
              </p>
            ) : (
              <select
                value={layerId}
                onChange={(e) => setLayerId(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">Choose a layer…</option>
                {polygonLayers.map((l: any) => (
                  <option key={l.id} value={l.id}>
                    {l.name}
                  </option>
                ))}
              </select>
            )}
          </div>

          {layerId && (
            <>
              <div className="relative">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search across columns…"
                  className="w-full rounded-lg border border-gray-300 pl-8 pr-3 py-2 text-sm"
                />
              </div>

              <div className="flex items-center justify-between text-xs text-gray-500">
                <span>
                  {selected.size} selected
                  {isFetching ? " · searching…" : ` · showing ${rows.length}`}
                  {columns.length > 0
                    ? ` · columns: ${columns.map(humanize).join(", ")}`
                    : ""}
                </span>
                <button
                  type="button"
                  onClick={togglePage}
                  className="text-blue-600 hover:underline"
                  disabled={rows.length === 0}
                >
                  Toggle page
                </button>
              </div>

              <div className="flex-1 min-h-0 overflow-auto rounded-lg border border-gray-200">
                {rowsLoading ? (
                  <div className="flex items-center justify-center py-10 text-gray-500 text-sm gap-2">
                    <Loader2 className="h-4 w-4 animate-spin" /> Loading rows…
                  </div>
                ) : rows.length === 0 ? (
                  <p className="text-sm text-gray-500 text-center py-10">
                    No rows match.
                  </p>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 border-b border-gray-200 sticky top-0">
                      <tr>
                        <th className="text-left px-3 py-2 font-medium text-gray-600 text-xs w-8">
                          <span className="sr-only">Select</span>
                        </th>
                        {columns.map((c) => (
                          <th
                            key={c}
                            className="text-left px-3 py-2 font-medium text-gray-600 text-xs whitespace-nowrap"
                          >
                            {humanize(c)}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {rows.map((r: any) => {
                        const ref = String(r.source_ref || r.id || "");
                        const checked = selected.has(ref);
                        const attrs = r.attributes || {};
                        return (
                          <tr
                            key={ref}
                            onClick={() => toggle(ref)}
                            className={`border-b border-gray-100 cursor-pointer ${
                              checked ? "bg-blue-50/60" : "hover:bg-gray-50"
                            }`}
                          >
                            <td
                              className="px-3 py-2"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <input
                                type="checkbox"
                                checked={checked}
                                onChange={() => toggle(ref)}
                              />
                            </td>
                            {columns.map((c) => (
                              <td
                                key={c}
                                className="px-3 py-2 text-gray-800 text-xs truncate max-w-[200px]"
                                title={formatCell(attrs[c])}
                              >
                                {formatCell(attrs[c])}
                              </td>
                            ))}
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                )}
              </div>

              <div className="flex items-center justify-between">
                <button
                  type="button"
                  disabled={page <= 0}
                  onClick={() => setPage((p) => Math.max(0, p - 1))}
                  className="text-xs text-gray-600 disabled:opacity-40"
                >
                  Previous
                </button>
                <span className="text-xs text-gray-500">{pageLabel}</span>
                <button
                  type="button"
                  disabled={!hasNext}
                  onClick={() => setPage((p) => p + 1)}
                  className="text-xs text-gray-600 disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </>
          )}

          {error && (
            <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
              {error}
            </p>
          )}
        </div>

        <div className="px-5 py-3 border-t border-gray-200 flex gap-2 justify-end">
          <button
            onClick={onClose}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => void handleApply()}
            disabled={!layerId || selected.size === 0 || building}
            className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            {building
              ? "Saving…"
              : `Use ${selected.size || ""} selected as AOI`}
          </button>
        </div>
      </div>
    </div>
  );
}
