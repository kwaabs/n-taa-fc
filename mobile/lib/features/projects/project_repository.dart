import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_responses.dart';
import '../../core/api/dio_client.dart';
import 'project_model.dart';

class ProjectRepository {
  final Dio _dio;
  ProjectRepository(this._dio);

  Future<List<Project>> list() async {
    final response = await _dio.get('/api/v1/projects');
    if (response.statusCode != 200) {
      throw Exception('Failed to list projects (HTTP ${response.statusCode})');
    }
    return unwrapList(response.data, (item) {
      return Project.fromJson(item as Map<String, dynamic>);
    });
  }

  Future<Project> get(String projectId) async {
    final response = await _dio.get('/api/v1/projects/$projectId');
    if (response.statusCode != 200) {
      throw Exception('Failed to load project (HTTP ${response.statusCode})');
    }
    return unwrap(response.data, (data) {
      return Project.fromJson(data as Map<String, dynamic>);
    });
  }
}

final projectRepositoryProvider = Provider<ProjectRepository?>((ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) return null;
  return ProjectRepository(dio);
});

final projectsListProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return [];
  return repo.list();
});