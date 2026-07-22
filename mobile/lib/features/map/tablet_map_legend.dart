import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The expanded, always-visible layer legend used on tablet landscape.
///
/// This mirrors the collapsible legend button on phone but is always
/// expanded and lives inside the persistent side panel.
class TabletMapLegend extends ConsumerWidget {
  final Map<String, bool> visible;
  final AsyncValue<Map<String, String>> layerNamesAsync;
  final Future<void> Function(String id, bool value) onToggle;

  const TabletMapLegend({
    super.key,
    required this.visible,
    required this.layerNamesAsync,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: layerNamesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
            data: (layers) {
              if (layers.isEmpty) {
                return Text(
                  'No layers in this project',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              final ids = layers.keys.toList()..sort();
              return ListView.separated(
                itemCount: ids.length,
                separatorBuilder: (_, __) => const Divider(height: 4),
                itemBuilder: (_, i) {
                  final id = ids[i];
                  final name = layers[id] ?? id;
                  final isOn = visible[id] ?? true;
                  return InkWell(
                    onTap: () => onToggle(id, !isOn),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOn
                                ? Icons.visibility
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: isOn
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
