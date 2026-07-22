import { useState, useRef, useEffect } from "react";
import { useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
import { Download, FileSpreadsheet, Globe, Loader } from "lucide-react";
import {
  buildCSV,
  buildGeoJSON,
  downloadCSV,
  downloadGeoJSON,
  makeFilename,
} from "@/lib/export";

interface Props {
  projectId: string;
  features: any[];
  baseName: string;       // e.g. "Water Project"
  scope?: string;         // optional sub-name, e.g. "layer-water_points"
  size?: "sm" | "md";
}

export function ExportMenu({
  projectId,
  features,
  baseName,
  scope,
  size = "md",
}: Props) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    if (open) document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, [open]);

  const csvMutation = useMutation({
    mutationFn: async () => {
      const csv = await buildCSV(projectId, features);
      const filename = makeFilename(baseName, "csv", scope);
      downloadCSV(filename, csv);
      return filename;
    },
    onSuccess: (filename) => {
      toast.success(`Exported ${filename}`);
      setOpen(false);
    },
    onError: (err: Error) => {
      toast.error(`CSV export failed: ${err.message}`);
    },
  });

  const geojsonMutation = useMutation({
    mutationFn: async () => {
      const geojson = buildGeoJSON(features);
      const filename = makeFilename(baseName, "geojson", scope);
      downloadGeoJSON(filename, geojson);
      return { filename, count: geojson.features.length };
    },
    onSuccess: ({ filename, count }) => {
      toast.success(`Exported ${filename} (${count} features)`);
      setOpen(false);
    },
    onError: (err: Error) => {
      toast.error(`GeoJSON export failed: ${err.message}`);
    },
  });

  const disabled = features.length === 0;
  const busy = csvMutation.isPending || geojsonMutation.isPending;

  const btnSize = size === "sm" ? "px-2 py-1 text-xs" : "px-3 py-1.5 text-sm";

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        disabled={disabled || busy}
        className={`flex items-center gap-1.5 rounded-lg border border-gray-300 hover:bg-gray-50 disabled:opacity-50 ${btnSize}`}
      >
        {busy ? (
          <Loader className="h-3.5 w-3.5 animate-spin" />
        ) : (
          <Download className="h-3.5 w-3.5" />
        )}
        Export
      </button>

      {open && !busy && (
        <div className="absolute right-0 top-full mt-1 w-56 bg-white rounded-lg border border-gray-200 shadow-lg z-20 overflow-hidden">
          <button
            onClick={() => csvMutation.mutate()}
            className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50 text-left"
          >
            <FileSpreadsheet className="h-4 w-4 text-green-600" />
            <div className="flex-1 min-w-0">
              <p className="text-gray-900">Export as CSV</p>
              <p className="text-xs text-gray-500">
                Spreadsheet with all attributes
              </p>
            </div>
          </button>
          <button
            onClick={() => geojsonMutation.mutate()}
            className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50 text-left border-t border-gray-100"
          >
            <Globe className="h-4 w-4 text-blue-600" />
            <div className="flex-1 min-w-0">
              <p className="text-gray-900">Export as GeoJSON</p>
              <p className="text-xs text-gray-500">
                Spatial data for QGIS / ArcGIS
              </p>
            </div>
          </button>
        </div>
      )}
    </div>
  );
}