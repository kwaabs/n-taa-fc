import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { ImportDataSourceDialog } from "./ImportDataSourceDialog";
import { LinkConnectionDrawer } from "./LinkConnectionDrawer";
import { ReconcileFlowModal } from "./ReconcileFlowModal";
import {
  Database,
  FileText,
  Link as LinkIcon,
  Database as DbIcon,
  RefreshCw,
  Trash2,
  CheckCircle2,
  XCircle,
  Clock,
  Eye,
  Plus,
  AlertCircle,
  Plug,
} from "lucide-react";

interface Props {
  projectId: string;
  layerId: string;
  layer?: any;
}

const typeIcons: Record<string, any> = {
  file: FileText,
  url: LinkIcon,
  database: DbIcon,
};

/** Live linked-table source: reference rows stay in the external table. */
function isLiveLinkedSource(source: any, layer?: any): boolean {
  if (layer?.source_type === "linked_table") return true;
  if (source?.last_sync_status === "linked") return true;
  return false;
}

/** Write-back/reconcile can use a connection profile or FC home DB + schema/table. */
function canReconcile(source: any): boolean {
  if (source?.config?.connection_id) return true;
  return (
    source?.source_type === "database" &&
    !!source?.config?.schema &&
    !!source?.config?.table
  );
}

export function LayerDataSourcesTab({ projectId, layerId, layer }: Props) {
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [linkingSource, setLinkingSource] = useState<any | null>(null);
  const [reconcilingSource, setReconcilingSource] = useState<any | null>(null);

  const isLinkedLayer = layer?.source_type === "linked_table";

  const { data: sources, isLoading } = useQuery({
    queryKey: ["dataSources", layerId],
    queryFn: () => api.getLayerDataSources(projectId, layerId),
    enabled: !!layerId,
  });

  const { data: reconcileSummary } = useQuery({
    queryKey: ["reconcileSummary", layerId],
    queryFn: () => api.getReconciliationSummary(projectId, layerId),
    enabled: !!layerId,
    refetchInterval: 30_000,
  });

  const sourceList = Array.isArray(sources) ? sources : [];

  const syncMutation = useMutation({
    mutationFn: (sourceId: string) =>
      api.syncDataSource(projectId, layerId, sourceId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layerSummary", layerId] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (sourceId: string) =>
      api.deleteDataSource(projectId, layerId, sourceId),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] }),
  });

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Data Sources</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            {isLinkedLayer
              ? "This layer reads a live database table. Link a connection profile for write-back credentials when needed."
              : "Import reference data from files, URLs, or databases"}
          </p>
        </div>
        {!isLinkedLayer && (
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 shrink-0"
          >
            <Plus className="h-4 w-4" /> Add Data Source
          </button>
        )}
      </div>

      {isLoading ? (
        <p className="text-gray-500">Loading...</p>
      ) : sourceList.length === 0 ? (
        <div className="bg-white rounded-xl border border-dashed border-gray-300 p-12 text-center">
          <Database className="h-12 w-12 mx-auto text-gray-300 mb-3" />
          <p className="text-lg font-medium text-gray-700">
            {isLinkedLayer ? "No data source registered" : "No data sources yet"}
          </p>
          <p className="text-sm text-gray-500 mt-1">
            {isLinkedLayer
              ? "Linked tables normally have one database source created at import. Re-run the import wizard if this is missing."
              : "Add a data source to populate this layer with reference features"}
          </p>
          {!isLinkedLayer && (
            <button
              onClick={() => setShowCreate(true)}
              className="mt-4 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              <Plus className="h-4 w-4" /> Add Your First Source
            </button>
          )}
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {sourceList.map((s: any) => {
            const Icon = typeIcons[s.source_type] || Database;
            const stats = s.last_sync_stats || {};
            const live = isLiveLinkedSource(s, layer);
            const hasConnection = !!s.config?.connection_id;
            const showReconcile = canReconcile(s);
            const schemaTable =
              s.config?.schema && s.config?.table
                ? `${s.config.schema}.${s.config.table}`
                : null;

            return (
              <div
                key={s.id}
                className="bg-white rounded-xl border border-gray-200 p-4"
              >
                <div className="flex items-start gap-3">
                  <div className="rounded-lg bg-gray-50 p-2 shrink-0">
                    <Icon className="h-5 w-5 text-gray-600" />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1 flex-wrap">
                      <h3 className="font-semibold text-gray-900 truncate">
                        {s.name}
                      </h3>
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-600">
                        {s.source_type}
                      </span>
                      {live && (
                        <span className="rounded-full bg-sky-50 border border-sky-200 px-2 py-0.5 text-xs text-sky-700">
                          Live table
                        </span>
                      )}
                      <SyncStatusBadge status={s.last_sync_status} live={live} />
                    </div>

                    {schemaTable && (
                      <p className="text-xs font-mono text-gray-500 mb-2 truncate">
                        {schemaTable}
                        {s.config?.id_column ? ` · id: ${s.config.id_column}` : ""}
                      </p>
                    )}

                    {!live && stats.total > 0 && (
                      <div className="flex flex-wrap items-center gap-3 text-xs text-gray-500 mb-2">
                        <span>Total: {stats.total}</span>
                        <span className="text-green-600">
                          +{stats.inserted || 0} inserted
                        </span>
                        {stats.unchanged > 0 && (
                          <span>{stats.unchanged} unchanged</span>
                        )}
                        {stats.errors > 0 && (
                          <span className="text-red-600">
                            {stats.errors} errors
                          </span>
                        )}
                      </div>
                    )}

                    {live && stats.total > 0 && (
                      <p className="text-xs text-gray-500 mb-2">
                        {stats.total} rows in source table (not copied into Field
                        Collector)
                      </p>
                    )}

                    {s.last_sync_error && !live && (
                      <p className="text-xs text-red-600 mb-2 font-mono bg-red-50 rounded px-2 py-1">
                        {s.last_sync_error}
                      </p>
                    )}

                    <div className="flex items-center gap-3 text-xs text-gray-500">
                      {!live && s.last_synced_at && (
                        <span className="flex items-center gap-1">
                          <Clock className="h-3 w-3" />
                          Last sync:{" "}
                          {new Date(s.last_synced_at).toLocaleString()}
                        </span>
                      )}
                      {s.auto_refresh_minutes > 0 && !live && (
                        <span>Auto every {s.auto_refresh_minutes} min</span>
                      )}
                    </div>

                    <div className="mt-2 flex items-center gap-2 flex-wrap">
                      <span className="text-xs text-gray-500">
                        Connection profile:
                      </span>
                      {hasConnection ? (
                        <span className="flex items-center gap-1 rounded-full bg-green-50 px-2 py-0.5 text-xs text-green-700 border border-green-200">
                          <Plug className="h-3 w-3" />
                          Linked
                        </span>
                      ) : live || showReconcile ? (
                        <span className="flex items-center gap-1 rounded-full bg-sky-50 px-2 py-0.5 text-xs text-sky-800 border border-sky-200">
                          <Database className="h-3 w-3" />
                          Using FC database
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 rounded-full bg-amber-50 px-2 py-0.5 text-xs text-amber-700 border border-amber-200">
                          <AlertCircle className="h-3 w-3" />
                          No connection profile
                        </span>
                      )}
                      <button
                        onClick={() => setLinkingSource(s)}
                        className="text-xs text-blue-600 hover:text-blue-800 underline"
                      >
                        {hasConnection ? "Change" : "Link connection"}
                      </button>
                      {!hasConnection && (live || showReconcile) && (
                        <span className="text-[11px] text-gray-400">
                          Optional — needed for remote DBs
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {showReconcile && (
                      <button
                        onClick={() => setReconcilingSource(s)}
                        className="rounded-lg bg-purple-50 px-3 py-1.5 text-sm text-purple-700 hover:bg-purple-100 flex items-center gap-1.5"
                        title={
                          (reconcileSummary?.resolved_pending_apply ?? 0) > 0
                            ? `${reconcileSummary.resolved_pending_apply} resolved conflict(s) ready to apply`
                            : "Reconcile collected changes to source"
                        }
                      >
                        <Eye className="h-3.5 w-3.5" />
                        Reconcile
                        {(reconcileSummary?.resolved_pending_apply ?? 0) > 0 && (
                          <span className="ml-0.5 rounded-full bg-amber-200 text-amber-900 px-1.5 py-0.5 text-[10px] font-semibold leading-none">
                            {reconcileSummary.resolved_pending_apply} ready
                          </span>
                        )}
                      </button>
                    )}
                    {live ? (
                      <span
                        className="rounded-lg bg-gray-50 px-3 py-1.5 text-sm text-gray-400 flex items-center gap-1 cursor-default"
                        title="Linked tables stay live in the source DB — nothing to materialize"
                      >
                        <RefreshCw className="h-3.5 w-3.5" />
                        Live — no sync
                      </span>
                    ) : (
                      s.source_type !== "file" && (
                        <button
                          onClick={() => syncMutation.mutate(s.id)}
                          disabled={syncMutation.isPending}
                          className="rounded-lg bg-blue-50 px-3 py-1.5 text-sm text-blue-700 hover:bg-blue-100 disabled:opacity-50 flex items-center gap-1"
                        >
                          <RefreshCw
                            className={`h-3.5 w-3.5 ${
                              syncMutation.isPending ? "animate-spin" : ""
                            }`}
                          />
                          Sync
                        </button>
                      )
                    )}
                    {!isLinkedLayer && (
                      <button
                        onClick={() => {
                          if (confirm("Delete this data source?"))
                            deleteMutation.mutate(s.id);
                        }}
                        className="text-gray-400 hover:text-red-500 p-1"
                        title="Delete"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {showCreate && (
        <ImportDataSourceDialog
          projectId={projectId}
          layerId={layerId}
          onClose={() => setShowCreate(false)}
        />
      )}

      {linkingSource && (
        <LinkConnectionDrawer
          projectId={projectId}
          layerId={layerId}
          dataSource={linkingSource}
          isLiveLinked={isLiveLinkedSource(linkingSource, layer)}
          onClose={() => setLinkingSource(null)}
        />
      )}
      {reconcilingSource && (
        <ReconcileFlowModal
          projectId={projectId}
          layerId={layerId}
          dataSource={reconcilingSource}
          onClose={() => {
            setReconcilingSource(null);
            queryClient.invalidateQueries({
              queryKey: ["reconcileSummary", layerId],
            });
          }}
        />
      )}
    </div>
  );
}

function SyncStatusBadge({
  status,
  live,
}: {
  status?: string;
  live?: boolean;
}) {
  if (live || status === "linked") {
    return (
      <span className="flex items-center gap-0.5 rounded-full bg-sky-50 px-2 py-0.5 text-xs text-sky-700">
        <CheckCircle2 className="h-3 w-3" /> Live
      </span>
    );
  }
  if (!status) return null;
  if (status === "success") {
    return (
      <span className="flex items-center gap-0.5 rounded-full bg-green-50 px-2 py-0.5 text-xs text-green-700">
        <CheckCircle2 className="h-3 w-3" /> Synced
      </span>
    );
  }
  if (status === "failed") {
    return (
      <span className="flex items-center gap-0.5 rounded-full bg-red-50 px-2 py-0.5 text-xs text-red-700">
        <XCircle className="h-3 w-3" /> Failed
      </span>
    );
  }
  if (status === "running") {
    return (
      <span className="flex items-center gap-0.5 rounded-full bg-blue-50 px-2 py-0.5 text-xs text-blue-700">
        <RefreshCw className="h-3 w-3 animate-spin" /> Syncing
      </span>
    );
  }
  return null;
}
