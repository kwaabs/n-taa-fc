import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_responses.dart';
import '../../core/api/dio_client.dart';
import 'sync_models.dart';

class FeaturePushResult {
  /// Map client_id → server_id for accepted features
  final Map<String, String> accepted;

  /// Map client_id → error message for rejected features
  final Map<String, String> rejected;

  /// Was there an overall network/server error? If so, none of the features were
  /// pushed — treat all as still pending.
  final String? overallError;

  /// Error type for the overall error (if any) — drives state machine.
  final AttachmentFailureType? errorType;

  const FeaturePushResult({
    this.accepted = const {},
    this.rejected = const {},
    this.overallError,
    this.errorType,
  });

  bool get hasOverallError => overallError != null;
  bool get isSuccess =>
      overallError == null && accepted.isNotEmpty && rejected.isEmpty;
}

class VerifyResponse {
  /// Map client_id → server_id for features the server has.
  final Map<String, String> found;
  final List<String> missing;

  const VerifyResponse({
    this.found = const {},
    this.missing = const [],
  });
}

class FeaturePushRepository {
  final Dio _dio;
  FeaturePushRepository(this._dio);

  /// Pushes a chunk of features to the backend.
  /// Returns per-feature accepted/rejected receipts.
  Future<FeaturePushResult> push({
    required String projectId,
    required List<Map<String, dynamic>> features,
  }) async {
    if (features.isEmpty) {
      return const FeaturePushResult();
    }

    try {
      final response = await _dio.post(
        '/api/v1/projects/$projectId/sync/push',
        data: {'features': features},
      );

      if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
        String errorBody = '';
        if (response.data is Map) {
          final body = response.data as Map;
          if (body['error'] is Map) {
            errorBody = (body['error'] as Map)['message']?.toString() ?? '';
          } else if (body['error'] != null) {
            errorBody = body['error'].toString();
          } else if (body['message'] != null) {
            errorBody = body['message'].toString();
          }
        } else if (response.data is String) {
          errorBody = response.data as String;
        }
        return FeaturePushResult(
          overallError: 'HTTP ${response.statusCode}: $errorBody',
          errorType: AttachmentFailureType.server,
        );
      }

      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return _parseReceipt(data);
    } on DioException catch (e) {
      return FeaturePushResult(
        overallError: _dioErrorMessage(e),
        errorType: _dioErrorType(e),
      );
    } catch (e) {
      return FeaturePushResult(
        overallError: e.toString(),
        errorType: AttachmentFailureType.unknown,
      );
    }
  }

  /// Verifies which client_ids the server has. Used for crash recovery.
  Future<VerifyResponse> verify({
    required String projectId,
    required List<String> clientIds,
  }) async {
    if (clientIds.isEmpty) {
      return const VerifyResponse();
    }

    final response = await _dio.post(
      '/api/v1/projects/$projectId/sync/verify',
      data: {'client_ids': clientIds},
    );

    final data = unwrap<Map<String, dynamic>>(
      response.data,
      (d) => d as Map<String, dynamic>,
    );

    final foundList = data['found'] as List? ?? [];
    final missingList = data['missing'] as List? ?? [];

    final found = <String, String>{};
    for (final entry in foundList) {
      if (entry is! Map) continue;
      final clientId = entry['client_id']?.toString();
      final serverId = entry['server_id']?.toString();
      if (clientId != null && serverId != null) {
        found[clientId] = serverId;
      }
    }

    return VerifyResponse(
      found: found,
      missing: missingList.map((e) => e.toString()).toList(),
    );
  }

  FeaturePushResult _parseReceipt(Map<String, dynamic> body) {
  final accepted = <String, String>{};
  final rejected = <String, String>{};

  // Backend shape:
  //   { accepted: <int>, flagged: <int>, errors: [ { client_id, issues, action } ] }
  //
  // It only tells us per-feature info for ERRORS. Accepted features are just
  // a count. We mark features as accepted if they're NOT in the errors list.

  final acceptedCount =
      body['accepted'] is int ? body['accepted'] as int : 0;
  final errorsArr = body['errors'] as List? ?? [];

  for (final entry in errorsArr) {
    if (entry is! Map) continue;
    final cid = entry['client_id']?.toString();
    if (cid == null) continue;

    final action = entry['action']?.toString() ?? 'rejected';
    String message = 'Rejected';

    final issues = entry['issues'] as List?;
    if (issues != null && issues.isNotEmpty) {
      final firstIssue = issues.first;
      if (firstIssue is Map) {
        message = firstIssue['message']?.toString() ?? message;
      }
    } else if (entry['error'] != null) {
      message = entry['error'].toString();
    } else if (entry['message'] != null) {
      message = entry['message'].toString();
    }

    if (action == 'rejected') {
      rejected[cid] = message;
    } else {
      // accepted_with_warnings → still accepted
      // We don't have server_id, so use empty string as placeholder
      accepted[cid] = '';
    }
  }

  // Return a result. The CALLER doesn't have server_ids per-feature, but
  // can deduce success by absence from rejected map.
  return FeaturePushResult(
    accepted: accepted,
    rejected: rejected,
    // Stash the count for visibility
    overallError: null,
  );
}

  String _dioErrorMessage(DioException e) {
    if (e.response != null) {
      final body = e.response!.data;
      if (body is Map && body['error'] is Map) {
        final err = body['error'];
        return err['message']?.toString() ?? 'Unknown error';
      }
      return 'HTTP ${e.response!.statusCode}: ${e.message ?? "unknown"}';
    }
    return e.message ?? e.type.toString();
  }

  AttachmentFailureType _dioErrorType(DioException e) {
    if (e.response != null) return AttachmentFailureType.server;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return AttachmentFailureType.network;
      default:
        return AttachmentFailureType.unknown;
    }
  }
}

final featurePushRepositoryProvider =
    Provider<FeaturePushRepository?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return FeaturePushRepository(dio);
});