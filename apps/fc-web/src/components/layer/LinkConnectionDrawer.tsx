import { useEffect, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  X,
  Link as LinkIcon,
  Unlink,
  Database,
  ExternalLink,
  AlertCircle,
  CheckCircle2,
} from "lucide-react";

import { api } from "@/lib/api";

interface Props {
  projectId: string;
  layerId: string;
  dataSource: any | null;
  /** When true, explain FC-home-DB fallback instead of "reconciliation disabled". */
  isLiveLinked?: boolean;
  onClose: () => void;
}

export function LinkConnectionDrawer({
  projectId,
  layerId,
  dataSource,
  isLiveLinked = false,
  onClose,
}: Props) {
  const queryClient = useQueryClient();

  const currentConnectionId: string | null =
    dataSource?.config?.connection_id ?? null;

  const [selected, setSelected] = useState<string | null>(currentConnectionId);

  useEffect(() => {
    setSelected(dataSource?.config?.connection_id ?? null);
  }, [dataSource]);

  const { data: connections, isLoading: connectionsLoading } = useQuery({
    queryKey: ["projectConnections", projectId],
    queryFn: () => api.getProjectConnections(projectId),
    enabled: !!projectId && !!dataSource,
  });

  const connectionList = Array.isArray(connections) ? connections : [];

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!dataSource) throw new Error("no data source");
      return api.linkDataSourceConnection(
        projectId,
        layerId,
        dataSource.id,
        selected
      );
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["dataSources", layerId] });
      toast.success(
        selected ? "Connection linked" : "Connection unlinked",
        {
          description: selected
            ? "Write-back will use this connection profile."
            : isLiveLinked
              ? "Write-back can still use the FC database when the table is on the same server."
              : "Link a connection profile before reconciling remote sources.",
        }
      );
      onClose();
    },
    onError: (err: any) => {
      toast.error("Failed to update link", {
        description: err?.message ?? "Could not update the data source link.",
      });
    },
  });

  if (!dataSource) return null;

  const cfg = dataSource.config ?? {};
  const schema = cfg.schema ?? "—";
  const table = cfg.table ?? "—";
  const hasChange = selected !== currentConnectionId;

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40 bg-black/30" />

      {/* Drawer */}
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">Link Connection</p>
            <p className="text-sm font-semibold text-gray-900 truncate">
              {dataSource.name}
            </p>
            <p className="text-[11px] font-mono text-gray-400 truncate">
              {schema}.{table}
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
          {/* Current state */}
          <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
            <p className="text-xs text-gray-500 mb-1">Current state</p>
            {currentConnectionId ? (
              <div className="flex items-center gap-2 text-sm text-green-700">
                <CheckCircle2 className="h-4 w-4" />
                Connection profile linked
              </div>
            ) : isLiveLinked ? (
              <div className="flex items-center gap-2 text-sm text-sky-800">
                <Database className="h-4 w-4" />
                Using FC database (no connection profile)
              </div>
            ) : (
              <div className="flex items-center gap-2 text-sm text-amber-700">
                <AlertCircle className="h-4 w-4" />
                No connection profile
              </div>
            )}
            {isLiveLinked && !currentConnectionId && (
              <p className="text-xs text-gray-500 mt-2">
                Optional for tables on the same database as Field Collector.
                Link a profile when write-back needs different credentials or a
                remote host.
              </p>
            )}
          </div>

          {/* Connection chooser */}
          <div className="flex flex-col gap-2">
            <label className="text-xs font-medium text-gray-600">
              Connection
            </label>

            {connectionsLoading ? (
              <p className="text-sm text-gray-500">Loading connections…</p>
            ) : connectionList.length === 0 ? (
              <div className="rounded-lg border border-dashed border-gray-300 p-4 text-center">
                <Database className="h-8 w-8 mx-auto text-gray-300 mb-2" />
                <p className="text-sm text-gray-700">No connections yet</p>
                <p className="text-xs text-gray-500 mt-1">
                  Create one via the Import Wizard first.
                </p>
              </div>
            ) : (
              <div className="flex flex-col gap-1">
                {/* Unlink option */}
                <label
                  className={
                    "flex items-start gap-3 rounded-lg border p-3 cursor-pointer transition-colors " +
                    (selected === null
                      ? "border-blue-500 bg-blue-50"
                      : "border-gray-200 hover:bg-gray-50")
                  }
                >
                  <input
                    type="radio"
                    name="connection"
                    checked={selected === null}
                    onChange={() => setSelected(null)}
                    className="mt-0.5"
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 text-sm font-medium text-gray-900">
                      <Unlink className="h-3.5 w-3.5" />
                      None (unlinked)
                    </div>
                    <p className="text-xs text-gray-500 mt-0.5">
                      {isLiveLinked
                        ? "Fall back to the FC database for write-back when the table is local."
                        : "Required for write-back on remote database sources."}
                    </p>
                  </div>
                </label>

                {connectionList.map((c: any) => (
                  <label
                    key={c.id}
                    className={
                      "flex items-start gap-3 rounded-lg border p-3 cursor-pointer transition-colors " +
                      (selected === c.id
                        ? "border-blue-500 bg-blue-50"
                        : "border-gray-200 hover:bg-gray-50")
                    }
                  >
                    <input
                      type="radio"
                      name="connection"
                      checked={selected === c.id}
                      onChange={() => setSelected(c.id)}
                      className="mt-0.5"
                    />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 text-sm font-medium text-gray-900">
                        <Database className="h-3.5 w-3.5" />
                        {c.name}
                      </div>
                      <p className="text-[11px] font-mono text-gray-500 truncate mt-0.5">
                        {c.host}:{c.port}/{c.database}
                      </p>
                      <p className="text-[11px] text-gray-400 mt-0.5">
                        as {c.username}
                      </p>
                    </div>
                  </label>
                ))}
              </div>
            )}

            {/* Manage link */}
            <a
              href={`/projects/${projectId}/connections`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-[11px] text-blue-600 hover:text-blue-800 flex items-center gap-0.5 mt-1"
            >
              Manage connections <ExternalLink className="h-2.5 w-2.5" />
            </a>
          </div>

          {/* Hint */}
          {selected && selected !== currentConnectionId && (
            <div className="rounded-lg border border-blue-200 bg-blue-50 p-3">
              <p className="text-xs text-blue-900">
                <strong>Save & Test</strong> will validate the connection by
                running <code className="font-mono">SELECT 1 FROM {schema}.
                {table} LIMIT 1</code>. If it fails, the link won't be saved.
              </p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-gray-200 bg-white shrink-0">
          <div className="flex gap-2 w-full">
            <button
              onClick={onClose}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending || !hasChange}
              className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <LinkIcon className="h-4 w-4" />
              {saveMutation.isPending
                ? "Saving…"
                : selected
                ? "Save & Test"
                : "Unlink"}
            </button>
          </div>
        </div>
      </div>
    </>
  );
}