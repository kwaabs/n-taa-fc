import 'package:flutter/material.dart';

import '../form_schema.dart';
import 'date_widget.dart';
import 'geopoint_widget.dart';
import 'note_widget.dart';
import 'number_field_widget.dart';
import 'select_multiple_widget.dart';
import 'multi_photo_widget.dart';
import 'select_one_widget.dart';
import 'text_area_widget.dart';
import 'text_field_widget.dart';
import 'group_widget.dart';

/// Returns the right widget for a given form field type.
class FieldWidget extends StatelessWidget {
  final FormFieldSpec field;
  const FieldWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FieldType.text:
        return TextFieldWidget(field: field);
      case FieldType.textArea:
        return TextAreaWidget(field: field);
      case FieldType.integer:
      case FieldType.decimal:
        return NumberFieldWidget(field: field);
      case FieldType.selectOne:
        return SelectOneWidget(field: field);
      case FieldType.selectMultiple:
        return SelectMultipleWidget(field: field);
      case FieldType.date:
      case FieldType.time:
      case FieldType.dateTime:
        return DateFieldWidget(field: field);
      case FieldType.geoPoint:
        return GeoPointWidget(field: field);
      case FieldType.photo:
        // Always allow multiple photos (capped via constraints.max_length, default 10).
        return MultiPhotoWidget(field: field);
      case FieldType.note:
        return NoteWidget(field: field);
      case FieldType.group:
        return GroupWidget(field: field);

      // Not yet implemented — show a placeholder
      case FieldType.audio:
      case FieldType.video:
      case FieldType.signature:
      case FieldType.barcode:
      case FieldType.geoTrace:
      case FieldType.geoShape:
      case FieldType.calculated:
      case FieldType.unknown:
        return _UnsupportedField(field: field);
    }
  }
}

class _UnsupportedField extends StatelessWidget {
  final FormFieldSpec field;
  const _UnsupportedField({required this.field});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.construction, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label.value.isEmpty ? field.id : field.label.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${field.type.name} fields are not yet supported',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
