import { api } from "@/lib/api";

// ── CSV ──────────────────────────────────────────────────

/**
 * Build a CSV string from features. Auto-derives columns from the union of all attributes.
 * Includes id, status, lat, lng, collected_at, plus every attribute column.
 * For features with attachments, adds a column per field with a download URL.
 */
export async function buildCSV(
  projectId: string,
  features: any[]
): Promise<string> {
  if (features.length === 0) return "";

  // Discover all attribute columns (union across all features)
  const attrKeys = new Set<string>();
  for (const f of features) {
    for (const k of Object.keys(f.attributes || {})) {
      attrKeys.add(k);
    }
  }
  const attrCols = Array.from(attrKeys).sort();

  // Fetch attachments for all features in parallel (best-effort)
  const attachmentsByFeature: Record<string, any[]> = {};
  await Promise.all(
    features.map(async (f) => {
      try {
        const list = await api.listFeatureAttachments(projectId, f.id);
        const arr = Array.isArray(list) ? list : [];
        if (arr.length > 0) {
          attachmentsByFeature[f.id] = arr;
        }
      } catch {
        // ignore — attachments are best-effort in exports
      }
    })
  );

  // Discover attachment field columns (one URL column per unique field_id)
  const attachmentFields = new Set<string>();
  for (const list of Object.values(attachmentsByFeature)) {
    for (const view of list) {
      const att = view.attachment || view;
      if (att?.field_id) attachmentFields.add(att.field_id);
    }
  }
  const attachmentCols = Array.from(attachmentFields)
    .sort()
    .map((f) => `${f}_url`);

  // Header
  const headers = [
    "id",
    "status",
    "source",
    "latitude",
    "longitude",
    "collected_at",
    "synced_at",
    ...attrCols,
    ...attachmentCols,
  ];

  const lines = [headers.map(csvEscape).join(",")];

  // Rows
  for (const f of features) {
    let lat = "";
    let lng = "";
    if (f.geometry) {
      try {
        const geom =
          typeof f.geometry === "string" ? JSON.parse(f.geometry) : f.geometry;
        if (geom?.type === "Point" && Array.isArray(geom.coordinates)) {
          lng = String(geom.coordinates[0] ?? "");
          lat = String(geom.coordinates[1] ?? "");
        }
      } catch {}
    }

    const row: string[] = [
      f.id || "",
      f.status || "",
      f.source || "collected",
      lat,
      lng,
      f.collected_at || "",
      f.synced_at || "",
    ];

    // Attribute columns
    for (const k of attrCols) {
      const v = f.attributes?.[k];
      row.push(cellValue(v));
    }

    // Attachment URL columns
    const myAttachments = attachmentsByFeature[f.id] || [];
    for (const col of attachmentCols) {
      const fieldId = col.replace(/_url$/, "");
      const view = myAttachments.find(
        (v: any) => (v.attachment || v).field_id === fieldId
      );
      row.push(view?.download_url || "");
    }

    lines.push(row.map(csvEscape).join(","));
  }

  return lines.join("\n");
}

function cellValue(v: any): string {
  if (v == null) return "";
  if (typeof v === "object") return JSON.stringify(v);
  return String(v);
}

// Proper CSV escaping: quote if contains comma, quote, newline, or leading/trailing whitespace
function csvEscape(s: string): string {
  if (s == null) return "";
  const needsQuoting = /[",\n\r]/.test(s) || /^\s|\s$/.test(s);
  if (!needsQuoting) return s;
  return `"${s.replace(/"/g, '""')}"`;
}

// ── GeoJSON ──────────────────────────────────────────────

export function buildGeoJSON(features: any[]): any {
  const geojsonFeatures = features
    .filter((f) => f.geometry)
    .map((f) => {
      let geom: any = null;
      try {
        geom =
          typeof f.geometry === "string" ? JSON.parse(f.geometry) : f.geometry;
      } catch {
        return null;
      }
      return {
        type: "Feature",
        id: f.id,
        geometry: geom,
        properties: {
          ...f.attributes,
          _status: f.status,
          _source: f.source || "collected",
          _client_id: f.client_id,
          _collected_at: f.collected_at,
          _collected_by: f.collected_by,
          _synced_at: f.synced_at,
          _device_id:
            f.device_info?.device_id ||
            f.device_info?.id ||
            f.device_info?.deviceId ||
            undefined,
          _change_type: f.change_type,
          _change_at: f.change_at,
          _change_by: f.change_by,
        },
      };
    })
    .filter(Boolean);

  return {
    type: "FeatureCollection",
    features: geojsonFeatures,
  };
}

// ── File download helper ─────────────────────────────────

export function downloadFile(
  filename: string,
  content: string | Blob,
  mimeType = "application/octet-stream"
) {
  const blob =
    content instanceof Blob ? content : new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function downloadCSV(filename: string, csv: string) {
  // Prepend BOM so Excel detects UTF-8 properly
  downloadFile(filename, "\uFEFF" + csv, "text/csv;charset=utf-8");
}

export function downloadGeoJSON(filename: string, geojson: any) {
  downloadFile(
    filename,
    JSON.stringify(geojson, null, 2),
    "application/geo+json"
  );
}

// ── Filename helper ──────────────────────────────────────

export function makeFilename(
  base: string,
  extension: string,
  scope?: string
): string {
  const safeBase = base.replace(/[^\w\-]+/g, "_").slice(0, 50);
  const safeScope = scope ? "_" + scope.replace(/[^\w\-]+/g, "_") : "";
  const ts = new Date().toISOString().slice(0, 10);
  return `${safeBase}${safeScope}_${ts}.${extension}`;
}