import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  CheckCircle2,
  XCircle,
  Loader,
  AlertTriangle,
  PlayCircle,
} from "lucide-react";
import type {
  ConnectionRef,
  DiscoveredTable,
  TableConfig,
  ImportJob,
  TableProgress,
} from "./types";

interface Props {
  projectId: string;
  connection: ConnectionRef;
  tables: DiscoveredTable[];
  configs: Record<string, TableConfig>;
  importMode?: "link" | "copy";
  onJobUpdated: (job: ImportJob) => void;
}

function buildPayload(
  connection: ConnectionRef,
  tables: DiscoveredTable[],
  configs: Record<string, TableConfig>,
  importMode: "link" | "copy"
) {
  return {
    connection,
    import_mode: importMode,
    tables: tables.map((t) => {
      const c = configs[t.qualified_name];
      return {
        schema: c.schema,
        name: c.name,
        layer_name: c.layer_name,
        geometry_type: c.geometry_type,
        geometry_column: c.geometry_column || "",
        lat_column: c.lat_column || "",
        lng_column: c.lng_column || "",
        id_column: c.id_column,
        editable: importMode === "link" ? false : c.editable,
        included_columns: c.included_columns,
        excluded_columns: c.excluded_columns,
        filter_clause: c.filter_clause,
        // Linked layers still get a form schema so Fields / attribute labels work.
        generate_form: c.generate_form,
        schedule_minutes: importMode === "link" ? 0 : c.schedule_minutes,
      };
    }),
  };
}

export function StepRun({
  projectId,
  connection,
  tables,
  configs,
  importMode = "copy",
  onJobUpdated,
}: Props) {
  const submittedRef = useRef(false);
  const [jobId, setJobId] = useState<string | null>(null);
  // Parent passes an inline callback — keep it in a ref so bubbling job
  // updates doesn't re-fire this effect and loop setState.
  const onJobUpdatedRef = useRef(onJobUpdated);
  onJobUpdatedRef.current = onJobUpdated;
  const lastNotifiedKeyRef = useRef<string>("");

  // Create import job (auto-runs once on mount)
  const createMutation = useMutation({
    mutationFn: () =>
      api.createImportJob(
        projectId,
        buildPayload(connection, tables, configs, importMode)
      ),
    onSuccess: (job: any) => {
      setJobId(job.id);
      lastNotifiedKeyRef.current = `${job.id}:${job.status}:${job.updated_at ?? ""}`;
      onJobUpdatedRef.current(job);
    },
  });

  useEffect(() => {
    if (!submittedRef.current) {
      submittedRef.current = true;
      createMutation.mutate();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Poll job every 2s while running
  const { data: job } = useQuery<ImportJob>({
    queryKey: ["importJob", jobId],
    queryFn: () => api.getImportJob(projectId, jobId!),
    enabled: !!jobId,
    refetchInterval: (q) => {
      const status = (q.state.data as any)?.status;
      if (status === "running" || status === "pending") return 2000;
      return false;
    },
  });

  // Bubble up the latest job to the wizard (only when it actually changes)
  useEffect(() => {
    if (!job) return;
    const key = `${job.id}:${job.status}:${job.updated_at ?? ""}:${job.progress?.current ?? 0}`;
    if (key === lastNotifiedKeyRef.current) return;
    lastNotifiedKeyRef.current = key;
    onJobUpdatedRef.current(job);
  }, [job]);

  // ── Render states ───────────────────────────────────────

  if (createMutation.isPending && !job) {
    return (
      <div className="flex flex-col items-center gap-3 py-12">
        <Loader className="h-8 w-8 text-blue-600 animate-spin" />
        <p className="text-sm text-gray-600">Submitting import job...</p>
      </div>
    );
  }

  if (createMutation.isError) {
    return (
      <div className="rounded-lg bg-red-50 border border-red-200 p-4">
        <p className="text-sm font-medium text-red-900">Failed to submit job</p>
        <p className="text-xs text-red-700 font-mono mt-1">
          {(createMutation.error as Error).message}
        </p>
      </div>
    );
  }

  if (!job) {
    return <p className="text-sm text-gray-500">Waiting for job to start...</p>;
  }

  const progress =
    job.progress || { current: 0, total: tables.length, per_table: {} };
  const overallPct =
    progress.total > 0
      ? Math.round((progress.current / progress.total) * 100)
      : 0;

  return (
    <div className="flex flex-col gap-4">
      {/* Overall status banner */}
      <StatusHeader job={job} pct={overallPct} />

      {/* Per-table progress list */}
      <div className="border border-gray-200 rounded-lg overflow-hidden">
        <div className="bg-gray-50 px-4 py-2 border-b border-gray-200">
          <p className="text-xs font-medium text-gray-600">
            Per-table progress
          </p>
        </div>
        <div className="max-h-80 overflow-y-auto divide-y divide-gray-100">
          {tables.map((t) => {
            const c = configs[t.qualified_name];
            const fromProgress = (progress.per_table || {})[t.qualified_name];
            const fromResult = (job.result?.table_results || {})[t.qualified_name];
            // Prefer finished result rows; fall back to live progress. If the job
            // ended but a row is still "running", treat it as failed (stale progress).
            let tp: TableProgress =
              fromResult ||
              fromProgress || {
                status: "pending",
                inserted: 0,
                total: 0,
              };
            const jobDone =
              job.status === "success" ||
              job.status === "partial" ||
              job.status === "failed";
            if (jobDone && tp.status === "running") {
              const err =
                job.result?.errors?.find((e) => e.startsWith(t.qualified_name + ":")) ||
                "import failed";
              tp = {
                ...tp,
                status: "failed",
                error: tp.error || err.replace(t.qualified_name + ": ", ""),
              };
            }
            return (
              <TableProgressRow
                key={t.qualified_name}
                name={c?.layer_name || t.qualified_name}
                qn={t.qualified_name}
                tp={tp}
              />
            );
          })}
        </div>
      </div>

      {/* Final result summary */}
      {job.result && (
        <div className="rounded-lg border border-gray-200 bg-white p-4">
          <p className="text-sm font-medium text-gray-900 mb-2">Summary</p>
          <div className="grid grid-cols-3 gap-3 text-center">
            <ResultPill
              value={job.result.layers_created}
              label="Layers created"
              color="text-blue-600"
            />
            <ResultPill
              value={job.result.forms_created}
              label="Forms created"
              color="text-purple-600"
            />
            <ResultPill
              value={job.result.features_imported}
              label="Features imported"
              color="text-green-600"
            />
          </div>

          {job.result.errors && job.result.errors.length > 0 && (
            <div className="mt-3 rounded-lg bg-yellow-50 border border-yellow-200 p-3">
              <p className="text-xs font-medium text-yellow-900 mb-1 flex items-center gap-1">
                <AlertTriangle className="h-3.5 w-3.5" />
                {job.result.errors.length} error(s) — partial success
              </p>
              <ul className="text-xs text-yellow-800 list-disc ml-4">
                {job.result.errors.map((e, i) => (
                  <li key={i} className="font-mono">
                    {e}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Sub-components ──────────────────────────────────────

function StatusHeader({ job, pct }: { job: ImportJob; pct: number }) {
  let icon = <Loader className="h-5 w-5 text-blue-600 animate-spin" />;
  let title = "Running...";
  let subtitle =
    job.progress?.message ||
    `${job.progress?.current || 0} / ${job.progress?.total || 0} tables`;
  let color = "bg-blue-100";

  if (job.status === "success") {
    icon = <CheckCircle2 className="h-5 w-5 text-green-600" />;
    title = "Import complete";
    subtitle = "All tables imported successfully";
    color = "bg-green-100";
  } else if (job.status === "partial") {
    icon = <AlertTriangle className="h-5 w-5 text-yellow-600" />;
    title = "Partial success";
    subtitle = "Some tables had errors";
    color = "bg-yellow-100";
  } else if (job.status === "failed") {
    icon = <XCircle className="h-5 w-5 text-red-600" />;
    title = "Import failed";
    subtitle = job.error_message || "See details below";
    color = "bg-red-100";
  } else if (job.status === "pending") {
    icon = <PlayCircle className="h-5 w-5 text-gray-400" />;
    title = "Queued";
    subtitle = "Waiting for a worker";
  }

  const showProgressBar = job.status === "running" || job.status === "pending";

  return (
    <div className="flex items-center gap-3 rounded-lg border border-gray-200 bg-white p-4">
      <div className={`rounded-lg ${color} p-2`}>{icon}</div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900">{title}</p>
        <p className="text-xs text-gray-500">{subtitle}</p>
      </div>
      {showProgressBar && (
        <div className="w-32">
          <div className="text-xs text-gray-500 text-right mb-0.5">{pct}%</div>
          <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
            <div
              className="h-full bg-blue-500 transition-all"
              style={{ width: `${pct}%` }}
            />
          </div>
        </div>
      )}
    </div>
  );
}

function TableProgressRow({
  name,
  qn,
  tp,
}: {
  name: string;
  qn: string;
  tp: TableProgress;
}) {
  let icon = <PlayCircle className="h-3.5 w-3.5 text-gray-300" />;
  let pillClass = "bg-gray-100 text-gray-500";
  let pct = 0;

  if (tp.status === "running") {
    icon = <Loader className="h-3.5 w-3.5 text-blue-500 animate-spin" />;
    pillClass = "bg-blue-50 text-blue-700";
    pct = tp.total > 0 ? Math.round((tp.inserted / tp.total) * 100) : 0;
  } else if (tp.status === "success") {
    icon = <CheckCircle2 className="h-3.5 w-3.5 text-green-500" />;
    pillClass = "bg-green-50 text-green-700";
    pct = 100;
  } else if (tp.status === "failed") {
    icon = <XCircle className="h-3.5 w-3.5 text-red-500" />;
    pillClass = "bg-red-50 text-red-700";
  }

  return (
    <div className="px-4 py-2.5">
      <div className="flex items-center gap-2 mb-1">
        {icon}
        <p className="text-sm font-medium text-gray-900 flex-1 truncate">
          {name}
        </p>
        <span className={`rounded-full px-2 py-0.5 text-xs ${pillClass}`}>
          {tp.status}
        </span>
        <span className="text-xs text-gray-500 font-mono">
          {tp.inserted}/{tp.total}
        </span>
      </div>
      <div className="w-full h-1.5 bg-gray-100 rounded-full overflow-hidden">
        <div
          className={`h-full transition-all ${
            tp.status === "failed"
              ? "bg-red-500"
              : tp.status === "success"
              ? "bg-green-500"
              : "bg-blue-500"
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>
      {tp.error && (
        <p
          className="text-xs text-red-600 font-mono mt-1 truncate"
          title={tp.error}
        >
          {tp.error}
        </p>
      )}
      <p className="text-[10px] text-gray-400 font-mono mt-0.5 truncate">{qn}</p>
    </div>
  );
}

function ResultPill({
  value,
  label,
  color,
}: {
  value: number;
  label: string;
  color: string;
}) {
  return (
    <div>
      <p className={`text-xl font-bold ${color}`}>{value}</p>
      <p className="text-xs text-gray-500">{label}</p>
    </div>
  );
}