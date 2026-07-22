import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import '../collection/feature_repository.dart';
import 'attachment_repository.dart';
import 'feature_push_repository.dart';
import 'sync_models.dart';
import 'sync_state.dart';
import 'sync_log_repository.dart';

const int _kPushChunkSize = 50;
const _kDeviceIdPrefKey = 'fc_device_id';
const Duration _kBackoffBase = Duration(milliseconds: 500);
const Duration _kBackoffMax = Duration(seconds: 30);
const int _kAttachmentMaxAttempts = 3;

bool _isOutsideAoiRejection(String reason) {
  final r = reason.toLowerCase();
  return r.contains('outside') &&
      (r.contains('aoi') || r.contains('project boundary'));
}

Future<Map<String, dynamic>> _buildDeviceInfo() async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString(_kDeviceIdPrefKey);
  if (deviceId == null || deviceId.isEmpty) {
    deviceId = const Uuid().v4();
    await prefs.setString(_kDeviceIdPrefKey, deviceId);
  }
  return {
    'device_id': deviceId,
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'locale': Platform.localeName,
  };
}

class SyncService {
  final AppDatabase db;
  final CollectedFeatureRepository featureRepo;
  final AttachmentRepository attachmentRepo;
  final FeaturePushRepository pushRepo;

  final SyncLogRepository syncLogRepo; // 👈 NEW

  SyncService({
    required this.db,
    required this.featureRepo,
    required this.attachmentRepo,
    required this.pushRepo,
    required this.syncLogRepo, // 👈 NEW
  });

  /// Main entry point: syncs all pending features for a project.
  /// Calls [onProgress] periodically (safe to ignore for headless usage).
  Future<SyncResult> syncProject({
    required String projectId,
    void Function(SyncProgress)? onProgress,
  }) async {
    debugPrint('[SYNC] Starting syncProject for $projectId');

    // 📜 Start audit log
    final runId = await syncLogRepo.startRun(projectId: projectId);

    int synced = 0;
    int failed = 0;
    int pending = 0;
    int outsideAoi = 0;
    int attachmentsUploaded = 0;
    int attachmentsFailed = 0;
    final errors = <String>[];

    final features = await featureRepo.getSyncablePending(projectId);
    debugPrint('[SYNC] Found ${features.length} features to sync');

    if (features.isEmpty) {
      await syncLogRepo.completeRun(
        runId: runId,
        status: 'success',
        featuresAttempted: 0,
        featuresSucceeded: 0,
        featuresFailed: 0,
        attachmentsAttempted: 0,
        attachmentsSucceeded: 0,
        attachmentsFailed: 0,
        summary: 'Nothing to sync',
      );
      return const SyncResult();
    }

    onProgress?.call(SyncProgress(
      totalFeatures: features.length,
      currentStep: 'Uploading attachments...',
    ));

    // ── Phase 1: upload all attachments per feature ──
    final readyFeatures = <CollectedFeature>[];
    final attachmentIdsByFeature = <String, List<String>>{};

    int featureIdx = 0;
    for (final feature in features) {
      featureIdx++;
      onProgress?.call(SyncProgress(
        totalFeatures: features.length,
        processedFeatures: featureIdx - 1,
        currentStep: 'Uploading attachments...',
      ));

      await featureRepo.markFeatureStatus(
        clientId: feature.clientId,
        status: 'syncing',
      );

      final attachments = await _attachmentsForFeature(feature);
      final attachmentClientIds = <String>[];
      bool allAttachmentsOk = true;

      for (final att in attachments) {
        attachmentClientIds.add(att.clientId);

        if (att.status == 'confirmed') {
          attachmentsUploaded++;
          continue;
        }

        var ok = false;
        for (var attempt = 1; attempt <= _kAttachmentMaxAttempts; attempt++) {
          if (attempt > 1) {
            final delay = _backoffDelay(attempt - 1);
            debugPrint('[SYNC] attachment retry ${att.clientId} '
                'after ${delay.inMilliseconds}ms (attempt $attempt)');
            await Future<void>.delayed(delay);
          }
          ok = await _uploadAttachment(
            projectId: projectId,
            featureClientId: feature.clientId,
            attachment: att,
          );
          if (ok) break;
          // Only retry network-style pending failures; status already set.
          final refreshed = await db.getAttachment(att.clientId);
          if (refreshed?.status == 'failed') break;
        }

        if (ok) {
          attachmentsUploaded++;
        } else {
          attachmentsFailed++;
          allAttachmentsOk = false;
          await syncLogRepo.logError(
            runId: runId,
            featureClientId: feature.clientId,
            attachmentClientId: att.clientId,
            errorCode: 'attachment_upload_failed',
            errorMessage: 'Upload failed for ${att.clientId}',
          );
        }
      }

      if (!allAttachmentsOk) {
        await featureRepo.markFeatureStatus(
          clientId: feature.clientId,
          status: 'pending',
          lastError: 'One or more attachments failed to upload',
        );
        pending++;
        continue;
      }

      readyFeatures.add(feature);
      attachmentIdsByFeature[feature.clientId] = attachmentClientIds;
    }

    // ── Phase 2: push features in batches of 50 ──
    if (readyFeatures.isNotEmpty) {
      for (int start = 0;
          start < readyFeatures.length;
          start += _kPushChunkSize) {
        final end = (start + _kPushChunkSize < readyFeatures.length)
            ? start + _kPushChunkSize
            : readyFeatures.length;
        final batch = readyFeatures.sublist(start, end);

        // Build the batch payload once
        final payloads = <Map<String, dynamic>>[];
        for (final f in batch) {
          final payload = await _buildFeaturePayload(
            f,
            attachmentIdsByFeature[f.clientId] ?? const [],
          );
          payloads.add(payload);
        }

        var batchDone = false;
        for (var attempt = 1; attempt <= 3 && !batchDone; attempt++) {
          if (attempt > 1) {
            final delay = _backoffDelay(attempt - 1);
            debugPrint('[SYNC] retrying batch after ${delay.inMilliseconds}ms '
                '(attempt $attempt/3)');
            onProgress?.call(SyncProgress(
              totalFeatures: features.length,
              processedFeatures: features.length - pending,
              currentStep:
                  'Retrying push in ${delay.inSeconds}s (attempt $attempt/3)…',
            ));
            await Future<void>.delayed(delay);
          }

          onProgress?.call(SyncProgress(
            totalFeatures: features.length,
            processedFeatures: features.length - pending,
            currentStep: 'Pushing batch ${(start ~/ _kPushChunkSize) + 1}'
                ' of ${(readyFeatures.length / _kPushChunkSize).ceil()}'
                ' (${batch.length} features)...',
          ));

          final result = await pushRepo.push(
            projectId: projectId,
            features: payloads,
          );

          if (result.hasOverallError) {
            debugPrint('[SYNC]   batch errored: ${result.overallError}');
            final isRetryable =
                result.errorType == AttachmentFailureType.network ||
                    result.errorType == AttachmentFailureType.server;
            if (isRetryable && attempt < 3) {
              continue;
            }

            final newStatus = isRetryable ? 'pending' : 'failed';
            for (final f in batch) {
              await featureRepo.markFeatureStatus(
                clientId: f.clientId,
                status: newStatus,
                lastError: result.overallError,
              );
              if (isRetryable) {
                pending++;
              } else {
                failed++;
              }
              errors
                  .add('${f.clientId.substring(0, 8)}: ${result.overallError}');

              await syncLogRepo.logError(
                runId: runId,
                featureClientId: f.clientId,
                errorCode: isRetryable ? 'batch_retryable' : 'batch_failed',
                errorMessage: result.overallError,
              );
            }
            batchDone = true;
            continue;
          }

          // Per-feature result handling
          for (final f in batch) {
            if (result.rejected.containsKey(f.clientId)) {
              final reason = result.rejected[f.clientId]!;
              await featureRepo.markFeatureStatus(
                clientId: f.clientId,
                status: 'failed',
                lastError: reason,
              );
              failed++;
              if (_isOutsideAoiRejection(reason)) {
                outsideAoi++;
              }
              errors.add('${f.clientId.substring(0, 8)}: $reason');

              await syncLogRepo.logError(
                runId: runId,
                featureClientId: f.clientId,
                errorCode: _isOutsideAoiRejection(reason)
                    ? 'outside_aoi'
                    : 'rejected',
                errorMessage: reason,
              );
            } else {
              await featureRepo.markFeatureStatus(
                clientId: f.clientId,
                status: 'synced',
                syncedAt: DateTime.now(),
              );
              synced++;
            }
          }
          batchDone = true;
        }
      }
    }

    onProgress?.call(SyncProgress(
      totalFeatures: features.length,
      processedFeatures: features.length,
      currentStep: 'Done',
    ));

    final summary = SyncResult(
      featuresSynced: synced,
      featuresFailed: failed,
      featuresPending: pending,
      featuresOutsideAoi: outsideAoi,
      attachmentsUploaded: attachmentsUploaded,
      attachmentsFailed: attachmentsFailed,
      errors: errors,
    );

    // 📜 Close audit log
    final overallStatus = failed == 0 && pending == 0
        ? 'success'
        : (synced > 0 ? 'partial' : 'failed');

    await syncLogRepo.completeRun(
      runId: runId,
      status: overallStatus,
      featuresAttempted: features.length,
      featuresSucceeded: synced,
      featuresFailed: failed + pending,
      attachmentsAttempted: attachmentsUploaded + attachmentsFailed,
      attachmentsSucceeded: attachmentsUploaded,
      attachmentsFailed: attachmentsFailed,
      summary: summary.summary,
    );

// 🔍 Auto-verify — best-effort crash-recovery pass.
    // Catches anything stuck in 'pending'/'syncing' that actually exists on
    // the server (e.g., response lost mid-flight).
    try {
      final recovered = await recoverProject(projectId: projectId);
      if (recovered.featuresSynced > 0) {
        debugPrint('[SYNC] Auto-verify recovered '
            '${recovered.featuresSynced} extra features');
      }
    } catch (e) {
      debugPrint('[SYNC] Auto-verify failed (non-fatal): $e');
    }

    debugPrint('[SYNC] Complete: ${summary.summary}');
    return summary;
  }

  /// Recovery / verification pass.
  ///
  /// Checks local features that are still `pending` or `syncing` and asks
  /// the backend whether they actually already exist on the server.
  ///
  /// This covers:
  /// - app killed mid-sync
  /// - server accepted but local state not updated
  /// - lost response after successful push
  Future<SyncResult> recoverProject({
    required String projectId,
  }) async {
    debugPrint('[RECOVER] Starting recovery for $projectId');

    // We verify local entries that are not yet confirmed locally.
    final candidates = await (db.select(db.collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..where((c) => c.status.isIn(['pending', 'syncing'])))
        .get();

    if (candidates.isEmpty) {
      debugPrint('[RECOVER] No candidates found');
      return const SyncResult();
    }

    debugPrint('[RECOVER] Found ${candidates.length} pending/syncing entries');

    int recovered = 0;
    int resetToPending = 0;
    final errors = <String>[];

    // Verify endpoint supports batches. Keep chunk size comfortably small.
    const int chunkSize = 100;

    for (int i = 0; i < candidates.length; i += chunkSize) {
      final chunk = candidates.skip(i).take(chunkSize).toList();
      final clientIds = chunk.map((f) => f.clientId).toList();

      try {
        final verify = await pushRepo.verify(
          projectId: projectId,
          clientIds: clientIds,
        );

        // Any local feature found on server becomes synced.
        for (final feature in chunk) {
          if (verify.found.containsKey(feature.clientId)) {
            final serverId = verify.found[feature.clientId]!;
            await featureRepo.markFeatureStatus(
              clientId: feature.clientId,
              status: 'synced',
              serverId: serverId,
              syncedAt: DateTime.now(),
            );
            recovered++;
            debugPrint(
              '[RECOVER] ${feature.clientId.substring(0, 8)} -> synced '
              '(server_id=$serverId)',
            );
            continue;
          }

          // Missing from server. If it was in-flight (`syncing`), roll back to pending
          // so user can retry safely.
          if (feature.status == 'syncing') {
            await featureRepo.markFeatureStatus(
              clientId: feature.clientId,
              status: 'pending',
              lastError: 'Recovered from interrupted sync; ready to retry',
            );
            resetToPending++;
            debugPrint(
              '[RECOVER] ${feature.clientId.substring(0, 8)} -> pending',
            );
          }
        }
      } catch (e) {
        debugPrint('[RECOVER] verify failed: $e');
        errors.add(e.toString());
        // Critical: do NOT mutate data on verify failure.
        // Safer to leave rows untouched than falsely mark anything.
      }
    }

    return SyncResult(
      featuresSynced: recovered,
      featuresPending: resetToPending,
      errors: errors,
    );
  }

  // ── Helpers ────────────────────────────────────────

  Future<List<FeatureAttachment>> _attachmentsForFeature(
      CollectedFeature feature) async {
    // Two ways to find attachments:
    // 1. Via feature_client_id column (newer attachments)
    // 2. By scanning the feature's attributes for "att:<id>" markers

    final markers = _extractAttachmentMarkers(feature.attributes);

    // First, link any attachments by their feature_client_id (best case)
    final linkedAttachments =
        await db.getAttachmentsForFeature(feature.clientId);
    final linkedIds = linkedAttachments.map((a) => a.clientId).toSet();

    // Then look up markers we haven't already linked
    final extraAttachments = <FeatureAttachment>[];
    for (final markerId in markers) {
      if (linkedIds.contains(markerId)) continue;
      final att = await db.getAttachment(markerId);
      if (att != null) {
        extraAttachments.add(att);
        // While we're at it — link them to this feature for next time
        await db.upsertAttachment(
          FeatureAttachmentsCompanion(
            clientId: Value(att.clientId),
            featureClientId: Value(feature.clientId),
            projectId: Value(att.projectId),
            fieldId: Value(att.fieldId),
            kind: Value(att.kind),
            localPath: Value(att.localPath),
            mimeType: att.mimeType != null
                ? Value(att.mimeType)
                : const Value.absent(),
            sizeBytes: att.sizeBytes != null
                ? Value(att.sizeBytes)
                : const Value.absent(),
            status: Value(att.status),
          ),
        );
      }
    }

    return [...linkedAttachments, ...extraAttachments];
  }

  /// Scans feature attributes JSON for strings like "att:<uuid>"
  /// and returns the list of attachment client IDs.
  Set<String> _extractAttachmentMarkers(String attributesJson) {
    final ids = <String>{};
    try {
      final decoded = jsonDecode(attributesJson);
      if (decoded is Map) {
        for (final value in decoded.values) {
          if (value is String && value.startsWith('att:')) {
            // Handle both single "att:<id>" and multi "att:<id1>,<id2>,..." formats
            final rawIds = value.substring(4).split(',');
            for (final id in rawIds) {
              final trimmed = id.trim();
              if (trimmed.isNotEmpty) {
                ids.add(trimmed);
              }
            }
          }
        }
      }
    } catch (_) {}
    return ids;
  }

  /// Returns true on success.
  Future<bool> _uploadAttachment({
    required String projectId,
    required String featureClientId,
    required FeatureAttachment attachment,
  }) async {
    final file = File(attachment.localPath);
    if (!await file.exists()) {
      debugPrint('[SYNC]   ✗ ${attachment.clientId} — local file missing');
      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'failed',
        lastError: 'Local file missing',
      );
      return false;
    }

    final sizeBytes = await file.length();
    final mimeType = attachment.mimeType ?? 'image/jpeg';

    try {
      // Step 1: Create / register
      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'uploading',
      );

      final created = await attachmentRepo.create(
        projectId: projectId,
        clientId: attachment.clientId,
        fieldId: attachment.fieldId,
        kind: attachment.kind,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        featureClientId: featureClientId,
      );

      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'uploading',
        serverId: created.attachmentId,
        uploadUrl: created.uploadUrl,
      );
      await db.incrementAttachmentAttempts(attachment.clientId);

      // Step 2: Upload bytes
      await attachmentRepo.uploadBytes(
        uploadUrl: created.uploadUrl,
        file: file,
        mimeType: mimeType,
      );

      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'uploaded',
      );

      // Step 3: Confirm
      await attachmentRepo.confirm(attachmentId: created.attachmentId);

      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'confirmed',
      );

      debugPrint('[SYNC]   ✓ ${attachment.clientId} uploaded + confirmed');
      return true;
    } on AttachmentException catch (e) {
      debugPrint('[SYNC]   ✗ ${attachment.clientId} — ${e.type}: ${e.message}');
      // Network errors → pending (retry)
      // Server/local errors → failed (user attention)
      final isRetryable = e.type == AttachmentFailureType.network;
      final newStatus = isRetryable ? 'pending' : 'failed';
      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: newStatus,
        lastError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[SYNC]   ✗ ${attachment.clientId} — $e');
      await db.updateAttachmentStatus(
        clientId: attachment.clientId,
        status: 'pending',
        lastError: e.toString(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> _buildFeaturePayload(
    CollectedFeature feature,
    List<String> attachmentClientIds,
  ) async {
    // 🔍 D1.2 DEBUG — verify the feature object carries our reference fields
    debugPrint('[D1.2 DEBUG] feature: '
        'clientId=${feature.clientId} '
        'sourceRef=${feature.sourceRef} '
        'dataSourceId=${feature.dataSourceId} '
        'originalAttributesLen=${feature.originalAttributes?.length} '
        'deletedAt=${feature.deletedAt}');

    Map<String, dynamic> attributes = {};

    try {
      final decoded = jsonDecode(feature.attributes);
      if (decoded is Map) {
        attributes = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    Map<String, dynamic>? geometry;
    if (feature.geometry != null && feature.geometry!.isNotEmpty) {
      try {
        final decoded = jsonDecode(feature.geometry!);
        if (decoded is Map) {
          geometry = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    // 🪦 Determine status for backend
    //  - 'deleted'   → tombstone (D0.4)
    //  - 'submitted' → new capture or edit (D0.3)
    final isTombstone = feature.deletedAt != null;
    final status = isTombstone ? 'deleted' : 'submitted';

    final payload = <String, dynamic>{
      'client_id': feature.clientId,
      'form_id': feature.formId,
      'form_version': feature.formVersion,
      'attributes': attributes,
      'collected_at': feature.collectedAt.toUtc().toIso8601String(),
      'status': status,
      'device_info': await _buildDeviceInfo(),
    };

    if (feature.layerId != null && feature.layerId!.isNotEmpty) {
      payload['layer_id'] = feature.layerId;
    }
    if (geometry != null) {
      payload['geometry'] = geometry;
    }
    if (attachmentClientIds.isNotEmpty) {
      payload['attachment_client_ids'] = attachmentClientIds;
    }

    // ── D0.5: reference-edit linkage + tombstone marker ──
    if (feature.sourceRef != null && feature.sourceRef!.isNotEmpty) {
      payload['source_ref'] = feature.sourceRef;
    }
    if (feature.dataSourceId != null && feature.dataSourceId!.isNotEmpty) {
      payload['data_source_id'] = feature.dataSourceId;
    }
    if (feature.originalAttributes != null &&
        feature.originalAttributes!.isNotEmpty) {
      try {
        final decoded = jsonDecode(feature.originalAttributes!);
        if (decoded is Map) {
          payload['original_attributes'] = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (feature.originalGeometry != null &&
        feature.originalGeometry!.isNotEmpty) {
      try {
        final decoded = jsonDecode(feature.originalGeometry!);
        if (decoded is Map) {
          payload['original_geometry'] = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (isTombstone) {
      payload['deleted'] = true;
      payload['deleted_at'] = feature.deletedAt!.toUtc().toIso8601String();
    }

    debugPrint('[SYNC] payload: ${jsonEncode(payload)}');
    debugPrint('[SYNC] payload keys: ${payload.keys.toList()}');
    debugPrint('[SYNC] payload source_ref: ${payload['source_ref']}');
    debugPrint('[SYNC] payload data_source_id: ${payload['data_source_id']}');
    debugPrint(
        '[SYNC] payload original_attributes present: ${payload.containsKey('original_attributes')}');
    debugPrint('[SYNC] payload deleted: ${payload['deleted']}');
    return payload;
  }

  // ── Public utility: count of pending features ────────

  Future<int> countPending(String projectId) async {
    final result = await (db.select(db.collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..where((c) => c.status.isIn(['pending', 'failed', 'syncing'])))
        .get();
    return result.length;
  }
}

Duration _backoffDelay(int failureCount) {
  if (failureCount <= 0) return _kBackoffBase;
  var ms = _kBackoffBase.inMilliseconds * (1 << (failureCount - 1));
  if (ms > _kBackoffMax.inMilliseconds) {
    ms = _kBackoffMax.inMilliseconds;
  }
  return Duration(milliseconds: ms);
}

// ── Provider ─────────────────────────────────────

final syncServiceProvider = Provider<SyncService?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final featureRepo = ref.watch(collectedFeatureRepoProvider);
  final attachmentRepo = ref.watch(attachmentRepositoryProvider);
  final pushRepo = ref.watch(featurePushRepositoryProvider);
  final syncLogRepo = ref.watch(syncLogRepositoryProvider); // 👈 NEW

  if (db == null ||
      featureRepo == null ||
      attachmentRepo == null ||
      pushRepo == null ||
      syncLogRepo == null) {
    // 👈 NEW
    return null;
  }

  return SyncService(
    db: db,
    featureRepo: featureRepo,
    attachmentRepo: attachmentRepo,
    pushRepo: pushRepo,
    syncLogRepo: syncLogRepo, // 👈 NEW
  );
});
