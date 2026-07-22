import 'package:flutter/foundation.dart';

class SyncProgress {
  final int totalFeatures;
  final int processedFeatures;
  final int totalAttachments;
  final int processedAttachments;
  final String? currentStep;

  const SyncProgress({
    this.totalFeatures = 0,
    this.processedFeatures = 0,
    this.totalAttachments = 0,
    this.processedAttachments = 0,
    this.currentStep,
  });

  double get featureRatio =>
      totalFeatures == 0 ? 0.0 : processedFeatures / totalFeatures;
  double get attachmentRatio =>
      totalAttachments == 0 ? 0.0 : processedAttachments / totalAttachments;
}

@immutable
class SyncResult {
  final int featuresSynced;
  final int featuresFailed;
  final int featuresPending;   // skipped due to transient errors
  final int featuresOutsideAoi;
  final int attachmentsUploaded;
  final int attachmentsFailed;
  final List<String> errors;

  const SyncResult({
    this.featuresSynced = 0,
    this.featuresFailed = 0,
    this.featuresPending = 0,
    this.featuresOutsideAoi = 0,
    this.attachmentsUploaded = 0,
    this.attachmentsFailed = 0,
    this.errors = const [],
  });

  bool get hasIssues =>
      featuresFailed > 0 ||
      featuresPending > 0 ||
      attachmentsFailed > 0 ||
      errors.isNotEmpty;

  bool get isFullSuccess => !hasIssues;

  String get summary {
    final parts = <String>[];
    if (featuresSynced > 0) parts.add('$featuresSynced synced');
    final otherFailed = featuresFailed - featuresOutsideAoi;
    if (featuresOutsideAoi > 0) {
      parts.add(
        '$featuresOutsideAoi outside AOI (not uploaded)',
      );
    }
    if (otherFailed > 0) parts.add('$otherFailed failed');
    if (featuresPending > 0) parts.add('$featuresPending pending retry');
    if (parts.isEmpty) return 'Nothing to sync';
    return parts.join(' · ');
  }
}

@immutable
class SyncState {
  final bool isRunning;
  final SyncProgress? progress;
  final SyncResult? lastResult;
  final DateTime? lastSyncedAt;

  const SyncState({
    this.isRunning = false,
    this.progress,
    this.lastResult,
    this.lastSyncedAt,
  });

  SyncState copyWith({
    bool? isRunning,
    SyncProgress? progress,
    SyncResult? lastResult,
    DateTime? lastSyncedAt,
    bool clearProgress = false,
  }) {
    return SyncState(
      isRunning: isRunning ?? this.isRunning,
      progress: clearProgress ? null : (progress ?? this.progress),
      lastResult: lastResult ?? this.lastResult,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}