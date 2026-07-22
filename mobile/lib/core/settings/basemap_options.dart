/// All supported basemap tile sources for the map view.
/// Each entry is independent: id, display name, and tile URL template.

enum BasemapId {
  osm,
  cartoPositron,
  cartoVoyager,
  esriTopo,
  esriImagery,
  googleHybrid,
}

class BasemapOption {
  final BasemapId id;
  final String label;
  final String description;
  final String tileUrl;
  final String attribution;
  final int tileSize;
  final int maxZoom;

  const BasemapOption({
    required this.id,
    required this.label,
    required this.description,
    required this.tileUrl,
    required this.attribution,
    this.tileSize = 256,
    this.maxZoom = 19,
  });
}

const basemapOptions = <BasemapOption>[
  BasemapOption(
    id: BasemapId.osm,
    label: 'OpenStreetMap',
    description: 'Classic OSM — free and global',
    tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
  ),
  BasemapOption(
    id: BasemapId.cartoPositron,
    label: 'Carto Positron',
    description: 'Light, minimal — ideal for overlays',
    tileUrl:
        'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap, © Carto',
  ),
  BasemapOption(
    id: BasemapId.cartoVoyager,
    label: 'Carto Voyager',
    description: 'Colored, data-viz style',
    tileUrl:
        'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap, © Carto',
  ),
  BasemapOption(
    id: BasemapId.esriTopo,
    label: 'Esri World Topographic',
    description: 'Topographic detail, terrain',
    tileUrl:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
  ),
  BasemapOption(
    id: BasemapId.esriImagery,
    label: 'Esri World Imagery',
    description: 'Satellite / aerial photography',
    tileUrl:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri, Maxar, Earthstar Geographics',
  ),
  BasemapOption(
    id: BasemapId.googleHybrid,
    label: 'Google Hybrid',
    description: 'Satellite with labels (dev use)',
    tileUrl: 'https://mt3.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    attribution: '© Google',
  ),
];

BasemapOption basemapById(BasemapId id) =>
    basemapOptions.firstWhere(
      (b) => b.id == id,
      orElse: () => basemapOptions.first,
    );

BasemapId basemapIdFromString(String? raw) {
  if (raw == null) return BasemapId.osm;
  for (final b in basemapOptions) {
    if (b.id.name == raw) return b.id;
  }
  return BasemapId.osm;
}