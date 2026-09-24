import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';

part 'app_database.g.dart';

// ── Tables ──────────────────────────────────────────────

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get mode => text()();
  TextColumn get status => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get contentHash => text().nullable()();
  TextColumn get bundleFilename => text().nullable()();
  IntColumn get bundleSizeBytes => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  /// GeoJSON geometry string for the project Area of Interest (Polygon).
  TextColumn get areaOfInterest => text().nullable()();

  /// Layer id used to build AOI (from project.config.aoi_layer_id). Field edits locked.
  TextColumn get aoiLayerId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Forms extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get schema => text()();
  DateTimeColumn get downloadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Layers extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get geometryType => text()();
  TextColumn get formId => text().nullable()();
  TextColumn get style => text().nullable()();

  /// If this layer was imported from an external data source, this is its id.
  /// Used by D-phase to know where edits / deletes should be pushed back to.
  TextColumn get dataSourceId => text().nullable()();

  /// Mirrors server `layers.is_editable`. AOI source layers are false.
  BoolColumn get isEditable =>
      boolean().withDefault(const Constant(true))();

  /// Linked-table source_config JSON — used for offline search attribute discovery.
  TextColumn get sourceConfig => text().nullable()();

  DateTimeColumn get downloadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChoiceLists extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get choices => text()();
  DateTimeColumn get downloadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Assignments extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  /// Optional layer this assignment targets — drives reference-pack working set.
  TextColumn get layerId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get priority => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get targetCount => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get area => text().nullable()();
  DateTimeColumn get downloadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ReferenceFeatures extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get layerId => text()();
  TextColumn get geometry => text()();
  TextColumn get attributes => text()();
  TextColumn get sourceRef => text().nullable()();

  /// Identifier of the external data source this row was imported from.
  /// Mirrors `layers.dataSourceId` — denormalized for easy access during edits.
  TextColumn get dataSourceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CollectedFeatures extends Table {
  TextColumn get clientId => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get layerId => text().nullable()();
  TextColumn get formId => text()();
  IntColumn get formVersion => integer().withDefault(const Constant(1))();
  TextColumn get geometry => text().nullable()();
  TextColumn get attributes => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get serverId => text().nullable()();
  DateTimeColumn get collectedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  /// pending | syncing | synced | failed | needs_attention
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastSyncAttemptAt => dateTime().nullable()();

  /// Set when this row represents an edit of a reference feature.
  /// Carries the data source id so reconciliation knows where to push back.
  TextColumn get dataSourceId => text().nullable()();

  /// JSON snapshot of the reference feature's attributes at the time of edit.
  /// Used by the backend to compute change_type and field-level diffs.
  TextColumn get originalAttributes => text().nullable()();

  /// GeoJSON snapshot of the reference feature's geometry at the time of edit.
  TextColumn get originalGeometry => text().nullable()();

  /// Tombstone marker. When set, this row represents a "mark deleted" action
  /// against the source feature identified by sourceRef + dataSourceId.
  /// Mobile rendering filters these out of the map view.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// External row id from the source data source (e.g., utility company's pole
  /// code "POLE-123"). Set when this collected row represents an EDIT of a
  /// reference feature. Carries through Phase B sync so backend can identify
  /// which source row to reconcile against.
  TextColumn get sourceRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

class FeatureAttachments extends Table {
  TextColumn get clientId => text()();
  TextColumn get featureClientId => text()();
  TextColumn get projectId => text()();
  TextColumn get fieldId => text()();
  TextColumn get kind => text().withDefault(const Constant('photo'))();
  TextColumn get localPath => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  /// pending | uploading | uploaded | confirmed | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Server-assigned UUID once /attachments returns it
  TextColumn get serverId => text().nullable()();

  /// Pre-signed PUT URL while we're uploading (transient)
  TextColumn get uploadUrl => text().nullable()();

  IntColumn get uploadAttempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {clientId};
}

class SyncRuns extends Table {
  TextColumn get id => text()(); // UUID v4 generated client-side
  TextColumn get projectId => text().nullable()();
  TextColumn get trigger => text()(); // manual | auto_wifi | retry
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();

  IntColumn get featuresAttempted => integer().withDefault(const Constant(0))();
  IntColumn get featuresSucceeded => integer().withDefault(const Constant(0))();
  IntColumn get featuresFailed => integer().withDefault(const Constant(0))();

  IntColumn get attachmentsAttempted =>
      integer().withDefault(const Constant(0))();
  IntColumn get attachmentsSucceeded =>
      integer().withDefault(const Constant(0))();
  IntColumn get attachmentsFailed => integer().withDefault(const Constant(0))();

  /// success | partial | failed | running
  TextColumn get status => text().withDefault(const Constant('running'))();

  TextColumn get summary => text().nullable()(); // optional human-readable note

  @override
  Set<Column> get primaryKey => {id};
}

class SyncErrors extends Table {
  TextColumn get id => text()();
  TextColumn get syncRunId =>
      text().references(SyncRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get featureClientId => text().nullable()();
  TextColumn get attachmentClientId => text().nullable()();
  TextColumn get errorCode => text()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get httpStatus => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database class ──────────────────────────────────────

@DriftDatabase(tables: [
  Projects,
  Forms,
  Layers,
  ChoiceLists,
  Assignments,
  ReferenceFeatures,
  CollectedFeatures,
  FeatureAttachments,
  SyncRuns, // 👈 NEW
  SyncErrors, // 👈 NEW
])
class AppDatabase extends _$AppDatabase {
  /// Opens the offline DB for [userId] (isolated per account on the device).
  AppDatabase.forUser(String userId) : super(_openConnection(userId));

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v1 → v2: feature attachments
          if (from < 2) {
            await _safeCreateTable(m, featureAttachments);
          }
          // v2 → v3: B1 sync metadata + sync log tables
          if (from < 3) {
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.syncStatus);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.syncAttempts);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.lastSyncAttemptAt);
            await _safeCreateTable(m, syncRuns);
            await _safeCreateTable(m, syncErrors);
          }
          // v3 → v4: D0.1 source linkage, original snapshots, tombstones
          if (from < 4) {
            await _safeAddColumn(m, layers, layers.dataSourceId);
            await _safeAddColumn(
                m, referenceFeatures, referenceFeatures.dataSourceId);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.dataSourceId);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.originalAttributes);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.originalGeometry);
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.deletedAt);
          }
          // v4 → v5: sourceRef on collected_features
          if (from < 5) {
            await _safeAddColumn(
                m, collectedFeatures, collectedFeatures.sourceRef);
          }
          // v5 → v6: project AOI GeoJSON for map boundary display
          if (from < 6) {
            await _safeAddColumn(m, projects, projects.areaOfInterest);
          }
          // v6 → v7: assignment layerId for reference-pack working set
          if (from < 7) {
            await _safeAddColumn(m, assignments, assignments.layerId);
          }
          // v7 → v8: AOI source layer lock (project.aoi_layer_id + layer.is_editable)
          if (from < 8) {
            await _safeAddColumn(m, layers, layers.isEditable);
            await _safeAddColumn(m, projects, projects.aoiLayerId);
          }
          // v8 → v9: layer source_config for offline search attribute discovery
          if (from < 9) {
            await _safeAddColumn(m, layers, layers.sourceConfig);
          }
        },
      );

  /// Idempotent addColumn — tolerates "duplicate column" errors that happen
  /// when schemaVersion drifts out of sync with the actual schema on disk
  /// (e.g., a partial migration on a previous run).
  /// //dd81bf47-ad42-45c7-ac50-c7ce62b4c476
  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    try {
      await m.addColumn(table, column);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate column')) {
        return; // already exists — skip silently
      }
      rethrow;
    }
  }

  /// Idempotent createTable — tolerates "table already exists" errors.
  Future<void> _safeCreateTable(Migrator m, TableInfo table) async {
    try {
      await m.createTable(table);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already exists')) {
        return;
      }
      rethrow;
    }
  }
  // ── Project helpers ───────────────────────────────────

  Future<List<Project>> getAllProjects() => select(projects).get();

  Future<Project?> getProject(String id) {
    return (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  Future<void> upsertProject(ProjectsCompanion data) {
    return into(projects).insertOnConflictUpdate(data);
  }

  Future<void> markProjectDownloaded({
    required String projectId,
    required String contentHash,
    required String filename,
    required int sizeBytes,
  }) async {
    final now = DateTime.now();
    await (update(projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        contentHash: Value(contentHash),
        bundleFilename: Value(filename),
        bundleSizeBytes: Value(sizeBytes),
        downloadedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // ── CollectedFeatures CRUD ────────────────────────────

  Future<CollectedFeature?> getCollectedFeature(String clientId) {
    return (select(collectedFeatures)
          ..where((c) => c.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  Stream<List<CollectedFeature>> watchCollectedForProject(String projectId) {
    return (select(collectedFeatures)
          ..where((c) => c.projectId.equals(projectId))
          ..orderBy([(c) => OrderingTerm.desc(c.collectedAt)]))
        .watch();
  }

  Stream<List<CollectedFeature>> watchCollectedForForm(String formId) {
    return (select(collectedFeatures)
          ..where((c) => c.formId.equals(formId))
          ..orderBy([(c) => OrderingTerm.desc(c.collectedAt)]))
        .watch();
  }

  Future<int> upsertCollectedFeature(CollectedFeaturesCompanion data) {
    return into(collectedFeatures).insertOnConflictUpdate(data);
  }

  Future<int> deleteCollectedFeature(String clientId) {
    return (delete(collectedFeatures)
          ..where((c) => c.clientId.equals(clientId)))
        .go();
  }

  // ── FeatureAttachments CRUD ────────────────────────────

  Future<List<FeatureAttachment>> getAttachmentsForFeature(
      String featureClientId) {
    return (select(featureAttachments)
          ..where((a) => a.featureClientId.equals(featureClientId)))
        .get();
  }

  Stream<List<FeatureAttachment>> watchAttachmentsForFeature(
      String featureClientId) {
    return (select(featureAttachments)
          ..where((a) => a.featureClientId.equals(featureClientId)))
        .watch();
  }

  Future<List<FeatureAttachment>> getPendingAttachmentsForProject(
      String projectId) {
    return (select(featureAttachments)
          ..where((a) =>
              a.projectId.equals(projectId) & a.status.isNotIn(['confirmed'])))
        .get();
  }

  Future<FeatureAttachment?> getAttachment(String clientId) {
    return (select(featureAttachments)
          ..where((a) => a.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  Future<int> upsertAttachment(FeatureAttachmentsCompanion data) {
    return into(featureAttachments).insertOnConflictUpdate(data);
  }

  Future<int> updateAttachmentStatus({
    required String clientId,
    required String status,
    String? serverId,
    String? lastError,
    String? uploadUrl,
  }) {
    final now = DateTime.now();
    return (update(featureAttachments)
          ..where((a) => a.clientId.equals(clientId)))
        .write(
      FeatureAttachmentsCompanion(
        status: Value(status),
        serverId: serverId != null ? Value(serverId) : const Value.absent(),
        lastError: lastError != null ? Value(lastError) : const Value.absent(),
        uploadUrl: uploadUrl != null ? Value(uploadUrl) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> incrementAttachmentAttempts(String clientId) async {
    final existing = await getAttachment(clientId);
    if (existing == null) return 0;
    return (update(featureAttachments)
          ..where((a) => a.clientId.equals(clientId)))
        .write(
      FeatureAttachmentsCompanion(
        uploadAttempts: Value(existing.uploadAttempts + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteAttachment(String clientId) {
    return (delete(featureAttachments)
          ..where((a) => a.clientId.equals(clientId)))
        .go();
  }
}

// ── Connection helpers ─────────────────────────────────

String _safeUserIdForFilename(String userId) {
  return userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

QueryExecutor _openConnection(String userId) {
  if (kIsWeb) {
    throw UnsupportedError('Drift disabled on web');
  }

  open.overrideFor(OperatingSystem.android, _openOnAndroid);

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final safe = _safeUserIdForFilename(userId);
    final userFile =
        File(p.join(dbFolder.path, 'field_collector_$safe.sqlite'));
    return NativeDatabase.createInBackground(userFile);
  });
}

DynamicLibrary _openOnAndroid() {
  try {
    return DynamicLibrary.open('libsqlite3.so');
  } catch (_) {
    for (final path in const [
      '/system/lib64/libsqlite.so',
      '/system/lib/libsqlite.so',
      '/data/data/com.fieldcollector.field_collector/lib/libsqlite3.so',
    ]) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    rethrow;
  }
}
