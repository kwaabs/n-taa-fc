import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_user.dart';
import 'app_database.dart';

/// Offline DB for the signed-in user only.
/// Each user gets `field_collector_<userId>.sqlite` so logins never inherit
/// or wipe another person's unsynced work.
final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  if (kIsWeb) return null;
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null || userId.isEmpty) return null;

  final database = AppDatabase.forUser(userId);
  ref.onDispose(() async {
    await database.close();
  });
  return database;
});
