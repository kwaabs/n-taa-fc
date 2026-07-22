import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  X,
  Eye,
  AlertCircle,
  CheckCircle2,
  ArrowRight,
  Database,
  Loader2,
  PlayCircle,
} from "lucide-react";

import { api } from "@/lib/api";

interface Props {
  projectId: string;
  layerId: string;
  dataSource: any | null;
  onClose: () => void;
  onProceedToApply: (preview: any) => void;
}

export function ReconcilePreviewDrawer({
  projectId,
  layerId,
  dataSource,
  onClose,
  onProceedToApply,
}: Props) {
  const [activeTab, setActiveTab] = useState<"safe" | "conflicts">("safe");

  const previewMutation = useMutation({
    mutationFn: async () => {
      if (!dataSource) throw new Error("no data source");
      return api.previewReconciliation(projectId, layerId, dataSource.id);
    },
    onError: (err: any) => {
      toast.error("Preview failed", {
        description: err?.message ?? "Could not run preview.",
      });
    },
  });

  const preview = previewMutation.data;
  const isRunning = previewMutation.isPending;
  const hasResult = !!preview;

  if (!dataSource) return null;

  const summary = preview?.summary ?? {};
  const byType = preview?.by_change_type ?? {};
  const sampleSafe = preview?.sample_safe ?? [];
  const sampleConflicts = preview?.sample_conflicts ?? [];

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/30" />

      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-xl bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">Reconcile Preview</p>
            <p className="text-sm font-semibold text-gray-900 truncate">
              {dataSource.name}
            </p>
            <p className="text-[11px] font-mono text-gray-400 truncate">
              {dataSource.config?.schema}.{dataSource.config?.table}
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 shrink-0"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-5 flex flex-col gap-4">
          {!hasResult && !isRunning && (
            <div className="rounded-lg border border-dashed border-gray-300 p-8 text-center">
              <Eye className="h-10 w-10 mx-auto text-gray-300 mb-3" />
              <h3 className="text-base font-medium text-gray-900">
                Dry-run reconciliation
              </h3>
              <p className="text-sm text-gray-500 mt-1 max-w-md mx-auto">
                Read-only check: connects to the source DB, compares pending
                changes against current state, surfaces conflicts. No writes.
              </p>
              <button
                onClick={() => previewMutation.mutate()}
                className="mt-4 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
              >
                <Eye className="h-4 w-4" />
                Run preview
              </button>
            </div>
          )}

          {isRunning && (
            <div className="rounded-lg border border-blue-200 bg-blue-50 p-6 text-center">
              <Loader2 className="h-8 w-8 mx-auto text-blue-600 animate-spin mb-2" />
              <p className="text-sm text-blue-900">
                Running preview… this may take a moment for large data sources.
              </p>
            </div>
          )}

          {hasResult && (
            <>
              {/* Summary cards */}
              <div className="grid grid-cols-2 gap-2">
                <SummaryCard
                  label="Total pending"
                  value={summary.total_pending ?? 0}
                  color="gray"
                />
                <SummaryCard
                  label="Safe to apply"
                  value={summary.safe_to_apply ?? 0}
                  color="green"
                  icon={<CheckCircle2 className="h-4 w-4" />}
                />
                <SummaryCard
                  label="Conflicts"
                  value={summary.conflicts ?? 0}
                  color="amber"
                  icon={<AlertCircle className="h-4 w-4" />}
                />
                <SummaryCard
                  label="Already applied"
                  value={summary.already_applied ?? 0}
                  color="blue"
                />
              </div>

              {/* By change type */}
              <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
                <p className="text-xs font-medium text-gray-600 mb-2">
                  By change type
                </p>
                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div>
                    <p className="text-gray-500 mb-1">Updates</p>
                    <p>
                      <span className="text-green-600 font-medium">
                        {byType.updated?.safe ?? 0} safe
                      </span>{" "}
                      ·{" "}
                      <span className="text-amber-700 font-medium">
                        {byType.updated?.conflict ?? 0} conflict
                      </span>
                    </p>
                  </div>
                  <div>
                    <p className="text-gray-500 mb-1">Deletes</p>
                    <p>
                      <span className="text-green-600 font-medium">
                        {byType.deleted?.safe ?? 0} safe
                      </span>{" "}
                      ·{" "}
                      <span className="text-amber-700 font-medium">
                        {byType.deleted?.conflict ?? 0} conflict
                      </span>
                    </p>
                  </div>
                </div>
              </div>

              {/* Sample tabs */}
              {(sampleSafe.length > 0 || sampleConflicts.length > 0) && (
                <div className="rounded-lg border border-gray-200">
                  <div className="flex border-b border-gray-200">
                    <button
                      onClick={() => setActiveTab("safe")}
                      className={
                        "flex-1 px-3 py-2 text-xs font-medium border-b-2 transition-colors " +
                        (activeTab === "safe"
                          ? "border-green-500 text-green-700"
                          : "border-transparent text-gray-500 hover:text-gray-700")
                      }
                    >
                      Safe ({sampleSafe.length})
                    </button>
                    <button
                      onClick={() => setActiveTab("conflicts")}
                      className={
                        "flex-1 px-3 py-2 text-xs font-medium border-b-2 transition-colors " +
                        (activeTab === "conflicts"
                          ? "border-amber-500 text-amber-700"
                          : "border-transparent text-gray-500 hover:text-gray-700")
                      }
                    >
                      Conflicts ({sampleConflicts.length})
                    </button>
                  </div>

                  <div className="p-3 max-h-72 overflow-y-auto">
                    {activeTab === "safe" && (
                      <SampleList rows={sampleSafe} variant="safe" />
                    )}
                    {activeTab === "conflicts" && (
                      <SampleList rows={sampleConflicts} variant="conflict" />
                    )}
                  </div>
                </div>
              )}

              {summary.total_pending === 0 && (
                <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 text-center">
                  <Database className="h-8 w-8 mx-auto text-gray-300 mb-2" />
                  <p className="text-sm text-gray-700 font-medium">
                    Nothing to reconcile
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Either no pending changes, or all have already been applied.
                  </p>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-gray-200 bg-white shrink-0">
          <div className="flex gap-2 w-full">
            <button
              onClick={onClose}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Close
            </button>
            {hasResult && (summary.safe_to_apply ?? 0) > 0 && (
              <button
                onClick={() => onProceedToApply(preview)}
                className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700"
              >
                <PlayCircle className="h-4 w-4" />
                Apply ({summary.safe_to_apply} ready)
                <ArrowRight className="h-3.5 w-3.5" />
              </button>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

function SummaryCard({
  label,
  value,
  color,
  icon,
}: {
  label: string;
  value: number;
  color: "gray" | "green" | "amber" | "blue";
  icon?: React.ReactNode;
}) {
  const colorMap = {
    gray: "bg-gray-50 text-gray-900 border-gray-200",
    green: "bg-green-50 text-green-900 border-green-200",
    amber: "bg-amber-50 text-amber-900 border-amber-200",
    blue: "bg-blue-50 text-blue-900 border-blue-200",
  };
  return (
    <div className={`rounded-lg border p-3 ${colorMap[color]}`}>
      <div className="flex items-center gap-1.5 text-xs font-medium">
        {icon}
        {label}
      </div>
      <p className="text-2xl font-semibold mt-1 tabular-nums">{value}</p>
    </div>
  );
}

function SampleList({
  rows,
  variant,
}: {
  rows: any[];
  variant: "safe" | "conflict";
}) {
  if (rows.length === 0) {
    return (
      <p className="text-xs text-gray-400 italic text-center py-4">
        No {variant === "safe" ? "safe-to-apply" : "conflicting"} samples
      </p>
    );
  }
  return (
    <div className="flex flex-col gap-1.5">
      {rows.map((r, i) => (
        <div
          key={r.feature_id || i}
          className={
            "rounded border px-2.5 py-1.5 text-xs " +
            (variant === "safe"
              ? "border-green-100 bg-green-50/30"
              : "border-amber-100 bg-amber-50/30")
          }
        >
          <div className="flex items-center justify-between gap-2">
            <span className="font-mono text-gray-700 truncate">
              {r.source_ref}
            </span>
            <span
              className={
                "shrink-0 rounded-full px-1.5 py-0.5 text-[10px] font-medium " +
                (r.change_type === "deleted"
                  ? "bg-red-50 text-red-700"
                  : "bg-blue-50 text-blue-700")
              }
            >
              {r.change_type}
            </span>
          </div>
          {(r.changing_fields?.length > 0 ||
            r.conflicting_fields?.length > 0) && (
            <p className="text-[10px] text-gray-500 mt-0.5 truncate">
              fields:{" "}
              {(r.conflicting_fields ?? r.changing_fields ?? []).join(", ")}
            </p>
          )}
        </div>
      ))}
    </div>
  );
}