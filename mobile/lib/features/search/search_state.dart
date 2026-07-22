import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Operators supported by the query builder.
enum QueryOperator {
  equals,
  notEquals,
  contains,
  startsWith,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  between,
  isEmpty,
  isNotEmpty,
}

extension QueryOperatorExt on QueryOperator {
  String get label {
    switch (this) {
      case QueryOperator.equals:
        return 'equals';
      case QueryOperator.notEquals:
        return 'not equals';
      case QueryOperator.contains:
        return 'contains';
      case QueryOperator.startsWith:
        return 'starts with';
      case QueryOperator.greaterThan:
        return '>';
      case QueryOperator.greaterOrEqual:
        return '>=';
      case QueryOperator.lessThan:
        return '<';
      case QueryOperator.lessOrEqual:
        return '<=';
      case QueryOperator.between:
        return 'between';
      case QueryOperator.isEmpty:
        return 'is empty';
      case QueryOperator.isNotEmpty:
        return 'is not empty';
    }
  }

  /// True if this operator needs any user-provided value.
  bool get needsValue {
    switch (this) {
      case QueryOperator.isEmpty:
      case QueryOperator.isNotEmpty:
        return false;
      default:
        return true;
    }
  }

  /// True if this operator needs TWO values (between).
  bool get needsTwoValues => this == QueryOperator.between;
}

/// A single condition in the query.
class QueryCondition {
  final String id; // for stable widget keys
  final String? attribute;
  final QueryOperator operator;
  final String value;
  final String value2; // for BETWEEN

  const QueryCondition({
    required this.id,
    this.attribute,
    this.operator = QueryOperator.equals,
    this.value = '',
    this.value2 = '',
  });

  QueryCondition copyWith({
    String? attribute,
    QueryOperator? operator,
    String? value,
    String? value2,
  }) {
    return QueryCondition(
      id: id,
      attribute: attribute ?? this.attribute,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      value2: value2 ?? this.value2,
    );
  }

  /// A condition is executable if it has an attribute and the required value(s).
  bool get isValid {
    if (attribute == null || attribute!.isEmpty) return false;
    if (!operator.needsValue) return true;
    if (value.trim().isEmpty) return false;
    if (operator.needsTwoValues && value2.trim().isEmpty) return false;
    return true;
  }
}

/// Full search query state.
class SearchQueryState {
  final String? layerId;
  final List<QueryCondition> conditions;
  final bool isRunning;
  final List<SearchResult>? results; // null = no search run yet
  final String? error;

  const SearchQueryState({
    this.layerId,
    this.conditions = const [],
    this.isRunning = false,
    this.results,
    this.error,
  });

  SearchQueryState copyWith({
    String? layerId,
    List<QueryCondition>? conditions,
    bool? isRunning,
    List<SearchResult>? results,
    String? error,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return SearchQueryState(
      layerId: layerId ?? this.layerId,
      conditions: conditions ?? this.conditions,
      isRunning: isRunning ?? this.isRunning,
      results: clearResults ? null : (results ?? this.results),
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// True if at least one condition is executable.
  bool get canRun {
    if (layerId == null) return false;
    return conditions.any((c) => c.isValid);
  }
}

/// A single matched feature returned from a search.
class SearchResult {
  final String featureId;
  final String layerId;
  final String? geometryJson; // raw GeoJSON for map-flying-to
  final Map<String, dynamic> attributes;

  const SearchResult({
    required this.featureId,
    required this.layerId,
    this.geometryJson,
    this.attributes = const {},
  });

  /// Best-effort primary label from attributes (for the list row).
  String get primaryLabel {
    // Common ID keys
    for (final key in ['objectid', 'globalid', 'name', 'substation_name']) {
      final v = attributes[key];
      if (v != null && v.toString().isNotEmpty) {
        return v.toString();
      }
    }
    return featureId;
  }

  /// Best-effort secondary label from attributes.
  String? get secondaryLabel {
    for (final key in ['district', 'location_description', 'circuit_id']) {
      final v = attributes[key];
      if (v != null && v.toString().isNotEmpty) {
        return v.toString();
      }
    }
    return null;
  }
}

/// Provider for the current search state (per project scope).
final searchQueryProvider =
    StateNotifierProvider.family<SearchQueryNotifier, SearchQueryState, String>(
        (ref, projectId) {
  return SearchQueryNotifier(projectId);
});

class SearchQueryNotifier extends StateNotifier<SearchQueryState> {
  final String projectId;

  SearchQueryNotifier(this.projectId) : super(const SearchQueryState());

  void setLayer(String? layerId) {
    // Changing layer clears results but keeps conditions
    state = state.copyWith(
      layerId: layerId,
      clearResults: true,
      clearError: true,
    );
  }

  void addCondition() {
    final newCondition = QueryCondition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    state = state.copyWith(
      conditions: [...state.conditions, newCondition],
    );
  }

  void removeCondition(String id) {
    state = state.copyWith(
      conditions: state.conditions.where((c) => c.id != id).toList(),
    );
  }

  void updateCondition(String id, QueryCondition updated) {
    state = state.copyWith(
      conditions: state.conditions
          .map((c) => c.id == id ? updated : c)
          .toList(),
    );
  }

  void setResults(List<SearchResult> results) {
    state = state.copyWith(
      results: results,
      isRunning: false,
      clearError: true,
    );
  }

  void setRunning(bool running) {
    state = state.copyWith(isRunning: running);
  }

  void setError(String message) {
    state = state.copyWith(error: message, isRunning: false);
  }

  void clear() {
    state = SearchQueryState(layerId: state.layerId);
  }
}