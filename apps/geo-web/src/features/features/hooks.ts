import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Feature } from "./types";

export function useFeature(layerId: string | null, ogcFid: number | null) {
  return useQuery({
    queryKey: ["feature", layerId, ogcFid],
    queryFn: () => api<Feature>(`/api/v1/layers/${layerId}/features/${ogcFid}`),
    enabled: !!layerId && ogcFid != null,
  });
}

export type FeatureAttachment = {
  id: string;
  kind: string;
  mime_type: string;
  field_id: string;
  size_bytes: number;
  download_url?: string;
  expires_at?: string;
};

export function useFeatureAttachments(
  layerId: string | null,
  ogcFid: number | null,
) {
  return useQuery({
    queryKey: ["feature-attachments", layerId, ogcFid],
    queryFn: () =>
      api<FeatureAttachment[]>(
        `/api/v1/layers/${layerId}/features/${ogcFid}/attachments`,
      ),
    enabled: !!layerId && ogcFid != null,
  });
}
