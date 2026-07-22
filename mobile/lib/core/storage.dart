import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ────────────────────────────────────────────────
const String kAccessToken = 'access_token';
const String kRefreshToken = 'refresh_token';
const String kTokenExpiry = 'token_expires_at';
const String kServerUrl = 'server_url';
const String kServerLabel = 'server_label';
const String kCustomServerUrl = 'custom_server_url';

// ── Secure storage (encrypted) ──────────────────────────
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

// ── Shared prefs (unencrypted, for non-secret config) ───
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});