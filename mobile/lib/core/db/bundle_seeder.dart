import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'db_provider.dart';

class SeedResult {
  final int forms;
  final int layers;
  final int choiceLists;
  final int assignments;
  final int referenceFeatures;
  final int referenceTiles; // 👈 NEW: .mbtiles files extracted
  final List<String> warnings;

  const SeedResult({
    required this.forms,
    required this.layers,
    required this.choiceLists,
    required this.assignments,
    required this.referenceFeatures,
    this.referenceTiles = 0,
    this.warnings = const [],
  });

  int get total =>
      forms + layers + choiceLists + assignments + referenceFeatures;
}

class BundleSeeder {
  final AppDatabase _db;
  BundleSeeder(this._db);

  /// Parses bundle ZIP bytes and seeds the local DB in a single transaction.
  /// Existing rows for this project are wiped first.
  Future<SeedResult> seed({
    required String projectId,
    required Uint8List zipBytes,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // Build a quick map of path -> bytes for fast lookup
    final files = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile) {
        files[file.name] = file.content as Uint8List;
      }
    }

    // ── Extract reference_tiles/*.mbtiles to disk BEFORE the transaction ──
    // Wipe the project mbtiles dir first so removed/failed layers cannot leave
    // stale tiles that force the offline map onto an outdated path.
    int tileCount = 0;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final tileDir = Directory(p.join(docs.path, 'mbtiles', projectId));
      if (await tileDir.exists()) {
        await tileDir.delete(recursive: true);
      }
      await tileDir.create(recursive: true);

      for (final path in files.keys) {
        if (!path.startsWith('reference_tiles/') || !path.endsWith('.mbtiles')) {
          continue;
        }
        final layerId = path
            .substring('reference_tiles/'.length)
            .replaceAll(RegExp(r'\.mbtiles$'), '');
        final bytes = files[path];
        if (bytes == null || bytes.isEmpty) continue;

        try {
          final tileFile = File(p.join(tileDir.path, '$layerId.mbtiles'));
          await tileFile.writeAsBytes(bytes, flush: true);
          debugPrint('[bundle_seeder] wrote mbtiles layer=$layerId '
              '(${bytes.length} bytes) to ${tileFile.path}');
          tileCount++;
        } catch (e) {
          debugPrint('[bundle_seeder] failed to write mbtiles for '
              'layer $layerId: $e');
        }
      }
    } catch (e) {
      debugPrint('[bundle_seeder] mbtiles extract failed: $e');
    }

    Map<String, dynamic>? readJson(String path) {
      final bytes = files[path];
      if (bytes == null) return null;
      try {
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    List<dynamic>? readJsonList(String path) {
      final bytes = files[path];
      if (bytes == null) return null;
      try {
        return jsonDecode(utf8.decode(bytes)) as List<dynamic>;
      } catch (_) {
        return null;
      }
    }

    final warnings = <String>[];

    // Manifest — surface warnings to the caller
    final manifest = readJson('manifest.json');
    if (manifest == null) {
      throw Exception('Bundle missing manifest.json');
    }
    if (manifest['warnings'] is List) {
      for (final w in manifest['warnings'] as List) {
        warnings.add(w.toString());
      }
    }

    int formCount = 0;
    int layerCount = 0;
    int choiceListCount = 0;
    int assignmentCount = 0;
    int refCount = 0;

    await _db.transaction(() async {
      // Wipe existing project data so re-seed is idempotent
      await _wipeProjectData(projectId);

      // ── Project metadata (AOI) ─────────────────────────
      final projectMeta = readJson('project.json');
      if (projectMeta != null) {
        final aoi = projectMeta['area_of_interest'];
        String? aoiJson;
        if (aoi != null) {
          aoiJson = aoi is String ? aoi : jsonEncode(aoi);
        }
        await _db.upsertProject(
          ProjectsCompanion(
            id: Value(projectId),
            name: Value((projectMeta['name'] ?? 'Untitled').toString()),
            description: Value(projectMeta['description']?.toString()),
            mode: Value(
                (projectMeta['mode'] ?? 'form_collection').toString()),
            status: Value((projectMeta['status'] ?? 'active').toString()),
            version: Value(_asInt(projectMeta['version']) ?? 1),
            areaOfInterest: Value(aoiJson),
          ),
        );
      }

      // ── Forms ─────────────────────────────────────────
      final formIds = _idsFromIndex(readJsonList('forms/index.json'));
      for (final formId in formIds) {
        final form = readJson('forms/$formId.json');
        if (form == null) continue;

        await _db.into(_db.forms).insert(
              FormsCompanion.insert(
                id: formId,
                projectId: projectId,
                name: (form['name'] ?? 'Untitled').toString(),
                description: Value(form['description']?.toString()),
                version: Value(_asInt(form['version']) ?? 1),
                schema: jsonEncode(form['schema'] ?? {}),
              ),
            );
        formCount++;
      }

      // ── Layers ────────────────────────────────────────
      final layerIds = _idsFromIndex(readJsonList('layers/index.json'));
      for (final layerId in layerIds) {
        final layer = readJson('layers/$layerId.json');
        if (layer == null) continue;

await _db.into(_db.layers).insert(
              LayersCompanion.insert(
                id: layerId,
                projectId: projectId,
                name: (layer['name'] ?? 'Untitled').toString(),
                geometryType: (layer['geometry_type'] ?? 'point').toString(),
                formId: Value(layer['form_id']?.toString()),
                style: layer['style'] != null
                    ? Value(jsonEncode(layer['style']))
                    : const Value.absent(),
                // 👇 D1.0: pulled from D1.0 bundle backend (data_source_id)
                dataSourceId: Value(layer['data_source_id']?.toString()),
              ),
            );
        layerCount++;
      }

      // ── Choice lists ─────────────────────────────────
      final clIds = _idsFromIndex(readJsonList('choice_lists/index.json'));
      for (final clId in clIds) {
        final cl = readJson('choice_lists/$clId.json');
        if (cl == null) continue;

        await _db.into(_db.choiceLists).insert(
              ChoiceListsCompanion.insert(
                id: clId,
                projectId: projectId,
                name: (cl['name'] ?? 'Untitled').toString(),
                choices: jsonEncode(cl['choices'] ?? []),
              ),
            );
        choiceListCount++;
      }

      // ── Assignments ──────────────────────────────────
      final asgnIds =
          _idsFromIndex(readJsonList('assignments/index.json'));
      for (final asgnId in asgnIds) {
        final asgn = readJson('assignments/$asgnId.json');
        if (asgn == null) continue;

        await _db.into(_db.assignments).insert(
              AssignmentsCompanion.insert(
                id: asgnId,
                projectId: projectId,
                title: Value(asgn['title']?.toString()),
                instructions: Value(asgn['instructions']?.toString()),
                priority: Value(asgn['priority']?.toString()),
                dueDate: Value(_parseDate(asgn['due_date'])),
                targetCount: Value(_asInt(asgn['target_count'])),
                status: Value(asgn['status']?.toString() ?? 'pending'),
                area: asgn['area'] != null
                    ? Value(jsonEncode(asgn['area']))
                    : const Value.absent(),
              ),
            );
        assignmentCount++;
      }

      // ── Reference features ───────────────────────────
      for (final path in files.keys) {
        if (!path.startsWith('reference_features/') ||
            !path.endsWith('.geojson')) continue;

        final layerId = path
            .substring('reference_features/'.length)
            .replaceAll(RegExp(r'\.geojson$'), '');

        final fc = readJson(path);
        if (fc == null) continue;

        final featureArr = fc['features'];
        if (featureArr is! List) continue;

        for (final f in featureArr) {
          if (f is! Map) continue;
          final rawId = f['id']?.toString();
          if (rawId == null || rawId.isEmpty) continue;

          final geom = f['geometry'];
          final props = f['properties'] is Map
              ? Map<String, dynamic>.from(f['properties'] as Map)
              : <String, dynamic>{};

          // Pull out _source_ref if present (added by server during import)
          final sourceRef = props.remove('_source_ref')?.toString() ?? rawId;

          // 👇 D1.0: pull out _data_source_id (added by D1.0 bundle backend)
          final dataSourceId = props.remove('_data_source_id')?.toString();

          // Namespace ids by layer so linked tables that reuse natural keys
          // (objectid=1 in two layers) cannot collide on the global PK.
          final featureId = '$layerId:$rawId';

          await _db.into(_db.referenceFeatures).insert(
                ReferenceFeaturesCompanion.insert(
                  id: featureId,
                  projectId: projectId,
                  layerId: layerId,
                  geometry: jsonEncode(geom),
                  attributes: jsonEncode(props),
                  sourceRef: Value(sourceRef),
                  dataSourceId: Value(dataSourceId),
                ),
              );
          refCount++;
        }
      }
    });

    return SeedResult(
      forms: formCount,
      layers: layerCount,
      choiceLists: choiceListCount,
      assignments: assignmentCount,
      referenceFeatures: refCount,
      referenceTiles: tileCount,
      warnings: warnings,
    );
  }

  Future<void> _wipeProjectData(String projectId) async {
    await (_db.delete(_db.referenceFeatures)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (_db.delete(_db.assignments)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (_db.delete(_db.choiceLists)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (_db.delete(_db.layers)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
    await (_db.delete(_db.forms)
          ..where((t) => t.projectId.equals(projectId)))
        .go();
  }
}

// ── Helpers ────────────────────────────────────────────

List<String> _idsFromIndex(List<dynamic>? index) {
  if (index == null) return [];
  final ids = <String>[];
  for (final entry in index) {
    if (entry is Map && entry['id'] != null) {
      ids.add(entry['id'].toString());
    }
  }
  return ids;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

// ── Provider ───────────────────────────────────────────

final bundleSeederProvider = Provider<BundleSeeder?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return BundleSeeder(db);
});