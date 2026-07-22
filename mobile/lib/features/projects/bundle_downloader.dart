import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  /// Core pack first, then per-layer reference packs for the working set.
  /// Uses packs/manifest hashes to skip unchanged downloads.
  Future<({BundleReady ready, SeedResult? seedResult, int downloadedBytes})>
      downloadEfficient({
    required Project project,
    required BundleRepository repo,
    required void Function(EfficientDownloadProgress) onProgress,
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
    final localCoreHash = await _localCoreHash(projectId);
    final skipCore = manifest != null &&
        manifest.coreHash.isNotEmpty &&
        localCoreHash != null &&
        localCoreHash == manifest.coreHash;

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
    if (seeder == null) {
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
        debugPrint('[BUNDLE] layer $layerId unchanged — skipping');
        onProgress(EfficientDownloadProgress(
          message: 'Map data up to date ($index/${layerIds.length})…',
          layerIndex: index,
          layerTotal: layerIds.length,
        ));
        continue;
      }

      onProgress(EfficientDownloadProgress(
        message: 'Requesting map data ($index/${layerIds.length})…',
        layerIndex: index,
        layerTotal: layerIds.length,
      ));

      try {
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
          onProgress: (p) => onProgress(EfficientDownloadProgress(
            message: 'Building map data ($index/${layerIds.length})…',
            jobProgress: p,
            layerIndex: index,
            layerTotal: layerIds.length,
          )),
        );

        onProgress(EfficientDownloadProgress(
          message: 'Downloading map data ($index/${layerIds.length})…',
          layerIndex: index,
          layerTotal: layerIds.length,
        ));
        final layerBytes = await downloadBundle(layerReady);
        totalBytes += layerBytes.bytes.length;

        onProgress(EfficientDownloadProgress(
          message: 'Merging map data ($index/${layerIds.length})…',
          layerIndex: index,
          layerTotal: layerIds.length,
        ));
        final merged = await seeder.mergeReferencePack(
          projectId: projectId,
          layerId: layerId,
          zipBytes: layerBytes.bytes,
        );
        seed = seed!.mergeRefs(
          referenceFeatures: merged.referenceFeatures,
          referenceTiles: merged.referenceTiles,
          warnings: merged.warnings,
        );
        final hash = layerBytes.contentHash ?? remoteHash;
        if (hash != null && hash.isNotEmpty) {
          updatedLayerHashes[layerId] = hash;
        }
      } catch (e) {
        debugPrint('[BUNDLE] layer pack failed layer=$layerId: $e');
        seed = seed!.mergeRefs(
          referenceFeatures: 0,
          referenceTiles: 0,
          warnings: ['Layer $layerId reference pack failed: $e'],
        );
      }
    }

    await _saveLayerHashes(projectId, updatedLayerHashes);

    return (
      ready: coreReady,
      seedResult: seed,
      downloadedBytes: totalBytes,
    );
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

  Future<BundleReady> _awaitReady({
    required Future<BundleRequestOutcome> Function() request,
    required Future<BundleJobView> Function(String jobId) poll,
    required void Function(BundleProgress?) onProgress,
  }) async {
    final outcome = await request();
    if (outcome.ready != null) return outcome.ready!;

    final jobId = outcome.jobId;
    if (jobId == null || jobId.isEmpty) {
      throw Exception('Pack request returned neither ready nor job_id');
    }

    while (true) {
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
