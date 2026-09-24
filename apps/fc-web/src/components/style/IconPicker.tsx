import { useState, useMemo, useRef } from "react";
import * as Icons from "lucide-react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Search, Upload, X, Check } from "lucide-react";
import { validateAndSanitizeSvg } from "@/lib/svg-validation";

interface Props {
  projectId: string;
  currentIcon?: string;
  /** When true, only show shared geo/FC map symbols (geo:name) + Custom SVG. */
  sharedSymbolsOnly?: boolean;
  onSelect: (iconRef: string) => void;
  /** Paste/upload raw SVG (stores as style.default.icon_svg). */
  onSelectSvg?: (svg: string) => void;
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

export function IconPicker({
  projectId,
  currentIcon,
  sharedSymbolsOnly = false,
  onSelect,
  onSelectSvg,
  onClose,
}: Props) {
  const [tab, setTab] = useState<"geo" | "lucide" | "custom">(
    sharedSymbolsOnly ? "geo" : "lucide",
  );
  const [search, setSearch] = useState("");
  const [uploadedIcon, setUploadedIcon] = useState<{ iconRef: string; url: string } | null>(null);
  const [pastedSvg, setPastedSvg] = useState("");
  const [pasteError, setPasteError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: geoSymbols = [], isError, isLoading, error } = useQuery({
    queryKey: ["mapSymbols"],
    queryFn: () => api.listMapSymbols(),
    enabled: sharedSymbolsOnly || tab === "geo",
  });

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return ICON_NAMES;
    return ICON_NAMES.filter((n) => n.includes(q));
  }, [search]);

  const filteredGeo = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = Array.isArray(geoSymbols) ? geoSymbols : [];
    if (!q) return list;
    return list.filter((s) => s.name?.toLowerCase().includes(q));
  }, [geoSymbols, search]);

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
          <h2 className="text-lg font-semibold text-gray-900">
            {sharedSymbolsOnly ? "Choose map symbol" : "Choose Icon"}
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 border-b border-gray-200 px-6 pt-2 shrink-0">
          {(sharedSymbolsOnly || true) && (
            <button
              onClick={() => setTab("geo")}
              className={`px-3 py-2 text-sm font-medium border-b-2 transition-colors ${
                tab === "geo"
                  ? "border-blue-600 text-blue-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
            >
              Map symbols
            </button>
          )}
          {!sharedSymbolsOnly && (
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
          )}
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
          {tab === "geo" && (
            <>
              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                <input
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search symbols…"
                  className="w-full rounded-lg border border-gray-300 pl-9 pr-3 py-2 text-sm"
                />
              </div>
              <div className="grid grid-cols-4 sm:grid-cols-6 gap-3">
                {filteredGeo.map((s) => {
                  const isSelected = currentIcon === s.ref || currentIcon === `geo:${s.name}`;
                  return (
                    <button
                      key={s.name}
                      onClick={() => onSelect(s.ref)}
                      title={s.name}
                      className={`relative flex flex-col items-center gap-1 rounded-lg p-2 transition-all ${
                        isSelected
                          ? "bg-blue-100 border-2 border-blue-500"
                          : "bg-gray-50 border-2 border-transparent hover:bg-blue-50 hover:border-blue-200"
                      }`}
                    >
                      <div
                        className="h-8 w-8 flex items-center justify-center"
                        dangerouslySetInnerHTML={{
                          __html: String(s.svg || "").replace(
                            /<svg/i,
                            '<svg width="32" height="32"',
                          ),
                        }}
                      />
                      <span className="text-[10px] text-gray-600 truncate w-full text-center">
                        {s.name}
                      </span>
                      {isSelected && (
                        <Check className="absolute top-0.5 right-0.5 h-3 w-3 text-blue-600" />
                      )}
                    </button>
                  );
                })}
              </div>
              {isLoading && (
                <p className="text-sm text-gray-500 text-center mt-6">Loading symbols…</p>
              )}
              {isError && (
                <p className="text-sm text-red-600 text-center mt-6">
                  Could not load map symbols. Restart fc-api and try again.
                  {(error as Error)?.message ? ` (${(error as Error).message})` : ""}
                </p>
              )}
              {!isLoading && !isError && filteredGeo.length === 0 && (
                <p className="text-sm text-gray-500 italic text-center mt-6">
                  No symbols matching "{search}"
                </p>
              )}
            </>
          )}

          {tab === "lucide" && !sharedSymbolsOnly && (
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
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">
                  Paste SVG markup
                </label>
                <textarea
                  value={pastedSvg}
                  onChange={(e) => {
                    setPastedSvg(e.target.value);
                    setPasteError(null);
                  }}
                  placeholder='<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">…</svg>'
                  rows={6}
                  className={`w-full rounded-lg border px-3 py-2 text-xs font-mono ${
                    pasteError ? "border-red-400" : "border-gray-300"
                  }`}
                />
                {pasteError && (
                  <p className="mt-1 text-xs text-red-600">{pasteError}</p>
                )}
                {!pasteError && pastedSvg.trim() && (
                  <div className="mt-2 flex items-center gap-3">
                    <span className="text-xs text-gray-500">Preview:</span>
                    <div
                      className="h-10 w-10 border border-gray-200 rounded bg-white p-1 flex items-center justify-center"
                      dangerouslySetInnerHTML={{
                        __html: pastedSvg.replace(
                          /<svg/i,
                          '<svg width="32" height="32"',
                        ),
                      }}
                    />
                    <button
                      type="button"
                      onClick={() => {
                        const result = validateAndSanitizeSvg(pastedSvg);
                        if (!result.valid) {
                          setPasteError(result.error || "Invalid SVG");
                          return;
                        }
                        const svg = result.sanitized || pastedSvg.trim();
                        if (onSelectSvg) {
                          onSelectSvg(svg);
                        } else {
                          onSelect("custom:svg");
                        }
                      }}
                      className="ml-auto rounded-lg bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
                    >
                      Use this SVG
                    </button>
                  </div>
                )}
              </div>

              {!sharedSymbolsOnly && (
                <>
                  <div className="relative flex items-center gap-3 text-xs text-gray-400">
                    <div className="flex-1 border-t border-gray-200" />
                    or upload
                    <div className="flex-1 border-t border-gray-200" />
                  </div>
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
                </>
              )}

              {sharedSymbolsOnly && (
                <label className="cursor-pointer text-xs text-blue-600 hover:underline self-start">
                  Or upload a .svg file…
                  <input
                    type="file"
                    accept=".svg,image/svg+xml"
                    className="hidden"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      const reader = new FileReader();
                      reader.onload = () => {
                        const raw = String(reader.result || "");
                        setPastedSvg(raw);
                        const result = validateAndSanitizeSvg(raw);
                        if (!result.valid) {
                          setPasteError(result.error || "Invalid SVG");
                        } else {
                          setPasteError(null);
                          setPastedSvg(result.sanitized || raw);
                        }
                      };
                      reader.readAsText(file);
                      e.target.value = "";
                    }}
                  />
                </label>
              )}

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