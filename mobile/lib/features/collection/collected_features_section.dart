import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../projects/local_data_providers.dart';
import 'collected_feature_detail_screen.dart';
import 'collected_feature_tile.dart';
import 'feature_repository.dart';

class CollectedFeaturesSection extends ConsumerStatefulWidget {
  final String projectId;
  final void Function(CollectedFeature feature) onResumeDraft;

  const CollectedFeaturesSection({
    super.key,
    required this.projectId,
    required this.onResumeDraft,
  });

  @override
  ConsumerState<CollectedFeaturesSection> createState() =>
      _CollectedFeaturesSectionState();
}

class _CollectedFeaturesSectionState
    extends ConsumerState<CollectedFeaturesSection> {
  String _filter = 'all'; // all | draft | pending | synced | failed

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuresAsync =
        ref.watch(collectedForProjectProvider(widget.projectId));
    final countsAsync =
        ref.watch(collectedStatusCountsProvider(widget.projectId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Collected Data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            featuresAsync.when(
              loading: () => Text(
                'Loading...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              error: (e, _) => Text(
                'Failed to load: $e',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              data: (rows) => Text(
                rows.isEmpty
                    ? 'Nothing collected yet'
                    : '${rows.length} entr${rows.length == 1 ? "y" : "ies"} on this device',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status filter chips
            countsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (counts) {
                final total = counts.values.fold<int>(0, (a, b) => a + b);
                if (total == 0) return const SizedBox.shrink();
                return Wrap(
                  spacing: 6,
                  children: [
                    _FilterChip(
                      label: 'All ($total)',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    for (final entry in counts.entries)
                      _FilterChip(
                        label: '${_humanStatus(entry.key)} (${entry.value})',
                        selected: _filter == entry.key,
                        onTap: () => setState(() => _filter = entry.key),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            featuresAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const SizedBox.shrink(),
              data: (rows) {
                final filtered = _filter == 'all'
                    ? rows
                    : rows.where((r) => r.status == _filter).toList();

                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 36,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap a form above to start collecting',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No entries match this filter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final feature in filtered)
                      CollectedFeatureTile(
                        feature: feature,
                        onTap: () {
                          if (feature.status == 'draft') {
                            widget.onResumeDraft(feature);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CollectedFeatureDetailScreen(
                                  feature: feature,
                                ),
                              ),
                            );
                          }
                        },
                        onDelete: feature.status == 'draft'
                            ? () async {
                                await ref
                                    .read(collectedFeatureRepoProvider)
                                    ?.delete(feature.clientId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Draft deleted'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _humanStatus(String s) {
    switch (s) {
      case 'draft':
        return 'Drafts';
      case 'pending':
        return 'Pending';
      case 'synced':
        return 'Synced';
      case 'failed':
        return 'Failed';
      default:
        return s;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}