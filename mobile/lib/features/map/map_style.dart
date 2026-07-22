import '../../core/settings/basemap_options.dart';

/// Builds a MapLibre raster style JSON for a single tile source.
/// Falls back to OSM if no basemap is specified.
String buildBasemapStyle({BasemapId basemap = BasemapId.osm}) {
  final opt = basemapById(basemap);

  // MapLibre style spec — single raster source + raster layer.
  return '''
{
  "version": 8,
  "sources": {
    "basemap-src": {
      "type": "raster",
      "tiles": ["${opt.tileUrl}"],
      "tileSize": ${opt.tileSize},
      "maxzoom": ${opt.maxZoom},
      "attribution": "${opt.attribution}"
    }
  },
  "layers": [
    {
      "id": "basemap-layer",
      "type": "raster",
      "source": "basemap-src",
      "minzoom": 0,
      "maxzoom": 22
    }
  ]
}
''';
}

/// Backwards-compatible wrapper. Existing call sites can keep using this
/// name until they're migrated to buildBasemapStyle.
String buildOsmRasterStyle() => buildBasemapStyle(basemap: BasemapId.osm);