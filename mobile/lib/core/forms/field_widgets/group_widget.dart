import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_widget.dart';

class GroupWidget extends StatelessWidget {
  final FormFieldSpec field;
  const GroupWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = FormControllerScope.of(context);

    final label = field.label.value;
    final desc = field.description?.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (desc != null && desc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Render children, respecting their own relevance
            for (final child in field.children)
              if (ctrl.isFieldVisible(child)) FieldWidget(field: child),
          ],
        ),
      ),
    );
  }
}