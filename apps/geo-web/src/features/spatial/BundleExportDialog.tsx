import { useEffect, useMemo, useState } from "react";
import {
  X,
  Loader2,
  FileSpreadsheet,
  FileJson,
  FileText,
  Globe,
  Map as MapIcon,
  Lasso,
  Lock,
} from "lucide-react";
import { useBundleExportStore } from "./bundleExportStore";
import { useLayers } from "@/features/layers/hooks";
import { useLayersStore } from "@/features/layers/store";
import { LayerSwatch } from "@/features/layers/LayerSwatch";
import { useAuthStore } from "@/features/auth/store";
import { useSelectionStore } from "@/features/features/store";
import { useMapContext } from "@/features/map/context/MapContext";
import { viewportPolygon } from "@/features/map/utils/viewportBounds";
import { downloadFile } from "@/lib/api";
import type { Layer } from "@/features/layers/types";
import type { GeoJsonGeometry } from "@/features/spatial/types";
import {
  toastProgress,
  toastCompleteProgress,
  toastFailProgress,
} from "@/features/notifications/store";

type BundleFormat = "csv" | "xlsx" | "geojson" | "kmz";
type ExtentMode = "viewport" | "selection";

const FORMATS: {
  format: BundleFormat;
  label: string;
  hint: string;
  icon: React.ComponentType<{ className?: string }>;
  ext: string;
}[] = [
  {
    format: "xlsx",
    label: "Excel",
    hint: "One workbook, one sheet per layer",
    icon: FileSpreadsheet,
    ext: "xlsx",
  },
  {
    format: "kmz",
    label: "KMZ (Google Earth)",
    hint: "One file, one folder per layer",
    icon: Globe,
    ext: "kmz",
  },
  {
    format: "csv",
    label: "CSV",
    hint: "Zip, one .csv per layer",
    icon: FileText,
    ext: "zip",
  },
  {
    format: "geojson",
    label: "GeoJSON",
    hint: "Zip, one .geojson per layer",
    icon: FileJson,
    ext: "zip",
  },
];

// Mirrors services/geo-api/internal/layers/permissions.go Layer.CanExport.
function canExport(layer: Layer, role: string | undefined): boolean {
  if (!role) return false;
  if (role === "superuser") return true;
  return layer.permissions.export_roles.includes(
    role as "supervisor" | "editor" | "viewer",
  );
}

export function BundleExportDialog() {
  const open = useBundleExportStore((s) => s.open);
  const closeDialog = useBundleExportStore((s) => s.closeDialog);

  const { data: layers } = useLayers();
  const visibleIds = useLayersStore((s) => s.visibleIds);
  const role = useAuthStore((s) => s.user?.role);

  const { getMap } = useMapContext();
  const local = useSelectionStore((s) => s.local);
  const hasDrawnSelection = !!local?.feature?.geometry;

  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [extentMode, setExtentMode] = useState<ExtentMode>("viewport");
  const [format, setFormat] = useState<BundleFormat>("xlsx");
  const [busy, setBusy] = useState(false);

  const exportableLayers = useMemo(
    () => (layers ?? []).filter((l) => canExport(l, role)),
    [layers, role],
  );

  // Default the checklist to whatever's currently visible, each time the
  // dialog opens.
  useEffect(() => {
    if (!open) return;
    setSelected(
      new Set(exportableLayers.filter((l) => visibleIds.has(l.id)).map((l) => l.id)),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeDialog();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, closeDialog]);

  if (!open) return null;

  const toggle = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const runExport = async () => {
    if (selected.size === 0) return;
    setBusy(true);

    const toastId = toastProgress(
      `Preparing ${format.toUpperCase()} export`,
      `${selected.size} layer${selected.size === 1 ? "" : "s"}`,
    );

    try {
      let within: GeoJsonGeometry | null = null;
      if (extentMode === "selection" && hasDrawnSelection) {
        within = local!.feature.geometry;
      } else {
        const map = getMap();
        if (map) within = viewportPolygon(map);
      }
      if (!within) throw new Error("Could not resolve export bounds");

      const { ext } = FORMATS.find((f) => f.format === format)!;
      const stamp = new Date().toISOString().slice(0, 19).replace(/[T:]/g, "-");
      const filename = `layers_bundle_${stamp}.${ext}`;

      await downloadFile(
        `/api/v1/export/bundle.${format}`,
        { layer_ids: Array.from(selected), within },
        filename,
      );

      toastCompleteProgress(toastId, "Export complete", filename);
      closeDialog();
    } catch (e) {
      console.error("bundle export failed", e);
      toastFailProgress(
        toastId,
        "Export failed",
        (e as { message?: string })?.message ?? "Unknown error",
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
      onClick={closeDialog}
      role="dialog"
      aria-modal="true"
    >
      <div
        className="flex h-full max-h-[80vh] w-full max-w-md flex-col overflow-hidden rounded-xl bg-white shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-sm font-semibold text-slate-800">
            Export multiple layers
          </h2>
          <button
            onClick={closeDialog}
            className="rounded p-1.5 hover:bg-slate-100"
            aria-label="Close"
          >
            <X className="h-4 w-4 text-slate-600" />
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto p-4">
          <div className="mb-1.5 flex items-center justify-between">
            <span className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">
              Layers ({selected.size} selected)
            </span>
            <div className="flex gap-2 text-xs">
              <button
                onClick={() =>
                  setSelected(new Set(exportableLayers.map((l) => l.id)))
                }
                className="text-emerald-700 hover:underline"
              >
                Select all
              </button>
              <button
                onClick={() => setSelected(new Set())}
                className="text-slate-500 hover:underline"
              >
                Clear
              </button>
            </div>
          </div>

          <ul className="mb-4 max-h-56 space-y-0.5 overflow-y-auto rounded-md border border-slate-200 p-1.5">
            {(layers ?? []).map((layer) => {
              const exportable = canExport(layer, role);
              return (
                <li key={layer.id}>
                  <label
                    className={[
                      "flex items-center gap-2 rounded px-2 py-1.5 text-sm",
                      exportable
                        ? "cursor-pointer hover:bg-slate-50"
                        : "cursor-not-allowed opacity-50",
                    ].join(" ")}
                    title={exportable ? undefined : "No export permission"}
                  >
                    <input
                      type="checkbox"
                      checked={selected.has(layer.id)}
                      disabled={!exportable}
                      onChange={() => toggle(layer.id)}
                      className="h-4 w-4 accent-emerald-600"
                    />
                    <LayerSwatch layer={layer} />
                    <span className="flex-1 truncate">
                      {layer.display_name}
                    </span>
                    {!exportable && (
                      <Lock className="h-3 w-3 shrink-0 text-slate-400" />
                    )}
                  </label>
                </li>
              );
            })}
            {(layers ?? []).length === 0 && (
              <li className="px-2 py-4 text-center text-xs text-slate-400">
                No layers available.
              </li>
            )}
          </ul>

          <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-slate-400">
            Extent
          </div>
          <div className="mb-4 flex gap-2">
            <ExtentOption
              active={extentMode === "viewport"}
              icon={<MapIcon className="h-3.5 w-3.5" />}
              label="Visible area"
              onClick={() => setExtentMode("viewport")}
            />
            <ExtentOption
              active={extentMode === "selection"}
              disabled={!hasDrawnSelection}
              icon={<Lasso className="h-3.5 w-3.5" />}
              label="Drawn selection"
              onClick={() => hasDrawnSelection && setExtentMode("selection")}
            />
          </div>

          <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-slate-400">
            Format
          </div>
          <div className="space-y-1">
            {FORMATS.map(({ format: f, label, hint, icon: Icon }) => (
              <button
                key={f}
                onClick={() => setFormat(f)}
                className={[
                  "flex w-full items-center gap-2.5 rounded-md border px-3 py-2 text-left text-sm transition",
                  format === f
                    ? "border-emerald-300 bg-emerald-50 text-emerald-800"
                    : "border-slate-200 text-slate-700 hover:bg-slate-50",
                ].join(" ")}
              >
                <Icon className="h-4 w-4 shrink-0 text-slate-500" />
                <span className="flex-1">
                  <div className="font-medium">{label}</div>
                  <div className="text-xs text-slate-500">{hint}</div>
                </span>
              </button>
            ))}
          </div>
        </div>

        <footer className="flex items-center justify-end gap-2 border-t border-slate-200 px-4 py-3">
          <button
            onClick={closeDialog}
            className="rounded-md border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50"
          >
            Cancel
          </button>
          <button
            onClick={() => void runExport()}
            disabled={selected.size === 0 || busy}
            className="inline-flex items-center gap-1.5 rounded-md bg-emerald-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {busy && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
            Download
          </button>
        </footer>
      </div>
    </div>
  );
}

function ExtentOption({
  active,
  disabled,
  icon,
  label,
  onClick,
}: {
  active: boolean;
  disabled?: boolean;
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={[
        "flex flex-1 items-center justify-center gap-1.5 rounded-md border px-2 py-1.5 text-xs transition",
        disabled
          ? "cursor-not-allowed border-slate-100 text-slate-300"
          : active
            ? "border-emerald-300 bg-emerald-50 text-emerald-700"
            : "border-slate-200 text-slate-700 hover:bg-slate-50",
      ].join(" ")}
      title={disabled ? "Draw a selection first" : undefined}
    >
      {icon}
      {label}
    </button>
  );
}
