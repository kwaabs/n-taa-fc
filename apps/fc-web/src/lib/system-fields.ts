/**
 * System field detection.
 *
 * MS.1 doesn't yet flag system fields in form schema metadata, so for now we
 * detect them by name pattern. This list mirrors the orchestrator's
 * IsSystemColumn rules.
 */

const SYSTEM_EXACT = new Set<string>([
    "objectid",
    "object_id",
    "globalid",
    "global_id",
    "ogc_fid",
    "fid",
    "created_at",
    "updated_at",
    "created_user",
    "created_date",
    "created_by",
    "updated_by",
    "last_edited_at",
    "last_edited_user",
    "last_edited_date",
    "device_id",
    "unique_id_hidden",
    "shape_length",
    "shape_area",
    "geometry",
    "geom",
    "the_geom",
  ]);
  
  const SYSTEM_PREFIXES = ["_", "shape_", "geom_"];
  
  export function isSystemFieldId(id: string | undefined | null): boolean {
    if (!id) return false;
    const lower = id.toLowerCase();
    if (SYSTEM_EXACT.has(lower)) return true;
    for (const p of SYSTEM_PREFIXES) {
      if (lower.startsWith(p)) return true;
    }
    return false;
  }