import 'package:flutter/material.dart';
import 'form_controller.dart';

/// Shows a banner at the top of a form summarizing validation errors.
///
/// Only visible when the form has been touched (submit attempted) AND there
/// are errors. Tapping the banner scrolls to and highlights the first
/// invalid field.
class FormValidationSummary extends StatelessWidget {
  final FormController controller;
  final VoidCallback? onTapFirstError;

  const FormValidationSummary({
    super.key,
    required this.controller,
    this.onTapFirstError,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.touched || controller.isValid) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final count = controller.errors.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.error.withOpacity(0.4),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTapFirstError,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count == 1
                                ? '1 field needs attention'
                                : '$count fields need attention',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          Text(
                            'Tap to jump to the first one',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}