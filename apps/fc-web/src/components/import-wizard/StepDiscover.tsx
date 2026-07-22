import { useEffect, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { RefreshCw, Map, Table as TableIcon, AlertCircle, Search } from "lucide-react";
import type { ConnectionRef, DiscoveredTable } from "./types";

interface Props {
  projectId: string;
  connection: ConnectionRef;
  discovered: DiscoveredTable[];
  selected: string[];
  onDiscovered: (tables: DiscoveredTable[]) => void;
  onSelectionChange: (qns: string[]) => void;
}

export function StepDiscover({
  projectId, connection, discovered, selected,
  onDiscovered, onSelectionChange,
}: Props) {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<"all" | "spatial" | "non_spatial">("spatial");

  const discoverMutation = useMutation({
    mutationFn: () => api.discoverTables(projectId, connection),
    onSuccess: (result: any) => {
      onDiscovered(result.tables || []);
    },
  });

  // Auto-run on first mount
  useEffect(() => {
    if (discovered.length === 0 && !discoverMutation.isPending) {
      discoverMutation.mutate();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggle = (qn: string) => {
    if (selected.includes(qn)) {
      onSelectionChange(selected.filter((s) => s !== qn));
    } else {
      onSelectionChange([...selected, qn]);
    }
  };

  const selectAll = (subset: DiscoveredTable[]) => {
    const qns = subset.map((t) => t.qualified_name);
    const allSelected = qns.every((qn) => selected.includes(qn));
    if (allSelected) {
      onSelectionChange(selected.filter((s) => !qns.includes(s)));
    } else {
      const next = new Set([...selected, ...qns]);
      onSelectionChange(Array.from(next));
    }
  };

  const filtered = discovered.filter((t) => {
    if (filter === "spatial" && !t.is_spatial) return false;
    if (filter === "non_spatial" && t.is_spatial) return false;
    if (search) {
      const q = search.toLowerCase();
      return t.qualified_name.toLowerCase().includes(q);
    }
    return true;
  });

  const spatialCount = discovered.filter((t) => t.is_spatial).length;
  const nonSpatialCount = discovered.length - spatialCount;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          {discoverMutation.isPending
            ? "Scanning the database..."
            : discovered.length > 0
            ? `Found ${spatialCount} spatial and ${nonSpatialCount} other tables.`
            : "Click Refresh to scan."}
        </p>
        <button
          onClick={() => discoverMutation.mutate()}
          disabled={discoverMutation.isPending}
          className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${discoverMutation.isPending ? "animate-spin" : ""}`} />
          Refresh
        </button>
      </div>

      {discoverMutation.isError && (
        <div className="rounded-lg bg-red-50 border border-red-200 p-3 flex items-start gap-2">
          <AlertCircle className="h-4 w-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-sm text-red-700 font-mono">
            {(discoverMutation.error as Error).message}
          </p>
        </div>
      )}

      {/* Filters */}
      {discovered.length > 0 && (
        <div className="flex items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Filter tables..."
              className="w-full rounded-lg border border-gray-300 pl-9 pr-3 py-2 text-sm"
            />
          </div>
          <div className="flex rounded-lg border border-gray-200 overflow-hidden">
            {(["spatial", "non_spatial", "all"] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-2 text-xs ${
                  filter === f
                    ? "bg-blue-50 text-blue-700 font-medium"
                    : "text-gray-600 hover:bg-gray-50"
                }`}
              >
                {f === "spatial" ? "Spatial only" : f === "non_spatial" ? "Non-spatial" : "All"}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Tables */}
      {filtered.length > 0 && (
        <div className="border border-gray-200 rounded-lg overflow-hidden">
          <div className="bg-gray-50 px-3 py-2 border-b border-gray-200 flex items-center gap-3">
            <input
              type="checkbox"
              checked={filtered.every((t) => selected.includes(t.qualified_name))}
              onChange={() => selectAll(filtered)}
            />
            <p className="text-xs font-medium text-gray-600">
              {selected.length} selected · click to toggle
            </p>
          </div>
          <div className="max-h-96 overflow-y-auto divide-y divide-gray-100">
            {filtered.map((t) => {
              const isSelected = selected.includes(t.qualified_name);
              return (
                <label
                  key={t.qualified_name}
                  className={`flex items-center gap-3 px-3 py-2.5 cursor-pointer hover:bg-blue-50/30 ${
                    isSelected ? "bg-blue-50/50" : ""
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={isSelected}
                    onChange={() => toggle(t.qualified_name)}
                  />
                  <div className="flex items-center gap-1.5 shrink-0">
                    {t.is_spatial ? (
                      <Map className="h-4 w-4 text-blue-600" />
                    ) : (
                      <TableIcon className="h-4 w-4 text-gray-400" />
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 font-mono truncate">
                      {t.qualified_name}
                    </p>
                    <p className="text-xs text-gray-500">
                      {t.is_spatial && (
                        <>
                          <span className="rounded bg-blue-100 text-blue-700 px-1.5 py-0.5 mr-1">
                            {t.geometry_type}
                          </span>
                          SRID {t.srid} ·{" "}
                        </>
                      )}
                      {t.row_count.toLocaleString()} rows ·{" "}
                      {t.columns?.length || 0} columns
                    </p>
                  </div>
                </label>
              );
            })}
          </div>
        </div>
      )}

      {filtered.length === 0 && discovered.length > 0 && !discoverMutation.isPending && (
        <p className="text-sm text-gray-400 italic text-center py-6">
          No tables match your filter
        </p>
      )}
    </div>
  );
}