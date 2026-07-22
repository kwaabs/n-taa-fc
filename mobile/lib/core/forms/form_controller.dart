import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'form_schema.dart';
import 'form_validator.dart';

class FormController extends ChangeNotifier {
  final FormSchema schema;
  final Map<String, dynamic> _responses;
  final Map<String, String> _errors;
  final Map<String, GlobalKey> _fieldKeys = {};
  bool _touched = false;

  FormController({
    required this.schema,
    Map<String, dynamic>? initialResponses,
  })  : _responses = {...?initialResponses},
        _errors = {};

  Map<String, dynamic> get responses => Map.unmodifiable(_responses);
  Map<String, String> get errors => Map.unmodifiable(_errors);
  bool get isValid => _errors.isEmpty;
  bool get touched => _touched;

  dynamic getValue(String fieldId) => _responses[fieldId];
  String? getError(String fieldId) => _errors[fieldId];

  /// Returns or creates a GlobalKey for a field, used to scroll to it.
  GlobalKey keyFor(String fieldId) {
    return _fieldKeys.putIfAbsent(fieldId, () => GlobalKey());
  }

  /// Returns the first field ID that has an error, or null.
  String? get firstErrorFieldId =>
      _errors.isEmpty ? null : _errors.keys.first;

  void setValue(String fieldId, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      _responses.remove(fieldId);
    } else {
      _responses[fieldId] = value;
    }
    _touched = true;

    final field = schema.fieldById(fieldId);
    if (field != null) {
      final result = FormValidator.validateField(field, value);
      if (result.isValid) {
        _errors.remove(fieldId);
      } else {
        _errors[fieldId] = result.errorMessage ?? 'Invalid';
      }
    }

    notifyListeners();
  }

  bool isFieldVisible(FormFieldSpec field) {
    if (field.relevant == null) return true;
    return field.relevant!.evaluate(_responses);
  }

  Map<String, String> validateAll() {
    _errors.clear();
    for (final field in schema.fields) {
      if (!isFieldVisible(field)) continue;
      _validateRecursive(field);
    }
    _touched = true;
    notifyListeners();
    return Map.unmodifiable(_errors);
  }

  /// Validates a field and recurses into group children.
  void _validateRecursive(FormFieldSpec field) {
    if (field.type == FieldType.group) {
      for (final child in field.children) {
        if (isFieldVisible(child)) {
          _validateRecursive(child);
        }
      }
      return;
    }
    final result = FormValidator.validateField(field, _responses[field.id]);
    if (!result.isValid) {
      _errors[field.id] = result.errorMessage ?? 'Invalid';
    }
  }

  void cleanupHiddenFieldErrors() {
    final toRemove = <String>[];
    for (final id in _errors.keys) {
      final field = schema.fieldById(id);
      if (field == null || !isFieldVisible(field)) {
        toRemove.add(id);
      }
    }
    for (final id in toRemove) {
      _errors.remove(id);
    }
  }

  void reset({bool keepResponses = false}) {
    if (!keepResponses) _responses.clear();
    _errors.clear();
    _touched = false;
    notifyListeners();
  }

  /// Marks the form as clean without clearing responses.
  /// Use after a successful save/submit so PopScope allows back navigation.
  void markClean() {
    _touched = false;
    notifyListeners();
  }
}

class FormControllerScope extends InheritedNotifier<FormController> {
  const FormControllerScope({
    super.key,
    required FormController controller,
    required super.child,
  }) : super(notifier: controller);

  static FormController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FormControllerScope>();
    if (scope == null) {
      throw FlutterError(
        'FormControllerScope not found. Wrap your form in FormControllerScope.',
      );
    }
    return scope.notifier!;
  }

  static FormController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FormControllerScope>()
        ?.notifier;
  }
}