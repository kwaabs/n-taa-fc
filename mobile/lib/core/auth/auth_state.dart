import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../storage.dart';
import 'auth_service.dart';
import 'oauth_service.dart';
import 'session_user.dart';

class AuthState {
  final bool initialized;
  final AuthUser? user;

  const AuthState({this.initialized = false, this.user});

  bool get isLoggedIn => user != null;

  AuthState copyWith(
      {bool? initialized, AuthUser? user, bool clearUser = false}) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

const String _kUserId = 'auth_user_id';
const String _kUserEmail = 'auth_user_email';
const String _kUserFullName = 'auth_user_full_name';

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    await hydrateTokens(_ref);
    final tokens = _ref.read(tokenStoreProvider).current;

    if (!tokens.hasValidAccessToken && tokens.refreshToken != null) {
      final auth = _ref.read(authServiceProvider);
      if (auth != null) {
        try {
          final result = await auth.refresh(tokens.refreshToken!);
          await writeTokens(_ref, result.tokens);
          await _writeUser(result.user);
          _bindSession(result.user.id);
          state = AuthState(initialized: true, user: result.user);
          return;
        } catch (_) {
          await clearTokens(_ref);
          await _clearUser();
          _bindSession(null);
        }
      }
    }

    if (tokens.hasValidAccessToken) {
      final user = await _readUser();
      _bindSession(user?.id);
      state = AuthState(initialized: true, user: user);
      return;
    }

    _bindSession(null);
    state = const AuthState(initialized: true);
  }

  Future<void> login(String email, String password) async {
    final auth = _ref.read(authServiceProvider);
    if (auth == null) {
      throw AuthException('Server not configured');
    }
    final result = await auth.login(email: email, password: password);
    await _completeLogin(result.user, result.tokens);
  }

  Future<void> loginWithOAuth(String provider) async {
    final oauth = _ref.read(oauthServiceProvider);
    final auth = _ref.read(authServiceProvider);
    if (oauth == null || auth == null) {
      throw AuthException('Server not configured');
    }

    final tokens = await oauth.signInWithProvider(provider);
    final user = await auth.fetchUser(tokens.accessToken!);
    await _completeLogin(user, tokens);
  }

  Future<void> _completeLogin(AuthUser user, Tokens tokens) async {
    await writeTokens(_ref, tokens);
    await _writeUser(user);
    // Switching sessionUserId closes the previous user's DB and opens this
    // user's file — no wipe, no shared offline data.
    _bindSession(user.id);
    state = AuthState(initialized: true, user: user);
  }

  Future<void> logout() async {
    await clearTokens(_ref);
    await _clearUser();
    _bindSession(null);
    state = const AuthState(initialized: true);
  }

  void _bindSession(String? userId) {
    _ref.read(sessionUserIdProvider.notifier).state = userId;
  }

  Future<void> _writeUser(AuthUser user) async {
    final s = _ref.read(secureStorageProvider);
    await s.write(key: _kUserId, value: user.id);
    await s.write(key: _kUserEmail, value: user.email);
    if (user.fullName != null) {
      await s.write(key: _kUserFullName, value: user.fullName);
    }
  }

  Future<AuthUser?> _readUser() async {
    final s = _ref.read(secureStorageProvider);
    final id = await s.read(key: _kUserId);
    final email = await s.read(key: _kUserEmail);
    if (id == null || email == null) return null;
    final fullName = await s.read(key: _kUserFullName);
    return AuthUser(id: id, email: email, fullName: fullName);
  }

  Future<void> _clearUser() async {
    final s = _ref.read(secureStorageProvider);
    await s.delete(key: _kUserId);
    await s.delete(key: _kUserEmail);
    await s.delete(key: _kUserFullName);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
