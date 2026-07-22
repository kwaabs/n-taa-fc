import 'dart:convert';

// ── Field Types ─────────────────────────────────────────

enum FieldType {
  // Text
  text,
  textArea,
  
  // Numbers
  integer,
  decimal,
  
  // Choice
  selectOne,
  selectMultiple,
  
  // Date/Time
  date,
  time,
  dateTime,
  
  // Geo
  geoPoint,
  geoTrace,
  geoShape,
  
  // Media
  photo,
  audio,
  video,
  signature,
  
  // Scanning
  barcode,
  
  // Special
  note,
  calculated,
  group,  // ← add this
  unknown;

  static FieldType fromString(String s) {
    switch (s.toLowerCase()) {
      case 'text':
        return text;
      case 'text_area':
      case 'textarea':
      case 'multiline_text':
        return textArea;
      case 'integer':
      case 'int':
        return integer;
      case 'decimal':
      case 'number':
        return decimal;
      case 'select_one':
        return selectOne;
      case 'select_multiple':
      case 'select_multi':
        return selectMultiple;
      case 'date':
        return date;
      case 'time':
        return time;
      case 'datetime':
      case 'date_time':
        return dateTime;
      case 'geopoint':
      case 'geo_point':
        return geoPoint;
      case 'geotrace':
      case 'geo_trace':
        return geoTrace;
      case 'geoshape':
      case 'geo_shape':
        return geoShape;
      case 'photo':
      case 'image':
        return photo;
      case 'audio':
        return audio;
      case 'video':
        return video;
      case 'signature':
        return signature;
      case 'barcode':
        return barcode;
      case 'note':
        return note;
      case 'calculated':
      case 'calculate':
        return calculated;
      case 'group':
      case 'section':
        return group;
      default:
        return unknown;
    }
  }

  bool get isMedia =>
      this == photo ||
      this == audio ||
      this == video ||
      this == signature;

  bool get isGeo =>
      this == geoPoint ||
      this == geoTrace ||
      this == geoShape;

  bool get isChoice =>
      this == selectOne || this == selectMultiple;

  bool get isText => this == text || this == textArea;

  bool get isNumeric => this == integer || this == decimal;

  bool get isReadOnly => this == note || this == calculated;
}

// ── Localized String ────────────────────────────────────

/// Multi-language string. Falls back to the first available language.
class LocalizedString {
  final Map<String, String> translations;

  const LocalizedString(this.translations);

  factory LocalizedString.fromJson(dynamic json) {
    if (json == null) return const LocalizedString({});
    if (json is String) return LocalizedString({'en': json});
    if (json is Map) {
      final result = <String, String>{};
      for (final entry in json.entries) {
        if (entry.value is String) {
          result[entry.key.toString()] = entry.value as String;
        }
      }
      return LocalizedString(result);
    }
    return const LocalizedString({});
  }

  /// Get the string in the preferred locale, falling back to English, then any.
  String get(String locale, {String fallbackLocale = 'en'}) {
    if (translations.containsKey(locale)) return translations[locale]!;
    if (translations.containsKey(fallbackLocale)) {
      return translations[fallbackLocale]!;
    }
    if (translations.isNotEmpty) return translations.values.first;
    return '';
  }

  /// Default getter — uses 'en' or first available.
  String get value => get('en');

  bool get isEmpty => translations.isEmpty;
  bool get isNotEmpty => translations.isNotEmpty;

  @override
  String toString() => value;
}

// ── Choice ──────────────────────────────────────────────

class Choice {
  final String value;
  final LocalizedString label;
  final String? choiceListId;

  const Choice({
    required this.value,
    required this.label,
    this.choiceListId,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      value: json['value']?.toString() ?? '',
      label: LocalizedString.fromJson(json['label']),
      choiceListId: json['choice_list_id']?.toString(),
    );
  }
}

// ── Validation Rule ─────────────────────────────────────

class ValidationRule {
  final bool required;
  final num? minValue;
  final num? maxValue;
  final int? minLength;
  final int? maxLength;
  final String? regex;
  final LocalizedString? errorMessage;

  const ValidationRule({
    this.required = false,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.regex,
    this.errorMessage,
  });

  factory ValidationRule.fromJson(Map<String, dynamic>? json,
      {bool? requiredFlag}) {
    if (json == null) {
      return ValidationRule(required: requiredFlag ?? false);
    }
    return ValidationRule(
      required: requiredFlag ?? json['required'] == true,
      minValue: _asNum(json['min']),
      maxValue: _asNum(json['max']),
      minLength: _asInt(json['min_length']),
      maxLength: _asInt(json['max_length']),
      regex: json['regex']?.toString(),
      errorMessage: json['error_message'] != null
          ? LocalizedString.fromJson(json['error_message'])
          : null,
    );
  }
}

/// Prefer API/web `constraints`, fall back to legacy `validation`.
Map<String, dynamic>? _validationMapFromFieldJson(Map<String, dynamic> json) {
  if (json['constraints'] is Map) {
    return Map<String, dynamic>.from(json['constraints'] as Map);
  }
  if (json['validation'] is Map) {
    return Map<String, dynamic>.from(json['validation'] as Map);
  }
  return null;
}

// ── Form Field ──────────────────────────────────────────

class FormFieldSpec {
  final String id;
  final FieldType type;
  final LocalizedString label;
  final LocalizedString? hint;
  final LocalizedString? description;
  final ValidationRule validation;
  final List<Choice> choices;
  final String? choiceListId;
  final RelevanceExpression? relevant;
  final dynamic defaultValue;
  final String? calculation;
  final List<FormFieldSpec> children; // ← new
  
  final String? appearance;             // 👈 NEW

  final Map<String, dynamic> raw;

  const FormFieldSpec({
    required this.id,
    required this.type,
    required this.label,
    this.hint,
    this.description,
    this.validation = const ValidationRule(),
    this.choices = const [],
    this.choiceListId,
    this.relevant,
    this.defaultValue,
    this.calculation,
    this.children = const [], // ← new
    
    this.appearance,                    // 👈 NEW

    this.raw = const {},
  });

  factory FormFieldSpec.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString() ?? 'text';
    final type = FieldType.fromString(typeStr);

    // Choices come either inline or by reference to a choice_list_id
    final choicesArr = json['choices'] as List?;
    final choices = choicesArr
            ?.whereType<Map>()
            .map((c) => Choice.fromJson(Map<String, dynamic>.from(c)))
            .toList() ??
        const <Choice>[];

    // Parse nested children (for group fields)
    final childrenArr = json['children'] as List? ?? json['fields'] as List?;
    final children = childrenArr
        ?.whereType<Map>()
        .map((f) => FormFieldSpec.fromJson(Map<String, dynamic>.from(f)))
        .toList() ??
      const <FormFieldSpec>[];

    return FormFieldSpec(
      id: json['id']?.toString() ?? '',
      type: type,
      label: LocalizedString.fromJson(json['label']),
      hint: json['hint'] != null
          ? LocalizedString.fromJson(json['hint'])
          : null,
      description: json['description'] != null
          ? LocalizedString.fromJson(json['description'])
          : null,
      validation: ValidationRule.fromJson(
        _validationMapFromFieldJson(json),
        requiredFlag: json['required'] == true,
      ),
      choices: choices,
      choiceListId: json['choice_list_id']?.toString(),
      relevant: json['relevant'] != null
          ? RelevanceExpression.fromJson(json['relevant'])
          : null,
      defaultValue: json['default'],
      calculation: json['calculation']?.toString(),
      children: children, // ← new
      
      appearance: json['appearance']?.toString(),   // 👈 NEW

      raw: json,
    );
  }
}

// ── Relevance Expression ────────────────────────────────

/// Models a skip-logic expression. Currently supports the object form
/// our style engine uses: { field, op, value } and { and/or: [...] }
class RelevanceExpression {
  final String? field;
  final String? op;
  final dynamic value;
  final List<RelevanceExpression> and;
  final List<RelevanceExpression> or;

  const RelevanceExpression({
    this.field,
    this.op,
    this.value,
    this.and = const [],
    this.or = const [],
  });

  factory RelevanceExpression.fromJson(dynamic json) {
    if (json is! Map) return const RelevanceExpression();
    final m = Map<String, dynamic>.from(json);
    return RelevanceExpression(
      field: m['field']?.toString(),
      op: m['op']?.toString(),
      value: m['value'],
      and: (m['and'] as List?)
              ?.map((e) => RelevanceExpression.fromJson(e))
              .toList() ??
          const [],
      or: (m['or'] as List?)
              ?.map((e) => RelevanceExpression.fromJson(e))
              .toList() ??
          const [],
    );
  }

  /// Evaluate this clause against current form responses.
  /// `responses` is a map of field_id → current value.
  bool evaluate(Map<String, dynamic> responses) {
    if (and.isNotEmpty) {
      return and.every((c) => c.evaluate(responses));
    }
    if (or.isNotEmpty) {
      return or.any((c) => c.evaluate(responses));
    }
    if (field != null && op != null) {
      final left = responses[field];
      return _compare(left, op!, value);
    }
    return true; // empty clause → always visible
  }

  static bool _compare(dynamic left, String op, dynamic right) {
    switch (op) {
      case 'eq':
        return _str(left) == _str(right);
      case 'neq':
        return _str(left) != _str(right);
      case 'gt':
        return _num(left) > _num(right);
      case 'lt':
        return _num(left) < _num(right);
      case 'gte':
        return _num(left) >= _num(right);
      case 'lte':
        return _num(left) <= _num(right);
      case 'in':
        if (right is List) {
          return right.any((v) => _str(v) == _str(left));
        }
        return false;
      case 'not_in':
        if (right is List) {
          return !right.any((v) => _str(v) == _str(left));
        }
        return true;
      case 'contains':
        return _str(left).toLowerCase().contains(_str(right).toLowerCase());
      case 'is_null':
        return left == null;
      case 'is_not_null':
        return left != null;
      default:
        return false;
    }
  }

  static String _str(dynamic v) => v?.toString() ?? '';
  static num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
}

// ── Form Schema ─────────────────────────────────────────

class FormSchema {
  final List<FormFieldSpec> fields;
  final String defaultLanguage;
  final List<String> languages;
  final Map<String, dynamic> raw;

  const FormSchema({
    required this.fields,
    this.defaultLanguage = 'en',
    this.languages = const ['en'],
    this.raw = const {},
  });

  factory FormSchema.fromJson(dynamic json) {
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        return const FormSchema(fields: []);
      }
    }
    if (json is! Map) return const FormSchema(fields: []);
    final m = Map<String, dynamic>.from(json);

    final fieldsArr = (m['fields'] as List?) ?? const [];
    final fields = fieldsArr
        .whereType<Map>()
        .map((f) => FormFieldSpec.fromJson(Map<String, dynamic>.from(f)))
        .toList();

    final settings = m['settings'] as Map?;
    final defaultLang = settings?['default_language']?.toString() ?? 'en';
    final langs =
        (settings?['languages'] as List?)?.map((e) => e.toString()).toList() ??
            const ['en'];

    return FormSchema(
      fields: fields,
      defaultLanguage: defaultLang,
      languages: langs,
      raw: m,
    );
  }

  /// Get a field by id.
  FormFieldSpec? fieldById(String id) {
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;
}

// ── Helpers ─────────────────────────────────────────────

num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}