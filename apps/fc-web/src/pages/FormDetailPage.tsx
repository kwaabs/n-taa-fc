import { useMemo, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { FormPreview } from "@/components/form-builder/FormPreview";
import { FieldRow } from "@/components/forms/FieldRow";
import { isSystemFieldId } from "@/lib/system-fields";
import {
  ArrowLeft,
  Pencil,
  ChevronRight,
  Clock,
  Check,
  Eye,
  EyeOff,
  FileJson,
  FileText,
} from "lucide-react";

export function FormDetailPage() {
  const { projectId, formId } = useParams();
  const queryClient = useQueryClient();
  const [selectedVersion, setSelectedVersion] = useState<number | null>(null);
  const [showSystem, setShowSystem] = useState(false);
  const [showRaw, setShowRaw] = useState(false);

  const { data: form } = useQuery({
    queryKey: ["form", formId],
    queryFn: () => api.getForm(projectId!, formId!),
    enabled: !!formId,
  });

  const { data: versions } = useQuery({
    queryKey: ["formVersions", formId],
    queryFn: () => api.getFormVersions(projectId!, formId!),
    enabled: !!formId,
  });

  const versionList = Array.isArray(versions) ? versions : [];

  const publishMutation = useMutation({
    mutationFn: (version: number) =>
      api.publishForm(projectId!, formId!, version),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["formVersions", formId] });
      queryClient.invalidateQueries({ queryKey: ["form", formId] });
    },
  });

  // Determine which schema to display
  const activeVersion = selectedVersion
    ? versionList.find((v: any) => v.version === selectedVersion)
    : null;

  const displaySchema = activeVersion?.schema || form?.schema;
  const allFields = useMemo<any[]>(
    () => displaySchema?.fields || [],
    [displaySchema]
  );
  const displayVersionNum = activeVersion
    ? activeVersion.version
    : form?.version;
  const displayIsDraft = activeVersion ? activeVersion.is_draft : false;

  // Apply system filter
  const visibleFields = useMemo(
    () =>
      showSystem
        ? allFields
        : allFields.filter((f: any) => !isSystemFieldId(f?.id)),
    [allFields, showSystem]
  );

  const systemFieldCount = allFields.length - visibleFields.length;
  const requiredCount = visibleFields.filter((f: any) => f.required).length;

  return (
    <div className="p-6 h-full flex flex-col overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Link
          to={"/projects/" + projectId + "/forms"}
          className="text-gray-400 hover:text-gray-600"
        >
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex-1">
          <h1 className="text-xl font-bold text-gray-900">
            {form?.name || "Loading..."}
          </h1>
          <p className="text-sm text-gray-500">{form?.description}</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowSystem(!showSystem)}
            className={
              "flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-medium transition-colors " +
              (showSystem
                ? "border-amber-200 bg-amber-50 text-amber-700"
                : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
            }
            title={
              showSystem
                ? "Hide system fields"
                : "Show system fields"
            }
          >
            {showSystem ? (
              <EyeOff className="h-4 w-4" />
            ) : (
              <Eye className="h-4 w-4" />
            )}
            System
            {systemFieldCount > 0 && (
              <span
                className={
                  "rounded-full px-1.5 py-0.5 text-[10px] " +
                  (showSystem
                    ? "bg-amber-100 text-amber-700"
                    : "bg-gray-100 text-gray-500")
                }
              >
                {systemFieldCount}
              </span>
            )}
          </button>

          <button
            onClick={() => setShowRaw(!showRaw)}
            className={
              "flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-medium transition-colors " +
              (showRaw
                ? "border-blue-200 bg-blue-50 text-blue-700"
                : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
            }
            title="Toggle raw JSON view"
          >
            {showRaw ? (
              <FileText className="h-4 w-4" />
            ) : (
              <FileJson className="h-4 w-4" />
            )}
            {showRaw ? "Pretty" : "Raw JSON"}
          </button>

          <span className="text-sm text-gray-400 ml-1">
            v{displayVersionNum}
            {displayIsDraft && " (draft)"}
          </span>
          <Link
            to={"/projects/" + projectId + "/forms/" + formId + "/edit"}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Pencil className="h-4 w-4" />
            Edit Form
          </Link>
        </div>
      </div>

      {/* Main content */}
      <div className="flex gap-6 flex-1 min-h-0">
        {/* Left: Versions */}
        <div className="w-72 flex flex-col gap-4 shrink-0">
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <h3 className="font-medium text-gray-900 mb-3 flex items-center gap-2">
              <Clock className="h-4 w-4 text-gray-400" />
              Versions ({versionList.length})
            </h3>
            <div className="flex flex-col gap-1.5 max-h-96 overflow-y-auto pr-1">
              {versionList.map((v: any) => {
                const isViewing =
                  selectedVersion === v.version ||
                  (!selectedVersion && v.version === form?.version);
                return (
                  <div
                    key={v.id}
                    onClick={() => setSelectedVersion(v.version)}
                    className={
                      "flex items-center justify-between rounded-lg px-3 py-2 text-sm transition-colors text-left cursor-pointer " +
                      (isViewing
                        ? "bg-blue-50 border border-blue-200 text-blue-700"
                        : "border border-gray-100 hover:bg-gray-50 text-gray-700")
                    }
                  >
                    <div className="flex items-center gap-2">
                      <span className="font-medium">v{v.version}</span>
                      {!v.is_draft && (
                        <span className="flex items-center gap-0.5 rounded-full bg-green-100 px-1.5 py-0.5 text-xs text-green-700">
                          <Check className="h-3 w-3" />
                          Published
                        </span>
                      )}
                      {v.is_draft && (
                        <span className="rounded-full bg-yellow-100 px-1.5 py-0.5 text-xs text-yellow-700">
                          Draft
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      {v.is_draft && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            publishMutation.mutate(v.version);
                          }}
                          disabled={publishMutation.isPending}
                          className="rounded bg-green-600 px-2 py-0.5 text-xs text-white hover:bg-green-700 disabled:opacity-50"
                        >
                          Publish
                        </button>
                      )}
                      {isViewing && (
                        <ChevronRight className="h-4 w-4 text-blue-400" />
                      )}
                    </div>
                  </div>
                );
              })}
              {versionList.length === 0 && (
                <p className="text-sm text-gray-400 italic">
                  No versions yet
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Middle: field list (enhanced) or raw JSON */}
        <div className="flex-1 bg-white rounded-xl border border-gray-200 p-4 flex flex-col min-w-0">
          <div className="flex items-baseline gap-3 mb-3">
            <h3 className="font-medium text-gray-900">Schema</h3>
            <span className="text-xs text-gray-500">
              {visibleFields.length} field
              {visibleFields.length === 1 ? "" : "s"} shown
              {!showSystem && systemFieldCount > 0 && (
                <>
                  {" "}
                  · {systemFieldCount} system hidden
                </>
              )}
              {requiredCount > 0 && (
                <>
                  {" "}
                  · {requiredCount} required
                </>
              )}
            </span>
          </div>

          {showRaw ? (
            <pre className="flex-1 overflow-auto rounded-lg bg-gray-50 border border-gray-200 p-3 text-[11px] font-mono text-gray-800">
              {JSON.stringify(displaySchema ?? {}, null, 2)}
            </pre>
          ) : (
            <div className="flex flex-col gap-1.5 overflow-y-auto pr-1 flex-1">
              {visibleFields.map((f: any, idx: number) => (
                <FieldRow key={f.id || idx} field={f} index={idx} />
              ))}
              {visibleFields.length === 0 && (
                <p className="text-sm text-gray-400 italic mt-2">
                  No fields to display
                  {!showSystem && systemFieldCount > 0 && (
                    <>
                      {" "}
                      (all {systemFieldCount} are system fields — toggle System
                      to view)
                    </>
                  )}
                </p>
              )}
            </div>
          )}
        </div>

        {/* Right: Interactive preview */}
        <div className="w-[380px] shrink-0 flex items-start justify-center bg-gray-100 rounded-xl border border-gray-200 overflow-y-auto p-6">
          {visibleFields.length > 0 ? (
            <div className="w-full max-w-[340px] sticky top-0">
              <FormPreview
                fields={visibleFields}
                formName={
                  (form?.name || "Form") +
                  " — v" +
                  (displayVersionNum || "?")
                }
              />
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-full text-gray-400">
              <p className="text-lg font-medium">No fields to preview</p>
              <p className="text-sm mt-1">
                {!showSystem && systemFieldCount > 0
                  ? "Only system fields exist"
                  : "Edit the form to add fields"}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}