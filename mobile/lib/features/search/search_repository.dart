import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import '../../core/forms/form_schema.dart';
import 'search_state.dart';

class SearchRepository {
  final AppDatabase _db;

  SearchRepository(this._db);

  /// Discovers attribute keys for the search builder.
  ///
  /// Prefer keys sampled from [referenceFeatures] (populated from layer search
  /// index). When tiles-only packs leave SQLite empty, fall back to layer
  /// source_config column lists and linked form schema field ids.
  Future<List<String>> discoverAttributes({
    required String projectId,
    required String layerId,
    int sampleSize = 500,
  }) async {
    final keys = <String>{};

    final rows = await (_db.select(_db.referenceFeatures)
          ..where((r) => r.projectId.equals(projectId))
          ..where((r) => r.layerId.equals(layerId))
          ..limit(sampleSize))
        .get();

    for (final row in rows) {
      keys.addAll(_keysFromAttributesJson(row.attributes));
    }
    if (keys.isNotEmpty) {
      final sorted = keys.toList()..sort();
      return sorted;
    }

    final layer = await (_db.select(_db.layers)
          ..where((l) => l.id.equals(layerId))
          ..where((l) => l.projectId.equals(projectId)))
        .getSingleOrNull();
    if (layer == null) return const [];

    keys.addAll(_keysFromSourceConfig(layer.sourceConfig));

    if (layer.formId != null && layer.formId!.isNotEmpty) {
      final form = await (_db.select(_db.forms)
            ..where((f) => f.id.equals(layer.formId!)))
          .getSingleOrNull();
      if (form != null) {
        try {
          final schema = FormSchema.fromJson(jsonDecode(form.schema));
          keys.addAll(_keysFromFormSchema(schema));
        } catch (e) {
          debugPrint('[search] form schema parse failed: $e');
        }
      }
    }

    final sorted = keys.toList()..sort();
    return sorted;
  }

  Set<String> _keysFromAttributesJson(String attributesJson) {
    final keys = <String>{};
    try {
      final parsed = jsonDecode(attributesJson);
      if (parsed is Map) {
        for (final key in parsed.keys) {
          if (key is String && !key.startsWith('_')) {
            keys.add(key);
          }
        }
      }
    } catch (_) {}
    return keys;
  }

  Set<String> _keysFromSourceConfig(String? sourceConfigJson) {
    final keys = <String>{};
    if (sourceConfigJson == null || sourceConfigJson.isEmpty) return keys;
    try {
      final cfg = jsonDecode(sourceConfigJson);
      if (cfg is! Map) return keys;
      final idCol = cfg['id_column']?.toString();
      if (idCol != null && idCol.isNotEmpty) keys.add(idCol);
      final included = cfg['included_columns'];
      if (included is List) {
        for (final col in included) {
          final name = col?.toString();
          if (name != null && name.isNotEmpty && !name.startsWith('_')) {
            keys.add(name);
          }
        }
      }
    } catch (_) {}
    return keys;
  }

  Set<String> _keysFromFormSchema(FormSchema schema) {
    final keys = <String>{};
    void walk(FormFieldSpec field) {
      if (field.type == FieldType.group) {
        for (final child in field.children) {
          walk(child);
        }
        return;
      }
      switch (field.type) {
        case FieldType.geoPoint:
        case FieldType.geoTrace:
        case FieldType.geoShape:
        case FieldType.note:
        case FieldType.calculated:
        case FieldType.unknown:
          return;
        default:
          break;
      }
      if (field.id.isNotEmpty && !field.id.startsWith('_')) {
        keys.add(field.id);
      }
    }

    for (final field in schema.fields) {
      walk(field);
    }
    return keys;
  }

  /// Executes a query against reference_features.
  /// Returns matches paginated up to [maxResults].
  Future<List<SearchResult>> runQuery({
    required String projectId,
    required String layerId,
    required List<QueryCondition> conditions,
    bool caseSensitive = false,
    int maxResults = 200,
  }) async {
    // Filter to only valid conditions
    final valid = conditions.where((c) => c.isValid).toList();
    if (valid.isEmpty) return const [];

    // Build the WHERE clauses using SQLite JSON1
    final whereClauses = <String>[
      'project_id = ?',
      'layer_id = ?',
    ];
    final args = <dynamic>[projectId, layerId];

    for (final c in valid) {
      final clause = _buildClause(c, args, caseSensitive: caseSensitive);
      if (clause != null) {
        whereClauses.add(clause);
      }
    }

    final sql = '''
      SELECT id, layer_id, geometry, attributes
      FROM reference_features
      WHERE ${whereClauses.join(' AND ')}
      LIMIT $maxResults
    ''';

    if (kDebugMode) {
      debugPrint('[search] SQL: $sql');
      debugPrint('[search] args: $args');
    }

    try {
      final results = await _db.customSelect(
        sql,
        variables: args.map(_toVar).toList(),
      ).get();

      final searchResults = <SearchResult>[];
      for (final row in results) {
        final data = row.data;
        Map<String, dynamic> attrs = const {};
        try {
          final parsed = jsonDecode(data['attributes'] as String? ?? '{}');
          if (parsed is Map) {
            attrs = Map<String, dynamic>.from(parsed);
          }
        } catch (_) {}

        searchResults.add(
          SearchResult(
            featureId: data['id'] as String,
            layerId: data['layer_id'] as String,
            geometryJson: data['geometry'] as String?,
            attributes: attrs,
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('[search] returned ${searchResults.length} results');
      }

      return searchResults;
    } catch (e, s) {
      debugPrint('[search] query failed: $e\n$s');
      rethrow;
    }
  }

  /// Rows in SQLite available for offline search on this layer.
  Future<int> countReferenceFeatures({
    required String projectId,
    required String layerId,
  }) async {
    final rows = await (_db.select(_db.referenceFeatures)
          ..where((r) => r.projectId.equals(projectId))
          ..where((r) => r.layerId.equals(layerId)))
        .get();
    return rows.length;
  }

  /// Builds a WHERE clause for one condition.
  /// Uses json_each so attribute names match case-insensitively.
  String? _buildClause(
    QueryCondition c,
    List<dynamic> args, {
    required bool caseSensitive,
  }) {
    final attr = c.attribute!;
    final val = c.value.trim();
    final val2 = c.value2.trim();

    String keyMatch(String alias) =>
        caseSensitive ? '$alias.key = ?' : 'LOWER($alias.key) = LOWER(?)';

    String textExpr(String alias) => caseSensitive
        ? 'CAST($alias.value AS TEXT)'
        : 'LOWER(CAST($alias.value AS TEXT))';

    String bindText(String s) => caseSensitive ? s : s.toLowerCase();

    switch (c.operator) {
      case QueryOperator.equals:
        args.add(attr);
        args.add(bindText(val));
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND ${textExpr('je')} = ?
        )''';

      case QueryOperator.notEquals:
        args.add(attr);
        args.add(bindText(val));
        return '''NOT EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND ${textExpr('je')} = ?
        )''';

      case QueryOperator.contains:
        args.add(attr);
        args.add('%${bindText(val)}%');
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND ${textExpr('je')} LIKE ?
        )''';

      case QueryOperator.startsWith:
        args.add(attr);
        args.add('${bindText(val)}%');
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND ${textExpr('je')} LIKE ?
        )''';

      case QueryOperator.greaterThan:
        args.add(attr);
        args.add(val);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND CAST(je.value AS REAL) > CAST(? AS REAL)
        )''';

      case QueryOperator.greaterOrEqual:
        args.add(attr);
        args.add(val);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND CAST(je.value AS REAL) >= CAST(? AS REAL)
        )''';

      case QueryOperator.lessThan:
        args.add(attr);
        args.add(val);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND CAST(je.value AS REAL) < CAST(? AS REAL)
        )''';

      case QueryOperator.lessOrEqual:
        args.add(attr);
        args.add(val);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND CAST(je.value AS REAL) <= CAST(? AS REAL)
        )''';

      case QueryOperator.between:
        args.add(attr);
        args.add(val);
        args.add(val2);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND CAST(je.value AS REAL) BETWEEN CAST(? AS REAL) AND CAST(? AS REAL)
        )''';

      case QueryOperator.isEmpty:
        args.add(attr);
        return '''NOT EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND je.value IS NOT NULL
          AND CAST(je.value AS TEXT) != ''
        )''';

      case QueryOperator.isNotEmpty:
        args.add(attr);
        return '''EXISTS (
          SELECT 1 FROM json_each(attributes) je
          WHERE ${keyMatch('je')}
          AND je.value IS NOT NULL
          AND CAST(je.value AS TEXT) != ''
        )''';
    }
  }

  Variable _toVar(dynamic v) {
    if (v is String) return Variable.withString(v);
    if (v is int) return Variable.withInt(v);
    if (v is double) return Variable.withReal(v);
    return Variable.withString(v.toString());
  }
}

final searchRepositoryProvider = Provider<SearchRepository?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return SearchRepository(db);
});

/// Provider that returns discovered attributes for a layer.
final searchAttributesProvider = FutureProvider.family
    .autoDispose<List<String>, ({String projectId, String layerId})>(
        (ref, key) async {
  final repo = ref.watch(searchRepositoryProvider);
  if (repo == null) return const [];
  return repo.discoverAttributes(
    projectId: key.projectId,
    layerId: key.layerId,
  );
});

/// How many searchable reference rows exist locally for a layer.
final searchIndexCountProvider = FutureProvider.family
    .autoDispose<int, ({String projectId, String layerId})>((ref, key) async {
  final repo = ref.watch(searchRepositoryProvider);
  if (repo == null) return 0;
  return repo.countReferenceFeatures(
    projectId: key.projectId,
    layerId: key.layerId,
  );
});