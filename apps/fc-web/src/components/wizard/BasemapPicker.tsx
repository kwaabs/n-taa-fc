import { BASEMAP_PROVIDERS } from "@/lib/basemaps";
import { Check, Globe } from "lucide-react";

interface Props {
  selectedId: string;
  customUrl: string;
  onChange: (id: string, customUrl?: string) => void;
}

export function BasemapPicker({ selectedId, customUrl, onChange }: Props) {
  return (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        {BASEMAP_PROVIDERS.map((bm) => {
          const isSelected = selectedId === bm.id;
          return (
            <button
              key={bm.id}
              onClick={() => onChange(bm.id)}
              className={`relative rounded-xl border-2 p-4 text-left transition-all ${
                isSelected
                  ? "border-blue-500 bg-blue-50"
                  : "border-gray-200 bg-white hover:border-blue-300 hover:bg-blue-50/30"
              }`}
            >
              {isSelected && (
                <Check className="absolute top-2 right-2 h-4 w-4 text-blue-600" />
              )}
              <div className="rounded-lg bg-gray-100 h-16 mb-2 flex items-center justify-center text-xs text-gray-400">
                <Globe className="h-6 w-6" />
              </div>
              <p className="text-sm font-medium text-gray-900">{bm.name}</p>
              <p className="text-xs text-gray-500 line-clamp-1">{bm.description}</p>
            </button>
          );
        })}

        {/* Custom URL option */}
        <button
          onClick={() => onChange("custom", customUrl)}
          className={`relative rounded-xl border-2 p-4 text-left transition-all ${
            selectedId === "custom"
              ? "border-blue-500 bg-blue-50"
              : "border-gray-200 bg-white hover:border-blue-300 hover:bg-blue-50/30"
          }`}
        >
          {selectedId === "custom" && (
            <Check className="absolute top-2 right-2 h-4 w-4 text-blue-600" />
          )}
          <div className="rounded-lg bg-gray-100 h-16 mb-2 flex items-center justify-center">
            <Globe className="h-6 w-6 text-gray-400" />
          </div>
          <p className="text-sm font-medium text-gray-900">Custom URL</p>
          <p className="text-xs text-gray-500">Paste any XYZ tile URL</p>
        </button>
      </div>

      {selectedId === "custom" && (
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">
            XYZ Tile URL
          </label>
          <input
            value={customUrl}
            onChange={(e) => onChange("custom", e.target.value)}
            placeholder="https://yourtileserver/{z}/{x}/{y}.png"
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono"
          />
          <p className="text-xs text-gray-400 mt-1">
            Must include <code>{"{z}"}</code>, <code>{"{x}"}</code>, <code>{"{y}"}</code> placeholders.
          </p>
        </div>
      )}
    </div>
  );
}