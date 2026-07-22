import { useState, useMemo, useRef } from "react";
import * as Icons from "lucide-react";
import { useMutation } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Search, Upload, X, Check } from "lucide-react";

interface Props {
  projectId: string;
  currentIcon?: string;
  onSelect: (iconRef: string) => void;
  onClose: () => void;
}

const ICON_NAMES = [
  // Locations & places
  "map-pin", "map-pinned", "map", "navigation", "flag", "compass", "anchor",
  "home", "building", "building-2", "factory", "warehouse", "school", "hospital",
  "store", "landmark", "tent", "fence",
  // Water & utilities
  "droplet", "droplets", "waves", "ship", "fuel", "zap", "plug",
  // Health & emergency
  "heart-pulse", "stethoscope", "syringe", "pill", "thermometer", "shield-alert",
  "siren", "alert-triangle", "alert-circle", "alert-octagon",
  // Status indicators
  "check-circle", "x-circle", "circle", "circle-check", "circle-x",
  "circle-dot", "target", "crosshair", "scan-line",
  // Transport
  "car", "truck", "bus", "bike", "footprints", "plane",
  // Agriculture & nature
  "tree-pine", "tree-deciduous", "leaf", "sprout", "flower", "wheat",
  // Tools & objects
  "wrench", "hammer", "screwdriver", "lightbulb", "phone", "wifi",
  // Generic markers
  "star", "bookmark", "tag", "pin", "diamond", "triangle", "square",
];

function toPascalCase(name: string): string {
  return name
    .split("-")
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join("");
}

export function IconPicker({ projectId, currentIcon, onSelect, onClose }: Props) {
  const [tab, setTab] = useState<"lucide" | "custom">("lucide");
  const [search, setSearch] = useState("");
  const [uploadedIcon, setUploadedIcon] = useState<{ iconRef: string; url: string } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return ICON_NAMES;
    return ICON_NAMES.filter((n) => n.includes(q));
  }, [search]);

  const uploadMutation = useMutation({
    mutationFn: (file: File) => api.uploadIcon(projectId, file),
    onSuccess: (result: any) => {
      setUploadedIcon({ iconRef: result.icon_ref, url: result.url });
    },
  });

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f) uploadMutation.mutate(f);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[80vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <h2 className="text-lg font-semibold text-gray-900">Choose Icon</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 border-b border-gray-200 px-6 pt-2 shrink-0">
          <button
            onClick={() => setTab("lucide")}
            className={`px-3 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === "lucide"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            Lucide Icons
          </button>
          <button
            onClick={() => setTab("custom")}
            className={`px-3 py-2 text-sm font-medium border-b-2 transition-colors ${
              tab === "custom"
                ? "border-blue-600 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            Custom SVG
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-6">
          {tab === "lucide" && (
            <>
              {/* Search */}
              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search icons..."
                  className="w-full rounded-lg border border-gray-300 pl-9 pr-3 py-2 text-sm"
                />
              </div>

              {/* Icon grid */}
              <div className="grid grid-cols-8 sm:grid-cols-10 gap-2">
                {filtered.map((name) => {
                  const Component = (Icons as any)[toPascalCase(name)];
                  if (!Component) return null;
                  const iconRef = `lucide:${name}`;
                  const isSelected = currentIcon === iconRef;
                  return (
                    <button
                      key={name}
                      onClick={() => onSelect(iconRef)}
                      title={name}
                      className={`relative aspect-square rounded-lg flex items-center justify-center transition-all ${
                        isSelected
                          ? "bg-blue-100 border-2 border-blue-500"
                          : "bg-gray-50 border-2 border-transparent hover:bg-blue-50 hover:border-blue-200"
                      }`}
                    >
                      <Component className="h-5 w-5 text-gray-700" />
                      {isSelected && (
                        <Check className="absolute top-0.5 right-0.5 h-3 w-3 text-blue-600" />
                      )}
                    </button>
                  );
                })}
              </div>

              {filtered.length === 0 && (
                <p className="text-sm text-gray-500 italic text-center mt-6">
                  No icons matching "{search}"
                </p>
              )}
            </>
          )}

          {tab === "custom" && (
            <div className="flex flex-col gap-4">
              {/* Upload zone */}
              <div
                onClick={() => fileInputRef.current?.click()}
                className="cursor-pointer rounded-lg border-2 border-dashed border-gray-300 px-4 py-8 text-center hover:border-blue-400 hover:bg-blue-50/30 transition-colors"
              >
                <Upload className="h-8 w-8 mx-auto text-gray-400 mb-2" />
                <p className="text-sm font-medium text-gray-700">
                  Click to upload an SVG icon
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  Max 2 MB · Solid color SVGs render best
                </p>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept=".svg,image/svg+xml"
                className="hidden"
                onChange={handleFileChange}
              />

              {uploadMutation.isPending && (
                <p className="text-sm text-gray-500 text-center">Uploading...</p>
              )}

              {uploadMutation.isError && (
                <p className="text-sm text-red-600">
                  {(uploadMutation.error as Error).message}
                </p>
              )}

              {/* Uploaded preview + Use button */}
              {uploadedIcon && (
                <div className="rounded-lg border border-green-200 bg-green-50 p-4 flex items-center gap-3">
                  <img
                    src={uploadedIcon.url}
                    alt="Uploaded icon"
                    className="h-10 w-10 bg-white border border-gray-200 rounded p-1"
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-green-900">
                      Uploaded successfully
                    </p>
                    <p className="text-xs text-green-700 font-mono truncate">
                      {uploadedIcon.iconRef}
                    </p>
                  </div>
                  <button
                    onClick={() => onSelect(uploadedIcon.iconRef)}
                    className="rounded-lg bg-green-600 px-3 py-1.5 text-sm text-white hover:bg-green-700"
                  >
                    Use This
                  </button>
                </div>
              )}

              {/* Tips card */}
              <div className="text-xs text-gray-500 bg-gray-50 border border-gray-200 rounded-lg p-3">
                <p className="font-medium mb-1">Tips for good map icons:</p>
                <ul className="list-disc ml-4 space-y-0.5">
                  <li>Single-color, solid silhouettes work best</li>
                  <li>24×24 or 32×32 viewBox is ideal</li>
                  <li>Avoid embedded images or complex gradients</li>
                </ul>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200 shrink-0">
          <button
            onClick={onClose}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}