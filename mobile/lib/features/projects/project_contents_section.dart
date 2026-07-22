import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assignment_detail_screen.dart';
import 'form_detail_screen.dart';
import 'layer_detail_screen.dart';
import 'local_data_providers.dart';

class ProjectContentsSection extends ConsumerWidget {
  final String projectId;
  const ProjectContentsSection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedAt = ref.watch(projectDownloadedAtProvider(projectId));

    return downloadedAt.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (when) {
        if (when == null) {
          return const _NotDownloadedCard();
        }
        return _ContentList(projectId: projectId, downloadedAt: when);
      },
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text('Could not load local data',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(message,
                style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NotDownloadedCard extends StatelessWidget {
  const _NotDownloadedCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined,
                color: theme.colorScheme.onSurfaceVariant, size: 36),
            const SizedBox(height: 8),
            Text('No local data yet', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Download a bundle above to use this project offline.',
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
}

class _ContentList extends ConsumerWidget {
  final String projectId;
  final DateTime downloadedAt;

  const _ContentList({required this.projectId, required this.downloadedAt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final forms = ref.watch(formsForProjectProvider(projectId));
    final layers = ref.watch(layersForProjectProvider(projectId));
    final choiceLists = ref.watch(choiceListsForProjectProvider(projectId));
    final assignments = ref.watch(assignmentsForProjectProvider(projectId));
    final refCount = ref.watch(referenceFeatureCountProvider(projectId));

    final formsList = forms.maybeWhen(data: (i) => i, orElse: () => null);
    final layersList = layers.maybeWhen(data: (i) => i, orElse: () => null);
    final clList = choiceLists.maybeWhen(data: (i) => i, orElse: () => null);
    final asgnList = assignments.maybeWhen(data: (i) => i, orElse: () => null);
    final formsCount = formsList?.length ?? 0;
    final layersCount = layersList?.length ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.folder_special_outlined,
            color: theme.colorScheme.primary),
        title: Text(
          'Project Contents',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$formsCount forms · $layersCount layers · downloaded ${_relativeTime(downloadedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContentSection(
            icon: Icons.description_outlined,
            title: 'Forms',
            items: formsList?.map((f) => f.name).toList(),
            onItemTap: formsList == null
                ? null
                : (index) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FormDetailScreen(form: formsList[index]),
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          _ContentSection(
            icon: Icons.layers_outlined,
            title: 'Layers',
            items: layersList?.map((l) => l.name).toList(),
            extraInfo: refCount.maybeWhen(
              data: (count) => count > 0 ? '$count reference features' : null,
              orElse: () => null,
            ),
            onItemTap: layersList == null
                ? null
                : (index) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LayerDetailScreen(layer: layersList[index]),
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          _ContentSection(
            icon: Icons.list_outlined,
            title: 'Choice Lists',
            items: clList?.map((c) => c.name).toList(),
          ),
          const SizedBox(height: 12),
          _ContentSection(
            icon: Icons.assignment_outlined,
            title: 'My Assignments',
            items:
                asgnList?.map((a) => a.title ?? 'Untitled assignment').toList(),
            onItemTap: asgnList == null
                ? null
                : (index) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AssignmentDetailScreen(assignment: asgnList[index]),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

class _ContentSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String>? items;
  final String? extraInfo;
  final void Function(int index)? onItemTap;

  const _ContentSection({
    required this.icon,
    required this.title,
    required this.items,
    this.extraInfo,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = items == null;
    final count = items?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isLoading ? '—' : '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(left: 22, top: 2),
            child: Text(
              'Loading...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        else if (count == 0)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              'None',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < items!.length; i++)
                  InkWell(
                    onTap: onItemTap != null ? () => onItemTap!(i) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 4,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              items![i],
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (onItemTap != null)
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (extraInfo != null)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4),
            child: Text(
              extraInfo!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
