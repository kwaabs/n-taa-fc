import 'dart:convert';

class Project {
  final String id;
  final String name;
  final String? description;
  final String mode; // 'form_collection' | 'map_based'
  final String status; // 'draft' | 'active' | 'archived'
  final int version;
  final DateTime? updatedAt;
  /// GeoJSON geometry map (Polygon / MultiPolygon) when the project has an AOI.
  final Map<String, dynamic>? areaOfInterest;

  const Project({
    required this.id,
    required this.name,
    this.description,
    required this.mode,
    required this.status,
    required this.version,
    this.updatedAt,
    this.areaOfInterest,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      mode: json['mode']?.toString() ?? 'form_collection',
      status: json['status']?.toString() ?? 'draft',
      version: json['version'] is int ? json['version'] as int : 1,
      updatedAt: _parseDate(json['updated_at']),
      areaOfInterest: _parseGeometry(json['area_of_interest']),
    );
  }

  bool get isMapBased => mode == 'map_based';
  bool get isActive => status == 'active';
  bool get hasAoi => areaOfInterest != null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _parseGeometry(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    try {
      return _parseGeometry(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final type = map['type']?.toString();
    if (type == 'Polygon' || type == 'MultiPolygon') return map;
    if (type == 'Feature') return _parseGeometry(map['geometry']);
    if (type == 'FeatureCollection' && map['features'] is List) {
      final features = map['features'] as List;
      if (features.isNotEmpty) {
        return _parseGeometry(features.first);
      }
    }
  }
  return null;
}
