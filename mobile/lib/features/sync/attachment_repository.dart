import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/api/dio_client.dart';
import '../../core/api/api_responses.dart';
import 'sync_models.dart';

class AttachmentRepository {
  final Dio _dio;
  AttachmentRepository(this._dio);

  /// Step 1: Register the attachment with the backend.
  /// Returns the attachment_id and a pre-signed upload URL valid for ~1 hour.
  Future<AttachmentCreateResult> create({
    required String projectId,
    required String clientId,
    required String fieldId,
    required String kind, // 'photo' | 'audio' | etc.
    required String mimeType,
    required int sizeBytes,
    String? featureClientId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/projects/$projectId/attachments',
        data: {
          'client_id': clientId,
          'field_id': fieldId,
          'kind': kind,
          'mime_type': mimeType,
          'size_bytes': sizeBytes,
          if (featureClientId != null) 'feature_client_id': featureClientId,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AttachmentException(
          'Create failed: HTTP ${response.statusCode}',
          type: AttachmentFailureType.server,
          statusCode: response.statusCode,
        );
      }

      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return AttachmentCreateResult.fromJson(data);
    } on DioException catch (e) {
      throw AttachmentException(
        _dioErrorMessage(e),
        type: _dioErrorType(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Step 2: PUT the file bytes to RustFS via the pre-signed URL.
  /// Uses the `http` package directly (not Dio) to avoid auth headers being
  /// added to the pre-signed URL (RustFS signs the URL itself).
  Future<void> uploadBytes({
    required String uploadUrl,
    required File file,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw AttachmentException(
        'Local file not found: ${file.path}',
        type: AttachmentFailureType.local,
      );
    }

    final bytes = await file.readAsBytes();

    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': mimeType,
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AttachmentException(
          'Upload to RustFS failed: HTTP ${response.statusCode} '
          '${response.body.isNotEmpty ? response.body.substring(0, response.body.length.clamp(0, 200)) : ''}',
          type: AttachmentFailureType.server,
          statusCode: response.statusCode,
        );
      }
      if (kDebugMode) {
        debugPrint('[ATTACHMENT] uploaded ${bytes.length} bytes successfully');
      }
    } on SocketException catch (e) {
      throw AttachmentException(
        'Network error: ${e.message}',
        type: AttachmentFailureType.network,
      );
    } on http.ClientException catch (e) {
      throw AttachmentException(
        'HTTP error: ${e.message}',
        type: AttachmentFailureType.network,
      );
    }
  }

  /// Step 3: Confirm with the backend that the upload finished.
  /// Backend validates the object exists in RustFS and marks status=uploaded.
  Future<AttachmentConfirmResult> confirm({
    required String attachmentId,
  }) async {
    try {
      final response = await _dio.post('/api/v1/attachments/$attachmentId/confirm');

      if (response.statusCode != 200) {
        throw AttachmentException(
          'Confirm failed: HTTP ${response.statusCode}',
          type: AttachmentFailureType.server,
          statusCode: response.statusCode,
        );
      }
      final data = unwrap<Map<String, dynamic>>(
        response.data,
        (d) => d as Map<String, dynamic>,
      );
      return AttachmentConfirmResult.fromJson(data);
    } on DioException catch (e) {
      throw AttachmentException(
        _dioErrorMessage(e),
        type: _dioErrorType(e),
        statusCode: e.response?.statusCode,
      );
    }
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

final attachmentRepositoryProvider =
    Provider<AttachmentRepository?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return AttachmentRepository(dio);
});