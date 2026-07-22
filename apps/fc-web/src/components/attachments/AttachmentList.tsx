import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { AttachmentThumbnail } from "./AttachmentThumbnail";
import { AttachmentLightbox } from "./AttachmentLightbox";
import { Paperclip, ExternalLink } from "lucide-react";

interface Props {
  projectId: string;
  feature: any;
  compact?: boolean;
}

// Detect URL-looking values in attributes that probably point to images
function detectAttributeUrls(attrs: any): Array<{ key: string; url: string; kind: string }> {
  if (!attrs || typeof attrs !== "object") return [];
  const results: Array<{ key: string; url: string; kind: string }> = [];
  for (const [key, value] of Object.entries(attrs)) {
    if (typeof value !== "string") continue;
    const lower = value.toLowerCase();
    if (!lower.startsWith("http://") && !lower.startsWith("https://")) continue;

    const keyLower = key.toLowerCase();
    let kind = "file";
    if (
      lower.endsWith(".jpg") || lower.endsWith(".jpeg") ||
      lower.endsWith(".png") || lower.endsWith(".webp") || lower.endsWith(".gif")
    ) kind = "photo";
    else if (lower.endsWith(".mp3") || lower.endsWith(".m4a") || lower.endsWith(".wav") || lower.endsWith(".ogg")) kind = "audio";
    else if (lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mov")) kind = "video";
    else if (keyLower.includes("photo") || keyLower.includes("image") || keyLower.includes("picture")) kind = "photo";
    else if (keyLower.includes("audio") || keyLower.includes("sound")) kind = "audio";
    else if (keyLower.includes("video")) kind = "video";
    else continue; // skip — too uncertain

    results.push({ key, url: value, kind });
  }
  return results;
}

export function AttachmentList({ projectId, feature, compact }: Props) {
  const [lightboxItems, setLightboxItems] = useState<any[] | null>(null);
  const [lightboxIndex, setLightboxIndex] = useState(0);

  const { data: serverAttachments = [], isLoading } = useQuery({
    queryKey: ["attachments", feature.id],
    queryFn: () => api.listFeatureAttachments(projectId, feature.id),
    enabled: !!feature?.id,
  });

  const inferredFromAttributes = useMemo(
    () => detectAttributeUrls(feature.attributes),
    [feature.attributes]
  );

  // Normalize both into a common shape
  type Item = {
    id: string;
    kind: string;
    field_id: string;
    downloadUrl?: string;
    raw?: any;            // server attachment
    inferred?: boolean;   // true if from attribute URL
    uploadedBy?: string;
    uploadedAt?: string;
  };

  const items: Item[] = useMemo(() => {
    const arr: Item[] = [];
    for (const view of serverAttachments) {
      const att = view.attachment || view;
      arr.push({
        id: att.id,
        kind: att.kind,
        field_id: att.field_id,
        downloadUrl: view.download_url || undefined,
        raw: att,
        uploadedBy: att.uploaded_by,
        uploadedAt: att.uploaded_at,
      });
    }
    for (const inf of inferredFromAttributes) {
      arr.push({
        id: "attr:" + inf.key,
        kind: inf.kind,
        field_id: inf.key,
        downloadUrl: inf.url,
        inferred: true,
      });
    }
    return arr;
  }, [serverAttachments, inferredFromAttributes]);

  // Group by field_id
  const grouped = useMemo(() => {
    const map: Record<string, Item[]> = {};
    for (const it of items) {
      if (!map[it.field_id]) map[it.field_id] = [];
      map[it.field_id].push(it);
    }
    return map;
  }, [items]);

  const fieldIds = Object.keys(grouped).sort();

  if (isLoading) {
    return <p className="text-xs text-gray-400 italic">Loading attachments…</p>;
  }

  if (items.length === 0) {
    return null; // no attachments — render nothing rather than empty section
  }

  // Open lightbox: collect viewable items (image/video), find this one's index
  const openLightbox = (item: Item) => {
    const viewable = items.filter(
      (i) =>
        (i.kind === "photo" ||
          i.kind === "signature" ||
          i.kind === "barcode_image" ||
          i.kind === "video") &&
        !!i.downloadUrl
    );
    const idx = viewable.findIndex((i) => i.id === item.id);
    setLightboxItems(viewable);
    setLightboxIndex(idx >= 0 ? idx : 0);
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-1.5">
        <Paperclip className="h-3.5 w-3.5 text-gray-500" />
        <p className="text-xs font-medium text-gray-600">
          Attachments ({items.length})
        </p>
      </div>

      {fieldIds.map((fid) => {
        const groupItems = grouped[fid];
        return (
          <div key={fid}>
            <p className="text-xs text-gray-500 mb-1.5">
              {humanize(fid)}
              {groupItems[0].inferred && (
                <span className="ml-1 text-[10px] text-gray-400 italic">
                  (from attribute)
                </span>
              )}
            </p>
            <div className={`flex flex-wrap gap-2 ${compact ? "" : ""}`}>
              {groupItems.map((it) => {
                if (it.kind === "audio" && it.downloadUrl) {
                  return (
                    <AttachmentThumbnail
                      key={it.id}
                      attachment={{
                        kind: it.kind,
                        field_id: it.field_id,
                        status: "uploaded",
                      }}
                      downloadUrl={it.downloadUrl}
                      inline
                    />
                  );
                }
                return (
                  <AttachmentThumbnail
                    key={it.id}
                    attachment={it.raw || {
                      kind: it.kind,
                      field_id: it.field_id,
                      status: "uploaded",
                    }}
                    downloadUrl={it.downloadUrl}
                    onClick={() => {
                      if (it.kind === "file" || !it.downloadUrl) {
                        if (it.downloadUrl) window.open(it.downloadUrl, "_blank");
                        return;
                      }
                      openLightbox(it);
                    }}
                  />
                );
              })}
            </div>
          </div>
        );
      })}

      {/* Lightbox */}
      {lightboxItems && (
        <AttachmentLightbox
          items={lightboxItems.map((i) => ({
            kind: i.kind,
            url: i.downloadUrl!,
            fieldId: i.field_id,
          }))}
          startIndex={lightboxIndex}
          onClose={() => setLightboxItems(null)}
        />
      )}
    </div>
  );
}

function humanize(s: string): string {
  return s
    .split("_")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
}