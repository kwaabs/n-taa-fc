import { useEffect, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { X, Save, Trash2 } from "lucide-react";

import { ChoiceEditor } from "@/components/form-builder/ChoiceEditor";
import { api } from "@/lib/api";

interface Props {
  projectId: string;
  list: any | null;  // null = create new; non-null = edit
  open: boolean;
  onClose: () => void;
}

interface Choice {
  value: string;
  label: { en: string };
}

export function ChoiceListDrawer({ projectId, list, open, onClose }: Props) {
  const queryClient = useQueryClient();
  const isEdit = !!list;

  const [name, setName] = useState("");
  const [choices, setChoices] = useState<Choice[]>([]);
  const [confirmDelete, setConfirmDelete] = useState(false);

  // Sync local state when list prop changes
  useEffect(() => {
    if (list) {
      setName(list.name || "");
      const arr = Array.isArray(list.choices) ? list.choices : [];
      setChoices(
        arr.map((c: any) => ({
          value: c.value || "",
          label: { en: c?.label?.en || c.value || "" },
        }))
      );
    } else {
      setName("");
      setChoices([
        { value: "option_1", label: { en: "Option 1" } },
        { value: "option_2", label: { en: "Option 2" } },
      ]);
    }
    setConfirmDelete(false);
  }, [list, open]);

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (isEdit) {
        return api.updateChoiceList(projectId, list.id, { name, choices });
      }
      return api.createChoiceList(projectId, { name, choices });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["choiceLists", projectId] });
      toast.success(isEdit ? "Choice list updated" : "Choice list created");
      onClose();
    },
    onError: (err: any) => {
      toast.error("Save failed", {
        description: err?.message ?? "Could not save the choice list.",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async () => {
      if (!list) return;
      return api.deleteChoiceList(projectId, list.id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["choiceLists", projectId] });
      toast.success("Choice list deleted");
      onClose();
    },
    onError: (err: any) => {
      toast.error("Delete failed", {
        description:
          err?.message ?? "Could not delete. It may be in use by a form field.",
      });
    },
  });

  if (!open) return null;

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-40 bg-black/30" />

      {/* Drawer */}
      <div className="fixed inset-y-0 right-0 z-50 w-full max-w-md bg-white shadow-2xl flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between px-5 py-4 border-b border-gray-200 shrink-0">
          <div className="min-w-0">
            <p className="text-xs text-gray-500">
              {isEdit ? "Edit Choice List" : "New Choice List"}
            </p>
            <p className="text-sm font-semibold text-gray-900 truncate">
              {name || (isEdit ? list.name : "Untitled")}
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
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">
              Name
            </label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Districts, Status codes"
              className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
            />
          </div>

          <ChoiceEditor choices={choices} onChange={setChoices} />

          {/* Delete confirmation inline */}
          {isEdit && confirmDelete && (
            <div className="rounded-lg border border-red-200 bg-red-50 p-3">
              <p className="text-xs text-red-800 mb-2">
                Delete <span className="font-semibold">{list.name}</span>? Fields
                using this list will need to be reattached.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setConfirmDelete(false)}
                  className="flex-1 rounded border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-white"
                >
                  Cancel
                </button>
                <button
                  onClick={() => deleteMutation.mutate()}
                  disabled={deleteMutation.isPending}
                  className="flex-1 rounded bg-red-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-700 disabled:opacity-50"
                >
                  {deleteMutation.isPending ? "Deleting..." : "Yes, delete"}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-gray-200 bg-white shrink-0">
          <div className="flex gap-2 w-full items-center">
            {isEdit && !confirmDelete && (
              <button
                onClick={() => setConfirmDelete(true)}
                className="flex items-center gap-1 rounded-lg border border-red-200 px-3 py-2 text-sm font-medium text-red-600 hover:bg-red-50"
              >
                <Trash2 className="h-4 w-4" />
                Delete
              </button>
            )}
            <div className="flex-1" />
            <button
              onClick={onClose}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending || !name.trim()}
              className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
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