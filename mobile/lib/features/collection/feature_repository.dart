import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';

class CollectedFeatureRepository {
  final AppDatabase _db;
  CollectedFeatureRepository(this._db);

  Future<String> saveDraft({
    required String projectId,
    required String formId,
    required int formVersion,
    required Map<String, dynamic> responses,
    String? clientId,
    String? layerId,
    Map<String, dynamic>? geometry,
  }) async {
    final id = clientId ?? _newClientId();
    final now = DateTime.now();

    final existing =
        clientId != null ? await _db.getCollectedFeature(clientId) : null;

    await _db.upsertCollectedFeature(
      CollectedFeaturesCompanion(
        clientId: Value(id),
        projectId: Value(projectId),
        layerId: Value(layerId),
        formId: Value(formId),
        formVersion: Value(formVersion),
        geometry: Value(geometry != null ? jsonEncode(geometry) : null),
        attributes: Value(jsonEncode(responses)),
        status: const Value('draft'),
        collectedAt:
            existing != null ? Value(existing.collectedAt) : Value(now),
        updatedAt: Value(now),
      ),
    );

    return id;
  }

  /// Marks an existing reference feature as deleted by creating a tombstone
  /// row in CollectedFeatures. Sync will carry this to the backend as a
  /// 'delete' change for reconciliation.
  ///
  /// If a pending edit already exists for the same sourceRef, the edit row
  /// is converted into a tombstone (deletedAt set, status=pending).
  Future<String> markReferenceDeleted({
    required String projectId,
    required String layerId,
    required String formId,
    required int formVersion,
    required String sourceRef,
    String? dataSourceId,
    Map<String, dynamic>? originalAttributes,
    Map<String, dynamic>? originalGeometry,
  }) async {
    final now = DateTime.now();

    // 1. Look for an existing pending edit for this sourceRef in this layer
    final existing = await (_db.select(_db.collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..where((c) => c.layerId.equals(layerId))
          ..where((c) => c.sourceRef.equals(sourceRef))
          ..where((c) => c.deletedAt.isNull()))
        .getSingleOrNull();

    final id = existing?.clientId ?? _newClientId();

    await _db.upsertCollectedFeature(
      CollectedFeaturesCompanion(
        clientId: Value(id),
        projectId: Value(projectId),
        layerId: Value(layerId),
        formId: Value(formId),
        formVersion: Value(formVersion),
        // Preserve original snapshots — needed for backend audit
        geometry: existing != null
            ? Value(existing.geometry)
            : Value(
                originalGeometry != null ? jsonEncode(originalGeometry) : null),
        attributes: existing != null
            ? Value(existing.attributes)
            : Value(jsonEncode(originalAttributes ?? const {})),
        originalAttributes: existing?.originalAttributes != null
            ? Value(existing!.originalAttributes)
            : Value(originalAttributes != null
                ? jsonEncode(originalAttributes)
                : null),
        originalGeometry: existing?.originalGeometry != null
            ? Value(existing!.originalGeometry)
            : Value(
                originalGeometry != null ? jsonEncode(originalGeometry) : null),
        sourceRef: Value(sourceRef),
        dataSourceId: Value(dataSourceId ?? existing?.dataSourceId),
        status: const Value('pending'),
        deletedAt: Value(now), // 🪦 the tombstone marker
        collectedAt:
            existing != null ? Value(existing.collectedAt) : Value(now),
        updatedAt: Value(now),
        lastError: const Value(null),
      ),
    );

    return id;
  }

  /// Updates ONLY the geometry of an existing collected_features row.
  /// Preserves original_geometry snapshot if it was already set.
  /// Returns the clientId of the row that was updated (or created if missing).
  ///
  /// If no row exists yet for [sourceRef], creates a new pending edit row with:
  ///  - sourceRef + dataSourceId carried through
  ///  - originalGeometry snapshot (so reconciliation can compare later)
  ///  - geometry = the new proposed geometry
  ///  - attributes = '{}'
  ///  - status = pending
  /// Updates ONLY the geometry of an existing collected_features row.
  /// Preserves original_geometry snapshot if it was already set.
  /// Returns the clientId of the row that was updated (or created if missing).
  ///
  /// When creating a new row (no prior edit exists), seeds `attributes` with
  /// the reference feature's current attribute values, so admins see complete
  /// data when tapping the moved feature.
  Future<String> updateGeometry({
    required String projectId,
    required String layerId,
    required String formId,
    required int formVersion,
    required String sourceRef,
    String? dataSourceId,
    required Map<String, dynamic> originalGeometry,
    required Map<String, dynamic> newGeometry,
    required Map<String, dynamic> originalAttributes,
  }) async {
    final now = DateTime.now();

    final existing = await (_db.select(_db.collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..where((c) => c.layerId.equals(layerId))
          ..where((c) => c.sourceRef.equals(sourceRef))
          ..where((c) => c.deletedAt.isNull()))
        .getSingleOrNull();

    final id = existing?.clientId ?? _newClientId();

    // Preserve original_geometry — never overwrite the first snapshot
    final preservedOrigGeom =
        existing?.originalGeometry ?? jsonEncode(originalGeometry);

    // Preserve original_attributes — never overwrite the first snapshot
    final preservedOrigAttrs =
        existing?.originalAttributes ?? jsonEncode(originalAttributes);

    // For attributes: preserve whatever's there OR seed with reference attrs
    final attrsToWrite =
        existing != null ? existing.attributes : jsonEncode(originalAttributes);

    await _db.upsertCollectedFeature(
      CollectedFeaturesCompanion(
        clientId: Value(id),
        projectId: Value(projectId),
        layerId: Value(layerId),
        formId: Value(formId),
        formVersion: Value(formVersion),

        // Geometry: the proposed new location
        geometry: Value(jsonEncode(newGeometry)),

        // Attributes: existing if any, else seeded from reference
        attributes: Value(attrsToWrite),

        status: const Value('pending'),
        collectedAt:
            existing != null ? Value(existing.collectedAt) : Value(now),
        updatedAt: Value(now),
        lastError: const Value(null),

        // Source linkage
        sourceRef: Value(sourceRef),
        dataSourceId: Value(dataSourceId ?? existing?.dataSourceId),

        // Original snapshots — always preserved
        originalGeometry: Value(preservedOrigGeom),
        originalAttributes: Value(preservedOrigAttrs),
      ),
    );

    return id;
  }

  Future<String> submit({
    required String projectId,
    required String formId,
    required int formVersion,
    required Map<String, dynamic> responses,
    String? clientId,
    String? layerId,
    Map<String, dynamic>? geometry,

    // ── D0.3: reference-edit linkage ──
    String? sourceRef,
    String? dataSourceId,
    Map<String, dynamic>? originalAttributes,
    Map<String, dynamic>? originalGeometry,
  }) async {
    final id = clientId ?? _newClientId();
    final now = DateTime.now();

    final existing =
        clientId != null ? await _db.getCollectedFeature(clientId) : null;

    // If the row already exists with a sourceRef + originalAttributes,
    // KEEP the originals — we always diff against the first imported version,
    // not against the previous local edit.
    final preservedOriginalAttrs = existing?.originalAttributes ??
        (originalAttributes != null ? jsonEncode(originalAttributes) : null);
    final preservedOriginalGeom = existing?.originalGeometry ??
        (originalGeometry != null ? jsonEncode(originalGeometry) : null);
    final preservedSourceRef = existing?.sourceRef ?? sourceRef;
    final preservedDataSourceId = existing?.dataSourceId ?? dataSourceId;

    await _db.upsertCollectedFeature(
      CollectedFeaturesCompanion(
        clientId: Value(id),
        projectId: Value(projectId),
        layerId: Value(layerId),
        formId: Value(formId),
        formVersion: Value(formVersion),
        geometry: Value(geometry != null ? jsonEncode(geometry) : null),
        attributes: Value(jsonEncode(responses)),
        status: const Value('pending'),
        collectedAt:
            existing != null ? Value(existing.collectedAt) : Value(now),
        updatedAt: Value(now),
        lastError: const Value(null),

        // ── D0.3: source linkage + snapshots ──
        sourceRef: Value(preservedSourceRef),
        dataSourceId: Value(preservedDataSourceId),
        originalAttributes: Value(preservedOriginalAttrs),
        originalGeometry: Value(preservedOriginalGeom),
      ),
    );

    return id;
  }

  Future<Map<String, dynamic>?> loadResponses(String clientId) async {
    final row = await _db.getCollectedFeature(clientId);
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.attributes);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String clientId) async {
    await _db.deleteCollectedFeature(clientId);
  }

  Future<List<CollectedFeature>> getSyncablePending(String projectId) async {
    // Excludes 'needs_attention' — those rows hit the 3-strike retry limit
    // and require explicit user action to retry.
    return (_db.select(_db.collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..where((c) => c.status.isIn(['pending', 'failed']))
          ..orderBy([(c) => OrderingTerm.asc(c.collectedAt)]))
        .get();
  }

  Future<void> markFeatureStatus({
    required String clientId,
    required String status,
    String? serverId,
    String? lastError,
    DateTime? syncedAt,
  }) async {
    final now = DateTime.now();

    // Decide effective status and counters based on the incoming status.
    // - 'synced' → reset attempts (clean slate), record syncedAt
    // - 'pending' or 'failed' → bump attempts; if it now hits the limit (3),
    //   promote to 'needs_attention' so it stops being auto-retried.
    // - 'syncing' → just touch lastSyncAttemptAt; do NOT bump attempts
    //   (attempt is counted by the terminal outcome, not the in-flight state)
    // - anything else → pass through verbatim
    final existing = await findByClientId(clientId);
    final currentAttempts = existing?.syncAttempts ?? 0;

    String effectiveStatus = status;
    int? newAttempts;

    if (status == 'pending' || status == 'failed') {
      newAttempts = currentAttempts + 1;
      if (newAttempts >= 3) {
        effectiveStatus = 'needs_attention';
      }
    } else if (status == 'synced') {
      newAttempts = 0; // reset on success
    }

    await (_db.update(_db.collectedFeatures)
          ..where((c) => c.clientId.equals(clientId)))
        .write(
      CollectedFeaturesCompanion(
        status: Value(effectiveStatus),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        lastError: lastError != null ? Value(lastError) : const Value(null),
        syncedAt: syncedAt != null ? Value(syncedAt) : const Value.absent(),
        syncAttempts:
            newAttempts != null ? Value(newAttempts) : const Value.absent(),
        lastSyncAttemptAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<CollectedFeature?> findByClientId(String clientId) {
    return (_db.select(_db.collectedFeatures)
          ..where((c) => c.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  static final _random = Random.secure();

  static String _newClientId() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + _random.nextInt(4)).toRadixString(16)}${hex(3)}-'
        '${hex(12)}';
  }
}

final collectedFeatureRepoProvider =
    Provider<CollectedFeatureRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return CollectedFeatureRepository(db);
});

final collectedForProjectProvider =
    StreamProvider.family<List<CollectedFeature>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return db.watchCollectedForProject(projectId);
});

final collectedForFormProvider =
    StreamProvider.family<List<CollectedFeature>, String>((ref, formId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return db.watchCollectedForForm(formId);
});

final collectedStatusCountsProvider =
    StreamProvider.family<Map<String, int>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const {});
  return db.watchCollectedForProject(projectId).map((rows) {
    final counts = <String, int>{};
    for (final r in rows) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    return counts;
  });
});
