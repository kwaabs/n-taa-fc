import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_state.dart';
import 'notification_repository.dart';
import 'notifications_sheet.dart';

/// Global messenger so poll alerts can show from any screen.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class NotificationInboxState {
  final int unreadCount;
  final List<AppNotification> items;
  final bool ready;

  /// Set when unread increases; consumed by [NotificationHost] for a SnackBar.
  final AppNotification? pendingAlert;

  const NotificationInboxState({
    this.unreadCount = 0,
    this.items = const [],
    this.ready = false,
    this.pendingAlert,
  });

  NotificationInboxState copyWith({
    int? unreadCount,
    List<AppNotification>? items,
    bool? ready,
    AppNotification? pendingAlert,
    bool clearAlert = false,
  }) {
    return NotificationInboxState(
      unreadCount: unreadCount ?? this.unreadCount,
      items: items ?? this.items,
      ready: ready ?? this.ready,
      pendingAlert: clearAlert ? null : (pendingAlert ?? this.pendingAlert),
    );
  }
}

class NotificationInboxNotifier extends StateNotifier<NotificationInboxState> {
  NotificationInboxNotifier(this._ref) : super(const NotificationInboxState());

  final Ref _ref;
  Timer? _timer;
  int _lastKnownUnread = 0;
  bool _running = false;

  static const _pollInterval = Duration(seconds: 30);

  void start() {
    if (_running) return;
    _running = true;
    unawaited(refresh(announce: false));
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh(announce: true));
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _lastKnownUnread = 0;
    state = const NotificationInboxState();
  }

  Future<void> refresh({bool announce = true}) async {
    final repo = _ref.read(notificationRepositoryProvider);
    if (repo == null) return;

    try {
      final unread = await repo.list(unreadOnly: true);
      final count = unread.length;
      AppNotification? alert;
      if (announce &&
          state.ready &&
          count > _lastKnownUnread &&
          unread.isNotEmpty) {
        alert = unread.first;
      }
      _lastKnownUnread = count;
      state = state.copyWith(
        unreadCount: count,
        items: unread,
        ready: true,
        pendingAlert: alert,
      );
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Offline / transient — keep last known state
    }
  }

  void clearPendingAlert() {
    if (state.pendingAlert != null) {
      state = state.copyWith(clearAlert: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
  (ref) {
    final notifier = NotificationInboxNotifier(ref);
    ref.onDispose(notifier.stop);

    // Start/stop with auth + connectivity to API (dio present).
    void sync() {
      final auth = ref.read(authProvider);
      final repo = ref.read(notificationRepositoryProvider);
      if (auth.isLoggedIn && repo != null) {
        notifier.start();
      } else {
        notifier.stop();
      }
    }

    ref.listen(authProvider, (_, __) => sync());
    ref.listen(notificationRepositoryProvider, (_, __) => sync());
    // Kick once after create
    Future.microtask(sync);

    return notifier;
  },
);

/// Wraps the logged-in tree: polls on resume and shows SnackBars for new items.
class NotificationHost extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationHost({super.key, required this.child});

  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationInboxProvider.notifier).refresh(announce: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationInboxState>(notificationInboxProvider, (prev, next) {
      final alert = next.pendingAlert;
      if (alert == null) return;
      if (prev?.pendingAlert?.id == alert.id) return;

      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) return;

      final isMessage = alert.kind == 'message';
      final label = isMessage
          ? 'New message: ${alert.title}'
          : 'New notification: ${alert.title}';

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
          content: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              messenger.hideCurrentSnackBar();
              final ctx = rootScaffoldMessengerKey.currentContext;
              if (ctx != null) showNotificationsSheet(ctx, ref);
            },
            child: Text(label),
          ),
        ),
      );
      ref.read(notificationInboxProvider.notifier).clearPendingAlert();
    });

    return widget.child;
  }
}
