import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

/** Read-only mini map that fits a GeoJSON polygon / multipolygon. */
export function AoiPreviewMap({
  geometry,
  className = "h-48 w-full rounded-lg border border-gray-200",
}: {
  geometry: any;
  className?: string;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

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
      zoom: 10,
      interactive: false,
      attributionControl: false,
    });
    mapRef.current = map;

    map.on("load", () => {
      map.addSource("aoi", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
      });
      map.addLayer({
        id: "aoi-fill",
        type: "fill",
        source: "aoi",
        paint: { "fill-color": "#2563eb", "fill-opacity": 0.25 },
      });
      map.addLayer({
        id: "aoi-line",
        type: "line",
        source: "aoi",
        paint: { "line-color": "#1d4ed8", "line-width": 2 },
      });
      applyGeometry(map, geometry);
    });

    return () => {
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;
    applyGeometry(map, geometry);
  }, [geometry]);

  return <div ref={containerRef} className={className} />;
}

function applyGeometry(map: maplibregl.Map, geometry: any) {
  const src = map.getSource("aoi") as maplibregl.GeoJSONSource | undefined;
  if (!src || !geometry) return;

  const feature =
    geometry.type === "Feature"
      ? geometry
      : { type: "Feature", properties: {}, geometry };

  src.setData({
    type: "FeatureCollection",
    features: [feature],
  });

  try {
    const bounds = new maplibregl.LngLatBounds();
    const coords = collectCoords(feature.geometry);
    for (const c of coords) bounds.extend(c as [number, number]);
    if (!bounds.isEmpty()) {
      map.fitBounds(bounds, { padding: 28, maxZoom: 14, duration: 0 });
    }
  } catch {
    // ignore bad geometry
  }
}

function collectCoords(geom: any): number[][] {
  if (!geom) return [];
  if (geom.type === "Point") return [geom.coordinates];
  if (geom.type === "LineString" || geom.type === "MultiPoint") {
    return geom.coordinates;
  }
  if (geom.type === "Polygon" || geom.type === "MultiLineString") {
    return geom.coordinates.flat();
  }
  if (geom.type === "MultiPolygon") {
    return geom.coordinates.flat(2);
  }
  return [];
}
