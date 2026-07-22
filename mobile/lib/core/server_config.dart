import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';

// ── Models ──────────────────────────────────────────────

class ServerPreset {
  final String label;
  final String url;
  final String description;
  final bool debugOnly;

  const ServerPreset({
    required this.label,
    required this.url,
    required this.description,
    this.debugOnly = false,
  });
}

const List<ServerPreset> kServerPresets = [
  ServerPreset(
    label: 'Production',
    url: 'https://api.fieldcollector.org',
    description: 'Official Field Collector service',
  ),
  ServerPreset(
    label: 'Staging',
    url: 'https://staging.fieldcollector.org',
    description: 'Test environment',
  ),
  ServerPreset(
    label: 'Local Emulator',
    url: 'http://10.0.2.2:5355',
    description: 'Dev backend (Android emulator)',
    debugOnly: true,
  ),
  ServerPreset(
    label: 'Local Browser',
    url: 'http://localhost:5355',
    description: 'Dev backend (Chrome on host)',
    debugOnly: true,
  ),
];

class ServerConfig {
  final String url;
  final String? label;

  const ServerConfig({required this.url, this.label});

  bool get isCustom => label == null;
}

// ── Connection test ─────────────────────────────────────

class ConnectionTestResult {
  final bool success;
  final String? error;
  final String? serverVersion;

  const ConnectionTestResult({
    required this.success,
    this.error,
    this.serverVersion,
  });
}

Future<ConnectionTestResult> testServerConnection(String url) async {
  final cleanedUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  if (cleanedUrl.isEmpty) {
    return const ConnectionTestResult(
      success: false,
      error: 'URL is empty',
    );
  }
  if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
    return const ConnectionTestResult(
      success: false,
      error: 'URL must start with http:// or https://',
    );
  }

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    validateStatus: (_) => true,
  ));

  try {
    final response = await dio.get('$cleanedUrl/health');
    if (response.statusCode == 200) {
      String? version;
      if (response.data is Map) {
        version = response.data['version']?.toString() ??
            response.data['service']?.toString();
      }
      return ConnectionTestResult(success: true, serverVersion: version);
    }
    return ConnectionTestResult(
      success: false,
      error: 'Server returned HTTP ${response.statusCode}',
    );
  } on DioException catch (e) {
    final msg = switch (e.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out',
      DioExceptionType.connectionError => 'Could not connect to server',
      _ => e.message ?? 'Connection failed',
    };
    return ConnectionTestResult(success: false, error: msg);
  } catch (e) {
    return ConnectionTestResult(success: false, error: e.toString());
  }
}

// ── Provider ────────────────────────────────────────────

class ServerConfigNotifier extends StateNotifier<AsyncValue<ServerConfig?>> {
  final SharedPreferences _prefs;

  ServerConfigNotifier(this._prefs) : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() {
    final url = _prefs.getString(kServerUrl);
    if (url == null || url.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    final label = _prefs.getString(kServerLabel);
    state = AsyncValue.data(ServerConfig(url: url, label: label));
  }

  Future<void> setServer({required String url, String? label}) async {
    await _prefs.setString(kServerUrl, url);
    if (label != null) {
      await _prefs.setString(kServerLabel, label);
    } else {
      await _prefs.remove(kServerLabel);
    }
    state = AsyncValue.data(ServerConfig(url: url, label: label));
  }

  Future<void> setCustomUrl(String url) async {
    await _prefs.setString(kCustomServerUrl, url);
  }

  String? get savedCustomUrl => _prefs.getString(kCustomServerUrl);

  Future<void> clear() async {
    await _prefs.remove(kServerUrl);
    await _prefs.remove(kServerLabel);
    state = const AsyncValue.data(null);
  }
}

final serverConfigProvider =
    StateNotifierProvider<ServerConfigNotifier, AsyncValue<ServerConfig?>>(
  (ref) {
    final prefsAsync = ref.watch(sharedPreferencesProvider);
    return prefsAsync.when(
      data: (prefs) => ServerConfigNotifier(prefs),
      loading: () => _LoadingNotifier(),
      error: (_, __) => _LoadingNotifier(),
    );
  },
);

// Placeholder while SharedPreferences is initializing
class _LoadingNotifier extends ServerConfigNotifier {
  _LoadingNotifier() : super(_DummyPrefs());
}

class _DummyPrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}