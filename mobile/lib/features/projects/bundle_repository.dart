import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_responses.dart';
import '../../core/api/dio_client.dart';

class BundleProgress {
  final String? step;
  final int? percent;
  const BundleProgress({this.step, this.percent});
}

class BundleReady {
  final String filename;
  final String downloadUrl;
  final int sizeBytes;
  final String? contentHash;
  final Map<String, dynamic>? counts;
  final List<String>? warnings;

  const BundleReady({
    required this.filename,
    required this.downloadUrl,
    required this.sizeBytes,
    this.contentHash,
    this.counts,
    this.warnings,
  });

  factory BundleReady.fromJson(Map<String, dynamic> json) {
    return BundleReady(
      filename: json['filename']?.toString() ?? 'bundle.zip',
      downloadUrl: json['download_url']?.toString() ?? '',
      sizeBytes:
          json['size_bytes'] is int ? json['size_bytes'] as int : 0,
      contentHash: json['content_hash']?.toString(),
      counts: json['counts'] as Map<String, dynamic>?,
      warnings: (json['warnings'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}

class PacksManifest {
  final String coreHash;
  final Map<String, String> layerHashes; // layerId -> contentHash

  const PacksManifest({
    required this.coreHash,
    required this.layerHashes,
  });

  factory PacksManifest.fromJson(Map<String, dynamic> json) {
    final layers = <String, String>{};
    final raw = json['layers'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['layer_id']?.toString();
        final hash = item['content_hash']?.toString();
        if (id != null && id.isNotEmpty && hash != null && hash.isNotEmpty) {
          layers[id] = hash;
        }
      }
    }
    return PacksManifest(
      coreHash: json['core_hash']?.toString() ?? '',
      layerHashes: layers,
    );
  }
}

typedef BundleJobView = ({
  BundleReady? ready,
  BundleProgress? progress,
  String status,
  String? error,
});

typedef BundleRequestOutcome = ({BundleReady? ready, String? jobId});

class BundleRepository {
  final Dio _dio;
  BundleRepository(this._dio);

  /// Legacy full (or slim) bundle.
  Future<BundleRequestOutcome> request({
    required String projectId,
    required bool includeReferenceData,
  }) {
    return _requestPack(
      '/api/v1/projects/$projectId/bundle',
      queryParameters: {
        'reference_data': includeReferenceData ? 'true' : 'false',
      },
    );
  }

  Future<BundleJobView> pollJob({
    required String projectId,
    required String jobId,
  }) {
    return _pollPack('/api/v1/projects/$projectId/bundle/jobs/$jobId');
  }

  /// Slim core pack: catalog + forms/assignments, no reference geometry.
  Future<BundleRequestOutcome> requestCore({required String projectId}) {
    return _requestPack('/api/v1/projects/$projectId/core-pack');
  }

  Future<BundleJobView> pollCoreJob({
    required String projectId,
    required String jobId,
  }) {
    return _pollPack('/api/v1/projects/$projectId/core-pack/jobs/$jobId');
  }

  /// Content hashes for incremental download (skip unchanged packs).
  Future<PacksManifest> getPacksManifest({required String projectId}) async {
    final response =
        await _dio.get('/api/v1/projects/$projectId/packs/manifest');
    if (response.statusCode != 200) {
      throw Exception('Manifest request failed (HTTP ${response.statusCode})');
    }
    final data = unwrap<Map<String, dynamic>>(
      response.data,
      (d) => d as Map<String, dynamic>,
    );
    return PacksManifest.fromJson(data);
  }

  /// Per-layer reference GeoJSON (+ optional mbtiles).
  Future<BundleRequestOutcome> requestLayerRef({
    required String projectId,
    required String layerId,
  }) {
    return _requestPack(
      '/api/v1/projects/$projectId/layers/$layerId/reference-pack',
    );
  }

  Future<BundleJobView> pollLayerRefJob({
    required String projectId,
    required String layerId,
    required String jobId,
  }) {
    return _pollPack(
      '/api/v1/projects/$projectId/layers/$layerId/reference-pack/jobs/$jobId',
    );
  }

  Future<BundleRequestOutcome> _requestPack(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParameters);

    if (response.statusCode == 200) {
      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return (ready: BundleReady.fromJson(data), jobId: null);
    } else if (response.statusCode == 202) {
      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return (ready: null, jobId: data['job_id']?.toString());
    } else {
      throw Exception('Pack request failed (HTTP ${response.statusCode})');
    }
  }

  Future<BundleJobView> _pollPack(String path) async {
    final response = await _dio.get(path);
    if (response.statusCode != 200) {
      throw Exception('Poll failed (HTTP ${response.statusCode})');
    }

    final view = unwrap<Map<String, dynamic>>(
      response.data,
      (d) => d as Map<String, dynamic>,
    );

    final status = view['status']?.toString() ?? 'unknown';
    BundleProgress? progress;
    if (view['progress'] is Map) {
      final p = view['progress'] as Map<String, dynamic>;
      progress = BundleProgress(
        step: p['step']?.toString(),
        percent: p['percent'] is int ? p['percent'] as int : null,
      );
    }

    BundleReady? ready;
    if (status == 'success' && view['result'] is Map) {
      ready = BundleReady.fromJson(view['result'] as Map<String, dynamic>);
    }

    return (
      ready: ready,
      progress: progress,
      status: status,
      error: view['error']?.toString(),
    );
  }
}

final bundleRepositoryProvider = Provider<BundleRepository?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return BundleRepository(dio);
});
