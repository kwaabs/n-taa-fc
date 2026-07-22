import { useEffect, useRef, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { X, Pentagon, Trash2, Check, MousePointer2, CheckCircle2 } from "lucide-react";

interface Props {
  initialPolygon?: any | null;
  onSave: (geojson: any | null) => void;
  onClose: () => void;
}

type Mode = "idle" | "drawing";

export function AreaDrawer({ initialPolygon, onSave, onClose }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  const [mode, setMode] = useState<Mode>("idle");
  const [points, setPoints] = useState<[number, number][]>([]);
  const [hasPolygon, setHasPolygon] = useState(false);

  // Keep refs in sync for use inside map event handlers (which capture initial state)
  const modeRef = useRef<Mode>(mode);
  const pointsRef = useRef<[number, number][]>(points);
  useEffect(() => { modeRef.current = mode; }, [mode]);
  useEffect(() => { pointsRef.current = points; }, [points]);

  // Initialize map ONCE
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap",
          },
        },
        layers: [{ id: "osm-layer", type: "raster", source: "osm" }],
      },
      center: [-0.187, 5.6037],
      zoom: 11,
    });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    mapRef.current = map;

    map.on("load", () => {
      // Add empty sources / layers we'll mutate as the user draws
      map.addSource("draw-line", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addSource("draw-fill", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addSource("draw-points", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });

      map.addLayer({
        id: "draw-fill-layer",
        type: "fill",
        source: "draw-fill",
        paint: { "fill-color": "#3b82f6", "fill-opacity": 0.2 },
      });
      map.addLayer({
        id: "draw-line-layer",
        type: "line",
        source: "draw-line",
        paint: { "line-color": "#3b82f6", "line-width": 2 },
      });
      map.addLayer({
        id: "draw-points-layer",
        type: "circle",
        source: "draw-points",
        paint: {
          "circle-color": "#ffffff",
          "circle-stroke-color": "#3b82f6",
          "circle-stroke-width": 2,
          "circle-radius": 5,
        },
      });

      // Load initial polygon if provided
      if (initialPolygon) {
        try {
          const geom = typeof initialPolygon === "string"
            ? JSON.parse(initialPolygon)
            : initialPolygon;
          if (geom?.coordinates?.[0]?.length) {
            const ring = geom.coordinates[0] as [number, number][];
            // Drop the duplicated closing point if present
            const open = ring[0][0] === ring[ring.length - 1][0] && ring[0][1] === ring[ring.length - 1][1]
              ? ring.slice(0, -1)
              : ring;
            setPoints(open);
            setHasPolygon(true);
            commitToMap(open, /*finalised=*/true, map);

            const bounds = new maplibregl.LngLatBounds();
            ring.forEach((c) => bounds.extend(c));
            map.fitBounds(bounds, { padding: 60, maxZoom: 15 });
          }
        } catch {
          // ignore
        }
      }
    });

    // Click handler — adds vertices when in drawing mode
    map.on("click", (e) => {
      if (modeRef.current !== "drawing") return;
      const next: [number, number][] = [...pointsRef.current, [e.lngLat.lng, e.lngLat.lat]];
      setPoints(next);
      commitToMap(next, false, map);
    });

    // Double-click — close polygon (and override default zoom)
    map.doubleClickZoom.disable();
    map.on("dblclick", () => {
      if (modeRef.current === "drawing" && pointsRef.current.length >= 3) {
        finishPolygon();
      }
    });

    return () => {
      map.remove();
      mapRef.current = null;
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Render visuals from points
  function commitToMap(pts: [number, number][], finalised: boolean, map: maplibregl.Map) {
    // Points always visible as small dots
    const pointSrc = map.getSource("draw-points") as maplibregl.GeoJSONSource;
    pointSrc?.setData({
      type: "FeatureCollection",
      features: pts.map((p) => ({
        type: "Feature",
        properties: {},
        geometry: { type: "Point", coordinates: p },
      })),
    });

    // Line: open polyline while drawing; closed ring when finalised
    const lineSrc = map.getSource("draw-line") as maplibregl.GeoJSONSource;
    if (pts.length >= 2) {
      const lineCoords = finalised && pts.length >= 3 ? [...pts, pts[0]] : pts;
      lineSrc?.setData({
        type: "FeatureCollection",
        features: [{
          type: "Feature",
          properties: {},
          geometry: { type: "LineString", coordinates: lineCoords },
        }],
      });
    } else {
      lineSrc?.setData({ type: "FeatureCollection", features: [] });
    }

    // Fill polygon only when finalised
    const fillSrc = map.getSource("draw-fill") as maplibregl.GeoJSONSource;
    if (finalised && pts.length >= 3) {
      fillSrc?.setData({
        type: "FeatureCollection",
        features: [{
          type: "Feature",
          properties: {},
          geometry: { type: "Polygon", coordinates: [[...pts, pts[0]]] },
        }],
      });
    } else {
      fillSrc?.setData({ type: "FeatureCollection", features: [] });
    }
  }

  const startDrawing = () => {
    setMode("drawing");
    setPoints([]);
    setHasPolygon(false);
    if (mapRef.current) {
      commitToMap([], false, mapRef.current);
      mapRef.current.getCanvas().style.cursor = "crosshair";
    }
  };

  const finishPolygon = () => {
    if (pointsRef.current.length < 3) return;
    setMode("idle");
    setHasPolygon(true);
    if (mapRef.current) {
      commitToMap(pointsRef.current, true, mapRef.current);
      mapRef.current.getCanvas().style.cursor = "";
    }
  };

  const cancelDrawing = () => {
    setMode("idle");
    setPoints([]);
    setHasPolygon(false);
    if (mapRef.current) {
      commitToMap([], false, mapRef.current);
      mapRef.current.getCanvas().style.cursor = "";
    }
  };

  const handleClear = () => {
    cancelDrawing();
  };

  const handleSave = () => {
    if (!hasPolygon || points.length < 3) {
      onSave(null);
      return;
    }
    const polygon = {
      type: "Polygon",
      coordinates: [[...points, points[0]]],
    };
    onSave(polygon);
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-white">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-3 border-b border-gray-200 shrink-0">
        <div className="flex items-center gap-3">
          <Pentagon className="h-5 w-5 text-blue-600" />
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Draw Area</h2>
            <p className="text-xs text-gray-500">
              {mode === "drawing"
                ? `Click on the map to add points (${points.length} so far). Double-click or "Finish" to close the polygon.`
                : hasPolygon
                ? "Polygon drawn. Click 'Draw New' to redraw, or 'Save Area'."
                : "Click 'Draw New' to start placing points on the map."}
            </p>
          </div>
        </div>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Map */}
      <div className="flex-1 relative min-h-0">
        <div ref={containerRef} className="absolute inset-0 w-full h-full" />

        {/* Floating toolbar */}
        <div className="absolute top-3 left-12 bg-white rounded-lg shadow-md border border-gray-200 flex gap-1 p-1">
          {mode === "idle" && (
            <button
              onClick={startDrawing}
              className="flex items-center gap-1.5 rounded px-2 py-1 text-xs hover:bg-blue-50 hover:text-blue-700"
            >
              <MousePointer2 className="h-3.5 w-3.5" />
              {hasPolygon ? "Draw New" : "Start Drawing"}
            </button>
          )}
          {mode === "drawing" && (
            <>
              <button
                onClick={finishPolygon}
                disabled={points.length < 3}
                className="flex items-center gap-1.5 rounded px-2 py-1 text-xs hover:bg-green-50 hover:text-green-700 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                <CheckCircle2 className="h-3.5 w-3.5" />
                Finish ({points.length} pts)
              </button>
              <button
                onClick={cancelDrawing}
                className="flex items-center gap-1.5 rounded px-2 py-1 text-xs hover:bg-gray-100"
              >
                Cancel
              </button>
            </>
          )}
          {(hasPolygon || mode === "drawing") && (
            <button
              onClick={handleClear}
              className="flex items-center gap-1.5 rounded px-2 py-1 text-xs hover:bg-red-50 hover:text-red-700"
            >
              <Trash2 className="h-3.5 w-3.5" />
              Clear
            </button>
          )}
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between px-6 py-3 border-t border-gray-200 shrink-0">
        <p className="text-xs text-gray-500">
          {hasPolygon
            ? "✓ Polygon ready. Click Save to apply."
            : mode === "drawing"
            ? `Drawing in progress — ${points.length} point${points.length === 1 ? "" : "s"} placed`
            : "No area drawn yet."}
        </p>
        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={!hasPolygon}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Check className="h-4 w-4" />
            Save Area
          </button>
        </div>
      </div>
    </div>
  );
}