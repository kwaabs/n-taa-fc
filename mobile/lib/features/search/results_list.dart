import 'package:flutter/material.dart';

import 'search_state.dart';

typedef ResultTapCallback = void Function(SearchResult result);

/// List of matched features from a search.
class ResultsList extends StatelessWidget {
  final List<SearchResult> results;
  final ResultTapCallback onResultTap;
  final int maxDisplay;

  const ResultsList({
    super.key,
    required this.results,
    required this.onResultTap,
    this.maxDisplay = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No matches',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try broadening your query.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final displayed = results.take(maxDisplay).toList();
    final hasMore = results.length > maxDisplay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Count header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                results.length == 1 ? '1 match' : '${results.length} matches',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (hasMore) ...[
                const Spacer(),
                Text(
                  'showing first $maxDisplay',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.separated(
            itemCount: displayed.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
            itemBuilder: (context, i) {
              final r = displayed[i];
              return _ResultRow(
                result: r,
                onTap: () => onResultTap(r),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultRow({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = result.secondaryLabel;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.primaryLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
