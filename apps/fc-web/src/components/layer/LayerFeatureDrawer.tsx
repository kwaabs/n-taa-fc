import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Tag, MapPin, Clock, FileText, Braces, Upload } from "lucide-react";
import { AttachmentList } from "@/components/attachments/AttachmentList";
import { api } from "@/lib/api";
import { useParams } from "react-router-dom";

interface Props {
  feature: any;
  layerId: string;
  onClose: () => void;
}

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}

function statusBadge(status: string) {
  const map: Record<string, string> = {
    approved: "bg-green-50 text-green-700",
    submitted: "bg-blue-50 text-blue-700",
    rejected: "bg-red-50 text-red-700",
    draft: "bg-gray-100 text-gray-600",
    under_review: "bg-purple-50 text-purple-700",
  };
  return map[status] || "bg-gray-100 text-gray-600";
}

function canWriteBack(feature: any, isLinked: boolean): boolean {
  if (isLinked || !feature?.id || feature.write_back_applied) return false;
  if (feature.change_type === "updated" || feature.change_type === "deleted") {
    return !!feature.source_ref;
  }
  return feature.change_type === "inserted";
}

export function LayerFeatureDrawer({ feature, layerId, onClose }: Props) {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const isLinked = feature._linked || feature.source === "linked";
  const attrs = feature.attributes || {};
  const [resultMsg, setResultMsg] = useState<{
    kind: "ok" | "warn" | "err";
    text: string;
  } | null>(null);
  const [locallyApplied, setLocallyApplied] = useState(false);
  const [prettyJSON, setPrettyJSON] = useState(true);

  let geom: any = null;
  try {
    geom =
      typeof feature.geometry === "string"
        ? JSON.parse(feature.geometry)
        : feature.geometry;
  } catch {}

  const title =
    feature.source_ref ||
    feature.client_id ||
    feature.id ||
    "Feature";

  const writeBack = useMutation({
    mutationFn: () =>
      api.writeBackFeature(projectId!, layerId, feature.id),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ["layerFeatures", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layerSummary", layerId] });
      queryClient.invalidateQueries({ queryKey: ["reconcileSummary", layerId] });
      queryClient.invalidateQueries({
        queryKey: ["reconcileConflicts", layerId],
      });
      if (res.outcome === "applied") {
        setLocallyApplied(true);
        setResultMsg({
          kind: "ok",
          text:
            res.change_type === "inserted"
              ? `Inserted into source as id ${res.source_ref}.`
              : `Wrote ${res.change_type} to source (${res.source_ref}).`,
        });
      } else if (res.outcome === "skipped") {
        setLocallyApplied(true);
        setResultMsg({
          kind: "warn",
          text: res.reason || "Already applied.",
        });
      } else if (res.outcome === "conflict") {
        setResultMsg({
          kind: "warn",
          text: res.reason
            ? `Conflict: ${res.reason}`
            : "Conflict detected — resolve on the Conflicts tab, then retry.",
        });
      } else {
        setResultMsg({
          kind: "err",
          text: res.reason || "Write-back failed.",
        });
      }
    },
    onError: (err: Error) => {
      setResultMsg({ kind: "err", text: err.message || "Write-back failed." });
    },
  });

  const alreadyApplied = !!feature.write_back_applied || locallyApplied;
  const showWriteBack =
    canWriteBack({ ...feature, write_back_applied: alreadyApplied }, isLinked) &&
    !!projectId &&
    !!layerId;

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/30" />
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-white shadow-2xl flex flex-col">
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">
              {isLinked ? "Linked feature" : "Feature"}
            </p>
            <p className="text-sm font-mono text-gray-900 truncate">{title}</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 shrink-0"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-5 flex flex-col gap-5">
          {/* Status + source */}
          <div className="flex items-center gap-2 flex-wrap">
            {feature.status && (
              <span
                className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusBadge(
                  feature.status
                )}`}
              >
                {feature.status}
              </span>
            )}
            {feature.source && (
              <span
                className={`rounded-full px-2 py-0.5 text-xs ${
                  feature.source === "reference" || feature.source === "linked"
                    ? "bg-blue-50 text-blue-700"
                    : "bg-green-50 text-green-700"
                }`}
              >
                {feature.source}
              </span>
            )}
            {feature.change_type && (
              <span className="rounded-full px-2 py-0.5 text-xs bg-yellow-50 text-yellow-700">
                {feature.change_type}
              </span>
            )}
            {alreadyApplied && (
              <span className="rounded-full px-2 py-0.5 text-xs bg-emerald-50 text-emerald-700">
                Written back
              </span>
            )}
            {!isLinked && feature.source_ref && (
              <span className="rounded-full px-2 py-0.5 text-xs bg-gray-100 text-gray-600 font-mono">
                ref: {feature.source_ref}
              </span>
            )}
          </div>

          {alreadyApplied && !showWriteBack && (
            <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
              Already written back to source
              {feature.source_ref ? ` (${feature.source_ref})` : ""}.
            </div>
          )}

          {showWriteBack && (
            <div className="rounded-lg border border-gray-200 p-3 flex flex-col gap-2">
              <button
                type="button"
                disabled={writeBack.isPending}
                onClick={() => {
                  setResultMsg(null);
                  writeBack.mutate();
                }}
                className="inline-flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                <Upload className="h-4 w-4" />
                {writeBack.isPending
                  ? "Writing back…"
                  : feature.change_type === "deleted"
                    ? "Write back delete"
                    : feature.change_type === "inserted"
                      ? "Write back insert"
                      : "Write back update"}
              </button>
              <p className="text-xs text-gray-500">
                {feature.change_type === "inserted"
                  ? "Inserts this collected feature into the linked source table. A new source id will be assigned."
                  : `Pushes this ${feature.change_type} change to the linked source row (${feature.source_ref}).`}
              </p>
              {resultMsg && (
                <p
                  className={`text-xs rounded-md px-2 py-1.5 ${
                    resultMsg.kind === "ok"
                      ? "bg-green-50 text-green-800"
                      : resultMsg.kind === "warn"
                        ? "bg-amber-50 text-amber-800"
                        : "bg-red-50 text-red-700"
                  }`}
                >
                  {resultMsg.text}
                </p>
              )}
            </div>
          )}

          {/* Geometry */}
          {geom && (
            <div className="rounded-lg border border-gray-200 p-3">
              <p className="text-xs font-medium text-gray-600 mb-2 flex items-center gap-1">
                <MapPin className="h-3.5 w-3.5" /> Geometry
              </p>
              <p className="text-xs text-gray-700">
                <span className="font-mono">{geom.type}</span>
                {geom.type === "Point" && geom.coordinates && (
                  <span className="ml-2 text-gray-500">
                    [{geom.coordinates[1].toFixed(5)},{" "}
                    {geom.coordinates[0].toFixed(5)}]
                  </span>
                )}
              </p>
            </div>
          )}

          {/* Attributes */}
          <div>
            <p className="text-xs font-medium text-gray-600 mb-2 flex items-center gap-1">
              <Tag className="h-3.5 w-3.5" /> Attributes
            </p>
            {Object.keys(attrs).length === 0 ? (
              <p className="text-xs text-gray-400 italic">No attributes</p>
            ) : (
              <div className="rounded-lg border border-gray-200 divide-y divide-gray-100">
                {Object.entries(attrs).map(([key, value]) => (
                  <div key={key} className="px-3 py-2 flex items-start gap-3">
                    <p className="text-xs text-gray-500 min-w-[100px]">
                      {humanize(key)}
                    </p>
                    <p className="text-xs text-gray-900 break-all flex-1">
                      {value === null || value === undefined
                        ? "—"
                        : typeof value === "object"
                        ? JSON.stringify(value)
                        : String(value)}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Attachments */}
          {projectId && !isLinked && (
            <AttachmentList projectId={projectId} feature={feature} />
          )}

          {/* Timestamps */}
          <div className="rounded-lg border border-gray-200 p-3 text-xs text-gray-600">
            <p className="font-medium text-gray-700 mb-2 flex items-center gap-1">
              <Clock className="h-3.5 w-3.5" /> Timeline
            </p>
            <div className="flex flex-col gap-1">
              {feature.collected_at && (
                <p>
                  Collected{" "}
                  <span className="text-gray-900">
                    {new Date(feature.collected_at).toLocaleString()}
                  </span>
                </p>
              )}
              {feature.synced_at && (
                <p>
                  Synced{" "}
                  <span className="text-gray-900">
                    {new Date(feature.synced_at).toLocaleString()}
                  </span>
                </p>
              )}
              {feature.reviewed_at && (
                <p>
                  Reviewed{" "}
                  <span className="text-gray-900">
                    {new Date(feature.reviewed_at).toLocaleString()}
                  </span>
                </p>
              )}
            </div>
          </div>

          {/* Raw JSON */}
          <details className="rounded-lg border border-gray-200 p-3">
            <summary className="text-xs font-medium text-gray-600 cursor-pointer flex items-center gap-1">
              <FileText className="h-3.5 w-3.5" /> Raw JSON
            </summary>
            <div className="mt-2 flex items-center justify-end">
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setPrettyJSON((v) => !v);
                }}
                className={
                  "inline-flex items-center gap-1 rounded border px-2 py-0.5 text-[11px] font-medium transition-colors " +
                  (prettyJSON
                    ? "border-blue-200 bg-blue-50 text-blue-700"
                    : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
                }
                title={prettyJSON ? "Show compact JSON" : "Show prettified JSON"}
              >
                <Braces className="h-3 w-3" />
                {prettyJSON ? "Pretty" : "Compact"}
              </button>
            </div>
            <pre className="text-xs text-gray-700 mt-2 overflow-auto max-h-64 whitespace-pre-wrap break-all">
              {prettyJSON
                ? JSON.stringify(feature, null, 2)
                : JSON.stringify(feature)}
            </pre>
          </details>
        </div>
      </div>
    </>
  );
}
