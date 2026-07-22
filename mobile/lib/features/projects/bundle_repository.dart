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

class BundleRepository {
  final Dio _dio;
  BundleRepository(this._dio);

  /// Request a bundle. Either returns BundleReady immediately (cache hit)
  /// OR returns a jobId we can poll.
  Future<({BundleReady? ready, String? jobId})> request({
    required String projectId,
    required bool includeReferenceData,
  }) async {
    final response = await _dio.get(
      '/api/v1/projects/$projectId/bundle',
      queryParameters: {'reference_data': includeReferenceData ? 'true' : 'false'},
    );

    if (response.statusCode == 200) {
      // Cache hit
      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return (ready: BundleReady.fromJson(data), jobId: null);
    } else if (response.statusCode == 202) {
      // Queued or running
      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return (ready: null, jobId: data['job_id']?.toString());
    } else {
      throw Exception('Bundle request failed (HTTP ${response.statusCode})');
    }
  }

  Future<({BundleReady? ready, BundleProgress? progress, String status, String? error})>
      pollJob({
    required String projectId,
    required String jobId,
  }) async {
    final response = await _dio.get(
      '/api/v1/projects/$projectId/bundle/jobs/$jobId',
    );
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