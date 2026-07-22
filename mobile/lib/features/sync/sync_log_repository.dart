import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';

class SyncLogRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  SyncLogRepository(this.db);

  /// Insert a new sync_runs row and return its id.
  Future<String> startRun({
    required String projectId,
    String trigger = 'manual',
  }) async {
    final id = _uuid.v4();
    await db.into(db.syncRuns).insert(
          SyncRunsCompanion.insert(
            id: id,
            trigger: trigger,
            projectId: Value(projectId),
            startedAt: Value(DateTime.now()),
            status: const Value('running'),
          ),
        );
    return id;
  }

  /// Update the run with final stats.
  Future<void> completeRun({
    required String runId,
    required String status, // success | partial | failed
    required int featuresAttempted,
    required int featuresSucceeded,
    required int featuresFailed,
    required int attachmentsAttempted,
    required int attachmentsSucceeded,
    required int attachmentsFailed,
    String? summary,
  }) async {
    await (db.update(db.syncRuns)..where((r) => r.id.equals(runId))).write(
      SyncRunsCompanion(
        endedAt: Value(DateTime.now()),
        status: Value(status),
        featuresAttempted: Value(featuresAttempted),
        featuresSucceeded: Value(featuresSucceeded),
        featuresFailed: Value(featuresFailed),
        attachmentsAttempted: Value(attachmentsAttempted),
        attachmentsSucceeded: Value(attachmentsSucceeded),
        attachmentsFailed: Value(attachmentsFailed),
        summary: summary != null ? Value(summary) : const Value.absent(),
      ),
    );

    // Trim policy — keep last 100 runs
    await _trimRuns();
  }

  Future<void> logError({
    required String runId,
    String? featureClientId,
    String? attachmentClientId,
    required String errorCode,
    String? errorMessage,
    int? httpStatus,
  }) async {
    await db.into(db.syncErrors).insert(
          SyncErrorsCompanion.insert(
            id: _uuid.v4(),
            syncRunId: runId,
            featureClientId: featureClientId != null
                ? Value(featureClientId)
                : const Value.absent(),
            attachmentClientId: attachmentClientId != null
                ? Value(attachmentClientId)
                : const Value.absent(),
            errorCode: errorCode,
            errorMessage:
                errorMessage != null ? Value(errorMessage) : const Value.absent(),
            httpStatus:
                httpStatus != null ? Value(httpStatus) : const Value.absent(),
          ),
        );

    await _trimErrors();
  }

  Future<void> _trimRuns() async {
    // Keep last 100 rows by startedAt DESC
    final keep = await (db.select(db.syncRuns)
          ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
          ..limit(100))
        .get();
    if (keep.isEmpty) return;
    final cutoff = keep.last.startedAt;
    await (db.delete(db.syncRuns)
          ..where((r) => r.startedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> _trimErrors() async {
    final keep = await (db.select(db.syncErrors)
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
          ..limit(100))
        .get();
    if (keep.isEmpty) return;
    final cutoff = keep.last.occurredAt;
    await (db.delete(db.syncErrors)
          ..where((e) => e.occurredAt.isSmallerThanValue(cutoff)))
        .go();
  }
}

final syncLogRepositoryProvider = Provider<SyncLogRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return SyncLogRepository(db);
});