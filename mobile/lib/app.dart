import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_state.dart';
import 'core/server_config.dart';
import 'core/settings/settings_provider.dart';
import 'core/theme.dart';
import 'features/login/login_screen.dart';
import 'features/projects/projects_list_screen.dart';
import 'features/server/server_selection_screen.dart';
import 'features/notifications/notification_inbox.dart';

class FieldCollectorApp extends ConsumerWidget {
  const FieldCollectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Field Collector',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ref.watch(settingsProvider).value?.themeMode.toFlutter() ??
          ThemeMode.system,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends ConsumerWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(serverConfigProvider);
    final auth = ref.watch(authProvider);

    return configAsync.when(
      loading: () => const _LoadingScreen(),
      error: (e, _) => _ErrorScreen(message: e.toString()),
      data: (config) {
        if (config == null) {
          return const ServerSelectionScreen();
        }
        if (!auth.initialized) {
          return const _LoadingScreen();
        }
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return const NotificationHost(child: ProjectsListScreen());
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Initialization failed',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}