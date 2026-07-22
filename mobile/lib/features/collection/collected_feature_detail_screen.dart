import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/layout/adaptive_two_column.dart';

import 'widgets/feature_mini_map.dart';
import '../map/map_project_screen.dart'; // for "open full map" navigation
import 'widgets/feature_mini_map.dart';
import 'feature_repository.dart';

class CollectedFeatureDetailScreen extends ConsumerWidget {
  final CollectedFeature feature;
  const CollectedFeatureDetailScreen({super.key, required this.feature});

  Map<String, dynamic> _parseAttributes() {
    try {
      final decoded = jsonDecode(feature.attributes);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  Map<String, dynamic>? _parseGeometry() {
    if (feature.geometry == null) return null;
    try {
      final decoded = jsonDecode(feature.geometry!);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (feature.status) {
      'draft' => cs.onSurfaceVariant,
      'pending' => cs.secondary,
      'synced' => cs.tertiary,
      'failed' => cs.error,
      _ => cs.onSurface,
    };
  }

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attrs = _parseAttributes();
    final geom = _parseGeometry();

    // ── Cards extracted so we can arrange them for phone vs tablet ──

    final summaryCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(feature.status),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: _statusColor(context)),
                ),
                Chip(
                  label: Text(
                    '${feature.collectedAt.year}-'
                    '${feature.collectedAt.month.toString().padLeft(2, '0')}-'
                    '${feature.collectedAt.day.toString().padLeft(2, '0')}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Client ID',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              feature.clientId,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            if (feature.lastError != null && feature.lastError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        size: 14, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        feature.lastError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final Widget? locationCard = (geom != null && geom['coordinates'] is List)
        ? Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: theme.colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        'Location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // In collected_feature_detail_screen.dart, inside locationCard:
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Builder(
                    builder: (context) {
                      try {
                        return FeatureMiniMap(geometry: geom, height: 240);
                      } catch (e) {
                        return Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Text('Map preview unavailable: $e',
                              style: const TextStyle(color: Colors.grey)),
                        );
                      }
                    },
                  ),
                ),
                if (geom['type'] == 'Point')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat ${(geom['coordinates'] as List)[1].toString()}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                        Text(
                          'Lng ${(geom['coordinates'] as List)[0].toString()}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          )
        : null;

    final responsesCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responses',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (attrs.isEmpty)
              Text(
                'No responses',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final entry in attrs.entries) ...[
                Text(
                  entry.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.value == null
                        ? '—'
                        : entry.value is Map || entry.value is List
                            ? jsonEncode(entry.value)
                            : entry.value.toString(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collected'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete this submission?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(collectedFeatureRepoProvider)
                    ?.delete(feature.clientId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AdaptiveTwoColumn(
          leftFlex: 3,
          rightFlex: 2,
          left: [
            summaryCard,
            const SizedBox(height: 16),
            responsesCard,
          ],
          right: [
            if (locationCard != null) locationCard,
          ],
        ),
      ),
    );
  }
}
