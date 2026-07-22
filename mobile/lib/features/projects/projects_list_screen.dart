import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_data_providers.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/layout/responsive_grid.dart';
import '../../core/auth/auth_state.dart';
import '../../core/server_config.dart';

import 'project_detail_screen.dart';
import 'project_model.dart';
import 'project_repository.dart';

import '../settings/settings_screen.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notification_inbox.dart';
import '../notifications/notifications_sheet.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsListProvider);
    final user = ref.watch(authProvider).user;
    final config = ref.watch(serverConfigProvider).value;
    final unreadCount = ref.watch(notificationInboxProvider).unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => showNotificationsSheet(context, ref),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  ref.invalidate(projectsListProvider);
                  await ref
                      .read(notificationInboxProvider.notifier)
                      .refresh(announce: false);
                  break;
                case 'logout':
                  await ref.read(authProvider.notifier).logout();
                  break;
                case 'switch':
                  await ref.read(authProvider.notifier).logout();
                  await ref.read(serverConfigProvider.notifier).clear();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  dense: true,
                  title: Text(
                    user?.email ?? '',
                    style: theme.textTheme.bodySmall,
                  ),
                  subtitle: Text(
                    config?.label ?? config?.url ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                ),
              ),
              const PopupMenuItem(
                value: 'switch',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('Switch server'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectsListProvider);
          await ref
              .read(notificationInboxProvider.notifier)
              .refresh(announce: false);
          await ref.read(projectsListProvider.future);
        },
        child: projectsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(error: e.toString()),
          data: (projects) {
            if (projects.isEmpty) {
              return const _EmptyView();
            }
            return ResponsiveGrid(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final project in projects)
                  _ProjectCard(
                    project: project,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(project: project),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadedAt = ref.watch(projectDownloadedAtProvider(project.id));

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: project.isMapBased
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  project.isMapBased ? Icons.map_outlined : Icons.assignment,
                  color: project.isMapBased
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        downloadedAt.maybeWhen(
                          data: (when) => when != null
                              ? Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: theme.colorScheme.tertiary,
                                )
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (project.description != null &&
                        project.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        project.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusChip(status: project.status),
                        const SizedBox(width: 6),
                        _ModeChip(isMapBased: project.isMapBased),
                        const SizedBox(width: 6),
                        downloadedAt.maybeWhen(
                          data: (when) {
                            if (when == null) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.download_done,
                                    size: 12,
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Local',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg, label) = switch (status) {
      'active' => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
          'Active'
        ),
      'archived' => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
          'Archived'
        ),
      _ => (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
          'Draft'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final bool isMapBased;
  const _ModeChip({required this.isMapBased});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isMapBased ? 'Map' : 'Form',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      // ListView so pull-to-refresh works on empty state
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.folder_open,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No projects yet',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Ask your admin to add you to a project.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline,
          size: 48,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Failed to load projects',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Pull down to refresh',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
