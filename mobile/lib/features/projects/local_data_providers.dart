import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';

/// Streams forms for a project. Emits an empty list if DB unavailable (web).
final formsForProjectProvider =
    StreamProvider.family<List<Form>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return (db.select(db.forms)
        ..where((f) => f.projectId.equals(projectId))
        ..orderBy([(f) => OrderingTerm.asc(f.name)]))
      .watch();
});

final layersForProjectProvider =
    StreamProvider.family<List<Layer>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return (db.select(db.layers)
        ..where((l) => l.projectId.equals(projectId))
        ..orderBy([(l) => OrderingTerm.asc(l.name)]))
      .watch();
});

final choiceListsForProjectProvider =
    StreamProvider.family<List<ChoiceList>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return (db.select(db.choiceLists)
        ..where((c) => c.projectId.equals(projectId))
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();
});

final assignmentsForProjectProvider =
    StreamProvider.family<List<Assignment>, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(const []);
  return (db.select(db.assignments)
        ..where((a) => a.projectId.equals(projectId))
        ..orderBy([
          (a) => OrderingTerm.asc(a.dueDate),
          (a) => OrderingTerm.asc(a.title),
        ]))
      .watch();
});

final referenceFeatureCountProvider =
    StreamProvider.family<int, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(0);

  // Watch the count of reference features for this project
  final query = db.selectOnly(db.referenceFeatures)
    ..addColumns([db.referenceFeatures.id.count()])
    ..where(db.referenceFeatures.projectId.equals(projectId));

  return query.watchSingle().map(
        (row) => row.read(db.referenceFeatures.id.count()) ?? 0,
      );
});

/// Watches whether a project has been downloaded (has any seeded data).
final projectDownloadedAtProvider =
    StreamProvider.family<DateTime?, String>((ref, projectId) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return Stream.value(null);
  return (db.select(db.projects)..where((p) => p.id.equals(projectId)))
      .watchSingleOrNull()
      .map((row) => row?.downloadedAt);
});