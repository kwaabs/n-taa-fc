import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../server_config.dart';
import '../storage.dart';

// ─────────────────────────────────────────────────────────
// Token data model
// ─────────────────────────────────────────────────────────

class Tokens {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresAt; // epoch seconds

  const Tokens({
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get hasValidAccessToken {
    if (accessToken == null) return false;
    if (expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt! > now;
  }

  bool get needsRefresh {
    if (accessToken == null || refreshToken == null) return false;
    if (expiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (expiresAt! - now) < 300; // less than 5 min remaining
  }

  bool get isEmpty => accessToken == null && refreshToken == null;
}

// ─────────────────────────────────────────────────────────
// In-memory token store
// ─────────────────────────────────────────────────────────

class TokenStore {
  Tokens _tokens = const Tokens();

  Tokens get current => _tokens;

  void set(Tokens tokens) {
    _tokens = tokens;
  }

  void clear() {
    _tokens = const Tokens();
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

// ─────────────────────────────────────────────────────────
// Dio provider
// ─────────────────────────────────────────────────────────

/// Dio configured for the API base. Adds token, handles refresh, surfaces errors.
final dioProvider = Provider<Dio?>((ref) {
  final configAsync = ref.watch(serverConfigProvider);
  final config = configAsync.value;
  if (config == null) return null;

  final tokenStore = ref.watch(tokenStoreProvider);

  final baseUrl = config.url.replaceAll(RegExp(r'/+$'), '');

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (s) => s != null && s < 500,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  dio.interceptors.add(_AuthInterceptor(tokenStore));
  dio.interceptors.add(
    _RefreshInterceptor(
      ref: ref,
      dio: dio,
      gotrueBaseUrl: baseUrl, // GoTrue is served behind the same proxy
    ),
  );

  return dio;
});

// ─────────────────────────────────────────────────────────
// Request interceptor: attaches bearer token
// ─────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final TokenStore _store;
  _AuthInterceptor(this._store);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _store.current.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
}

// ─────────────────────────────────────────────────────────
// Refresh-on-401 interceptor
// ─────────────────────────────────────────────────────────

class _RefreshInterceptor extends QueuedInterceptor {
  _RefreshInterceptor({
    required this.ref,
    required this.dio,
    required this.gotrueBaseUrl,
  });

  final Ref ref;
  final Dio dio;
  final String gotrueBaseUrl;

  bool _refreshing = false;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['__retried'] == true;

    if (status != 401 || alreadyRetried) {
      return handler.next(err);
    }

    final storage = ref.read(secureStorageProvider);
    final store = ref.read(tokenStoreProvider);

    final refreshToken = store.current.refreshToken ??
        await storage.read(key: kRefreshToken);

    if (refreshToken == null || refreshToken.isEmpty) {
      await _forceLogout();
      return handler.next(err);
    }

    if (_refreshing) {
      // Another refresh is in flight — let dio's queue logic handle ordering.
      return handler.next(err);
    }

    _refreshing = true;
    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: gotrueBaseUrl,
          connectTimeout: const Duration(seconds: 15),
        ),
      );

      final resp = await refreshDio.post(
        '/gotrue/token',
        queryParameters: {'grant_type': 'refresh_token'},
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (resp.statusCode != 200 || resp.data is! Map) {
        await _forceLogout();
        return handler.next(err);
      }

      final data = resp.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'];

      if (newAccess == null || newRefresh == null) {
        await _forceLogout();
        return handler.next(err);
      }

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = expiresIn is int
          ? nowSec + expiresIn
          : (expiresIn is String
              ? nowSec + (int.tryParse(expiresIn) ?? 3600)
              : nowSec + 3600);

      final tokens = Tokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
        expiresAt: expiresAt,
      );

      // Persist to both in-memory and secure storage using the project's
      // canonical keys, so other code paths see the new tokens.
      await writeTokens(ref, tokens);

      // Retry the original request once
      final original = err.requestOptions;
      original.headers['Authorization'] = 'Bearer $newAccess';
      original.extra['__retried'] = true;

      final retryResp = await dio.fetch(original);
      return handler.resolve(retryResp);
    } catch (_) {
      await _forceLogout();
      return handler.next(err);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _forceLogout() async {
    try {
      await clearTokens(ref);
    } catch (_) {
      // ignore: best-effort
    }
  }
}

// ─────────────────────────────────────────────────────────
// Token persistence helpers
// ─────────────────────────────────────────────────────────

/// Helper to load tokens from secure storage into the in-memory TokenStore.
Future<void> hydrateTokens(Ref ref) async {
  final storage = ref.read(secureStorageProvider);
  final store = ref.read(tokenStoreProvider);

  final access = await storage.read(key: kAccessToken);
  final refresh = await storage.read(key: kRefreshToken);
  final expiry = await storage.read(key: kTokenExpiry);

  store.set(Tokens(
    accessToken: access,
    refreshToken: refresh,
    expiresAt: expiry != null ? int.tryParse(expiry) : null,
  ));
}

/// Persist tokens to secure storage AND in-memory store.
Future<void> writeTokens(Ref ref, Tokens tokens) async {
  final storage = ref.read(secureStorageProvider);
  final store = ref.read(tokenStoreProvider);

  store.set(tokens);

  if (tokens.accessToken != null) {
    await storage.write(key: kAccessToken, value: tokens.accessToken);
  } else {
    await storage.delete(key: kAccessToken);
  }
  if (tokens.refreshToken != null) {
    await storage.write(key: kRefreshToken, value: tokens.refreshToken);
  } else {
    await storage.delete(key: kRefreshToken);
  }
  if (tokens.expiresAt != null) {
    await storage.write(key: kTokenExpiry, value: tokens.expiresAt.toString());
  } else {
    await storage.delete(key: kTokenExpiry);
  }
}

/// Clear tokens from both stores.
Future<void> clearTokens(Ref ref) async {
  final storage = ref.read(secureStorageProvider);
  final store = ref.read(tokenStoreProvider);

  store.clear();
  await storage.delete(key: kAccessToken);
  await storage.delete(key: kRefreshToken);
  await storage.delete(key: kTokenExpiry);
}