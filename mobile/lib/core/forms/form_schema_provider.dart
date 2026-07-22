import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart' as db;
import '../db/db_provider.dart';
import 'form_schema.dart';

/// Loads a form by ID, parses its schema, and resolves choice list references
/// against the project's choice lists.
final formSchemaProvider =
    FutureProvider.family<FormSchema?, String>((ref, formId) async {
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return null;

  final formRow = await (database.select(database.forms)
        ..where((f) => f.id.equals(formId)))
      .getSingleOrNull();
  if (formRow == null) return null;

  final schema = FormSchema.fromJson(formRow.schema);

  // Resolve choice list references — load any choices needed
  final referencedListIds = <String>{};
  for (final field in schema.fields) {
    if (field.choiceListId != null && field.choices.isEmpty) {
      referencedListIds.add(field.choiceListId!);
    }
  }

  if (referencedListIds.isEmpty) return schema;

  final lists = await (database.select(database.choiceLists)
        ..where((cl) => cl.id.isIn(referencedListIds)))
      .get();

  final listChoices = <String, List<Choice>>{};
  for (final list in lists) {
    try {
      final parsed = jsonDecode(list.choices);
      if (parsed is List) {
        listChoices[list.id] = parsed
            .whereType<Map>()
            .map((c) => Choice.fromJson(Map<String, dynamic>.from(c)))
            .toList();
      }
    } catch (_) {}
  }

  // Rebuild fields with resolved choices
  final resolvedFields = schema.fields.map((field) {
    if (field.choiceListId != null &&
        field.choices.isEmpty &&
        listChoices.containsKey(field.choiceListId)) {
      return FormFieldSpec(
        id: field.id,
        type: field.type,
        label: field.label,
        hint: field.hint,
        description: field.description,
        validation: field.validation,
        choices: listChoices[field.choiceListId]!,
        choiceListId: field.choiceListId,
        relevant: field.relevant,
        defaultValue: field.defaultValue,
        calculation: field.calculation,
        raw: field.raw,
      );
    }
    return field;
  }).toList();

  return FormSchema(
    fields: resolvedFields,
    defaultLanguage: schema.defaultLanguage,
    languages: schema.languages,
    raw: schema.raw,
  );
});

/// Watches a form row from local DB.
final localFormProvider =
    StreamProvider.family<db.Form?, String>((ref, formId) {
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return Stream.value(null);
  return (database.select(database.forms)
        ..where((f) => f.id.equals(formId)))
      .watchSingleOrNull();
});