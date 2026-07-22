import maplibregl from "maplibre-gl";

let patched = false;

/**
 * Patch MapLibre to work with @mapbox/mapbox-gl-draw.
 * mapbox-gl-draw uses dasharray expressions that MapLibre 3+ rejects.
 * Solution: strip the dasharray entirely — lines render solid instead of dashed.
 */
export function patchMapLibreForDraw() {
  if (patched) return;
  patched = true;

  const proto: any = (maplibregl as any).Map.prototype;
  const origAddLayer = proto.addLayer;

  proto.addLayer = function (layer: any, beforeId?: string) {
    if (layer?.paint && "line-dasharray" in layer.paint) {
      delete layer.paint["line-dasharray"];
    }
    return origAddLayer.call(this, layer, beforeId);
  };
}