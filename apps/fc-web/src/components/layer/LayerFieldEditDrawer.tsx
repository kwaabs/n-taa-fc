import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { X, Save, Lock } from "lucide-react";

import { FieldSettingsPanel } from "@/components/form-builder/FieldSettingsPanel";
import { isSystemFieldId } from "@/lib/system-fields";
import { api } from "@/lib/api";

interface Props {
  projectId: string;
  form: any; // full form object (with .schema.fields)
  field: any | null; // null = closed; non-null = editing that field
  onClose: () => void;
}

export function LayerFieldEditDrawer({
  projectId,
  form,
  field,
  onClose,
}: Props) {
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<any | null>(field);
  const isSystem = !!field && isSystemFieldId(field.id);

  useEffect(() => {
    setDraft(field);
  }, [field]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!draft || !form) throw new Error("Nothing to save");

      const fields = (form.schema?.fields ?? []).map((f: any) =>
        f.id === draft.id ? draft : f
      );

      const updatedSchema = {
        ...form.schema,
        fields,
      };

      return api.updateForm(projectId, form.id, {
        ...form,
        schema: updatedSchema,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["form", form.id] });
      queryClient.invalidateQueries({ queryKey: ["layer"] });
      toast.success("Field saved", {
        description: "Publish the layer to push field + form changes to mobile.",
      });
      onClose();
    },
    onError: (err: any) => {
      toast.error("Save failed", {
        description: err?.message ?? "Could not save the field.",
      });
    },
  });

  if (!field) return null;

  const labelText =
    typeof draft?.label === "object"
      ? draft?.label?.en ?? draft?.id
      : draft?.label ?? draft?.id ?? "Field";

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40 bg-black/30" />

      {/* Drawer */}
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">Edit Field</p>
            <p className="text-sm font-semibold text-gray-900 truncate">
              {labelText}
            </p>
            <p className="text-[11px] font-mono text-gray-400 truncate">
              {draft?.type} · {draft?.id}
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 shrink-0"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* System field warning */}
        {isSystem && (
          <div className="mx-5 mt-3 mb-1 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 flex items-start gap-2 shrink-0">
            <Lock className="h-4 w-4 text-amber-700 mt-0.5 shrink-0" />
            <p className="text-xs text-amber-800">
              This is a system field. It cannot be edited from the layer view.
              Use the form editor for advanced changes.
            </p>
          </div>
        )}

        {/* Body */}
        <div className="flex-1 overflow-y-auto">
          {!isSystem && draft && (
            <FieldSettingsPanel
              field={draft}
              onChange={(updated) => setDraft(updated)}
            />
          )}
          {isSystem && draft && (
            <div className="px-5 py-3">
              <p className="text-xs text-gray-500">
                Field info shown for reference only.
              </p>
              <pre className="mt-2 rounded bg-gray-50 border border-gray-200 p-2 text-[11px] font-mono text-gray-700 overflow-auto">
                {JSON.stringify(draft, null, 2)}
              </pre>
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
              disabled={saveMutation.isPending || isSystem}
              className="flex-1 flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Save className="h-4 w-4" />
              {saveMutation.isPending ? "Saving..." : "Save"}
            </button>
          </div>
        </div>
      </div>
    </>
  );
}