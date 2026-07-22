import 'form_schema.dart';

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.ok() : isValid = true, errorMessage = null;
  const ValidationResult.error(String msg)
      : isValid = false,
        errorMessage = msg;
}

class FormValidator {
  /// Validates one field's value against its rules.
  /// Returns ValidationResult.ok() if valid, or ValidationResult.error(msg) otherwise.
  static ValidationResult validateField(FormFieldSpec field, dynamic value) {
    final rule = field.validation;

    // Empty value check
    final isEmpty = _isEmpty(value);
    if (rule.required && isEmpty) {
      return const ValidationResult.error('This field is required');
    }
    if (isEmpty) {
      return const ValidationResult.ok();
    }

    // Type-specific validation
    if (field.type.isNumeric) {
      final n = _asNum(value);
      if (n == null) {
        return const ValidationResult.error('Must be a number');
      }
      if (field.type == FieldType.integer && n != n.toInt()) {
        return const ValidationResult.error('Must be a whole number');
      }
      if (rule.minValue != null && n < rule.minValue!) {
        return ValidationResult.error('Must be at least ${rule.minValue}');
      }
      if (rule.maxValue != null && n > rule.maxValue!) {
        return ValidationResult.error('Must be at most ${rule.maxValue}');
      }
    }

    if (field.type.isText) {
      final s = value.toString();
      if (rule.minLength != null && s.length < rule.minLength!) {
        return ValidationResult.error(
          'Must be at least ${rule.minLength} characters',
        );
      }
      if (rule.maxLength != null && s.length > rule.maxLength!) {
        return ValidationResult.error(
          'Must be at most ${rule.maxLength} characters',
        );
      }
      if (rule.regex != null && rule.regex!.isNotEmpty) {
        final pattern = RegExp(rule.regex!);
        if (!pattern.hasMatch(s)) {
          return ValidationResult.error(
            rule.errorMessage?.value ?? 'Invalid format',
          );
        }
      }
    }

    return const ValidationResult.ok();
  }

  /// Validates an entire form. Returns a map of field_id → error message
  /// for any fields that failed (skips fields that are not relevant).
  static Map<String, String> validateForm(
    FormSchema schema,
    Map<String, dynamic> responses,
  ) {
    final errors = <String, String>{};
    for (final field in schema.fields) {
      // Skip hidden fields
      if (field.relevant != null && !field.relevant!.evaluate(responses)) {
        continue;
      }
      final result = validateField(field, responses[field.id]);
      if (!result.isValid) {
        errors[field.id] = result.errorMessage ?? 'Invalid';
      }
    }
    return errors;
  }

  static bool _isEmpty(dynamic v) {
    if (v == null) return true;
    if (v is String && v.isEmpty) return true;
    if (v is List && v.isEmpty) return true;
    if (v is Map && v.isEmpty) return true;
    return false;
  }

  static num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }
}