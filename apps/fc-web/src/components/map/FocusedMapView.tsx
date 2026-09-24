import { useEffect, useRef, useMemo } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { useQuery, useQueries } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { buildMapStyle } from "@/lib/basemaps";
import {
  computeFeatureStyle,
  getLabelText,
  isMapZoomInLayerRange,
  layerZoomRange,
  type LayerStyle,
} from "@/lib/style-engine";
import { iconToDataUrl } from "@/lib/icon-renderer";

const MARTIN_URL = import.meta.env.VITE_MARTIN_URL || "http://localhost:5360";

function parseLinkedConfig(raw: unknown): {
  schema: string;
  table: string;
  sourceLayer: string;
  idColumn?: string;
  bbox?: number[];
} | null {
  if (!raw) return null;
  let cfg: any = raw;
  if (typeof raw === "string") {
    try {
      cfg = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  const schema = cfg.schema || cfg.Schema;
  const table = cfg.table || cfg.Table;
  if (!schema || !table) return null;
  const bbox = Array.isArray(cfg.bbox) && cfg.bbox.length === 4 ? cfg.bbox : undefined;
  const idColumn = cfg.id_column || cfg.idColumn || undefined;
  return {
    schema,
    table,
    sourceLayer: cfg.martin_source_id || `${schema}.${table}`,
    idColumn: typeof idColumn === "string" ? idColumn : undefined,
    bbox,
  };
}

/** Geometry / Martin internals that should not appear as attributes. */
const TILE_PROP_SKIP = new Set([
  "geom",
  "geometry",
  "shape",
  "wkb_geometry",
  "the_geom",
  "geojson",
]);

/** MapLibre/MVT properties → inspector attributes for linked dbo tables. */
function linkedTileToFeature(
  props: Record<string, unknown>,
  geometry: unknown,
  ld: { id: string; name: string; linked: { idColumn?: string } | null },
) {
  const attributes: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(props)) {
    if (TILE_PROP_SKIP.has(k.toLowerCase())) continue;
    // MVT may stringify nested values
    if (typeof v === "string" && (v.startsWith("{") || v.startsWith("["))) {
      try {
        attributes[k] = JSON.parse(v);
        continue;
      } catch {
        /* keep string */
      }
    }
    attributes[k] = v;
  }

  const idCol = ld.linked?.idColumn;
  const rawId =
    (idCol && props[idCol] != null ? props[idCol] : undefined) ??
    props.objectid ??
    props.OBJECTID ??
    props.ogc_fid ??
    props.OGC_FID ??
    props.id ??
    props.gid;

  const sourceRef = rawId != null ? String(rawId) : undefined;

  return {
    id: sourceRef,
    source_ref: sourceRef,
    geometry,
    attributes,
    source: "linked",
    status: undefined,
    _layerId: ld.id,
    _layerName: ld.name,
    _linked: true,
  };
}

interface Props {
  projectId: string;
  layers: any[];
  visibleLayers: Record<string, boolean>;
  focusedLayerId: string | null;
  onSelectFeature: (feature: any) => void;
}

export function FocusedMapView({
  projectId,
  layers,
  visibleLayers,
  focusedLayerId,
  onSelectFeature,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  // Refs for added sources/layers per logical layer id, so we can clean up.
  const sourceIdsRef = useRef<string[]>([]);
  const layerIdsRef = useRef<string[]>([]);
  const markersRef = useRef<maplibregl.Marker[]>([]);
  // Keep callback stable so feature selection doesn't re-run the layer effect.
  const onSelectFeatureRef = useRef(onSelectFeature);
  onSelectFeatureRef.current = onSelectFeature;
  // Fit-to-data only when visibility/focus changes — not on every re-render.
  const fittedForKeyRef = useRef<string>("");
  const markerZoomHandlerRef = useRef<(() => void) | null>(null);

  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.getProject(projectId),
  });

  // Layer styles
  const styleQueries = useQueries({
    queries: layers.map((l: any) => ({
      queryKey: ["layerStyle", l.id],
      queryFn: () => api.getLayerStyle(projectId, l.id),
    })),
  });

  // Layer features
  // Layer features — skip for reference layers (they use Martin tiles)
  const featureQueries = useQueries({
    queries: layers.map((l: any) => ({
      queryKey: ["layerFeaturesAll", l.id],
      queryFn: () =>
        api.getLayerFeatures(projectId, l.id, { limit: 2000 }),
      enabled: l.source_type !== "external" && l.source_type !== "linked_table",
    })),
  });

  // useQueries returns a new array each render — depend on data timestamps.
  const styleDataKey = styleQueries.map((q) => q.dataUpdatedAt).join("|");
  const featureDataKey = featureQueries.map((q) => q.dataUpdatedAt).join("|");

  const layerData = useMemo(
    () =>
      layers.map((l: any, idx: number) => {
        const featData = featureQueries[idx]?.data;
        const features = Array.isArray(featData)
          ? featData
          : featData?.data || [];
        const useTiles =
          l.source_type === "external" || l.source_type === "linked_table";
        const linked =
          l.source_type === "linked_table"
            ? parseLinkedConfig(l.source_config)
            : null;
        return {
          id: l.id,
          name: l.name,
          geometry_type: l.geometry_type as "point" | "line" | "polygon",
          style: (styleQueries[idx]?.data as LayerStyle) || null,
          features: useTiles ? [] : features,
          useTiles,
          linked,
        };
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [layers, styleDataKey, featureDataKey]
  );

  const fitKey = useMemo(() => {
    const visible = Object.entries(visibleLayers)
      .filter(([, v]) => v)
      .map(([id]) => id)
      .sort()
      .join(",");
    return `${visible}|${focusedLayerId ?? ""}`;
  }, [visibleLayers, focusedLayerId]);




  // Initialize map once
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const basemapId = project?.config?.basemap_id || "osm";
    const customUrl = project?.config?.basemap_custom_url;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: buildMapStyle(basemapId, customUrl),
      center: [0, 0],
      zoom: 2,
    });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, [project?.config?.basemap_id, project?.config?.basemap_custom_url]);

  // Render features per layer
  useEffect(() => {
    if (!mapRef.current) return;
    const map = mapRef.current;

    const apply = () => {
      // Remove previously added sources & layers & markers
      for (const id of layerIdsRef.current) {
        if (map.getLayer(id)) map.removeLayer(id);
      }
      for (const id of sourceIdsRef.current) {
        if (map.getSource(id)) map.removeSource(id);
      }
      for (const m of markersRef.current) m.remove();
      if (markerZoomHandlerRef.current) {
        map.off("zoom", markerZoomHandlerRef.current);
        markerZoomHandlerRef.current = null;
      }
      layerIdsRef.current = [];
      sourceIdsRef.current = [];
      markersRef.current = [];

      const bounds = new maplibregl.LngLatBounds();
      let anyGeom = false;

      for (const ld of layerData) {
        if (!visibleLayers[ld.id]) continue;
        const dimmed =
          focusedLayerId !== null && focusedLayerId !== ld.id;
        const zoomRange = layerZoomRange(ld.style);

        // ── Reference layer: use Martin vector tiles ─────────────────
        // ── Reference layer: use Martin vector tiles (scales to 100k+ features) ──
        if (ld.useTiles) {
          // Extend bounds using the layer's bbox from the API (since tile
          // features aren't in `ld.features`, auto-fit can't discover them).
          const layerObj = layers.find((L: any) => L.id === ld.id) as any;
          const linkedBbox = ld.linked?.bbox;
          const bbox: number[] | undefined =
            linkedBbox ||
            (Array.isArray(layerObj?.bbox) && layerObj.bbox.length === 4
              ? layerObj.bbox
              : undefined);
          if (Array.isArray(bbox) && bbox.length === 4) {
            bounds.extend([bbox[0], bbox[1]]);
            bounds.extend([bbox[2], bbox[3]]);
            if (!dimmed) anyGeom = true;
          }

          const sourceId = `layer-${ld.id}-tiles`;
          const isLinked = !!ld.linked;
          const tileURL = isLinked
            ? `${MARTIN_URL}/${ld.linked!.sourceLayer}/{z}/{x}/{y}`
            : `${MARTIN_URL}/reference_features/{z}/{x}/{y}?project_id=${projectId}&layer_id=${ld.id}`;
          const sourceLayerName = isLinked
            ? ld.linked!.sourceLayer
            : "reference_features";

          map.addSource(sourceId, {
            type: "vector",
            tiles: [tileURL],
            minzoom: 0,
            maxzoom: 22,
          });
          sourceIdsRef.current.push(sourceId);

          const color = pickColor(ld.style, "#3b82f6");
          const width = pickLineWidth(ld.style, 3);
          const baseOpacity = pickOpacity(ld.style, 1);
          const opacity = dimmed ? Math.min(baseOpacity, 0.25) : baseOpacity;

          const renderLayerId = `layer-${ld.id}-tiles-render`;

          if (ld.geometry_type === "line") {
            const dash = dashArrayFor(pickLineStyle(ld.style));
            map.addLayer({
              id: renderLayerId,
              type: "line",
              source: sourceId,
              "source-layer": sourceLayerName,
              minzoom: zoomRange.minzoom,
              maxzoom: zoomRange.maxzoom,
              paint: {
                "line-color": color,
                "line-width": width,
                "line-opacity": opacity,
                ...(dash ? { "line-dasharray": dash } : {}),
              },
            });
          } else if (ld.geometry_type === "polygon") {
            map.addLayer({
              id: renderLayerId,
              type: "fill",
              source: sourceId,
              "source-layer": sourceLayerName,
              minzoom: zoomRange.minzoom,
              maxzoom: zoomRange.maxzoom,
              paint: {
                "fill-color": color,
                "fill-opacity": Math.min(opacity, 0.4),
                "fill-outline-color": color,
              },
            });
          } else {
            // point (or unknown)
            const iconSvg = pickIconSvg(ld.style);
            console.log('[svg]', ld.name, 'iconSvg found:', !!iconSvg,
              'style shape:', ld.style ? Object.keys(ld.style) : 'null');
            if (iconSvg) {
              const imgId = `icon-${ld.id}`;
              ensureSvgImage(map, imgId, iconSvg, () => {
                console.log('[svg]', ld.name, 'image ready, hasImage:',
                  map.hasImage(imgId), 'layerExists:', !!map.getLayer(renderLayerId));
                if (map.hasImage(imgId) && !map.getLayer(renderLayerId)) {
                  map.addLayer({
                    id: renderLayerId,
                    type: "symbol",
                    source: sourceId,
                    "source-layer": sourceLayerName,
                    minzoom: zoomRange.minzoom,
                    maxzoom: zoomRange.maxzoom,
                    layout: {
                      "icon-image": imgId,
                      "icon-size": 0.15,
                      "icon-allow-overlap": true,
                      "icon-ignore-placement": true,
                    },
                    paint: {
                      "icon-opacity": opacity,
                    },
                  });
                } else if (!map.getLayer(renderLayerId)) {
                  // SVG failed → fallback circle
                  map.addLayer({
                    id: renderLayerId,
                    type: "circle",
                    source: sourceId,
                    "source-layer": sourceLayerName,
                    minzoom: zoomRange.minzoom,
                    maxzoom: zoomRange.maxzoom,
                    paint: {
                      "circle-color": color,
                      "circle-radius": 4,
                      "circle-opacity": opacity,
                      "circle-stroke-color": "#ffffff",
                      "circle-stroke-width": 1,
                    },
                  });
                }
              });
            } else {
              map.addLayer({
                id: renderLayerId,
                type: "circle",
                source: sourceId,
                "source-layer": sourceLayerName,
                minzoom: zoomRange.minzoom,
                maxzoom: zoomRange.maxzoom,
                paint: {
                  "circle-color": color,
                  "circle-radius": 4,
                  "circle-opacity": opacity,
                  "circle-stroke-color": "#ffffff",
                  "circle-stroke-width": 1,
                },
              });
            }
          }
          layerIdsRef.current.push(renderLayerId);

          // Click on a tile feature → open inspector
          map.on("click", renderLayerId, async (e) => {
            const f0 = e.features?.[0];
            if (!f0) return;
            const props = (f0.properties || {}) as Record<string, unknown>;

            // Linked dbo tables: attributes live on the tile; there is no FC features row.
            if (isLinked) {
              onSelectFeatureRef.current(
                linkedTileToFeature(props, f0.geometry, ld),
              );
              return;
            }

            const featureId = props.id as string | undefined;

            // Copied reference: open immediately, then hydrate from API
            onSelectFeatureRef.current({
              id: featureId,
              source_ref: props.source_ref,
              geometry: f0.geometry,
              source: "reference",
              _layerId: ld.id,
              _layerName: ld.name,
              _loading: true,
            });

            if (!featureId) return;

            try {
              const full = await api.getFeature(projectId, featureId);
              onSelectFeatureRef.current({
                ...full,
                _layerId: ld.id,
                _layerName: ld.name,
              });
            } catch (err) {
              console.warn("[FocusedMapView] getFeature failed:", err);
            }
          });
          map.on("mouseenter", renderLayerId, () => {
            map.getCanvas().style.cursor = "pointer";
          });
          map.on("mouseleave", renderLayerId, () => {
            map.getCanvas().style.cursor = "";
          });

          // Skip the GeoJSON path below — nothing to render from `features` array
          continue;
        }

        // ── Existing GeoJSON path (collected features, small layers) ─
        const ptFeatures: any[] = [];
        const lineFeatures: any[] = [];
        const polyFeatures: any[] = [];

        for (const f of ld.features) {
          if (!f.geometry) continue;
          let geom: any;
          try {
            geom =
              typeof f.geometry === "string"
                ? JSON.parse(f.geometry)
                : f.geometry;
          } catch {
            continue;
          }
          if (!geom || !geom.type) continue;

          // Extend bounds based on geometry type (we still extend for dimmed
          // so the world view fits everything once layers become visible).
          extendBoundsForGeom(geom, bounds);
          if (!dimmed) anyGeom = true;

          switch (geom.type) {
            case "Point":
            case "MultiPoint": {
              // Use existing DOM markers for points
              ptFeatures.push({ feature: f, geometry: geom });
              break;
            }
            case "LineString":
            case "MultiLineString": {
              lineFeatures.push(
                makeGeoJSONFeature(f, geom, ld.id, ld.name)
              );
              break;
            }
            case "Polygon":
            case "MultiPolygon": {
              polyFeatures.push(
                makeGeoJSONFeature(f, geom, ld.id, ld.name)
              );
              break;
            }
            default:
              continue;
          }
        }

        // Render points as DOM markers (preserves existing UX/labels/icons)
        for (const { feature, geometry } of ptFeatures) {
          renderPointMarker({
            map,
            feature,
            geometry,
            layerId: ld.id,
            layerName: ld.name,
            style: ld.style,
            dimmed,
            onSelectFeature: (f) => onSelectFeatureRef.current(f),
            collectInto: markersRef.current,
          });
        }

        // Render lines as a GeoJSON source + line layer
        if (lineFeatures.length > 0) {
          const sourceId = `layer-${ld.id}-lines`;
          const layerId = `layer-${ld.id}-lines-fill`;

          map.addSource(sourceId, {
            type: "geojson",
            data: {
              type: "FeatureCollection",
              features: lineFeatures,
            } as any,
          });
          sourceIdsRef.current.push(sourceId);

          const lineColor = pickColor(ld.style, "#3b82f6");
          const lineWidth = pickLineWidth(ld.style, 3);
          const baseOpacity = pickOpacity(ld.style, 1);
          const opacity = dimmed
            ? Math.min(baseOpacity, 0.25)
            : baseOpacity;

          const dash = dashArrayFor(pickLineStyle(ld.style));
          map.addLayer({
            id: layerId,
            type: "line",
            source: sourceId,
            minzoom: zoomRange.minzoom,
            maxzoom: zoomRange.maxzoom,
            paint: {
              "line-color": lineColor,
              "line-width": lineWidth,
              "line-opacity": opacity,
              ...(dash ? { "line-dasharray": dash } : {}),
            },
          });
          layerIdsRef.current.push(layerId);

          // Click → inspect
          map.on("click", layerId, (e) => {
            const f0 = e.features?.[0];
            if (!f0) return;
            const props = f0.properties || {};
            onSelectFeatureRef.current({
              id: props._featureId,
              geometry: f0.geometry,
              attributes: safeParseAttrs(props._attributes),
              status: props._status,
              source: props._source,
              client_id: props._clientId,
              collected_at: props._collectedAt,
              synced_at: props._syncedAt,
              _layerId: ld.id,
              _layerName: ld.name,
            });
          });
          map.on("mouseenter", layerId, () => {
            map.getCanvas().style.cursor = "pointer";
          });
          map.on("mouseleave", layerId, () => {
            map.getCanvas().style.cursor = "";
          });
        }

        // Render polygons as a GeoJSON source + fill + outline
        if (polyFeatures.length > 0) {
          const sourceId = `layer-${ld.id}-polys`;
          const fillId = `layer-${ld.id}-polys-fill`;
          const outlineId = `layer-${ld.id}-polys-outline`;

          map.addSource(sourceId, {
            type: "geojson",
            data: {
              type: "FeatureCollection",
              features: polyFeatures,
            } as any,
          });
          sourceIdsRef.current.push(sourceId);

          const fillColor = pickColor(ld.style, "#3b82f6");
          const strokeColor = pickStrokeColor(ld.style, "#1e3a8a");
          const baseFillOpacity = pickFillOpacity(ld.style, 0.25);
          const baseLineOpacity = pickOpacity(ld.style, 1);
          const baseLineWidth = pickLineWidth(ld.style, 1.5);

          const fillOpacity = dimmed
            ? Math.min(baseFillOpacity, 0.07)
            : baseFillOpacity;
          const outlineOpacity = dimmed
            ? Math.min(baseLineOpacity, 0.25)
            : baseLineOpacity;

          map.addLayer({
            id: fillId,
            type: "fill",
            source: sourceId,
            minzoom: zoomRange.minzoom,
            maxzoom: zoomRange.maxzoom,
            paint: {
              "fill-color": fillColor,
              "fill-opacity": fillOpacity,
            },
          });
          layerIdsRef.current.push(fillId);

          map.addLayer({
            id: outlineId,
            type: "line",
            source: sourceId,
            minzoom: zoomRange.minzoom,
            maxzoom: zoomRange.maxzoom,
            paint: {
              "line-color": strokeColor,
              "line-width": baseLineWidth,
              "line-opacity": outlineOpacity,
            },
          });
          layerIdsRef.current.push(outlineId);

          // Click → inspect
          map.on("click", fillId, (e) => {
            const f0 = e.features?.[0];
            if (!f0) return;
            const props = f0.properties || {};
            onSelectFeatureRef.current({
              id: props._featureId,
              geometry: f0.geometry,
              attributes: safeParseAttrs(props._attributes),
              status: props._status,
              source: props._source,
              client_id: props._clientId,
              collected_at: props._collectedAt,
              synced_at: props._syncedAt,
              _layerId: ld.id,
              _layerName: ld.name,
            });
          });
          map.on("mouseenter", fillId, () => {
            map.getCanvas().style.cursor = "pointer";
          });
          map.on("mouseleave", fillId, () => {
            map.getCanvas().style.cursor = "";
          });
        }
      }

      // Fit once for a given visibility/focus set — not when opening the inspector.
      if (
        anyGeom &&
        !bounds.isEmpty() &&
        fittedForKeyRef.current !== fitKey
      ) {
        map.fitBounds(bounds, { padding: 80, maxZoom: 15 });
        fittedForKeyRef.current = fitKey;
      }

      const syncMarkersToZoom = () => {
        const z = map.getZoom();
        for (const m of markersRef.current) {
          const el = m.getElement();
          const min = Number(el.dataset.layerMinZoom ?? "0");
          const max = Number(el.dataset.layerMaxZoom ?? "22");
          const show = z >= min && z < max;
          el.style.display = show ? "" : "none";
          el.style.pointerEvents = show ? "" : "none";
        }
      };
      markerZoomHandlerRef.current = syncMarkersToZoom;
      map.on("zoom", syncMarkersToZoom);
      syncMarkersToZoom();
    };

    // We must wait for the style to load before adding sources/layers.
    if (map.isStyleLoaded()) {
      apply();
    } else {
      map.once("load", apply);
    }

    return () => {
      // Cleanup happens on next effect run via the `apply` function.
      // We intentionally don't remove anything here because removing
      // sources/layers during teardown of a stale effect can collide
      // with map destruction.
    };
  }, [layerData, visibleLayers, focusedLayerId, fitKey, layers, projectId]);




  return (
    <div className="relative w-full h-full" style={{ minHeight: 400 }}>
      <div ref={containerRef} style={{ position: "absolute", inset: 0 }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

function extendBoundsForGeom(
  geom: any,
  bounds: maplibregl.LngLatBounds
): void {
  if (!geom || !geom.coordinates) return;
  switch (geom.type) {
    case "Point": {
      const [lng, lat] = geom.coordinates;
      if (isFiniteCoord(lng, lat)) bounds.extend([lng, lat]);
      break;
    }
    case "MultiPoint":
    case "LineString": {
      for (const c of geom.coordinates) {
        if (Array.isArray(c) && isFiniteCoord(c[0], c[1])) {
          bounds.extend([c[0], c[1]]);
        }
      }
      break;
    }
    case "MultiLineString":
    case "Polygon": {
      for (const ring of geom.coordinates) {
        for (const c of ring) {
          if (Array.isArray(c) && isFiniteCoord(c[0], c[1])) {
            bounds.extend([c[0], c[1]]);
          }
        }
      }
      break;
    }
    case "MultiPolygon": {
      for (const poly of geom.coordinates) {
        for (const ring of poly) {
          for (const c of ring) {
            if (Array.isArray(c) && isFiniteCoord(c[0], c[1])) {
              bounds.extend([c[0], c[1]]);
            }
          }
        }
      }
      break;
    }
  }
}

function isFiniteCoord(lng: any, lat: any): boolean {
  return (
    typeof lng === "number" &&
    typeof lat === "number" &&
    Number.isFinite(lng) &&
    Number.isFinite(lat)
  );
}

function makeGeoJSONFeature(
  f: any,
  geom: any,
  layerId: string,
  layerName: string
) {
  return {
    type: "Feature",
    geometry: geom,
    properties: {
      _layerId: layerId,
      _layerName: layerName,
      _featureId: f.id,
      _clientId: f.client_id,
      _status: f.status,
      _source: f.source,
      _collectedAt: f.collected_at,
      _syncedAt: f.synced_at,
      _attributes: JSON.stringify(f.attributes || {}),
    },
  };
}

function safeParseAttrs(s: any): Record<string, any> {
  if (!s) return {};
  if (typeof s !== "string") return s;
  try {
    return JSON.parse(s);
  } catch {
    return {};
  }
}

// Style accessors with safe defaults
function pickColor(style: any, fallback: string): string {
  return style?.color || style?.default?.color || fallback;
}
function pickIconSvg(style: any): string | undefined {
  return style?.icon_svg || style?.default?.icon_svg;
}

function svgToDataUrl(svg: string): string {
  let s = svg.trim();
  // Namespace is REQUIRED for the browser to load SVG as an <img>.
  if (!/xmlns=/.test(s)) {
    s = s.replace(/<svg\b/i, '<svg xmlns="http://www.w3.org/2000/svg"');
  }
  // Force width/height so it rasterizes at a real size (viewBox alone → 0×0).
  if (!/\swidth\s*=/.test(s)) {
    s = s.replace(/<svg\b/i, '<svg width="64"');
  }
  if (!/\sheight\s*=/.test(s)) {
    s = s.replace(/<svg\b/i, '<svg height="64"');
  }
  return "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(s)));
}

/** Registers an SVG as a named map image (once), then runs cb when ready. */
function ensureSvgImage(
  map: any,
  imgId: string,
  svg: string,
  cb: () => void,
) {
  if (map.hasImage(imgId)) {
    cb();
    return;
  }
  const img = new Image(64, 64);
  img.onload = () => {
    if (!map.hasImage(imgId)) {
      map.addImage(imgId, img);
    }
    cb();
  };
  img.onerror = () => cb();
  img.src = svgToDataUrl(svg);
}

function pickStrokeColor(style: any, fallback: string): string {
  return (
    style?.stroke_color ||
    style?.default?.stroke_color ||
    pickColor(style, fallback)
  );
}
function pickOpacity(style: any, fallback: number): number {
  const v =
    style?.opacity ??
    style?.default?.opacity ??
    fallback;
  return typeof v === "number" ? v : fallback;
}
function pickFillOpacity(style: any, fallback: number): number {
  const v =
    style?.fill_opacity ??
    style?.default?.fill_opacity ??
    fallback;
  return typeof v === "number" ? v : fallback;
}
function pickLineWidth(style: any, fallback: number): number {
  const v =
    style?.stroke_width ??
    style?.default?.stroke_width ??
    style?.line_width ??
    style?.default?.line_width ??
    fallback;
  return typeof v === "number" ? v : fallback;
}
function pickLineStyle(style: any): string | undefined {
  return style?.line_style || style?.default?.line_style;
}

function dashArrayFor(lineStyle?: string): number[] | undefined {
  switch (lineStyle) {
    case "dashed": return [3, 2];
    case "dotted": return [0.5, 1.5];
    case "dash_dot": return [3, 1.5, 0.5, 1.5];
    default: return undefined;
  }
}

// ─────────────────────────────────────────────────────────
// Point rendering (preserves existing DOM marker UX)
// ─────────────────────────────────────────────────────────

function renderPointMarker(args: {
  map: maplibregl.Map;
  feature: any;
  geometry: any;
  layerId: string;
  layerName: string;
  style: any;
  dimmed: boolean;
  onSelectFeature: (f: any) => void;
  collectInto: maplibregl.Marker[];
}) {
  const {
    map,
    feature,
    geometry,
    layerId,
    layerName,
    style,
    dimmed,
    onSelectFeature,
    collectInto,
  } = args;

  const points: [number, number][] = [];
  if (geometry.type === "Point") {
    const [lng, lat] = geometry.coordinates;
    points.push([lng, lat]);
  } else if (geometry.type === "MultiPoint") {
    for (const c of geometry.coordinates) {
      points.push([c[0], c[1]]);
    }
  }

  const computed = computeFeatureStyle(style, feature.attributes);
  const label = getLabelText(style, feature.attributes);

  for (const [lng, lat] of points) {
    if (!isFiniteCoord(lng, lat)) continue;

    const el = buildMarker(computed, label, dimmed);
    const range = layerZoomRange(style);
    el.dataset.layerMinZoom = String(range.minzoom);
    el.dataset.layerMaxZoom = String(range.maxzoom);
    if (!isMapZoomInLayerRange(map.getZoom(), style)) {
      el.style.display = "none";
      el.style.pointerEvents = "none";
    }
    el.addEventListener("click", () =>
      onSelectFeature({
        ...feature,
        _layerId: layerId,
        _layerName: layerName,
      })
    );

    const marker = new maplibregl.Marker({ element: el })
      .setLngLat([lng, lat])
      .addTo(map);
    collectInto.push(marker);
  }
}



function buildMarker(
  s: any,
  label: string | null,
  dimmed: boolean
): HTMLDivElement {
  const wrapper = document.createElement("div");
  wrapper.style.cssText =
    "display: flex; flex-direction: column; align-items: center; cursor: pointer;";

  const pin = document.createElement("div");
  const size = s.size || 14;
  const color = s.color || "#3b82f6";
  const stroke = s.stroke_color || "#ffffff";
  const strokeW = s.stroke_width || 2;
  const baseOpacity = s.opacity ?? 1;
  const opacity = dimmed ? Math.min(baseOpacity, 0.3) : baseOpacity;

  if (s.icon && s.icon.startsWith("lucide:")) {
    pin.style.cssText = `
      width: ${size + 8}px; height: ${size + 8}px;
      background: ${color}; border: ${strokeW}px solid ${stroke};
      border-radius: 50%;
      box-shadow: 0 2px 6px rgba(0,0,0,0.15);
      opacity: ${opacity};
      display: flex; align-items: center; justify-content: center;
    `;
    const url = iconToDataUrl(s.icon.slice(7), "#ffffff");
    if (url) {
      const img = document.createElement("img");
      img.src = url;
      img.style.cssText = `width: ${size * 0.6}px; height: ${size * 0.6}px;`;
      pin.appendChild(img);
    }
  } else {
    pin.style.cssText = `
      width: ${size}px; height: ${size}px;
      background: ${color}; border: ${strokeW}px solid ${stroke};
      border-radius: 50%;
      box-shadow: 0 2px 6px rgba(0,0,0,0.15);
      opacity: ${opacity};
    `;
  }
  wrapper.appendChild(pin);

  if (label && !dimmed) {
    const lbl = document.createElement("div");
    lbl.textContent = label;
    lbl.style.cssText = `
      margin-top: 2px;
      font-size: 11px; font-weight: 500;
      color: #1f2937;
      padding: 1px 4px;
      background: rgba(255,255,255,0.85);
      border-radius: 3px;
      pointer-events: none;
      white-space: nowrap;
      max-width: 120px;
      overflow: hidden;
      text-overflow: ellipsis;
    `;
    wrapper.appendChild(lbl);
  }

  return wrapper;
}

