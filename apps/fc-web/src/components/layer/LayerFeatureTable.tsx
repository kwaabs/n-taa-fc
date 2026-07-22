import { useState, useMemo, useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Eye, ChevronLeft, ChevronRight, Search, Upload, X } from "lucide-react";
import { ExportMenu } from "@/components/data/ExportMenu";
import {
  FeatureQueryBuilder,
  emptyCondition,
  type AppliedFilter,
  type QueryCondition,
} from "./FeatureQueryBuilder";

function canWriteBack(feature: any, linked: boolean): boolean {
  if (linked || !feature?.id || feature.write_back_applied) return false;
  if (feature.change_type === "updated" || feature.change_type === "deleted") {
    return !!feature.source_ref;
  }
  return feature.change_type === "inserted";
}

interface Props {
  projectId: string;
  layerId: string;
  onSelectFeature: (feature: any) => void;
  /** When true, page live linked_table rows instead of public.features */
  linked?: boolean;
  /** Column names for the query builder (from layer source_config) */
  columns?: string[];
}

const PAGE_SIZE = 50;

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

export function LayerFeatureTable({
  projectId,
  layerId,
  onSelectFeature,
  linked = false,
  columns: propColumns = [],
}: Props) {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(0);
  const [searchInput, setSearchInput] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [draft, setDraft] = useState<QueryCondition[]>([]);
  const [appliedFilters, setAppliedFilters] = useState<AppliedFilter[]>([]);
  const [writeBackId, setWriteBackId] = useState<string | null>(null);
  const [writeBackNote, setWriteBackNote] = useState<string | null>(null);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkBusy, setBulkBusy] = useState(false);

  const invalidateAfterWriteBack = () => {
    queryClient.invalidateQueries({ queryKey: ["layerFeatures", layerId] });
    queryClient.invalidateQueries({ queryKey: ["layerSummary", layerId] });
    queryClient.invalidateQueries({ queryKey: ["reconcileSummary", layerId] });
    queryClient.invalidateQueries({
      queryKey: ["reconcileConflicts", layerId],
    });
  };

  const writeBack = useMutation({
    mutationFn: (featureId: string) =>
      api.writeBackFeature(projectId, layerId, featureId),
    onSuccess: (res) => {
      invalidateAfterWriteBack();
      if (res.outcome === "applied") {
        setWriteBackNote(`Wrote ${res.change_type} for ${res.source_ref}`);
      } else if (res.outcome === "conflict") {
        setWriteBackNote(res.reason || "Conflict — check Conflicts tab");
      } else {
        setWriteBackNote(res.reason || res.outcome);
      }
      setWriteBackId(null);
    },
    onError: (err: Error) => {
      setWriteBackNote(err.message || "Write-back failed");
      setWriteBackId(null);
    },
  });

  useEffect(() => {
    if (!linked) {
      const t = window.setTimeout(() => {
        setDebouncedQ(searchInput.trim());
        setPage(0);
      }, 300);
      return () => window.clearTimeout(t);
    }
  }, [searchInput, linked]);

  useEffect(() => {
    setPage(0);
  }, [appliedFilters]);

  const { data, isLoading, error, isFetching } = useQuery({
    queryKey: [
      linked ? "linkedLayerRows" : "layerFeatures",
      layerId,
      page,
      linked ? appliedFilters : debouncedQ,
    ],
    queryFn: () =>
      linked
        ? api.getLinkedLayerRows(projectId, layerId, {
            limit: PAGE_SIZE,
            offset: page * PAGE_SIZE,
            filters: appliedFilters.length ? appliedFilters : undefined,
          })
        : api.getLayerFeatures(projectId, layerId, {
            limit: PAGE_SIZE,
            offset: page * PAGE_SIZE,
          }),
  });

  const features: any[] = useMemo(() => {
    if (!data) return [];
    if (Array.isArray(data)) return data;
    return data.data || [];
  }, [data]);

  const discoveredColumns = useMemo(() => {
    if (propColumns.length > 0) return propColumns;
    const keys = new Set<string>();
    for (const f of features.slice(0, 20)) {
      for (const k of Object.keys(f.attributes || {})) keys.add(k);
    }
    return Array.from(keys).sort();
  }, [propColumns, features]);

  // Seed one empty condition once columns are known (linked only).
  useEffect(() => {
    if (!linked || draft.length > 0 || discoveredColumns.length === 0) return;
    setDraft([emptyCondition(discoveredColumns)]);
  }, [linked, discoveredColumns, draft.length]);

  const visibleFeatures = useMemo(() => {
    if (linked || !debouncedQ) return features;
    const q = debouncedQ.toLowerCase();
    return features.filter((f) => {
      const blob = JSON.stringify(f.attributes || {}).toLowerCase();
      return (
        blob.includes(q) ||
        String(f.id || "")
          .toLowerCase()
          .includes(q) ||
        String(f.source_ref || "")
          .toLowerCase()
          .includes(q) ||
        String(f.status || "")
          .toLowerCase()
          .includes(q)
      );
    });
  }, [features, linked, debouncedQ]);

  const total = linked
    ? data?.meta?.total ?? features.length
    : debouncedQ
      ? visibleFeatures.length
      : data?.meta?.total ?? features.length;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const tableColumns = useMemo(() => {
    const sample = linked ? features : visibleFeatures;
    if (sample.length === 0) return discoveredColumns.slice(0, linked ? 8 : 6);
    const allKeys = new Set<string>();
    for (const f of sample.slice(0, 10)) {
      for (const k of Object.keys(f.attributes || {})) {
        allKeys.add(k);
      }
    }
    return Array.from(allKeys).slice(0, linked ? 8 : 6);
  }, [features, visibleFeatures, linked, discoveredColumns]);

  const rows = linked ? features : visibleFeatures;

  const eligibleOnPage = useMemo(
    () => rows.filter((f) => canWriteBack(f, linked)),
    [rows, linked]
  );

  useEffect(() => {
    setSelectedIds(new Set());
  }, [page, linked, layerId, debouncedQ, appliedFilters]);

  const toggleSelected = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAllEligible = () => {
    const eligibleIds = eligibleOnPage.map((f) => f.id as string);
    const allSelected =
      eligibleIds.length > 0 && eligibleIds.every((id) => selectedIds.has(id));
    if (allSelected) {
      setSelectedIds(new Set());
      return;
    }
    setSelectedIds(new Set(eligibleIds));
  };

  const runBulkWriteBack = async () => {
    const ids = [...selectedIds].filter((id) =>
      eligibleOnPage.some((f) => f.id === id)
    );
    if (ids.length === 0) return;
    setBulkBusy(true);
    setWriteBackNote(null);
    let applied = 0;
    let failed = 0;
    let skipped = 0;
    let conflicts = 0;
    for (const id of ids) {
      try {
        const res = await api.writeBackFeature(projectId, layerId, id);
        if (res.outcome === "applied") applied++;
        else if (res.outcome === "conflict") conflicts++;
        else if (res.outcome === "skipped") skipped++;
        else failed++;
      } catch {
        failed++;
      }
    }
    setBulkBusy(false);
    setSelectedIds(new Set());
    invalidateAfterWriteBack();
    setWriteBackNote(
      `Bulk: ${applied} applied` +
        (conflicts ? `, ${conflicts} conflict` : "") +
        (skipped ? `, ${skipped} skipped` : "") +
        (failed ? `, ${failed} failed` : "")
    );
  };

  return (
    <div className="flex flex-col gap-3">
      {linked ? (
        <FeatureQueryBuilder
          fields={discoveredColumns}
          draft={draft}
          onDraftChange={setDraft}
          appliedCount={appliedFilters.length}
          busy={isFetching}
          onApply={(filters) => {
            setAppliedFilters(filters);
            setPage(0);
          }}
          onClear={() => {
            setAppliedFilters([]);
            setDraft(
              discoveredColumns.length
                ? [emptyCondition(discoveredColumns)]
                : []
            );
            setPage(0);
          }}
        />
      ) : (
        <div className="relative flex-1 min-w-[220px] max-w-md">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search attributes on this page…"
            className="w-full rounded-lg border border-gray-300 pl-8 pr-8 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          {searchInput && (
            <button
              type="button"
              onClick={() => setSearchInput("")}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
              aria-label="Clear search"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      )}

      <div className="flex items-center justify-between gap-3 flex-wrap">
        <p className="text-xs text-gray-500">
          {isFetching && !isLoading ? "Searching… · " : ""}
          {total.toLocaleString()} feature{total === 1 ? "" : "s"}
          {linked ? " · linked source" : ""}
          {linked && appliedFilters.length > 0
            ? ` · ${appliedFilters.length} filter${appliedFilters.length === 1 ? "" : "s"}`
            : ""}
          {!linked && debouncedQ ? ` matching “${debouncedQ}”` : ""}
          {writeBackNote ? ` · ${writeBackNote}` : ""}
        </p>
        <div className="flex items-center gap-2">
          {!linked && selectedIds.size > 0 && (
            <button
              type="button"
              disabled={bulkBusy}
              onClick={() => void runBulkWriteBack()}
              className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
            >
              <Upload className="h-3.5 w-3.5" />
              {bulkBusy
                ? "Writing back…"
                : `Write back selected (${selectedIds.size})`}
            </button>
          )}
          {!linked && (
            <ExportMenu
              projectId={projectId}
              features={rows}
              baseName="layer"
              scope={layerId.slice(0, 8)}
              size="sm"
            />
          )}
        </div>
      </div>

      {isLoading ? (
        <p className="text-sm text-gray-500 py-8 text-center">Loading features…</p>
      ) : error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-sm text-red-700">
          Failed to load features: {(error as Error).message}
        </div>
      ) : rows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-gray-300 p-12 text-center">
          <p className="text-base font-medium text-gray-700">
            {appliedFilters.length || debouncedQ
              ? "No matching features"
              : "No features yet"}
          </p>
          <p className="text-xs text-gray-500 mt-1">
            {appliedFilters.length || debouncedQ
              ? "Adjust or clear your query and try again."
              : linked
                ? "The linked source table returned no rows."
                : "Import data into this layer via Data Sources, or wait for field workers to collect."}
          </p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  {!linked && (
                    <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs w-8">
                      <input
                        type="checkbox"
                        aria-label="Select all pending write-backs"
                        checked={
                          eligibleOnPage.length > 0 &&
                          eligibleOnPage.every((f) => selectedIds.has(f.id))
                        }
                        disabled={eligibleOnPage.length === 0 || bulkBusy}
                        onChange={toggleSelectAllEligible}
                        onClick={(e) => e.stopPropagation()}
                      />
                    </th>
                  )}
                  {!linked && (
                    <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs">
                      Status
                    </th>
                  )}
                  <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs">
                    {linked ? "ID" : "Source"}
                  </th>
                  {!linked && (
                    <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs">
                      📎
                    </th>
                  )}
                  {tableColumns.map((c) => (
                    <th
                      key={c}
                      className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs"
                    >
                      {humanize(c)}
                    </th>
                  ))}
                  {!linked && (
                    <th className="text-left px-3 py-2.5 font-medium text-gray-600 text-xs">
                      Collected
                    </th>
                  )}
                  <th className="text-right px-3 py-2.5 font-medium text-gray-600 text-xs">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((f, idx) => (
                  <tr
                    key={f.id ?? f.source_ref ?? idx}
                    onClick={() => onSelectFeature(f)}
                    className="border-b border-gray-100 hover:bg-blue-50/30 cursor-pointer"
                  >
                    {!linked && (
                      <td
                        className="px-3 py-2"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <input
                          type="checkbox"
                          aria-label="Select for write-back"
                          checked={selectedIds.has(f.id)}
                          disabled={!canWriteBack(f, linked) || bulkBusy}
                          onChange={() => toggleSelected(f.id)}
                        />
                      </td>
                    )}
                    {!linked && (
                      <td className="px-3 py-2">
                        <div className="flex flex-wrap items-center gap-1">
                          <span
                            className={`rounded-full px-2 py-0.5 text-xs ${
                              f.status === "approved"
                                ? "bg-green-50 text-green-700"
                                : f.status === "rejected"
                                  ? "bg-red-50 text-red-700"
                                  : f.status === "submitted"
                                    ? "bg-blue-50 text-blue-700"
                                    : "bg-gray-100 text-gray-600"
                            }`}
                          >
                            {f.status}
                          </span>
                          {f.write_back_applied && (
                            <span className="rounded-full px-2 py-0.5 text-xs bg-emerald-50 text-emerald-700">
                              Written back
                            </span>
                          )}
                        </div>
                      </td>
                    )}
                    <td className="px-3 py-2">
                      {linked ? (
                        <span className="font-mono text-xs text-gray-800">
                          {f.source_ref || f.id || "—"}
                        </span>
                      ) : (
                        <span
                          className={`rounded-full px-2 py-0.5 text-xs ${
                            f.source === "reference"
                              ? "bg-blue-50 text-blue-700"
                              : "bg-green-50 text-green-700"
                          }`}
                        >
                          {f.source || "collected"}
                        </span>
                      )}
                    </td>
                    {!linked && (
                      <td className="px-3 py-2">
                        <AttachmentBadge
                          projectId={projectId}
                          featureId={f.id}
                        />
                      </td>
                    )}
                    {tableColumns.map((c) => {
                      const value = f.attributes?.[c];
                      return (
                        <td
                          key={c}
                          className="px-3 py-2 text-gray-700 text-xs truncate max-w-[160px]"
                          title={String(value ?? "")}
                        >
                          {value == null
                            ? "—"
                            : typeof value === "object"
                              ? JSON.stringify(value)
                              : String(value)}
                        </td>
                      );
                    })}
                    {!linked && (
                      <td className="px-3 py-2 text-xs text-gray-500">
                        {f.collected_at
                          ? new Date(f.collected_at).toLocaleDateString()
                          : "—"}
                      </td>
                    )}
                    <td className="px-3 py-2 text-right">
                      <div className="inline-flex items-center gap-1">
                        {canWriteBack(f, linked) && (
                          <button
                            type="button"
                            title="Write back to source"
                            disabled={
                              (writeBack.isPending && writeBackId === f.id) ||
                              bulkBusy
                            }
                            onClick={(e) => {
                              e.stopPropagation();
                              setWriteBackNote(null);
                              setWriteBackId(f.id);
                              writeBack.mutate(f.id);
                            }}
                            className="inline-flex items-center gap-1 rounded bg-emerald-50 px-2 py-1 text-xs text-emerald-700 hover:bg-emerald-100 disabled:opacity-50"
                          >
                            <Upload className="h-3 w-3" />
                            {writeBack.isPending && writeBackId === f.id
                              ? "…"
                              : "Write back"}
                          </button>
                        )}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onSelectFeature(f);
                          }}
                          className="inline-flex items-center gap-1 rounded bg-blue-50 px-2 py-1 text-xs text-blue-700 hover:bg-blue-100"
                        >
                          <Eye className="h-3 w-3" /> View
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="flex items-center justify-between px-3 py-2 border-t border-gray-100 bg-gray-50/50">
            <p className="text-xs text-gray-500">
              Showing {page * PAGE_SIZE + 1}–
              {Math.min((page + 1) * PAGE_SIZE, total).toLocaleString()} of{" "}
              {total.toLocaleString()}
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
                className="rounded border border-gray-300 p-1 hover:bg-gray-100 disabled:opacity-30"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              <span className="text-xs text-gray-600">
                Page {page + 1} of {totalPages}
              </span>
              <button
                onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                disabled={page >= totalPages - 1}
                className="rounded border border-gray-300 p-1 hover:bg-gray-100 disabled:opacity-30"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function AttachmentBadge({
  projectId,
  featureId,
}: {
  projectId: string;
  featureId: string;
}) {
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
    <span className="inline-flex items-center gap-0.5 rounded bg-blue-50 px-1.5 py-0.5 text-xs text-blue-700">
      📎 {list.length}
    </span>
  );
}
