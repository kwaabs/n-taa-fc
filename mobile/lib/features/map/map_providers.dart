import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';

/// Transient sourceRef of a feature being edited in geometry-edit mode.
/// When set, that feature is excluded from the reference render so the
/// edit overlay can act as a live preview.
final activeGeomEditRefProvider = StateProvider<String?>((ref) => null);

class LocalMapFeature {
  final String id;
  final String projectId;
  final String layerId;
  final String? sourceRef;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> attributes;

  /// Where this row came from on the device:
  ///  - 'reference'  → loaded from ReferenceFeatures (imported from a data source)
  ///  - 'collected'  → loaded from CollectedFeatures (captured / edited by surveyor)
  final String source;

  /// External data source id. Set for reference features that came from an
  /// imported data source. Forwarded into CollectedFeatures rows when the
  /// surveyor edits a reference feature (D0.3).
  final String? dataSourceId;

  const LocalMapFeature({
    required this.id,
    required this.projectId,
    required this.layerId,
    this.sourceRef,
    required this.geometry,
    required this.attributes,
    this.source = 'reference',
    this.dataSourceId,
  });

  /// First coordinate longitude — only meaningful for point geometries.
  double? get longitude {
    final coords = geometry['coordinates'];
    if (geometry['type'] == 'Point' &&
        coords is List &&
        coords.length >= 2 &&
        coords[0] is num) {
      return (coords[0] as num).toDouble();
    }
    return null;
  }

  /// First coordinate latitude — only meaningful for point geometries.
  double? get latitude {
    final coords = geometry['coordinates'];
    if (geometry['type'] == 'Point' &&
        coords is List &&
        coords.length >= 2 &&
        coords[1] is num) {
      return (coords[1] as num).toDouble();
    }
    return null;
  }

  bool get isPoint =>
      geometry['type'] == 'Point' || geometry['type'] == 'MultiPoint';

  bool get isLine =>
      geometry['type'] == 'LineString' || geometry['type'] == 'MultiLineString';

  bool get isPolygon =>
      geometry['type'] == 'Polygon' || geometry['type'] == 'MultiPolygon';

  String get title {
    for (final key in ['name', 'title', 'label']) {
      final v = attributes[key];
      if (v is String && v.isNotEmpty) return v;
    }
    if (sourceRef != null && sourceRef!.isNotEmpty) return sourceRef!;
    return id.length > 8 ? id.substring(0, 8) : id;
  }
}

/// Allowed GeoJSON geometry types. Anything else is silently dropped.
const _kAllowedGeomTypes = <String>{
  'Point',
  'MultiPoint',
  'LineString',
  'MultiLineString',
  'Polygon',
  'MultiPolygon',
};

final localReferenceFeaturesProvider =
    FutureProvider.family<List<LocalMapFeature>, String>(
        (ref, projectId) async {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return const [];

  // 🪦 First, find sourceRefs that have been locally tombstoned by the surveyor
  // (mark-deleted but not yet reconciled). Hide those reference rows from the map.
  // 🪦/✏️ Find sourceRefs that have been locally edited OR tombstoned by the surveyor.
  // Either way, the reference layer should NOT render them — the collected
  // features layer will draw the surveyor's version (at its new location).
  final overrideRows = await (db.select(db.collectedFeatures)
        ..where((c) => c.projectId.equals(projectId))
        ..where((c) => c.sourceRef.isNotNull()))
      .get();
  // Scope by layer so the same natural key in two layers does not hide both.
  final overriddenKeys = <String>{
    for (final r in overrideRows)
      if (r.sourceRef != null && r.layerId != null)
        '${r.layerId}|${r.sourceRef}',
  };

  final rows = await (db.select(db.referenceFeatures)
        ..where((r) => r.projectId.equals(projectId)))
      .get();

  final features = <LocalMapFeature>[];

  for (final row in rows) {
    try {
      // Skip if this reference has a pending edit/tombstone in collected_features
      if (row.sourceRef != null &&
          overriddenKeys.contains('${row.layerId}|${row.sourceRef}')) {
        continue;
      }

      final geomDecoded = jsonDecode(row.geometry);
      final attrsDecoded = jsonDecode(row.attributes);

      if (geomDecoded is! Map) continue;
      if (attrsDecoded is! Map) continue;

      final geom = Map<String, dynamic>.from(geomDecoded);
      final attrs = Map<String, dynamic>.from(attrsDecoded);

      final type = geom['type'];
      if (type is! String) continue;
      if (!_kAllowedGeomTypes.contains(type)) continue;
      if (geom['coordinates'] == null) continue;

      features.add(
        LocalMapFeature(
          id: row.id,
          projectId: row.projectId,
          layerId: row.layerId,
          sourceRef: row.sourceRef,
          geometry: geom,
          attributes: attrs,
          source: 'reference',
          dataSourceId: row.dataSourceId,
        ),
      );
    } catch (_) {
      // ignore malformed rows
    }
  }

  return features;
});

final localCollectedFeaturesProvider =
    FutureProvider.family<List<LocalMapFeature>, String>(
        (ref, projectId) async {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return const [];

  final rows = await (db.select(db.collectedFeatures)
        ..where((r) => r.projectId.equals(projectId))
        ..where((r) => r.status
            .isNotIn(['draft'])) // skip drafts; show pending/synced/failed
        ..where((r) => r.deletedAt.isNull()) // 👈 NEW: hide tombstones from map

      )
      .get();

  final features = <LocalMapFeature>[];

  for (final row in rows) {
    try {
      // Skip rows with no geometry (e.g. corrupted)
      final geomRaw = row.geometry;
      if (geomRaw == null || geomRaw.isEmpty) continue;

      final geomDecoded = jsonDecode(geomRaw);
      Map<String, dynamic> attrs = const {};

      try {
        final attrsRaw = row.attributes;
        if (attrsRaw.isNotEmpty) {
          final attrsDecoded = jsonDecode(attrsRaw);
          if (attrsDecoded is Map) {
            attrs = Map<String, dynamic>.from(attrsDecoded);
          }
        }
      } catch (_) {}

      if (geomDecoded is! Map) continue;
      final geom = Map<String, dynamic>.from(geomDecoded);
      final type = geom['type'];
      if (type is! String) continue;
      if (!_kAllowedGeomTypes.contains(type)) continue;
      if (geom['coordinates'] == null) continue;

      // Use layer_id from the collected_features row.
      // If null (e.g. some older entries), skip — they have no rendering home.
      final layerId = row.layerId;
      if (layerId == null) continue;

      features.add(
        LocalMapFeature(
          id: row.clientId,
          projectId: row.projectId,
          layerId: layerId,
          sourceRef: row
              .sourceRef, // 👈 was row.serverId — now use the real sourceRef column from D0.1
          geometry: geom,
          attributes: attrs,
          source: 'collected', // 👈 NEW
          dataSourceId: row.dataSourceId, // 👈 NEW
        ),
      );
    } catch (_) {
      // ignore malformed rows
    }
  }

  debugPrint('[map] localCollectedFeaturesProvider returned ${features.length} '
      'features for project $projectId');
  for (final f in features) {
    debugPrint('  - ${f.id.substring(0, 8)} '
        'layerId=${f.layerId.substring(0, 8)} '
        'type=${f.geometry['type']}');
  }

  return features;
});

final localLayerNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, projectId) async {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return const {};

  final rows = await (db.select(db.layers)
        ..where((l) => l.projectId.equals(projectId)))
      .get();

  return {
    for (final row in rows) row.id: row.name,
  };
});

final localLayerStylesProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, projectId) async {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return const {};

  // Fetch the raw "style" text column for each layer in the project
  final rows = await (db.select(db.layers)
        ..where((tbl) => tbl.projectId.equals(projectId)))
      .get();

  final out = <String, dynamic>{};
  for (final row in rows) {
    if (row.style != null && row.style!.isNotEmpty) {
      out[row.id] = row.style; // store raw json string; map screen parses it
    }
  }
  return out;
});

// Simple typedef for the composite key
typedef _LayerTilesKey = ({String projectId, String layerId});

/// Returns absolute path to a layer's cached .mbtiles file, or null if
/// bundle didn't include tiles for this layer.
///
/// Cached in Riverpod so callers can watch it and rebuild only when needed.
final layerTilesPathProvider =
    FutureProvider.family<String?, _LayerTilesKey>((ref, key) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(
      docs.path,
      'mbtiles',
      key.projectId,
      '${key.layerId}.mbtiles',
    );
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
  } catch (_) {}
  return null;
});
