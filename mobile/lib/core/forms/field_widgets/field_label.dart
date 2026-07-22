import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';

/// Renders the field label, hint, required asterisk, and error message.
/// Wraps the actual input widget.
class FieldLabel extends StatelessWidget {
  final FormFieldSpec field;
  final String? error;
  final Widget child;

  const FieldLabel({
    super.key,
    required this.field,
    this.error,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    
    final theme = Theme.of(context);
      final labelText = field.label.value.isEmpty ? field.id : field.label.value;
      final hintText = field.hint?.value;
      final descText = field.description?.value;

      // Capture controller from context — if not in a FormControllerScope, skip the key
      final ctrl = FormControllerScope.maybeOf(context);
      final key = ctrl?.keyFor(field.id);


    return KeyedSubtree(
      key: key,
      child:Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: labelText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (field.validation.required)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (descText != null && descText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              descText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
          if (hintText != null && hintText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hintText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}