import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_responses.dart';
import '../../core/api/dio_client.dart';

class AppNotification {
  final String id;
  final String projectId;
  final String? assignmentId;
  final String kind;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.projectId,
    this.assignmentId,
    required this.kind,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      assignmentId: json['assignment_id'] as String?,
      kind: json['kind'] as String? ?? 'assignment_created',
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class NotificationRepository {
  final Dio _dio;
  NotificationRepository(this._dio);

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final response = await _dio.get(
      '/api/v1/notifications',
      queryParameters: {
        if (unreadOnly) 'unread': 'true',
        'limit': 50,
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load notifications (HTTP ${response.statusCode})',
      );
    }
    return unwrapList(response.data, (item) {
      return AppNotification.fromJson(item as Map<String, dynamic>);
    });
  }

  Future<int> unreadCount() async {
    final response = await _dio.get('/api/v1/notifications/unread-count');
    if (response.statusCode != 200) return 0;
    final data = unwrap(response.data, (d) => d as Map<String, dynamic>);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String notificationId) async {
    await _dio.patch('/api/v1/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _dio.post('/api/v1/notifications/read-all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return NotificationRepository(dio);
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  if (repo == null) return [];
  try {
    return await repo.list();
  } catch (_) {
    return [];
  }
});

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  if (repo == null) return 0;
  try {
    return await repo.unreadCount();
  } catch (_) {
    return 0;
  }
});
