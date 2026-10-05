import { useEffect } from "react";
import { Layers } from "lucide-react";
import { usePickerStore } from "./pickerStore";
import { useSelectionStore } from "./store";

export function FeaturePickerMenu() {
  const menu = usePickerStore((s) => s.menu);
  const closeMenu = usePickerStore((s) => s.closeMenu);
  const setSelection = useSelectionStore((s) => s.setSelection);

  useEffect(() => {
    if (!menu) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeMenu();
    };
    const onClickOutside = (e: MouseEvent) => {
      const el = document.getElementById("__feature_picker_menu");
      if (el && !el.contains(e.target as Node)) closeMenu();
    };
    window.addEventListener("keydown", onKey);
    const t = setTimeout(
      () => window.addEventListener("click", onClickOutside),
      0,
    );
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("click", onClickOutside);
      clearTimeout(t);
    };
  }, [menu, closeMenu]);

  if (!menu) return null;

  const style: React.CSSProperties = {
    position: "fixed",
    left: Math.min(menu.x, window.innerWidth - 240),
    top: Math.min(menu.y, window.innerHeight - 260),
    zIndex: 40,
  };

  return (
    <div
      id="__feature_picker_menu"
      style={style}
      className="w-56 rounded-lg border border-slate-200 bg-white p-2 shadow-lg"
    >
      <div className="flex items-center gap-1.5 border-b border-slate-100 px-1 pb-2 text-xs font-semibold uppercase tracking-wide text-slate-500">
        <Layers className="h-3.5 w-3.5 text-cyan-600" />
        {menu.candidates.length} features here
      </div>

      <ul className="mt-1 max-h-72 space-y-0.5 overflow-y-auto">
        {menu.candidates.map((c) => (
          <li key={`${c.layerId}:${c.ogcFid}`}>
            <button
              onClick={() => {
                setSelection(c);
                closeMenu();
              }}
              className="flex w-full items-center justify-between rounded-md px-2 py-1.5 text-left text-sm text-slate-700 hover:bg-slate-100"
            >
              <span className="truncate">{c.label}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
