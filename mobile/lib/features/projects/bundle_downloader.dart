import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/app_database.dart' as db;
import '../../core/db/bundle_seeder.dart';
import '../../core/db/db_provider.dart';
import 'bundle_repository.dart';
import 'project_model.dart';

class BundleDownloadResult {
  final Uint8List bytes;
  final String filename;
  final String? contentHash;
  final SeedResult? seedResult;

  const BundleDownloadResult({
    required this.bytes,
    required this.filename,
    this.contentHash,
    this.seedResult,
  });

  BundleDownloadResult withSeed(SeedResult seed) {
    return BundleDownloadResult(
      bytes: bytes,
      filename: filename,
      contentHash: contentHash,
      seedResult: seed,
    );
  }
}

/// Progress callbacks for the hybrid core + layer-ref download path.
class EfficientDownloadProgress {
  final String message;
  final BundleProgress? jobProgress;
  final int? layerIndex;
  final int? layerTotal;

  const EfficientDownloadProgress({
    required this.message,
    this.jobProgress,
    this.layerIndex,
    this.layerTotal,
  });
}

class BundleDownloader {
  final db.AppDatabase? _db;
  final BundleSeeder? _seeder;

  BundleDownloader(this._db, this._seeder);

  /// Bump when tile/search pack shape changes so devices drop stale hashes
  /// even if the server has not been restarted yet.
  static const layerPackClientVersion = 'v7-fc-ref-no-drop';

  Future<void> ensureProjectRow(Project project) async {
    final database = _db;
    if (database == null) return;
    await database.upsertProject(
      db.ProjectsCompanion(
        id: Value(project.id),
        name: Value(project.name),
        description: Value(project.description),
        mode: Value(project.mode),
        status: Value(project.status),
        version: Value(project.version),
        areaOfInterest: project.areaOfInterest != null
            ? Value(jsonEncode(project.areaOfInterest))
            : const Value.absent(),
      ),
    );
  }

  Future<BundleDownloadResult> downloadBundle(BundleReady ready) async {
    final response = await http
        .get(Uri.parse(ready.downloadUrl))
        .timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download bundle (HTTP ${response.statusCode})',
      );
    }
    return BundleDownloadResult(
      bytes: response.bodyBytes,
      filename: ready.filename,
      contentHash: ready.contentHash,
    );
  }

  /// Seeds the local DB from the downloaded bundle, then marks the project
  /// row as downloaded. Returns the seed stats so the UI can display them.
  Future<SeedResult?> seedAndRecord({
    required String projectId,
    required BundleDownloadResult result,
  }) async {
    final seeder = _seeder;
    SeedResult? seedResult;
    if (seeder != null) {
      seedResult = await seeder.seed(
        projectId: projectId,
        zipBytes: result.bytes,
      );
    }

    final database = _db;
    if (database != null) {
      await database.markProjectDownloaded(
        projectId: projectId,
        contentHash: result.contentHash ?? '',
        filename: result.filename,
        sizeBytes: result.bytes.length,
      );
    }
    return seedResult;
  }

  /// Core pack first, then optionally per-layer reference packs.
  ///
  /// When [downloadReferencePacks] is false (default for large projects), only
  /// project setup is downloaded; map layers are fetched lazily on the map.
  /// Uses packs/manifest hashes to skip unchanged downloads.
  Future<({BundleReady ready, SeedResult? seedResult, int downloadedBytes})>
      downloadEfficient({
    required Project project,
    required BundleRepository repo,
    required void Function(EfficientDownloadProgress) onProgress,
    bool downloadReferencePacks = false,
  }) async {
    final projectId = project.id;
    await ensureProjectRow(project);

    PacksManifest? manifest;
    try {
      onProgress(const EfficientDownloadProgress(message: 'Checking pack versions…'));
      manifest = await repo.getPacksManifest(projectId: projectId);
    } catch (e) {
      debugPrint('[BUNDLE] manifest unavailable, full download: $e');
    }

    final localLayerHashes = await _loadLayerHashes(projectId);
    await _invalidateStaleLayerPackClientVersion(
      projectId,
      localLayerHashes,
    );
    final localCoreHash = await _localCoreHash(projectId);
    var skipCore = manifest != null &&
        manifest.coreHash.isNotEmpty &&
        localCoreHash != null &&
        localCoreHash == manifest.coreHash;
    if (skipCore && manifest != null) {
      final catalogOk =
          await _localLayerCatalogMatchesManifest(projectId, manifest);
      if (!catalogOk) {
        debugPrint(
          '[BUNDLE] core hash matched but local layer catalog is stale '
          '— re-downloading core',
        );
        skipCore = false;
      }
    }

    late BundleReady coreReady;
    var totalBytes = 0;
    SeedResult? seed;

    if (skipCore) {
      debugPrint('[BUNDLE] core pack unchanged — skipping download');
      onProgress(const EfficientDownloadProgress(
        message: 'Core pack up to date — skipping…',
      ));
      coreReady = BundleReady(
        filename: 'core-pack (cached)',
        downloadUrl: '',
        sizeBytes: 0,
        contentHash: localCoreHash,
      );
      seed = const SeedResult(
        forms: 0,
        layers: 0,
        choiceLists: 0,
        assignments: 0,
        referenceFeatures: 0,
      );
    } else {
      onProgress(
          const EfficientDownloadProgress(message: 'Requesting core pack…'));
      coreReady = await _awaitReady(
        request: () => repo.requestCore(projectId: projectId),
        poll: (jobId) => repo.pollCoreJob(projectId: projectId, jobId: jobId),
        onProgress: (p) => onProgress(EfficientDownloadProgress(
          message: 'Building core pack…',
          jobProgress: p,
        )),
      );

      onProgress(EfficientDownloadProgress(
        message: 'Downloading core pack…',
        jobProgress: const BundleProgress(step: 'download', percent: 0),
      ));
      final coreBytes = await downloadBundle(coreReady);
      totalBytes = coreBytes.bytes.length;

      onProgress(
          const EfficientDownloadProgress(message: 'Seeding core pack…'));
      seed = await seedAndRecord(projectId: projectId, result: coreBytes);
      seed ??= const SeedResult(
        forms: 0,
        layers: 0,
        choiceLists: 0,
        assignments: 0,
        referenceFeatures: 0,
      );
      // Core reseed wipes refs — clear stored layer hashes.
      await _saveLayerHashes(projectId, {});
      localLayerHashes.clear();
    }

    final seeder = _seeder;
    if (seeder == null || !downloadReferencePacks) {
      if (!downloadReferencePacks) {
        onProgress(const EfficientDownloadProgress(
          message: 'Core ready — map layers will download when you open the map',
        ));
      }
      return (
        ready: coreReady,
        seedResult: seed,
        downloadedBytes: totalBytes,
      );
    }

    final layerIds = await seeder.workingSetLayerIds(projectId);
    debugPrint('[BUNDLE] working set layers=${layerIds.length}');
    final updatedLayerHashes = Map<String, String>.from(localLayerHashes);

    for (var i = 0; i < layerIds.length; i++) {
      final layerId = layerIds[i];
      final index = i + 1;
      final remoteHash = manifest?.layerHashes[layerId];
      final localHash = localLayerHashes[layerId];
      if (remoteHash != null &&
          remoteHash.isNotEmpty &&
          localHash == remoteHash) {
        if (await _layerReferencePresent(projectId, layerId)) {
          debugPrint('[BUNDLE] layer $layerId unchanged — skipping');
          onProgress(EfficientDownloadProgress(
            message: 'Map data up to date ($index/${layerIds.length})…',
            layerIndex: index,
            layerTotal: layerIds.length,
          ));
          continue;
        }
        debugPrint(
          '[BUNDLE] layer $layerId hash match but no local tiles/geojson '
          '— re-downloading',
        );
      }

      try {
        final merged = await ensureLayerReferencePack(
          projectId: projectId,
          layerId: layerId,
          repo: repo,
          remoteHash: remoteHash,
          onProgress: (msg) => onProgress(EfficientDownloadProgress(
            message: '$msg ($index/${layerIds.length})…',
            layerIndex: index,
            layerTotal: layerIds.length,
          )),
        );
        totalBytes += merged.downloadedBytes;
        seed = seed!.mergeRefs(
          referenceFeatures: merged.referenceFeatures,
          referenceTiles: merged.referenceTiles,
          warnings: merged.warnings,
        );
        final hash = merged.contentHash ?? remoteHash;
        if (hash != null &&
            hash.isNotEmpty &&
            merged.referenceTiles > 0) {
          updatedLayerHashes[layerId] = hash;
        } else if (hash != null && hash.isNotEmpty) {
          updatedLayerHashes.remove(layerId);
        }
      } catch (e) {
        debugPrint('[BUNDLE] layer pack failed layer=$layerId: $e');
        seed = seed!.mergeRefs(
          referenceFeatures: 0,
          referenceTiles: 0,
          warnings: ['Layer $layerId reference pack failed: $e'],
        );
      }
      // Yield between layers so GC can reclaim zip/geojson peak RAM.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    await _saveLayerHashes(projectId, updatedLayerHashes);

    return (
      ready: coreReady,
      seedResult: seed,
      downloadedBytes: totalBytes,
    );
  }

  /// Download + merge one layer's reference pack (tiles-first). Idempotent when
  /// [remoteHash] matches the locally stored hash.
  Future<
      ({
        int referenceFeatures,
        int referenceTiles,
        List<String> warnings,
        int downloadedBytes,
        String? contentHash,
      })> ensureLayerReferencePack({
    required String projectId,
    required String layerId,
    required BundleRepository repo,
    String? remoteHash,
    void Function(String message)? onProgress,
  }) async {
    final seeder = _seeder;
    if (seeder == null) {
      throw StateError('Bundle seeder unavailable');
    }

    final localHashes = await _loadLayerHashes(projectId);
    await _invalidateStaleLayerPackClientVersion(projectId, localHashes);
    final localHash = localHashes[layerId];
    if (remoteHash != null &&
        remoteHash.isNotEmpty &&
        localHash == remoteHash) {
      if (await _layerReferencePresent(projectId, layerId)) {
        onProgress?.call('Map data up to date');
        return (
          referenceFeatures: 0,
          referenceTiles: 0,
          warnings: const <String>[],
          downloadedBytes: 0,
          contentHash: localHash,
        );
      }
      debugPrint(
        '[BUNDLE] layer $layerId hash match but missing local map data '
        '— re-downloading',
      );
    }

    onProgress?.call('Requesting map data');
    final layerReady = await _awaitReady(
      request: () => repo.requestLayerRef(
        projectId: projectId,
        layerId: layerId,
      ),
      poll: (jobId) => repo.pollLayerRefJob(
        projectId: projectId,
        layerId: layerId,
        jobId: jobId,
      ),
      onProgress: (p) {
        final step = p?.step;
        final msg = step == 'tiling'
            ? 'Building map tiles'
            : step == 'querying_features'
                ? 'Loading features'
                : 'Building map data';
        onProgress?.call(msg);
      },
      timeout: const Duration(minutes: 45),
    );

    onProgress?.call('Downloading map data');
    final layerBytes = await downloadBundle(layerReady);

    onProgress?.call('Merging map data');
    final merged = await seeder.mergeReferencePack(
      projectId: projectId,
      layerId: layerId,
      zipBytes: layerBytes.bytes,
    );

    final hash = layerBytes.contentHash ?? remoteHash;
    if (hash != null &&
        hash.isNotEmpty &&
        merged.referenceTiles > 0) {
      localHashes[layerId] = hash;
      await _saveLayerHashes(projectId, localHashes);
    } else if (hash != null && hash.isNotEmpty && merged.referenceTiles == 0) {
      debugPrint(
        '[BUNDLE] layer $layerId pack had no mbtiles — not caching hash '
        '(will retry on next map open)',
      );
      localHashes.remove(layerId);
      await _saveLayerHashes(projectId, localHashes);
    }

    return (
      referenceFeatures: merged.referenceFeatures,
      referenceTiles: merged.referenceTiles,
      warnings: merged.warnings,
      downloadedBytes: layerBytes.bytes.length,
      contentHash: hash,
    );
  }

  Future<bool> _localLayerCatalogMatchesManifest(
    String projectId,
    PacksManifest manifest,
  ) async {
    final seeder = _seeder;
    if (seeder == null) return true;
    final remoteIds = manifest.layerHashes.keys.toSet();
    if (remoteIds.isEmpty) return true;

    final localIds = (await seeder.workingSetLayerIds(projectId)).toSet();
    for (final id in remoteIds) {
      if (!localIds.contains(id)) return false;
    }
    return true;
  }

  Future<bool> _layerReferencePresent(
    String projectId,
    String layerId,
  ) async {
    // Map renders reference geometry from mbtiles only — SQLite rows do not count.
    try {
      final docs = await getApplicationDocumentsDirectory();
      final tileFile = File(
        p.join(docs.path, 'mbtiles', projectId, '$layerId.mbtiles'),
      );
      if (!await tileFile.exists() || await tileFile.length() == 0) {
        return false;
      }
    } catch (_) {
      return false;
    }

    // Offline search needs rows seeded from reference_search/*.ndjson.
    final database = _db;
    if (database != null) {
      final rows = await (database.select(database.referenceFeatures)
            ..where((r) => r.projectId.equals(projectId))
            ..where((r) => r.layerId.equals(layerId))
            ..limit(1))
          .get();
      if (rows.isEmpty) {
        debugPrint(
          '[BUNDLE] layer $layerId has mbtiles but no search index — '
          're-downloading',
        );
        return false;
      }
    }
    return true;
  }

  Future<String?> _localCoreHash(String projectId) async {
    final database = _db;
    if (database == null) return null;
    final row = await (database.select(database.projects)
          ..where((p) => p.id.equals(projectId)))
        .getSingleOrNull();
    final hash = row?.contentHash;
    if (hash == null || hash.isEmpty) return null;
    return hash;
  }

  static String _layerHashKey(String projectId) =>
      'fc_layer_pack_hashes_$projectId';

  static String _layerClientVersionKey(String projectId) =>
      'fc_layer_pack_client_ver_$projectId';

  Future<Map<String, String>> _loadLayerHashes(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_layerHashKey(projectId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLayerHashes(
    String projectId,
    Map<String, String> hashes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layerHashKey(projectId), jsonEncode(hashes));
  }

  /// Clears cached layer hashes when the app’s expected pack shape changes,
  /// so opening the map re-downloads instead of keeping clustered/old mbtiles.
  Future<void> _invalidateStaleLayerPackClientVersion(
    String projectId,
    Map<String, String> localLayerHashes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _layerClientVersionKey(projectId);
    final current = prefs.getString(key);
    if (current == layerPackClientVersion) return;
    debugPrint(
      '[BUNDLE] layer pack client version '
      '${current ?? "(none)"} → $layerPackClientVersion — clearing hashes',
    );
    localLayerHashes.clear();
    await _saveLayerHashes(projectId, {});
    await prefs.setString(key, layerPackClientVersion);
  }

  /// Public entry used by the map screen before ensuring packs.
  Future<void> invalidateStaleLayerPacksIfNeeded(String projectId) async {
    final hashes = await _loadLayerHashes(projectId);
    await _invalidateStaleLayerPackClientVersion(projectId, hashes);
  }

  Future<BundleReady> _awaitReady({
    required Future<BundleRequestOutcome> Function() request,
    required Future<BundleJobView> Function(String jobId) poll,
    required void Function(BundleProgress?) onProgress,
    Duration timeout = const Duration(minutes: 45),
  }) async {
    final outcome = await request();
    if (outcome.ready != null) return outcome.ready!;

    final jobId = outcome.jobId;
    if (jobId == null || jobId.isEmpty) {
      throw Exception('Pack request returned neither ready nor job_id');
    }

    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw Exception(
          'Pack generation timed out after ${timeout.inMinutes} minutes',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      final view = await poll(jobId);
      onProgress(view.progress);
      if (view.status == 'success' && view.ready != null) {
        return view.ready!;
      }
      if (view.status == 'failed') {
        throw Exception(view.error ?? 'Pack generation failed');
      }
    }
  }
}

final bundleDownloaderProvider = Provider<BundleDownloader>((ref) {
  return BundleDownloader(
    ref.watch(appDatabaseProvider),
    ref.watch(bundleSeederProvider),
  );
});
