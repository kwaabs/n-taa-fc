import type { Layer } from "@/features/layers/types";

// Every style sub-layer a data layer can render as. Must stay in sync with
// layerStyle.ts (applyLayerStyle) — anything added there that isn't listed
// here becomes invisible to click/hover hit-testing.
export const STYLE_SUFFIXES = [
  "__circle",
  "__line",
  "__fill",
  "__outline",
  "__centroid",
] as const;

export function styleLayerIdsFor(layer: Layer): string[] {
  return STYLE_SUFFIXES.map((s) => `${layer.name}${s}`);
}
