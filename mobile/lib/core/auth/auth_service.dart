import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';

class AuthUser {
  final String id;
  final String email;
  final String? fullName;
  final String role;
  final bool isSystemAdmin;

  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.role = 'field_worker',
    this.isSystemAdmin = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final meta = json['user_metadata'] as Map<String, dynamic>?;
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: meta?['full_name']?.toString(),
      role: json['role']?.toString() ?? 'field_worker',
      isSystemAdmin: json['is_system_admin'] == true,
    );
  }

  AuthUser copyWith({String? role, bool? isSystemAdmin}) {
    return AuthUser(
      id: id,
      email: email,
      fullName: fullName,
      role: role ?? this.role,
      isSystemAdmin: isSystemAdmin ?? this.isSystemAdmin,
    );
  }

  bool get canReconcile =>
      isSystemAdmin || role == 'supervisor' || role == 'admin';
  bool get canManage => isSystemAdmin || role == 'admin';
}

class AuthResult {
  final AuthUser user;
  final Tokens tokens;

  const AuthResult({required this.user, required this.tokens});
}

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // GoTrue is mounted at /gotrue per our backend setup; the JWT endpoint:
    final response = await _dio.post(
      '/gotrue/token',
      queryParameters: {'grant_type': 'password'},
      data: {'email': email, 'password': password},
      options: Options(
        // GoTrue uses its own error formatting; don't let interceptors fight it
        headers: {'Authorization': null},
      ),
    );

    if (response.statusCode != 200) {
      final data = response.data;
      String msg = 'Login failed';
      if (data is Map) {
        msg = (data['error_description'] ?? data['msg'] ?? data['error'] ?? msg)
            .toString();
      }
      throw AuthException(msg);
    }

    return _parseAuthResponse(response.data);
  }

  Future<AuthResult> refresh(String refreshToken) async {
    final response = await _dio.post(
      '/gotrue/token',
      queryParameters: {'grant_type': 'refresh_token'},
      data: {'refresh_token': refreshToken},
      options: Options(headers: {'Authorization': null}),
    );

    if (response.statusCode != 200) {
      throw AuthException('Refresh failed');
    }

    return _parseAuthResponse(response.data);
  }

  /// Fetches the current user's profile (including role) from our backend.
  Future<AuthUser> fetchMe(String accessToken) async {
    final response = await _dio.get(
      '/api/v1/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    if (response.statusCode != 200) {
      throw AuthException('Failed to fetch profile');
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw AuthException('Unexpected /me response');
    }
    return AuthUser.fromJson(data);
  }

  AuthResult _parseAuthResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw AuthException('Unexpected response');
    }
    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    final expiresAt = data['expires_at'] is int
        ? data['expires_at'] as int
        : int.tryParse(data['expires_at']?.toString() ?? '');
    final userJson = data['user'] as Map<String, dynamic>?;

    if (accessToken == null || refreshToken == null || userJson == null) {
      throw AuthException('Server response missing required fields');
    }

    return AuthResult(
      user: AuthUser.fromJson(userJson),
      tokens: Tokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      ),
    );
  }

  /// After OAuth completes, we have tokens but no user record yet.
  /// Fetch the user via GoTrue's /user endpoint.
  Future<AuthUser> fetchUser(String accessToken) async {
    final response = await _dio.get(
      '/gotrue/user',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    if (response.statusCode != 200) {
      throw AuthException('Failed to fetch user');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw AuthException('Unexpected /user response');
    }

    return AuthUser.fromJson(data);
  }
}

enum AuthErrorType { cancelled, network, denied, config, server, unknown }

class AuthException implements Exception {
  final String message;
  final AuthErrorType type;
  AuthException(this.message, [this.type = AuthErrorType.unknown]);
  @override
  String toString() => message;
}

final authServiceProvider = Provider<AuthService?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return AuthService(dio);
});
