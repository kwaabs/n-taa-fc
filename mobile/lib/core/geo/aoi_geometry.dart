/// Lightweight GeoJSON AOI helpers (no turf dependency).
///
/// Coordinates are [lng, lat] as in GeoJSON. Containment uses ray casting on
/// the polygon rings the user sees on the map (no buffer).
library;

bool geometryOutsideAoi(
  Map<String, dynamic>? geometry,
  Map<String, dynamic>? aoi,
) {
  if (geometry == null || aoi == null) return false;
  final points = _geometryVertices(geometry);
  if (points.isEmpty) return false;
  for (final p in points) {
    if (!pointInAoi(p.$1, p.$2, aoi)) return true;
  }
  return false;
}

bool pointInAoi(double lng, double lat, Map<String, dynamic> aoi) {
  final type = aoi['type']?.toString();
  final coords = aoi['coordinates'];
  if (type == 'Polygon' && coords is List) {
    return _pointInPolygon(lng, lat, coords);
  }
  if (type == 'MultiPolygon' && coords is List) {
    for (final poly in coords) {
      if (poly is List && _pointInPolygon(lng, lat, poly)) return true;
    }
    return false;
  }
  // Feature / FeatureCollection wrappers
  if (type == 'Feature') {
    final g = aoi['geometry'];
    if (g is Map<String, dynamic>) return pointInAoi(lng, lat, g);
  }
  if (type == 'FeatureCollection') {
    final features = aoi['features'];
    if (features is List) {
      for (final f in features) {
        if (f is Map<String, dynamic> && pointInAoi(lng, lat, f)) return true;
      }
    }
    return false;
  }
  return true; // unknown AOI shape → don't block
}

List<(double, double)> _geometryVertices(Map<String, dynamic> geometry) {
  final type = geometry['type']?.toString();
  final coords = geometry['coordinates'];
  final out = <(double, double)>[];
  if (type == 'Point' && coords is List && coords.length >= 2) {
    out.add((_asDouble(coords[0]), _asDouble(coords[1])));
  } else if (type == 'LineString' && coords is List) {
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        out.add((_asDouble(c[0]), _asDouble(c[1])));
      }
    }
  } else if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    final ring = coords.first;
    if (ring is List) {
      for (final c in ring) {
        if (c is List && c.length >= 2) {
          out.add((_asDouble(c[0]), _asDouble(c[1])));
        }
      }
    }
  } else if (type == 'MultiPoint' && coords is List) {
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        out.add((_asDouble(c[0]), _asDouble(c[1])));
      }
    }
  } else if (type == 'MultiLineString' && coords is List) {
    for (final line in coords) {
      if (line is! List) continue;
      for (final c in line) {
        if (c is List && c.length >= 2) {
          out.add((_asDouble(c[0]), _asDouble(c[1])));
        }
      }
    }
  } else if (type == 'MultiPolygon' && coords is List) {
    for (final poly in coords) {
      if (poly is! List || poly.isEmpty) continue;
      final ring = poly.first;
      if (ring is! List) continue;
      for (final c in ring) {
        if (c is List && c.length >= 2) {
          out.add((_asDouble(c[0]), _asDouble(c[1])));
        }
      }
    }
  }
  return out;
}

/// [coords] = list of rings; first is exterior. Point must be in exterior
/// and not in any hole.
bool _pointInPolygon(double lng, double lat, List coords) {
  if (coords.isEmpty) return false;
  final exterior = coords.first;
  if (exterior is! List || !_rayCast(lng, lat, exterior)) return false;
  for (var i = 1; i < coords.length; i++) {
    final hole = coords[i];
    if (hole is List && _rayCast(lng, lat, hole)) return false;
  }
  return true;
}

bool _rayCast(double lng, double lat, List ring) {
  final pts = <(double, double)>[];
  for (final c in ring) {
    if (c is List && c.length >= 2) {
      pts.add((_asDouble(c[0]), _asDouble(c[1])));
    }
  }
  if (pts.length < 3) return false;

  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final xi = pts[i].$1, yi = pts[i].$2;
    final xj = pts[j].$1, yj = pts[j].$2;
    final intersect = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-15 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
