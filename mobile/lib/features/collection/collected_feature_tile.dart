import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

class CollectedFeatureTile extends StatelessWidget {
  final CollectedFeature feature;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const CollectedFeatureTile({
    super.key,
    required this.feature,
    required this.onTap,
    this.onDelete,
  });

  String get _title {
  try {
    final attrs = jsonDecode(feature.attributes);
    if (attrs is Map) {
      // Prefer common human-readable identifiers first.
      for (final key in ['name', 'title', 'label']) {
        final v = attrs[key];
        if (v is String && v.isNotEmpty) return v;
      }

      // Then any non-attachment, non-geometry-ish string.
      for (final entry in attrs.entries) {
        final v = entry.value;
        if (v is String &&
            v.isNotEmpty &&
            !v.startsWith('att:') &&
            !RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(v)) {
          return v;
        }
      }

      // Then any number.
      for (final entry in attrs.entries) {
        final v = entry.value;
        if (v is num) return v.toString();
      }
    }
  } catch (_) {}

    return feature.clientId.substring(0, 8);
  }

  bool get _hasGeometry => feature.geometry != null && feature.geometry!.isNotEmpty;

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  ({Color bg, Color fg, String label, IconData icon}) _statusStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (feature.status) {
      case 'draft':
        return (
          bg: cs.surfaceContainerHighest,
          fg: cs.onSurfaceVariant,
          label: 'Draft',
          icon: Icons.edit_note,
        );
      case 'pending':
        return (
          bg: cs.secondaryContainer,
          fg: cs.onSecondaryContainer,
          label: 'Pending sync',
          icon: Icons.sync,
        );
      case 'syncing':
        return (
          bg: cs.primaryContainer,
          fg: cs.onPrimaryContainer,
          label: 'Syncing...',
          icon: Icons.cloud_upload,
        );
      case 'synced':
        return (
          bg: cs.tertiaryContainer,
          fg: cs.onTertiaryContainer,
          label: 'Synced',
          icon: Icons.cloud_done,
        );
      case 'failed':
        return (
          bg: cs.errorContainer,
          fg: cs.onErrorContainer,
          label: 'Failed',
          icon: Icons.error_outline,
        );

      default:
        return (
          bg: cs.surfaceContainerHigh,
          fg: cs.onSurface,
          label: feature.status,
          icon: Icons.help_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusStyle(context);

    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: status.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(status.icon, size: 18, color: status.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: status.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _relativeTime(feature.collectedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_hasGeometry) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return tile;

    // Wrap in Dismissible for swipe-to-delete
    return Dismissible(
      key: ValueKey(feature.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete draft?'),
            content: const Text(
              'This draft will be permanently deleted. This cannot be undone.',
            ),
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
        return result == true;
      },
      onDismissed: (_) => onDelete?.call(),
      child: tile,
    );
  }
}