import { useEffect, useRef, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  X,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Loader2,
  PlayCircle,
  StopCircle,
  Clock,
  AlertCircle,
} from "lucide-react";
import { JobLogDrawer } from "./JobLogDrawer";
import { api } from "@/lib/api";

interface Props {
  projectId: string;
  layerId: string;
  dataSource: any;
  preview: any;
  onClose: () => void;
}

type Phase = "confirm" | "running" | "done";

export function ApplyReconciliationModal({
  projectId,
  layerId,
  dataSource,
  preview,
  onClose,
}: Props) {
  const queryClient = useQueryClient();
  const [phase, setPhase] = useState<Phase>("confirm");
  const [jobId, setJobId] = useState<string | null>(null);
  const [job, setJob] = useState<any>(null);
  const [cancelling, setCancelling] = useState(false);
  const pollRef = useRef<number | null>(null);
  const [showLog, setShowLog] = useState(false);

  const [acks, setAcks] = useState<Record<string, boolean>>(() => {
    const next: Record<string, boolean> = {};
    for (const key of preview?.required_acknowledgments ?? []) next[key] = false;
    return next;
  });

  const safeCount = preview?.summary?.safe_to_apply ?? 0;
  const conflictCount = preview?.summary?.conflicts ?? 0;
  const schema = dataSource?.config?.schema ?? "—";
  const table = dataSource?.config?.table ?? "—";
  const requiredAcks: string[] = preview?.required_acknowledgments ?? [];
  const applyBlocked = !!preview?.apply_blocked;
  const allAcksChecked =
    requiredAcks.length === 0 || requiredAcks.every((k) => acks[k]);
  const canApply = safeCount > 0 && !applyBlocked && allAcksChecked;

  const applyMutation = useMutation({
    mutationFn: async () => {
      return api.applyReconciliation(
        projectId,
        layerId,
        dataSource.id,
        undefined,
        undefined,
        Object.entries(acks)
          .filter(([, v]) => v)
          .map(([k]) => k),
      );
    },
    onSuccess: (resp: any) => {
      // Backend returns { job_id, status, ... }
      const id = resp?.job_id;
      if (!id) {
        toast.error("Apply enqueue failed", {
          description: "No job ID returned by server.",
        });
        return;
      }
      setJobId(id);
      setPhase("running");
    },
    onError: (err: any) => {
      toast.error("Apply failed to start", {
        description: err?.message ?? "Could not enqueue apply job.",
      });
    },
  });

  // Poll job status while running
  useEffect(() => {
    if (phase !== "running" || !jobId) return;

    const poll = async () => {
      try {
        const j = await api.getReconciliationJob(projectId, jobId);
        setJob(j);
        // Terminal statuses
        if (
          j?.status === "success" ||
          j?.status === "partial" ||
          j?.status === "failed" ||
          j?.status === "cancelled"
        ) {
          if (pollRef.current) {
            window.clearInterval(pollRef.current);
            pollRef.current = null;
          }
          setPhase("done");
          // Refresh data source list (pending counts change)
          queryClient.invalidateQueries({
            queryKey: ["dataSources", layerId],
          });
        }
      } catch (e: any) {
        // Keep polling; transient errors are normal
        console.warn("[reconcile] poll error", e?.message);
      }
    };

    poll(); // initial
    pollRef.current = window.setInterval(poll, 1500);
    return () => {
      if (pollRef.current) {
        window.clearInterval(pollRef.current);
        pollRef.current = null;
      }
    };
  }, [phase, jobId, projectId, layerId, queryClient]);

  const handleCancel = async () => {
    if (!jobId || cancelling) return;
    setCancelling(true);
    try {
      await api.cancelReconciliationJob(projectId, jobId);
      toast.info("Cancel requested", {
        description:
          "Worker will stop between chunks — applied rows stay applied.",
      });
    } catch (e: any) {
      toast.error("Cancel failed", {
        description: e?.message ?? "Could not cancel job.",
      });
    } finally {
      setCancelling(false);
    }
  };

  // Live counters
  const applied = (job?.updates_succeeded ?? 0) + (job?.deletes_succeeded ?? 0);
  const attempted =
    (job?.updates_attempted ?? 0) + (job?.deletes_attempted ?? 0);
  const failed = job?.errors ?? 0;
  const newConflicts = job?.conflicts_detected ?? 0;
  const total = job?.changes_total ?? safeCount;
  const pct = total > 0 ? Math.min(100, Math.round((applied / total) * 100)) : 0;

  // Final status mapping
  const finalStatus = job?.status as string | undefined;
  const isTerminalSuccess = finalStatus === "success";
  const isTerminalPartial = finalStatus === "partial";
  const isTerminalFailed = finalStatus === "failed";
  const isTerminalCancelled = finalStatus === "cancelled";

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40 bg-black/40" />

      {/* Centered Modal */}
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
        <div className="bg-white rounded-xl shadow-2xl w-full max-w-md pointer-events-auto flex flex-col">
          {/* Header */}
          <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200">
            <div className="min-w-0">
              <p className="text-xs text-gray-500">
                {phase === "confirm" && "Confirm Apply"}
                {phase === "running" && "Applying changes…"}
                {phase === "done" && "Apply complete"}
              </p>
              <p className="text-sm font-semibold text-gray-900 truncate">
                {dataSource.name}
              </p>
              <p className="text-[11px] font-mono text-gray-400 truncate">
                {schema}.{table}
              </p>
            </div>
            {phase !== "running" && (
              <button
                onClick={onClose}
                className="text-gray-400 hover:text-gray-600 shrink-0"
              >
                <X className="h-5 w-5" />
              </button>
            )}
          </div>

          {/* Body */}
          <div className="px-5 py-4">
            {/* ── Confirm phase ────────────────── */}
            {phase === "confirm" && (
              <div className="flex flex-col gap-3">
                <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 flex items-start gap-2">
                  <AlertTriangle className="h-4 w-4 text-amber-700 mt-0.5 shrink-0" />
                  <div className="text-xs text-amber-900">
                    <p className="font-medium">
                      About to apply {safeCount} change
                      {safeCount === 1 ? "" : "s"} to{" "}
                      <span className="font-mono">
                        {schema}.{table}
                      </span>
                      .
                    </p>
                    <ul className="mt-1.5 list-disc list-inside space-y-0.5">
                      <li>Source DB rows will be modified in place.</li>
                      <li>
                        This is irreversible without restoring from backup.
                      </li>
                      <li>An audit log row will be written per change.</li>
                    </ul>
                  </div>
                </div>

                {conflictCount > 0 && (
                  <div className="rounded-lg border border-gray-200 bg-gray-50 p-3 flex items-start gap-2">
                    <AlertCircle className="h-4 w-4 text-gray-500 mt-0.5 shrink-0" />
                    <p className="text-xs text-gray-700">
                      <strong>{conflictCount} conflict</strong>
                      {conflictCount === 1 ? "" : "s"} will be skipped. Resolve
                      them on the Conflicts page before reapplying.
                    </p>
                  </div>
                )}
              </div>
            )}

            {/* ── Running phase ────────────────── */}
            {phase === "running" && (
              <div className="flex flex-col gap-3">
                <div className="flex items-center gap-2 text-sm text-blue-900">
                  <Loader2 className="h-4 w-4 text-blue-600 animate-spin" />
                  {job?.status === "pending"
                    ? "Job queued, waiting for worker…"
                    : "Worker processing chunks…"}
                </div>

                {/* Progress bar */}
                <div className="space-y-1">
                  <div className="flex justify-between text-xs text-gray-600">
                    <span>
                      {applied} of {total} applied
                    </span>
                    <span>{pct}%</span>
                  </div>
                  <div className="w-full h-2 rounded-full bg-gray-100 overflow-hidden">
                    <div
                      className="h-full bg-blue-600 transition-all duration-300"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>

                {/* Live counters */}
                <div className="grid grid-cols-3 gap-2">
                  <CounterTile
                    label="Applied"
                    value={applied}
                    color="green"
                  />
                  <CounterTile
                    label="Failed"
                    value={failed}
                    color="red"
                  />
                  <CounterTile
                    label="Conflicts"
                    value={newConflicts}
                    color="amber"
                  />
                </div>

                {attempted > 0 && attempted !== applied && (
                  <p className="text-[11px] text-gray-500">
                    {attempted - applied} change
                    {attempted - applied === 1 ? "" : "s"} in flight…
                  </p>
                )}
              </div>
            )}

            {/* ── Done phase ────────────────── */}
            {phase === "done" && (
              <div className="flex flex-col gap-3">
                <div
                  className={
                    "rounded-lg p-4 flex flex-col items-center text-center " +
                    (isTerminalSuccess
                      ? "bg-green-50 border border-green-200"
                      : isTerminalCancelled
                        ? "bg-gray-50 border border-gray-200"
                        : isTerminalFailed
                          ? "bg-red-50 border border-red-200"
                          : "bg-amber-50 border border-amber-200")
                  }
                >
                  {isTerminalSuccess && (
                    <CheckCircle2 className="h-10 w-10 text-green-600 mb-2" />
                  )}
                  {isTerminalPartial && (
                    <AlertCircle className="h-10 w-10 text-amber-600 mb-2" />
                  )}
                  {isTerminalFailed && (
                    <XCircle className="h-10 w-10 text-red-600 mb-2" />
                  )}
                  {isTerminalCancelled && (
                    <StopCircle className="h-10 w-10 text-gray-500 mb-2" />
                  )}

                  <p
                    className={
                      "text-sm font-semibold " +
                      (isTerminalSuccess
                        ? "text-green-900"
                        : isTerminalCancelled
                          ? "text-gray-700"
                          : isTerminalFailed
                            ? "text-red-900"
                            : "text-amber-900")
                    }
                  >
                    {isTerminalSuccess &&
                      `All ${applied} change${applied === 1 ? "" : "s"} applied`}
                    {isTerminalPartial &&
                      `Partial — ${applied} applied, ${failed + newConflicts} skipped`}
                    {isTerminalFailed &&
                      `Failed — ${job?.error_message ?? "see job log"}`}
                    {isTerminalCancelled &&
                      `Cancelled — ${applied} applied before stop`}
                  </p>
                  {job?.error_message && !isTerminalFailed && (
                    <p className="text-[11px] text-gray-600 mt-1 font-mono">
                      {job.error_message}
                    </p>
                  )}
                </div>

                {/* Detail counters */}
                <div className="grid grid-cols-2 gap-2">
                  <FinalTile
                    label="Updates"
                    succeeded={job?.updates_succeeded ?? 0}
                    attempted={job?.updates_attempted ?? 0}
                  />
                  <FinalTile
                    label="Deletes"
                    succeeded={job?.deletes_succeeded ?? 0}
                    attempted={job?.deletes_attempted ?? 0}
                  />
                </div>

                {(failed > 0 || newConflicts > 0) && (
                  <div className="rounded-lg border border-gray-200 bg-gray-50 p-3 text-xs text-gray-700 space-y-1">
                    {failed > 0 && (
                      <p className="flex items-center gap-1.5">
                        <XCircle className="h-3 w-3 text-red-600" />
                        {failed} failed —{" "}
                        <span className="text-gray-500">
                          check job log for reasons
                        </span>
                      </p>
                    )}
                    {newConflicts > 0 && (
                      <p className="flex items-center gap-1.5">
                        <AlertCircle className="h-3 w-3 text-amber-600" />
                        {newConflicts} new conflict
                        {newConflicts === 1 ? "" : "s"} —{" "}
                        <span className="text-gray-500">
                          source changed during apply
                        </span>
                      </p>
                    )}
                  </div>
                )}

                {jobId && (
                  <p className="text-[11px] text-gray-400 font-mono">
                    Job: {jobId}
                  </p>
                )}
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="px-5 py-3 border-t border-gray-200 bg-white">
            {phase === "confirm" && (
              <div className="flex gap-2 w-full">
                <button
                  onClick={onClose}
                  className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={() => applyMutation.mutate()}
                  disabled={applyMutation.isPending || !canApply}
                  className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <PlayCircle className="h-4 w-4" />
                  {applyMutation.isPending
                    ? "Starting…"
                    : `Apply ${safeCount} change${safeCount === 1 ? "" : "s"}`}
                </button>
              </div>
            )}

            {phase === "running" && (
              <div className="flex gap-2 w-full">
                <button
                  onClick={handleCancel}
                  disabled={cancelling}
                  className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
                >
                  <StopCircle className="h-4 w-4" />
                  {cancelling ? "Cancelling…" : "Cancel"}
                </button>
                <div className="flex-1 flex items-center justify-end text-xs text-gray-500 gap-1.5">
                  <Clock className="h-3 w-3" />
                  Polling every 1.5s
                </div>
              </div>
            )}

            {phase === "done" && (
              <div className="flex gap-2 w-full">
                <button
                  onClick={onClose}
                  className="flex-1 rounded-lg bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
                >
                  Close
                </button>
                {/* D3.3 will wire this to a job log drawer */}
                <button
                  onClick={() => setShowLog(true)}
                  className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  View job log
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
      {showLog && jobId && (
        <JobLogDrawer
          projectId={projectId}
          jobId={jobId}
          onClose={() => setShowLog(false)}
        />
      )}
    </>
  );
}

function CounterTile({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: "green" | "red" | "amber";
}) {
  const colorMap = {
    green: "text-green-700",
    red: "text-red-700",
    amber: "text-amber-700",
  };
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-2 text-center">
      <p className="text-[10px] text-gray-500 uppercase tracking-wide">
        {label}
      </p>
      <p className={`text-lg font-semibold ${colorMap[color]} tabular-nums`}>
        {value}
      </p>
    </div>
  );
}

function FinalTile({
  label,
  succeeded,
  attempted,
}: {
  label: string;
  succeeded: number;
  attempted: number;
}) {
  return (
    <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
      <p className="text-[10px] text-gray-500 uppercase tracking-wide">
        {label}
      </p>
      <p className="text-sm font-semibold text-gray-900 mt-0.5">
        {succeeded}{" "}
        <span className="text-xs font-normal text-gray-500">
          of {attempted}
        </span>
      </p>
    </div>
  );
}