import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../map/map_providers.dart';
import 'condition_row.dart';
import 'coordinate_parser.dart';
import 'results_list.dart';
import 'search_repository.dart';
import 'search_state.dart';

typedef GoToLocationCallback = void Function(double lat, double lng);

/// The full search panel — layer picker + condition builder + results.
///
/// Consumers pass an [onResultTap] handler to receive tap events on
/// individual result rows (typically opens the feature detail drawer
/// or centers the map). Optional [onResultDirections] adds a directions
/// action on each row.
class SearchPanel extends ConsumerWidget {
  final String projectId;
  final ResultTapCallback onResultTap;
  final ResultTapCallback? onResultDirections;
  final GoToLocationCallback? onGoToLocation;

  const SearchPanel({
    super.key,
    required this.projectId,
    required this.onResultTap,
    this.onResultDirections,
    this.onGoToLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(searchQueryProvider(projectId));
    final notifier = ref.read(searchQueryProvider(projectId).notifier);
    final layerNamesAsync = ref.watch(localLayerNamesProvider(projectId));

    return SingleChildScrollView(
      // Push content up when the keyboard appears so the focused field
      // stays visible above it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onGoToLocation != null) ...[
            _GoToCoordinates(onGoTo: onGoToLocation!),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],

          // Layer picker
          _sectionTitle(context, 'Layer'),
          const SizedBox(height: 6),
          layerNamesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Layers unavailable',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (layerNames) {
              final ids = layerNames.keys.toList()..sort();
              return DropdownButtonFormField<String>(
                value: state.layerId,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                hint: const Text('Select a layer…'),
                items: ids.map((id) {
                  return DropdownMenuItem(
                    value: id,
                    child: Text(
                      layerNames[id] ?? id,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => notifier.setLayer(v),
              );
            },
          ),

          const SizedBox(height: 16),

          // Conditions
          _sectionTitle(context, 'Where (all must match)'),
          const SizedBox(height: 8),

          if (state.layerId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Pick a layer first.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            _SearchIndexBanner(
              projectId: projectId,
              layerId: state.layerId!,
            ),
            const SizedBox(height: 8),
            // Conditions — natural height, scrolls with the outer view
            ...state.conditions.map(
              (c) => ConditionRow(
                key: ValueKey(c.id),
                projectId: projectId,
                layerId: state.layerId!,
                condition: c,
                onChanged: (updated) => notifier.updateCondition(c.id, updated),
                onRemove: () => notifier.removeCondition(c.id),
              ),
            ),
            TextButton.icon(
              onPressed: notifier.addCondition,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add condition'),
            ),

            CheckboxListTile(
              value: state.caseSensitive,
              onChanged: (v) => notifier.setCaseSensitive(v ?? false),
              title: const Text('Case sensitive'),
              subtitle: Text(
                state.caseSensitive
                    ? 'Match exact letter case'
                    : 'Ignore letter case (recommended)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              tileColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
            ),

            const SizedBox(height: 8),

            // Action row
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.canRun && !state.isRunning
                        ? () => _runSearch(ref, notifier, state)
                        : null,
                    icon: state.isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(state.isRunning ? 'Searching…' : 'Search'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: notifier.clear,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),

            // Error banner
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Results — natural height, part of the outer scroll
            if (state.results != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              _InlineResults(
                results: state.results!,
                onResultTap: onResultTap,
                onResultDirections: onResultDirections,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _runSearch(
    WidgetRef ref,
    SearchQueryNotifier notifier,
    SearchQueryState state,
  ) async {
    final repo = ref.read(searchRepositoryProvider);
    if (repo == null) {
      notifier.setError('Database not available');
      return;
    }

    notifier.setRunning(true);
    try {
      final results = await repo.runQuery(
        projectId: projectId,
        layerId: state.layerId!,
        conditions: state.conditions,
        caseSensitive: state.caseSensitive,
      );
      notifier.setResults(results);
    } catch (e) {
      notifier.setError(_prettyError(e));
    }
  }

  String _prettyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('json_extract') || msg.contains('json_each')) {
      return 'SQL error running query. Check attribute names.';
    }
    return 'Search failed: $msg';
  }
}

/// Warns when the layer pack has no local search index (SQLite rows).
class _SearchIndexBanner extends ConsumerWidget {
  final String projectId;
  final String layerId;

  const _SearchIndexBanner({
    required this.projectId,
    required this.layerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(
      searchIndexCountProvider((projectId: projectId, layerId: layerId)),
    );

    return countAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (count) {
        if (count > 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 18,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No offline search data for this layer. Re-download the '
                  'project (or open the map and wait for layer packs) after '
                  'updating the server.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Inline results renderer — used inside the scrollable search panel.
/// Doesn't use Expanded so it can live inside a SingleChildScrollView.
class _InlineResults extends StatelessWidget {
  final List<SearchResult> results;
  final ResultTapCallback onResultTap;
  final ResultTapCallback? onResultDirections;
  final int maxDisplay;

  const _InlineResults({
    required this.results,
    required this.onResultTap,
    this.onResultDirections,
    this.maxDisplay = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No matches',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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

        // Rows
        for (int i = 0; i < displayed.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
          _InlineResultRow(
            result: displayed[i],
            onTap: () => onResultTap(displayed[i]),
            onDirections: onResultDirections == null
                ? null
                : () => onResultDirections!(displayed[i]),
          ),
        ],
      ],
    );
  }
}

class _InlineResultRow extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final VoidCallback? onDirections;

  const _InlineResultRow({
    required this.result,
    required this.onTap,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = result.secondaryLabel;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
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
            if (onDirections != null)
              IconButton(
                tooltip: 'Directions',
                onPressed: onDirections,
                icon: Icon(
                  Icons.directions,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                visualDensity: VisualDensity.compact,
              )
            else
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

/// Compact "go to lat / lng" control for the search panel.
///
/// Two numeric fields so the device shows a number pad (digits + decimal)
/// without a letter keyboard. Comma-as-decimal is normalized on parse.
class _GoToCoordinates extends StatefulWidget {
  final GoToLocationCallback onGoTo;

  const _GoToCoordinates({required this.onGoTo});

  @override
  State<_GoToCoordinates> createState() => _GoToCoordinatesState();
}

class _GoToCoordinatesState extends State<_GoToCoordinates> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _lngFocus = FocusNode();
  String? _error;

  static final _coordFilter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'));

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _lngFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseLatLngPair(_latController.text, _lngController.text);
    if (parsed == null) {
      setState(() {
        _error = 'Enter valid latitude (−90…90) and longitude (−180…180)';
      });
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    widget.onGoTo(parsed.$1, parsed.$2);
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Go to location',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _lngFocus.requestFocus(),
                inputFormatters: [_coordFilter],
                decoration: _fieldDecoration('Lat', '5.6037'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lngController,
                focusNode: _lngFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                inputFormatters: [_coordFilter],
                decoration: _fieldDecoration('Lng', '-0.1870'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _submit,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Go'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
