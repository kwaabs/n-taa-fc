import 'package:flutter/material.dart';

import 'form_controller.dart';
import 'form_schema.dart';

class FormProgressIndicator extends StatelessWidget {
  final FormSchema schema;
  const FormProgressIndicator({super.key, required this.schema});

  /// Flattens groups + their children into a single list of leaf fields.
  Iterable<FormFieldSpec> _allLeafFields(List<FormFieldSpec> fields) sync* {
    for (final f in fields) {
      if (f.type == FieldType.group) {
        yield* _allLeafFields(f.children);
      } else if (f.type != FieldType.note) {
        yield f;
      }
    }
  }

  bool _isFilled(dynamic value) {
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    if (value is Map && value.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = FormControllerScope.of(context);

    final leafFields = _allLeafFields(schema.fields)
        .where((f) => ctrl.isFieldVisible(f))
        .toList();
    final total = leafFields.length;
    if (total == 0) return const SizedBox.shrink();

    final filled =
        leafFields.where((f) => _isFilled(ctrl.getValue(f.id))).length;
    final ratio = total == 0 ? 0.0 : filled / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$filled of $total fields completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (ratio >= 1.0)
                Icon(Icons.check_circle,
                    size: 16, color: theme.colorScheme.tertiary),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(
                ratio >= 1.0
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}