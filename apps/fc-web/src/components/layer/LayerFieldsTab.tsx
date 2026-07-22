import { useEffect, useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "@/lib/api";
import { FieldRow } from "@/components/forms/FieldRow";
import { FormPreview } from "@/components/form-builder/FormPreview";
import { isSystemFieldId } from "@/lib/system-fields";
import { LayerFieldEditDrawer } from "./LayerFieldEditDrawer";
import { ReuseFormTemplateDialog } from "./ReuseFormTemplateDialog";
import {
  Eye,
  EyeOff,
  FileJson,
  FileText,
  AlertCircle,
  ExternalLink,
  Link2,
  Loader,
  Copy,
} from "lucide-react";

interface Props {
  projectId: string;
  layerId: string;
  formId?: string | null;
}

export function LayerFieldsTab({ projectId, layerId, formId }: Props) {
  const queryClient = useQueryClient();
  const [showSystem, setShowSystem] = useState(false);
  const [showRaw, setShowRaw] = useState(false);
  const [editingField, setEditingField] = useState<any | null>(null);
  const [ensureAttempted, setEnsureAttempted] = useState(false);
  const [showReuse, setShowReuse] = useState(false);

  const { data: layer, isLoading: layerLoading } = useQuery({
    queryKey: ["layer", layerId],
    queryFn: () => api.getLayer(projectId, layerId),
    enabled: !!layerId,
  });

  const effectiveFormId = formId || layer?.form_id;
  const isLinked = layer?.source_type === "linked_table";

  const ensureMutation = useMutation({
    mutationFn: () => api.ensureLayerForm(projectId, layerId),
    onSuccess: (updated) => {
      queryClient.setQueryData(["layer", layerId], updated);
      queryClient.invalidateQueries({ queryKey: ["layer", layerId] });
      queryClient.invalidateQueries({ queryKey: ["layers", projectId] });
    },
  });

  // Linked layers imported before form generation: backfill once.
  useEffect(() => {
    if (
      !layerLoading &&
      isLinked &&
      !effectiveFormId &&
      !ensureAttempted &&
      !ensureMutation.isPending &&
      !ensureMutation.isError
    ) {
      setEnsureAttempted(true);
      ensureMutation.mutate();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- run once when layer loads without form
  }, [layerLoading, isLinked, effectiveFormId, ensureAttempted]);

  const { data: form, isLoading, error } = useQuery({
    queryKey: ["form", effectiveFormId],
    queryFn: () => api.getForm(projectId, effectiveFormId!),
    enabled: !!effectiveFormId,
  });

  const allFields = useMemo<any[]>(
    () => form?.schema?.fields || [],
    [form]
  );

  const visibleFields = useMemo(
    () =>
      showSystem
        ? allFields
        : allFields.filter((f: any) => !isSystemFieldId(f?.id)),
    [allFields, showSystem]
  );

  const systemFieldCount = allFields.length - visibleFields.length;
  const requiredCount = visibleFields.filter((f: any) => f.required).length;

  if (isLinked && !effectiveFormId) {
    if (ensureMutation.isPending || (!ensureAttempted && !ensureMutation.isError)) {
      return (
        <div className="bg-white rounded-xl border border-gray-200 p-8">
          <div className="flex items-center justify-center gap-2 text-sm text-gray-500">
            <Loader className="h-4 w-4 animate-spin" />
            Generating fields from linked source table…
          </div>
        </div>
      );
    }
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8">
        <div className="flex flex-col items-center justify-center text-center">
          <div className="rounded-full bg-amber-50 p-3 mb-3">
            <Link2 className="h-6 w-6 text-amber-600" />
          </div>
          <h3 className="text-base font-medium text-gray-900">
            Couldn’t load source columns
          </h3>
          <p className="text-sm text-gray-500 mt-1 max-w-md">
            {(ensureMutation.error as Error)?.message ||
              "Failed to generate a form from the linked table."}
          </p>
          <button
            type="button"
            onClick={() => ensureMutation.mutate()}
            className="mt-4 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Retry
          </button>
          <button
            type="button"
            onClick={() => setShowReuse(true)}
            className="mt-2 flex items-center gap-1.5 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            <Copy className="h-4 w-4" />
            Reuse form from another project
          </button>
        </div>
        {showReuse && (
          <ReuseFormTemplateDialog
            projectId={projectId}
            layerId={layerId}
            layerName={layer?.name}
            onClose={() => setShowReuse(false)}
          />
        )}
      </div>
    );
  }

  // No linked form
  if (!effectiveFormId) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8">
        <div className="flex flex-col items-center justify-center text-center">
          <div className="rounded-full bg-amber-50 p-3 mb-3">
            <AlertCircle className="h-6 w-6 text-amber-600" />
          </div>
          <h3 className="text-base font-medium text-gray-900">
            No fields defined for this layer
          </h3>
          <p className="text-sm text-gray-500 mt-1 max-w-md">
            This layer has no linked form yet. Reuse a form template from another
            project, or create a form and link it to this layer.
          </p>
          <button
            type="button"
            onClick={() => setShowReuse(true)}
            className="mt-4 flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Copy className="h-4 w-4" />
            Reuse form template
          </button>
        </div>
        {showReuse && (
          <ReuseFormTemplateDialog
            projectId={projectId}
            layerId={layerId}
            layerName={layer?.name}
            onClose={() => setShowReuse(false)}
          />
        )}
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8">
        <p className="text-sm text-gray-500">Loading fields...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-xl border border-red-200 p-6">
        <p className="text-sm text-red-700">
          Failed to load form: {(error as Error).message}
        </p>
      </div>
    );
  }

  return (
    <div className="h-full min-h-0 flex gap-4">
      {/* Left: notice + toolbar + field list */}
      <div className="flex-1 min-w-0 min-h-0 flex flex-col bg-white rounded-xl border border-gray-200 overflow-hidden">
        {isLinked && (
          <div className="shrink-0 border-b border-blue-100 bg-blue-50 px-3 py-2 text-xs text-blue-800 flex items-start gap-2">
            <Link2 className="h-3.5 w-3.5 shrink-0 mt-0.5" />
            <span>
              Fields mirror columns on the linked source table. Editing here
              changes the form schema in Field Collector; it does not alter the
              database table.
            </span>
          </div>
        )}

        <div className="shrink-0 border-b border-gray-200 p-3">
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex-1 min-w-0">
              <h3 className="font-medium text-gray-900">
                Layer Fields
                <span className="ml-2 text-xs text-gray-500 font-normal">
                  v{form?.version}
                  {form?.description && ` · ${form.description}`}
                </span>
              </h3>
              <p className="text-xs text-gray-500 mt-0.5">
                {visibleFields.length} field
                {visibleFields.length === 1 ? "" : "s"} shown
                {!showSystem && systemFieldCount > 0 && (
                  <> · {systemFieldCount} system hidden</>
                )}
                {requiredCount > 0 && <> · {requiredCount} required</>}
              </p>
            </div>

            <button
              onClick={() => setShowSystem(!showSystem)}
              className={
                "flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors " +
                (showSystem
                  ? "border-amber-200 bg-amber-50 text-amber-700"
                  : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
              }
            >
              {showSystem ? (
                <EyeOff className="h-3.5 w-3.5" />
              ) : (
                <Eye className="h-3.5 w-3.5" />
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
                "flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors " +
                (showRaw
                  ? "border-blue-200 bg-blue-50 text-blue-700"
                  : "border-gray-200 bg-white text-gray-600 hover:bg-gray-50")
              }
            >
              {showRaw ? (
                <FileText className="h-3.5 w-3.5" />
              ) : (
                <FileJson className="h-3.5 w-3.5" />
              )}
              {showRaw ? "Pretty" : "Raw JSON"}
            </button>

            <Link
              to={`/projects/${projectId}/forms/${effectiveFormId}`}
              className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50"
              title="Open underlying form (advanced)"
            >
              <ExternalLink className="h-3.5 w-3.5" />
              Advanced
            </Link>

            <button
              type="button"
              onClick={() => setShowReuse(true)}
              className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50"
              title="Replace with a form template from another project"
            >
              <Copy className="h-3.5 w-3.5" />
              Reuse template
            </button>
          </div>
        </div>

        <div className="flex-1 min-h-0 overflow-y-auto p-4">
          {showRaw ? (
            <pre className="rounded-lg bg-gray-50 border border-gray-200 p-3 text-[11px] font-mono text-gray-800 whitespace-pre-wrap">
              {JSON.stringify(form?.schema ?? {}, null, 2)}
            </pre>
          ) : visibleFields.length === 0 ? (
            <p className="text-sm text-gray-400 italic">
              No fields to display
              {!showSystem && systemFieldCount > 0 && (
                <>
                  {" "}
                  (all {systemFieldCount} are system fields — toggle System to
                  view)
                </>
              )}
            </p>
          ) : (
            <div className="flex flex-col gap-1.5">
              {visibleFields.map((f: any, idx: number) => (
                <FieldRow
                  key={f.id || idx}
                  field={f}
                  index={idx}
                  onClick={(clicked) => setEditingField(clicked)}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Right: live preview — full column height */}
      <div className="w-[360px] shrink-0 min-h-0 flex items-stretch justify-center bg-gray-100 rounded-xl border border-gray-200 p-4 overflow-hidden">
        {visibleFields.length > 0 ? (
          <FormPreview
            fields={visibleFields}
            formName={
              (form?.name || layer?.name || "Layer form") +
              " — v" +
              (form?.version ?? "?")
            }
            className="h-full max-h-full"
          />
        ) : (
          <div className="flex flex-col items-center justify-center text-gray-400 text-center px-4">
            <p className="text-sm font-medium">No fields to preview</p>
            <p className="text-xs mt-1">
              {!showSystem && systemFieldCount > 0
                ? "Toggle System to include hidden fields"
                : "Add or reuse a form template first"}
            </p>
          </div>
        )}
      </div>

      <LayerFieldEditDrawer
        projectId={projectId}
        form={form}
        field={editingField}
        onClose={() => setEditingField(null)}
      />

      {showReuse && (
        <ReuseFormTemplateDialog
          projectId={projectId}
          layerId={layerId}
          layerName={layer?.name}
          onClose={() => setShowReuse(false)}
          onApplied={() => {
            queryClient.invalidateQueries({ queryKey: ["form"] });
          }}
        />
      )}
    </div>
  );
}
