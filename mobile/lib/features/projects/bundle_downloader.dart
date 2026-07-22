import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
}

final bundleDownloaderProvider = Provider<BundleDownloader>((ref) {
  return BundleDownloader(
    ref.watch(appDatabaseProvider),
    ref.watch(bundleSeederProvider),
  );
});