import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'search_state.dart';

class SearchRepository {
  final AppDatabase _db;

  SearchRepository(this._db);

  /// Discovers all attribute keys used across a layer's reference features.
  /// Scans the JSON blobs since Drift's schema doesn't know them.
  Future<List<String>> discoverAttributes({
    required String projectId,
    required String layerId,
    int sampleSize = 500,
  }) async {
    // Sample features from this layer
    final rows = await (_db.select(_db.referenceFeatures)
          ..where((r) => r.projectId.equals(projectId))
          ..where((r) => r.layerId.equals(layerId))
          ..limit(sampleSize))
        .get();

    final keys = <String>{};
    for (final row in rows) {
      try {
        final parsed = jsonDecode(row.attributes);
        if (parsed is Map) {
          for (final key in parsed.keys) {
            if (key is String && !key.startsWith('_')) {
              keys.add(key);
            }
          }
        }
      } catch (_) {
        // Skip malformed rows
      }
    }

    final sorted = keys.toList()..sort();
    return sorted;
  }

  /// Executes a query against reference_features.
  /// Returns matches paginated up to [maxResults].
  Future<List<SearchResult>> runQuery({
    required String projectId,
    required String layerId,
    required List<QueryCondition> conditions,
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
      final clause = _buildClause(c, args);
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

      return searchResults;
    } catch (e, s) {
      debugPrint('[search] query failed: $e\n$s');
      rethrow;
    }
  }

  /// Builds a SQL WHERE clause for a single condition.
  /// Appends any bound values to [args].
  String? _buildClause(QueryCondition c, List<dynamic> args) {
    final attr = c.attribute!;
    final extractSql = "json_extract(attributes, '\$.$attr')";
    final val = c.value.trim();
    final val2 = c.value2.trim();

    switch (c.operator) {
      case QueryOperator.equals:
        args.add(val);
        // For numeric equality, cast the extracted value
        return "(CAST($extractSql AS TEXT) = CAST(? AS TEXT))";

      case QueryOperator.notEquals:
        args.add(val);
        return "(CAST($extractSql AS TEXT) != CAST(? AS TEXT))";

      case QueryOperator.contains:
        args.add('%$val%');
        return "CAST($extractSql AS TEXT) LIKE ?";

      case QueryOperator.startsWith:
        args.add('$val%');
        return "CAST($extractSql AS TEXT) LIKE ?";

      case QueryOperator.greaterThan:
        args.add(val);
        return "(CAST($extractSql AS REAL) > CAST(? AS REAL))";

      case QueryOperator.greaterOrEqual:
        args.add(val);
        return "(CAST($extractSql AS REAL) >= CAST(? AS REAL))";

      case QueryOperator.lessThan:
        args.add(val);
        return "(CAST($extractSql AS REAL) < CAST(? AS REAL))";

      case QueryOperator.lessOrEqual:
        args.add(val);
        return "(CAST($extractSql AS REAL) <= CAST(? AS REAL))";

      case QueryOperator.between:
        args.add(val);
        args.add(val2);
        return "(CAST($extractSql AS REAL) BETWEEN CAST(? AS REAL) AND CAST(? AS REAL))";

      case QueryOperator.isEmpty:
        return "($extractSql IS NULL OR CAST($extractSql AS TEXT) = '')";

      case QueryOperator.isNotEmpty:
        return "($extractSql IS NOT NULL AND CAST($extractSql AS TEXT) != '')";
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