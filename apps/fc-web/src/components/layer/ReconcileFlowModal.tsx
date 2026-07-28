import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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
    Eye,
    ChevronDown,
    ChevronRight,
    ArrowRight,
    Database,
} from "lucide-react";

import { api } from "@/lib/api";
import { JobLogDrawer } from "./JobLogDrawer";

interface Props {
    projectId: string;
    layerId: string;
    dataSource: any;
    onClose: () => void;
}

type Phase = "calculating" | "confirm" | "running" | "done";

export function ReconcileFlowModal({
    projectId,
    layerId,
    dataSource,
    onClose,
}: Props) {
    const queryClient = useQueryClient();
    const [phase, setPhase] = useState<Phase>("calculating");
    const [preview, setPreview] = useState<any>(null);
    const [jobId, setJobId] = useState<string | null>(null);
    const [job, setJob] = useState<any>(null);
    const [cancelling, setCancelling] = useState(false);
    const [showLog, setShowLog] = useState(false);
    const [showSamples, setShowSamples] = useState(false);
    const [activeSampleTab, setActiveSampleTab] = useState<"safe" | "conflicts">(
        "safe"
    );
    const [acks, setAcks] = useState<Record<string, boolean>>({});
    const pollRef = useRef<number | null>(null);
    const [stuckSeconds, setStuckSeconds] = useState(0);
    const [forcing, setForcing] = useState(false);
    const runningStartRef = useRef<number | null>(null);

    const schema = dataSource?.config?.schema ?? "—";
    const table = dataSource?.config?.table ?? "—";

    // ── Phase 1: Calculating (auto-run Preview on mount) ──
    const previewMutation = useMutation({
        mutationFn: () =>
            api.previewReconciliation(projectId, layerId, dataSource.id),
        onSuccess: (data: any) => {
            setPreview(data);
            const next: Record<string, boolean> = {};
            for (const key of data?.required_acknowledgments ?? []) {
                next[key] = false;
            }
            setAcks(next);
            setPhase("confirm");
        },
        onError: (err: any) => {
            toast.error("Preview failed", {
                description: err?.message ?? "Could not run preview.",
            });
            onClose();
        },
    });

    useEffect(() => {
        if (phase === "calculating") {
            previewMutation.mutate();
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        if (phase !== "running" || !jobId) return;

        // Track when running started for the force-stop escalation
        runningStartRef.current = Date.now();
        setStuckSeconds(0);

        const updateStuck = () => {
            if (runningStartRef.current) {
                setStuckSeconds(Math.floor((Date.now() - runningStartRef.current) / 1000));
            }
        };
        const stuckInterval = window.setInterval(updateStuck, 1000);

        const poll = async () => {
            try {
                const j = await api.getReconciliationJob(projectId, jobId);
                setJob(j);
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
                    window.clearInterval(stuckInterval);
                    setPhase("done");
                    queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
                    queryClient.invalidateQueries({
                        queryKey: ["reconcileConflicts", layerId],
                    });
                }
            } catch (e: any) {
                console.warn("[reconcile] poll error", e?.message);
            }
        };

        poll();
        pollRef.current = window.setInterval(poll, 1500);
        return () => {
            if (pollRef.current) {
                window.clearInterval(pollRef.current);
                pollRef.current = null;
            }
            window.clearInterval(stuckInterval);
        };
    }, [phase, jobId, projectId, layerId, queryClient]);

    // ── Phase 3: Apply mutation ──
    const applyMutation = useMutation({
        mutationFn: () =>
            api.applyReconciliation(
                projectId,
                layerId,
                dataSource.id,
                undefined,
                undefined,
                Object.entries(acks)
                    .filter(([, v]) => v)
                    .map(([k]) => k),
            ),
        onSuccess: (resp: any) => {
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

    // ── Poll job during run phase ──
    useEffect(() => {
        if (phase !== "running" || !jobId) return;

        const poll = async () => {
            try {
                const j = await api.getReconciliationJob(projectId, jobId);
                setJob(j);
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
                    queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
                    queryClient.invalidateQueries({
                        queryKey: ["reconcileConflicts", layerId],
                    });
                }
            } catch (e: any) {
                console.warn("[reconcile] poll error", e?.message);
            }
        };

        poll();
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

    const handleForceStop = async () => {
        if (!jobId || forcing) return;
        if (!window.confirm(
            "Force-finalize this job?\n\n" +
            "This sets status to terminal regardless of worker state. " +
            "Any in-flight DB writes will continue but their counters won't update."
        )) {
            return;
        }
        setForcing(true);
        try {
            await api.forceFinalizeReconciliationJob(projectId, jobId);
            toast.success("Job force-finalized", {
                description: "Status updated. Modal will close on next poll.",
            });
        } catch (e: any) {
            toast.error("Force-finalize failed", {
                description: e?.message ?? "Could not force-finalize.",
            });
        } finally {
            setForcing(false);
        }
    };

    // Derived
    const summary = preview?.summary ?? {};
    const byType = preview?.by_change_type ?? {};
    const safeCount = summary.safe_to_apply ?? 0;
    const conflictCount = summary.conflicts ?? 0;
    const alreadyApplied = summary.already_applied ?? 0;
    const totalPending = summary.total_pending ?? 0;

    // Live job counters
    const applied = (job?.updates_succeeded ?? 0) + (job?.deletes_succeeded ?? 0);
    const attempted =
        (job?.updates_attempted ?? 0) + (job?.deletes_attempted ?? 0);
    const failed = job?.errors ?? 0;
    const newConflicts = job?.conflicts_detected ?? 0;
    const total = job?.changes_total || safeCount || 1;
    const pct = total > 0 ? Math.min(100, Math.round((applied / total) * 100)) : 0;

    // Final status
    const finalStatus = job?.status as string | undefined;
    const isTerminalSuccess = finalStatus === "success";
    const isTerminalPartial = finalStatus === "partial";
    const isTerminalFailed = finalStatus === "failed";
    const isTerminalCancelled = finalStatus === "cancelled";

    const sampleSafe = preview?.sample_safe ?? [];
    const sampleConflicts = preview?.sample_conflicts ?? [];
    const precautions: Array<{
        code: string;
        severity: string;
        message: string;
        requires_ack?: boolean;
        ack_key?: string;
    }> = preview?.precautions ?? [];
    const applyBlocked = !!preview?.apply_blocked;
    const requiredAcks: string[] = preview?.required_acknowledgments ?? [];
    const allAcksChecked =
        requiredAcks.length === 0 || requiredAcks.every((k) => acks[k]);
    const canApply = safeCount > 0 && !applyBlocked && allAcksChecked;

    return (
        <>
            <div className="fixed inset-0 z-40 bg-black/40" />

            <div className="fixed inset-0 z-50 flex items-center justify-center p-4 pointer-events-none">
                <div className="bg-white rounded-xl shadow-2xl w-full max-w-lg pointer-events-auto flex flex-col">
                    {/* ── Header ── */}
                    <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200">
                        <div className="min-w-0">
                            <p className="text-xs text-gray-500">
                                {phase === "calculating" && "Calculating impact…"}
                                {phase === "confirm" && "Confirm Reconcile"}
                                {phase === "running" && "Applying changes…"}
                                {phase === "done" && "Reconcile complete"}
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

                    {/* ── Body ── */}
                    <div className="px-5 py-4 max-h-[60vh] overflow-y-auto">
                        {/* ── Phase 1: Calculating ── */}
                        {phase === "calculating" && (
                            <div className="flex flex-col items-center text-center py-6">
                                <Loader2 className="h-10 w-10 text-blue-600 animate-spin mb-3" />
                                <p className="text-sm font-medium text-gray-900">
                                    Running dry-run preview
                                </p>
                                <p className="text-xs text-gray-500 mt-1 max-w-sm">
                                    Connecting to source DB and comparing pending changes against
                                    current state. No writes yet.
                                </p>
                            </div>
                        )}

                        {/* ── Phase 2: Confirm ── */}
                        {phase === "confirm" && (
                            <div className="flex flex-col gap-3">
                                {/* Nothing to do */}
                                {totalPending === 0 && (
                                    <div className="rounded-lg border border-gray-200 bg-gray-50 p-6 text-center">
                                        <Database className="h-10 w-10 mx-auto text-gray-300 mb-2" />
                                        <p className="text-sm font-medium text-gray-700">
                                            Nothing to reconcile
                                        </p>
                                        <p className="text-xs text-gray-500 mt-1">
                                            No pending changes for this data source.
                                        </p>
                                    </div>
                                )}

                                {totalPending > 0 && (
                                    <>
                                        {/* Summary tiles */}
                                        <div className="grid grid-cols-3 gap-2">
                                            <SummaryTile
                                                label="Safe to apply"
                                                value={safeCount}
                                                color="green"
                                                icon={<CheckCircle2 className="h-3.5 w-3.5" />}
                                            />
                                            <SummaryTile
                                                label="Conflicts"
                                                value={conflictCount}
                                                color="amber"
                                                icon={<AlertCircle className="h-3.5 w-3.5" />}
                                            />
                                            <SummaryTile
                                                label="Already applied"
                                                value={alreadyApplied}
                                                color="blue"
                                            />
                                        </div>

                                        {/* By change type */}
                                        <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
                                            <p className="text-[10px] uppercase tracking-wide text-gray-500 mb-1.5">
                                                Breakdown
                                            </p>
                                            <div className="grid grid-cols-2 gap-2 text-xs">
                                                <div>
                                                    <p className="text-gray-500">Updates</p>
                                                    <p className="font-medium">
                                                        <span className="text-green-700">
                                                            {byType.updated?.safe ?? 0} safe
                                                        </span>
                                                        {" · "}
                                                        <span className="text-amber-700">
                                                            {byType.updated?.conflict ?? 0} conflict
                                                        </span>
                                                    </p>
                                                </div>
                                                <div>
                                                    <p className="text-gray-500">Deletes</p>
                                                    <p className="font-medium">
                                                        <span className="text-green-700">
                                                            {byType.deleted?.safe ?? 0} safe
                                                        </span>
                                                        {" · "}
                                                        <span className="text-amber-700">
                                                            {byType.deleted?.conflict ?? 0} conflict
                                                        </span>
                                                    </p>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Registered precautions */}
                                        {precautions.length > 0 && (
                                            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 flex flex-col gap-2">
                                                <p className="text-[10px] uppercase tracking-wide text-slate-500 font-medium">
                                                    Write-back precautions
                                                </p>
                                                {precautions.map((p) => (
                                                    <div
                                                        key={p.code}
                                                        className={
                                                            "text-xs rounded-md px-2 py-1.5 border " +
                                                            (p.severity === "blocker"
                                                                ? "border-red-200 bg-red-50 text-red-900"
                                                                : p.severity === "warning"
                                                                  ? "border-amber-200 bg-amber-50 text-amber-950"
                                                                  : "border-slate-200 bg-white text-slate-700")
                                                        }
                                                    >
                                                        <span className="font-medium uppercase text-[10px] tracking-wide opacity-70">
                                                            {p.severity}
                                                        </span>
                                                        <p className="mt-0.5">{p.message}</p>
                                                        {p.requires_ack && p.ack_key && (
                                                            <label className="mt-1.5 flex items-start gap-2 cursor-pointer">
                                                                <input
                                                                    type="checkbox"
                                                                    className="mt-0.5"
                                                                    checked={!!acks[p.ack_key]}
                                                                    onChange={(e) =>
                                                                        setAcks((prev) => ({
                                                                            ...prev,
                                                                            [p.ack_key!]: e.target.checked,
                                                                        }))
                                                                    }
                                                                />
                                                                <span>
                                                                    I understand and accept risk{" "}
                                                                    <code className="text-[10px] bg-black/5 px-1 rounded">
                                                                        {p.ack_key}
                                                                    </code>
                                                                </span>
                                                            </label>
                                                        )}
                                                    </div>
                                                ))}
                                            </div>
                                        )}

                                        {/* Warning banners */}
                                        {safeCount > 0 && (
                                            <div className="rounded-lg border border-amber-200 bg-amber-50 p-3 flex items-start gap-2">
                                                <AlertTriangle className="h-4 w-4 text-amber-700 mt-0.5 shrink-0" />
                                                <div className="text-xs text-amber-900">
                                                    <p className="font-medium">
                                                        About to write {safeCount} change
                                                        {safeCount === 1 ? "" : "s"} to{" "}
                                                        <span className="font-mono">
                                                            {schema}.{table}
                                                        </span>
                                                        .
                                                    </p>
                                                    <p className="mt-0.5">
                                                        This is irreversible. An audit log row is written per
                                                        change.
                                                    </p>
                                                </div>
                                            </div>
                                        )}

                                        {conflictCount > 0 && (
                                            <div className="rounded-lg border border-gray-200 bg-gray-50 p-3 flex items-start gap-2">
                                                <AlertCircle className="h-4 w-4 text-gray-500 mt-0.5 shrink-0" />
                                                <p className="text-xs text-gray-700">
                                                    <strong>{conflictCount} conflict</strong>
                                                    {conflictCount === 1 ? "" : "s"} will be skipped.
                                                    Resolve them on the Conflicts tab to include in a
                                                    future Apply run.
                                                </p>
                                            </div>
                                        )}

                                        {/* Samples */}
                                        {(sampleSafe.length > 0 || sampleConflicts.length > 0) && (
                                            <div className="rounded-lg border border-gray-200">
                                                <button
                                                    onClick={() => setShowSamples(!showSamples)}
                                                    className="w-full px-3 py-2 flex items-center justify-between hover:bg-gray-50 text-xs font-medium text-gray-700"
                                                >
                                                    <span className="flex items-center gap-1.5">
                                                        <Eye className="h-3.5 w-3.5" />
                                                        Sample rows ({sampleSafe.length} safe ·{" "}
                                                        {sampleConflicts.length} conflicts)
                                                    </span>
                                                    {showSamples ? (
                                                        <ChevronDown className="h-3.5 w-3.5" />
                                                    ) : (
                                                        <ChevronRight className="h-3.5 w-3.5" />
                                                    )}
                                                </button>

                                                {showSamples && (
                                                    <div>
                                                        <div className="flex border-t border-b border-gray-200">
                                                            <button
                                                                onClick={() => setActiveSampleTab("safe")}
                                                                className={
                                                                    "flex-1 px-3 py-1.5 text-xs font-medium " +
                                                                    (activeSampleTab === "safe"
                                                                        ? "border-b-2 border-green-500 text-green-700"
                                                                        : "text-gray-500 hover:text-gray-700")
                                                                }
                                                            >
                                                                Safe ({sampleSafe.length})
                                                            </button>
                                                            <button
                                                                onClick={() => setActiveSampleTab("conflicts")}
                                                                className={
                                                                    "flex-1 px-3 py-1.5 text-xs font-medium " +
                                                                    (activeSampleTab === "conflicts"
                                                                        ? "border-b-2 border-amber-500 text-amber-700"
                                                                        : "text-gray-500 hover:text-gray-700")
                                                                }
                                                            >
                                                                Conflicts ({sampleConflicts.length})
                                                            </button>
                                                        </div>
                                                        <div className="p-2 max-h-40 overflow-y-auto">
                                                            <SampleList
                                                                rows={
                                                                    activeSampleTab === "safe"
                                                                        ? sampleSafe
                                                                        : sampleConflicts
                                                                }
                                                                variant={activeSampleTab}
                                                            />
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        )}
                                    </>
                                )}
                            </div>
                        )}

                        {/* ── Phase 3: Running ── */}
                        {phase === "running" && (
                            <div className="flex flex-col gap-3">
                                <div className="flex items-center gap-2 text-sm text-blue-900">
                                    <Loader2 className="h-4 w-4 text-blue-600 animate-spin" />
                                    {job?.status === "pending"
                                        ? "Job queued, waiting for worker…"
                                        : "Worker processing chunks…"}
                                </div>

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

                                <div className="grid grid-cols-3 gap-2">
                                    <CounterTile label="Applied" value={applied} color="green" />
                                    <CounterTile label="Failed" value={failed} color="red" />
                                    <CounterTile
                                        label="Conflicts"
                                        value={newConflicts}
                                        color="amber"
                                    />
                                </div>
                            </div>
                        )}

                        {/* ── Phase 4: Done ── */}
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
                                            `Partial — ${applied} applied, ${failed + newConflicts
                                            } skipped`}
                                        {isTerminalFailed &&
                                            `Failed — ${job?.error_message ?? "see job log"}`}
                                        {isTerminalCancelled &&
                                            `Cancelled — ${applied} applied before stop`}
                                    </p>
                                </div>

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

                                {jobId && (
                                    <p className="text-[11px] text-gray-400 font-mono">
                                        Job: {jobId}
                                    </p>
                                )}
                            </div>
                        )}
                    </div>

                    {/* ── Footer ── */}
                    <div className="px-5 py-3 border-t border-gray-200">
                        {phase === "calculating" && (
                            <div className="flex justify-end">
                                <button
                                    onClick={onClose}
                                    className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                                >
                                    Cancel
                                </button>
                            </div>
                        )}

                        {phase === "confirm" && (
                            <div className="flex gap-2 w-full">
                                <button
                                    onClick={onClose}
                                    className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                                >
                                    Cancel
                                </button>
                                {canApply && (
                                    <button
                                        onClick={() => applyMutation.mutate()}
                                        disabled={applyMutation.isPending}
                                        className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                                    >
                                        <PlayCircle className="h-4 w-4" />
                                        {applyMutation.isPending
                                            ? "Starting…"
                                            : `Apply ${safeCount} change${safeCount === 1 ? "" : "s"}`}
                                        <ArrowRight className="h-3.5 w-3.5" />
                                    </button>
                                )}
                                {safeCount > 0 && applyBlocked && (
                                    <div className="flex-1 text-xs text-red-700 text-center self-center">
                                        Apply blocked — fix precautions first
                                    </div>
                                )}
                                {safeCount > 0 && !applyBlocked && !allAcksChecked && (
                                    <div className="flex-1 text-xs text-amber-800 text-center self-center">
                                        Acknowledge all warnings to apply
                                    </div>
                                )}
                                {safeCount === 0 && totalPending > 0 && (
                                    <div className="flex-1 text-xs text-gray-500 text-center self-center">
                                        Resolve conflicts first
                                    </div>
                                )}
                            </div>
                        )}
                        {phase === "running" && (
                            <div className="flex flex-col gap-2 w-full">
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
                                        {stuckSeconds < 60
                                            ? `Running for ${stuckSeconds}s`
                                            : `Running for ${Math.floor(stuckSeconds / 60)}m ${stuckSeconds % 60}s`}
                                    </div>
                                </div>

                                {/* Escalation — appears after 10s if still running */}
                                {stuckSeconds >= 10 && (
                                    <div className="rounded-lg border border-amber-200 bg-amber-50 p-2 flex items-center gap-2">
                                        <AlertTriangle className="h-3.5 w-3.5 text-amber-700 shrink-0" />
                                        <p className="text-[11px] text-amber-900 flex-1">
                                            Taking longer than expected.
                                        </p>
                                        <button
                                            onClick={handleForceStop}
                                            disabled={forcing}
                                            className="text-[11px] font-medium text-amber-900 underline hover:no-underline disabled:opacity-50"
                                        >
                                            {forcing ? "Forcing…" : "Force-stop"}
                                        </button>
                                    </div>
                                )}
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
                                {jobId && (
                                    <button
                                        onClick={() => setShowLog(true)}
                                        className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                                    >
                                        View job log
                                    </button>
                                )}
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Job log drawer (D3.3 hookup) */}
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

// ── Small UI helpers ────────────────────────────────────

function SummaryTile({
    label,
    value,
    color,
    icon,
}: {
    label: string;
    value: number;
    color: "green" | "amber" | "blue";
    icon?: React.ReactNode;
}) {
    const map = {
        green: "bg-green-50 text-green-900 border-green-200",
        amber: "bg-amber-50 text-amber-900 border-amber-200",
        blue: "bg-blue-50 text-blue-900 border-blue-200",
    };
    return (
        <div className={`rounded-lg border p-2.5 ${map[color]}`}>
            <div className="flex items-center gap-1 text-[10px] uppercase tracking-wide">
                {icon}
                {label}
            </div>
            <p className="text-xl font-semibold mt-0.5 tabular-nums">{value}</p>
        </div>
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

function SampleList({
    rows,
    variant,
}: {
    rows: any[];
    variant: "safe" | "conflicts";
}) {
    if (rows.length === 0) {
        return (
            <p className="text-[11px] text-gray-400 italic text-center py-2">
                No {variant === "safe" ? "safe" : "conflict"} samples
            </p>
        );
    }
    return (
        <div className="flex flex-col gap-1">
            {rows.map((r, i) => (
                <div
                    key={r.feature_id || i}
                    className={
                        "rounded border px-2 py-1 text-[11px] " +
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
                </div>
            ))}
        </div>
    );
}