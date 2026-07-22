import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently signed-in user id. Drives which offline SQLite file is open.
/// Null when logged out — no project DB is attached.
final sessionUserIdProvider = StateProvider<String?>((ref) => null);
