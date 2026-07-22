import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../config/oauth_config.dart';
import 'auth_service.dart';

/// Handles OAuth sign-in via flutter_appauth (same as parent field-collector).
///
/// Flow:
/// 1. AppAuth → Azure with redirect `fieldcollector://auth-callback`
/// 2. Receive `id_token` (nonce hashed for Azure)
/// 3. `POST /gotrue/token?grant_type=id_token` with provider + raw nonce
///
/// Does NOT open GoTrue's browser authorize URL, so it does not depend on
/// `adb reverse` of port 5354 for the Azure → GoTrue web callback.
class OAuthService {
  final Dio _dio;
  final FlutterAppAuth _appAuth;

  OAuthService(this._dio) : _appAuth = const FlutterAppAuth();

  /// Raw nonce (for GoTrue) + SHA-256 hash (for the IdP).
  (String raw, String hashed) _generateNoncePair([int length = 32]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    final raw = base64Url.encode(bytes).replaceAll('=', '');
    final hashed = sha256.convert(utf8.encode(raw)).toString();
    return (raw, hashed);
  }

  Future<Tokens> signInWithProvider(String provider) async {
    late final String clientId;
    late final String discoveryUrl;
    late final List<String> scopes;

    switch (provider) {
      case 'azure':
        clientId = OAuthConfig.azureClientId;
        discoveryUrl = OAuthConfig.azureDiscoveryUrl;
        scopes = const ['openid', 'profile', 'email'];
        break;
      case 'google':
        clientId = OAuthConfig.googleClientId;
        discoveryUrl = OAuthConfig.googleDiscoveryUrl;
        scopes = const ['openid', 'profile', 'email'];
        break;
      default:
        throw AuthException('Unsupported provider: $provider');
    }

    final (rawNonce, hashedNonce) = _generateNoncePair();

    final AuthorizationTokenResponse result;
    try {
      result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          OAuthConfig.redirectUri,
          discoveryUrl: discoveryUrl,
          scopes: scopes,
          nonce: hashedNonce,
        ),
      );
    } catch (e) {
      throw _categorizeOAuthError(e);
    }

    final idToken = result.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException('Provider did not return an id_token');
    }

    final gotrueResponse = await _dio.post(
      '/gotrue/token',
      queryParameters: {'grant_type': 'id_token'},
      data: {
        'provider': provider,
        'id_token': idToken,
        'nonce': rawNonce,
      },
      options: Options(
        headers: {'Authorization': null},
        validateStatus: (_) => true,
      ),
    );

    if (gotrueResponse.statusCode != 200) {
      final data = gotrueResponse.data;
      String msg = 'GoTrue rejected id_token';
      if (data is Map) {
        msg = (data['error_description'] ?? data['msg'] ?? data['error'] ?? msg)
            .toString();
      }
      throw AuthException(msg);
    }

    final data = gotrueResponse.data;
    if (data is! Map<String, dynamic>) {
      throw AuthException('Unexpected GoTrue response');
    }

    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    final expiresAt = data['expires_at'] is int
        ? data['expires_at'] as int
        : int.tryParse(data['expires_at']?.toString() ?? '');

    if (accessToken == null || refreshToken == null) {
      throw AuthException('GoTrue response missing tokens');
    }

    return Tokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  AuthException _categorizeOAuthError(Object e) {
    final s = e.toString().toLowerCase();

    if (e is PlatformException) {
      final code = e.code.toLowerCase();
      if (code.contains('cancel') ||
          code == 'null_intent' ||
          s.contains('cancel')) {
        return AuthException('Sign-in cancelled.', AuthErrorType.cancelled);
      }
      if (s.contains('access_denied') || s.contains('denied')) {
        return AuthException(
          'Sign-in was denied. Please try again.',
          AuthErrorType.denied,
        );
      }
      if (s.contains('redirect') ||
          s.contains('invalid_client') ||
          s.contains('invalid_request')) {
        return AuthException(
          'Sign-in configuration error. Contact your administrator.',
          AuthErrorType.config,
        );
      }
      return AuthException(
        'Sign-in failed. Please try again.',
        AuthErrorType.unknown,
      );
    }

    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return AuthException(
            'Network error. Check your connection and try again.',
            AuthErrorType.network,
          );
        default:
          return AuthException(
            'Authentication failed. Please try again.',
            AuthErrorType.server,
          );
      }
    }

    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('timeout')) {
      return AuthException(
        'Network error. Check your connection and try again.',
        AuthErrorType.network,
      );
    }

    return AuthException(
      'Sign-in failed. Please try again.',
      AuthErrorType.unknown,
    );
  }
}

final oauthServiceProvider = Provider<OAuthService?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return OAuthService(dio);
});
