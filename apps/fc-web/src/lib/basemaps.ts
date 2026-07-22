export interface BasemapProvider {
    id: string;
    name: string;
    description: string;
    type: "raster";
    tiles: string[];
    attribution: string;
    maxZoom: number;
    preview?: string; // small preview image URL
  }
  
  export const BASEMAP_PROVIDERS: BasemapProvider[] = [
    {
      id: "osm",
      name: "OpenStreetMap",
      description: "Default community map",
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      attribution: "© OpenStreetMap contributors",
      maxZoom: 19,
    },
    {
      id: "esri_topo",
      name: "Esri World Topo",
      description: "Topographic detail",
      type: "raster",
      tiles: [
        "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
      ],
      attribution: "© Esri",
      maxZoom: 19,
    },
    {
      id: "esri_satellite",
      name: "Esri Imagery",
      description: "Satellite imagery",
      type: "raster",
      tiles: [
        "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
      ],
      attribution: "© Esri",
      maxZoom: 19,
    },
    {
      id: "carto_positron",
      name: "Carto Positron",
      description: "Light, minimal style",
      type: "raster",
      tiles: [
        "https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
        "https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
        "https://c.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
      ],
      attribution: "© Carto © OpenStreetMap",
      maxZoom: 20,
    },
    {
      id: "carto_voyager",
      name: "Carto Voyager",
      description: "Balanced, vibrant",
      type: "raster",
      tiles: [
        "https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
        "https://b.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
        "https://c.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
      ],
      attribution: "© Carto © OpenStreetMap",
      maxZoom: 20,
    },
    {
      id: "google_mt3",
      name: "Google Maps",
      description: "Unofficial — check ToS for production use",
      type: "raster",
      tiles: ["https://mt3.google.com/vt/lyrs=m&x={x}&y={y}&z={z}"],
      attribution: "© Google",
      maxZoom: 20,
    },
  ];
  
  export function getBasemap(id: string | undefined | null): BasemapProvider {
    const found = BASEMAP_PROVIDERS.find((b) => b.id === id);
    return found || BASEMAP_PROVIDERS[0];
  }
  
  // Build a MapLibre style object from a basemap (or custom URL)
  export function buildMapStyle(
    basemapId: string | undefined | null,
    customUrl?: string
  ): any {
    let tiles: string[];
    let attribution: string;
    let maxZoom: number;
  
    if (basemapId === "custom" && customUrl) {
      tiles = [customUrl];
      attribution = "Custom source";
      maxZoom = 22;
    } else {
      const bm = getBasemap(basemapId);
      tiles = bm.tiles;
      attribution = bm.attribution;
      maxZoom = bm.maxZoom;
    }
  
    return {
      version: 8,
      sources: {
        basemap: {
          type: "raster",
          tiles,
          tileSize: 256,
          attribution,
          maxzoom: maxZoom,
        },
      },
      layers: [{ id: "basemap-layer", type: "raster", source: "basemap" }],
    };
  }