import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_repository.dart';
import 'notification_inbox.dart';

Future<void> showNotificationsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return _NotificationsSheet(
            scrollController: scrollController,
          );
        },
      );
    },
  ).whenComplete(() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.read(notificationInboxProvider.notifier).refresh(announce: false);
  });
}

class _NotificationsSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _NotificationsSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notifications',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final repo = ref.read(notificationRepositoryProvider);
                  if (repo == null) return;
                  await repo.markAllRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationCountProvider);
                  ref
                      .read(notificationInboxProvider.notifier)
                      .refresh(announce: false);
                },
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load: $e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No notifications yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ListView.separated(
                controller: scrollController,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return ListTile(
                    leading: Icon(
                      n.kind == 'message'
                          ? (n.isUnread
                              ? Icons.mail
                              : Icons.mail_outline)
                          : (n.isUnread
                              ? Icons.notifications_active
                              : Icons.notifications_none),
                      color: n.isUnread
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      n.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            n.isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      n.body.isEmpty
                          ? (n.kind == 'message'
                              ? 'Supervisor message'
                              : 'Open the project to download updates')
                          : n.body,
                    ),
                    trailing: n.isUnread
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () async {
                      if (!n.isUnread) return;
                      final repo = ref.read(notificationRepositoryProvider);
                      if (repo == null) return;
                      await repo.markRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                      ref
                          .read(notificationInboxProvider.notifier)
                          .refresh(announce: false);
                    },
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
