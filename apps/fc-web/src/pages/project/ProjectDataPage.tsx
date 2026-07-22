import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { DataTable } from "@/components/data/DataTable";
import { ExportMenu } from "@/components/data/ExportMenu";
import { LayerFeatureDrawer } from "@/components/layer/LayerFeatureDrawer";
import { Sparkles } from "lucide-react";

export function ProjectDataPage() {
  const { projectId } = useParams();
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState("");
  const [selectedFeature, setSelectedFeature] = useState<any | null>(null);

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId!),
    enabled: !!projectId,
  });

  const { data, isLoading } = useQuery({
    queryKey: ["features", projectId],
    queryFn: () => api.getProjectFeatures(projectId!, { limit: 500 }),
    enabled: !!projectId,
  });

  const { data: forms } = useQuery({
    queryKey: ["forms", projectId],
    queryFn: () => api.getProjectForms(projectId!),
    enabled: !!projectId,
  });

  const features = Array.isArray(data) ? data : data?.data || [];
  const filtered = statusFilter
    ? features.filter((f: any) => f.status === statusFilter)
    : features;

  const reviewMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) =>
      api.updateFeatureStatus(projectId!, id, status),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["features", projectId] }),
  });

  const seedMutation = useMutation({
    mutationFn: async () => {
      const formList = Array.isArray(forms) ? forms : [];
      if (formList.length === 0) {
        throw new Error("Create a form first before seeding test data");
      }
      const form = formList[0];
      const baseLat = 5.6037;
      const baseLng = -0.187;
      const points = Array.from({ length: 12 }, (_, i) => {
        const lat = baseLat + (Math.random() - 0.5) * 0.08;
        const lng = baseLng + (Math.random() - 0.5) * 0.08;
        const statuses = ["submitted", "submitted", "approved", "draft", "rejected"];
        return {
          client_id: crypto.randomUUID(),
          form_id: form.id,
          form_version: form.version,
          geometry: { type: "Point", coordinates: [lng, lat] },
          attributes: { test_index: i + 1, note: "Test record " + (i + 1) },
          status: statuses[i % statuses.length],
          collected_at: new Date().toISOString(),
        };
      });

      const token = localStorage.getItem("access_token");
      const res = await fetch("/api/v1/projects/" + projectId + "/sync/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + token,
        },
        body: JSON.stringify({ features: points }),
      });
      if (!res.ok) throw new Error("Seed failed");
      return res.json();
    },
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["features", projectId] }),
  });

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="flex items-center justify-between mb-4 shrink-0">
        <div className="flex items-center gap-2">
          <h2 className="text-lg font-semibold text-gray-900">Collected Data</h2>
          <span className="text-sm text-gray-500">
            ({filtered.length} records)
          </span>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => seedMutation.mutate()}
            disabled={seedMutation.isPending}
            className="flex items-center gap-1.5 rounded-lg border border-purple-200 bg-purple-50 px-3 py-1.5 text-sm text-purple-700 hover:bg-purple-100 disabled:opacity-50"
          >
            <Sparkles className="h-4 w-4" />
            {seedMutation.isPending ? "Seeding..." : "Seed Test Data"}
          </button>

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm"
          >
            <option value="">All Statuses</option>
            <option value="draft">Draft</option>
            <option value="submitted">Submitted</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>

          <ExportMenu
            projectId={projectId!}
            features={filtered}
            baseName={project?.name || "project"}
          />
        </div>

      </div>


      {seedMutation.isError && (
        <p className="text-sm text-red-600 mb-3 shrink-0">
          {(seedMutation.error as Error).message}
        </p>
      )}

      <div className="flex-1 min-h-0">
        {isLoading ? (
          <p className="text-gray-500">Loading...</p>
        ) : (
          <DataTable
            projectId={projectId!}
            features={filtered}
            onSelectFeature={setSelectedFeature}
            onReview={(id, status) => reviewMutation.mutate({ id, status })}
          />
        )}
      </div>

      {selectedFeature && (
        <LayerFeatureDrawer
          feature={selectedFeature}
          layerId={selectedFeature.layer_id || ""}
          onClose={() => setSelectedFeature(null)}
        />
      )}


    </div>
  );
}