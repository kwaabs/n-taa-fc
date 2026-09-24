import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import {
  CheckCircle2, Edit3, Send, RotateCcw, AlertCircle,
} from "lucide-react";

interface Props {
  projectId: string;
  layer: any;
}

export function LayerPublishBanner({ projectId, layer }: Props) {
  const queryClient = useQueryClient();
  const [showUnpublishConfirm, setShowUnpublishConfirm] = useState(false);
  const isPublished = layer?.status === "published";

  const publishMutation = useMutation({
    mutationFn: async () => {
      // Linked imports can lack a form; ensure before making the layer live.
      if (layer?.source_type === "linked_table" && !layer?.form_id) {
        await api.ensureLayerForm(projectId, layer.id);
      }
      return api.publishLayer(projectId, layer.id);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["layer", layer.id] });
      queryClient.invalidateQueries({ queryKey: ["layers", projectId] });
    },
  });

  const unpublishMutation = useMutation({
    mutationFn: () => api.unpublishLayer(projectId, layer.id),
    onSuccess: () => {
      setShowUnpublishConfirm(false);
      queryClient.invalidateQueries({ queryKey: ["layer", layer.id] });
      queryClient.invalidateQueries({ queryKey: ["layers", projectId] });
    },
  });

  return (
    <>
    <div
      className={`rounded-xl border p-4 flex items-start gap-3 ${
        isPublished
          ? "border-green-200 bg-green-50"
          : "border-yellow-200 bg-yellow-50"
      }`}
    >
      <div
        className={`rounded-lg p-2 shrink-0 ${
          isPublished ? "bg-green-100" : "bg-yellow-100"
        }`}
      >
        {isPublished ? (
          <CheckCircle2 className="h-5 w-5 text-green-700" />
        ) : (
          <Edit3 className="h-5 w-5 text-yellow-700" />
        )}
      </div>

      <div className="flex-1 min-w-0">
        <p
          className={`text-sm font-medium ${
            isPublished ? "text-green-900" : "text-yellow-900"
          }`}
        >
          {isPublished ? "Published" : "Draft"}
        </p>
        <p
          className={`text-xs mt-0.5 ${
            isPublished ? "text-green-700" : "text-yellow-700"
          }`}
        >
          {isPublished
            ? `Available to field workers. Last published ${
                layer.published_at
                  ? new Date(layer.published_at).toLocaleString()
                  : ""
              }.`
            : "This layer is not yet visible to field workers. Publish when ready — the linked form will be published too."}
        </p>
        {!isPublished && (
          <p className="text-xs text-yellow-700 mt-1 flex items-center gap-1">
            <AlertCircle className="h-3 w-3" />
            Editing is allowed only in draft mode.
          </p>
        )}
      </div>

      <div className="shrink-0">
        {isPublished ? (
          <button
            onClick={() => setShowUnpublishConfirm(true)}
            disabled={unpublishMutation.isPending}
            className="flex items-center gap-1.5 rounded-lg border border-green-300 bg-white px-3 py-2 text-sm text-green-700 hover:bg-green-100 disabled:opacity-50"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            {unpublishMutation.isPending ? "Unpublishing…" : "Unpublish"}
          </button>
        ) : (
          <button
            onClick={() => publishMutation.mutate()}
            disabled={publishMutation.isPending}
            className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Send className="h-3.5 w-3.5" />
            {publishMutation.isPending ? "Publishing…" : "Publish Layer"}
          </button>
        )}
      </div>
    </div>

    <ConfirmDialog
      open={showUnpublishConfirm}
      title="Unpublish layer?"
      message="This will hide the layer from field workers and allow editing again in draft mode."
      confirmLabel="Unpublish"
      cancelLabel="Cancel"
      destructive
      loading={unpublishMutation.isPending}
      onConfirm={() => unpublishMutation.mutate()}
      onCancel={() => setShowUnpublishConfirm(false)}
    />
    </>
  );
}