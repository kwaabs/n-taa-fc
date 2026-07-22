import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  X,
  CheckCircle2,
  AlertCircle,
  XCircle,
  CircleDashed,
  Trash2,
  Edit3,
  Plus,
  Loader2,
  ChevronDown,
  ChevronRight,
  Clock,
} from "lucide-react";

import { api } from "@/lib/api";

interface Props {
  projectId: string;
  jobId: string | null;
  onClose: () => void;
}

type OutcomeFilter = "all" | "applied" | "conflict" | "failed" | "skipped";

export function JobLogDrawer({ projectId, jobId, onClose }: Props) {
  const [outcomeFilter, setOutcomeFilter] = useState<OutcomeFilter>("all");
  const [limit, setLimit] = useState(200);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());

  const { data, isLoading, error } = useQuery({
    queryKey: ["reconcileJobLog", jobId, limit],
    queryFn: () => api.getReconciliationJobLog(projectId, jobId!, limit),
    enabled: !!jobId,
  });

  const entries = useMemo(() => data?.entries ?? [], [data]);

  const filtered = useMemo(() => {
    if (outcomeFilter === "all") return entries;
    return entries.filter((e: any) => e.outcome === outcomeFilter);
  }, [entries, outcomeFilter]);

  const counts = useMemo(() => {
    const c = { all: entries.length, applied: 0, conflict: 0, failed: 0, skipped: 0 };
    for (const e of entries) {
      if (c[e.outcome as keyof typeof c] !== undefined) {
        (c as any)[e.outcome] += 1;
      }
    }
    return c;
  }, [entries]);

  const toggle = (id: string) => {
    const next = new Set(expandedIds);
    next.has(id) ? next.delete(id) : next.add(id);
    setExpandedIds(next);
  };

  if (!jobId) return null;

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/30" />

      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-2xl bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">Job log</p>
            <p className="text-[11px] font-mono text-gray-400 truncate">{jobId}</p>

            <p className="text-[10px] text-gray-400 mt-1">
              Audit trail of every row processed in this job
            </p>

          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 shrink-0"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Filter chips */}
        <div className="px-5 py-3 border-b border-gray-200 shrink-0 flex flex-wrap gap-1.5">
          <FilterChip
            label="All"
            count={counts.all}
            active={outcomeFilter === "all"}
            onClick={() => setOutcomeFilter("all")}
          />
          <FilterChip
            label="Applied"
            count={counts.applied}
            active={outcomeFilter === "applied"}
            onClick={() => setOutcomeFilter("applied")}
            color="green"
          />
          <FilterChip
            label="Conflicted"
            count={counts.conflict}
            active={outcomeFilter === "conflict"}
            onClick={() => setOutcomeFilter("conflict")}
            color="amber"
          />
          <FilterChip
            label="Failed"
            count={counts.failed}
            active={outcomeFilter === "failed"}
            onClick={() => setOutcomeFilter("failed")}
            color="red"
          />
          <FilterChip
            label="Skipped"
            count={counts.skipped}
            active={outcomeFilter === "skipped"}
            onClick={() => setOutcomeFilter("skipped")}
            color="gray"
          />
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4">
          {isLoading && (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-6 w-6 text-gray-400 animate-spin" />
            </div>
          )}

          {error && (
            <div className="rounded-lg border border-red-200 bg-red-50 p-3">
              <p className="text-sm text-red-700">
                Failed to load log: {(error as Error).message}
              </p>
            </div>
          )}

          {!isLoading && !error && filtered.length === 0 && (
            <div className="text-center py-12 text-gray-400 italic text-sm">
              {entries.length === 0
                ? "No log entries for this job"
                : `No ${outcomeFilter} entries`}
            </div>
          )}

          {!isLoading && !error && filtered.length > 0 && (
            <div className="flex flex-col gap-1.5">
              {filtered.map((e: any) => (
                <LogEntry
                  key={e.id}
                  entry={e}
                  expanded={expandedIds.has(e.id)}
                  onToggle={() => toggle(e.id)}
                />
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-gray-200 bg-white shrink-0">
          <div className="flex items-center justify-between text-xs text-gray-500">
            <span>
              Showing {filtered.length} of {entries.length}
              {entries.length >= limit && " (capped)"}
            </span>
            {entries.length >= limit && (
              <button
                onClick={() => setLimit(limit + 200)}
                className="text-blue-600 hover:underline font-medium"
              >
                Load 200 more
              </button>
            )}
          </div>
        </div>
      </div>
    </>
  );
}

function FilterChip({
  label,
  count,
  active,
  onClick,
  color,
}: {
  label: string;
  count: number;
  active: boolean;
  onClick: () => void;
  color?: "green" | "amber" | "red" | "gray";
}) {
  const colorMap = {
    green: active ? "bg-green-600 text-white" : "bg-green-50 text-green-700",
    amber: active ? "bg-amber-600 text-white" : "bg-amber-50 text-amber-700",
    red: active ? "bg-red-600 text-white" : "bg-red-50 text-red-700",
    gray: active ? "bg-gray-700 text-white" : "bg-gray-100 text-gray-700",
  };
  const base = color
    ? colorMap[color]
    : active
      ? "bg-blue-600 text-white"
      : "bg-blue-50 text-blue-700";
  return (
    <button
      onClick={onClick}
      className={
        "rounded-full px-2.5 py-1 text-xs font-medium transition-colors " + base
      }
    >
      {label}{" "}
      <span
        className={
          "ml-0.5 tabular-nums " +
          (active ? "opacity-80" : "opacity-60")
        }
      >
        ({count})
      </span>
    </button>
  );
}

function LogEntry({
  entry,
  expanded,
  onToggle,
}: {
  entry: any;
  expanded: boolean;
  onToggle: () => void;
}) {
  const hasPayload =
    entry.attempted_payload &&
    Object.keys(entry.attempted_payload).length > 0;
  const canExpand = hasPayload || !!entry.failure_reason;

  return (
    <div className="rounded-lg border border-gray-200 bg-white">
      <button
        onClick={canExpand ? onToggle : undefined}
        className={
          "w-full text-left px-3 py-2 flex items-start gap-2.5 " +
          (canExpand ? "cursor-pointer hover:bg-gray-50" : "cursor-default")
        }
      >
        {/* Outcome badge */}
        <OutcomeIcon outcome={entry.outcome} />

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <ChangeTypeIcon changeType={entry.change_type} />
            <span className="font-mono text-xs text-gray-900 truncate">
              {entry.source_ref || "(no source_ref)"}
            </span>
            <OutcomeBadge outcome={entry.outcome} />
          </div>
          {entry.failure_reason && (
            <p className="text-[11px] text-gray-600 mt-0.5 italic truncate">
              {entry.failure_reason}
            </p>
          )}
          <p className="text-[10px] text-gray-400 mt-0.5 flex items-center gap-1">
            <Clock className="h-2.5 w-2.5" />
            {new Date(entry.applied_at).toLocaleString()}
          </p>
        </div>

        {canExpand && (
          <div className="pt-0.5">
            {expanded ? (
              <ChevronDown className="h-3.5 w-3.5 text-gray-400" />
            ) : (
              <ChevronRight className="h-3.5 w-3.5 text-gray-400" />
            )}
          </div>
        )}
      </button>

      {expanded && hasPayload && (
        <div className="px-3 pb-2.5 border-t border-gray-100 pt-2">
          <p className="text-[10px] uppercase tracking-wide text-gray-400 mb-1">
            Attempted payload
          </p>
          <pre className="text-[11px] font-mono bg-gray-50 rounded p-2 overflow-x-auto">
            {JSON.stringify(entry.attempted_payload, null, 2)}
          </pre>
        </div>
      )}

      {expanded && entry.failure_reason && !hasPayload && (
        <div className="px-3 pb-2.5 border-t border-gray-100 pt-2">
          <p className="text-[10px] uppercase tracking-wide text-gray-400 mb-1">
            Reason
          </p>
          <p className="text-xs text-gray-700">{entry.failure_reason}</p>
        </div>
      )}
    </div>
  );
}

function OutcomeIcon({ outcome }: { outcome: string }) {
  switch (outcome) {
    case "applied":
      return <CheckCircle2 className="h-4 w-4 text-green-600 mt-0.5" />;
    case "conflict":
      return <AlertCircle className="h-4 w-4 text-amber-600 mt-0.5" />;
    case "failed":
      return <XCircle className="h-4 w-4 text-red-600 mt-0.5" />;
    case "skipped":
      return <CircleDashed className="h-4 w-4 text-gray-400 mt-0.5" />;
    default:
      return <CircleDashed className="h-4 w-4 text-gray-400 mt-0.5" />;
  }
}

function OutcomeBadge({ outcome }: { outcome: string }) {
  const map: Record<string, string> = {
    applied: "bg-green-50 text-green-700",
    conflict: "bg-amber-50 text-amber-700",
    failed: "bg-red-50 text-red-700",
    skipped: "bg-gray-100 text-gray-600",
  };
  return (
    <span
      className={
        "rounded-full px-1.5 py-0.5 text-[10px] font-medium " +
        (map[outcome] ?? "bg-gray-100 text-gray-600")
      }
    >

      {outcome === "conflict" ? "conflicted" : outcome}

    </span>
  );
}

function ChangeTypeIcon({ changeType }: { changeType: string }) {
  switch (changeType) {
    case "updated":
      return <Edit3 className="h-3 w-3 text-blue-500" />;
    case "deleted":
      return <Trash2 className="h-3 w-3 text-red-500" />;
    case "inserted":
      return <Plus className="h-3 w-3 text-green-500" />;
    default:
      return null;
  }
}