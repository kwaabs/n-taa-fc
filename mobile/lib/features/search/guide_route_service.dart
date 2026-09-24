import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/api/api_responses.dart';
import '../../core/api/dio_client.dart';

/// One turn-by-turn line for the guide card.
class GuideDirectionStep {
  final String instruction;
  final double distanceMeters;
  final String? streetName;

  const GuideDirectionStep({
    required this.instruction,
    required this.distanceMeters,
    this.streetName,
  });

  factory GuideDirectionStep.fromJson(Map<String, dynamic> json) {
    return GuideDirectionStep(
      instruction: json['instruction']?.toString() ?? '',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      streetName: json['street_name']?.toString(),
    );
  }
}

/// Result of routing for the map guide overlay.
class GuideRouteResult {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double bearingDegrees;
  final bool followsRoads;
  final String hint;
  final List<GuideDirectionStep> steps;

  const GuideRouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.followsRoads,
    required this.hint,
    this.steps = const [],
  });
}

/// Fetches a road-following route when online; falls back to a straight segment.
class GuideRouteService {
  final Dio? _apiDio;

  GuideRouteService({Dio? apiDio}) : _apiDio = apiDio;

  GuideRouteResult straightLine({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    final from = LatLng(fromLat, fromLng);
    final to = LatLng(toLat, toLng);
    final distance = Geolocator.distanceBetween(
      fromLat,
      fromLng,
      toLat,
      toLng,
    );
    final bearing = Geolocator.bearingBetween(
      fromLat,
      fromLng,
      toLat,
      toLng,
    );
    return GuideRouteResult(
      geometry: [from, to],
      distanceMeters: distance,
      bearingDegrees: bearing,
      followsRoads: false,
      hint: 'Straight line — road route unavailable or offline.',
      steps: [
        GuideDirectionStep(
          instruction:
              'Go straight toward the destination (${_formatDistance(distance)})',
          distanceMeters: distance,
        ),
      ],
    );
  }

  static String formatDistancePublic(double meters) => _formatDistance(meters);

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  Future<GuideRouteResult> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final straight = straightLine(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );

    final api = _apiDio;
    if (api == null) {
      return straight;
    }

    try {
      final response = await api.get(
        '/api/v1/routing/guide',
        queryParameters: {
          'from_lat': fromLat,
          'from_lng': fromLng,
          'to_lat': toLat,
          'to_lng': toLng,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        if (kDebugMode) {
          debugPrint('[guide_route] API routing failed: HTTP $status');
        }
        return straight;
      }

      final body = _coerceJsonMap(response.data);
      if (body == null) {
        if (kDebugMode) {
          debugPrint('[guide_route] API routing: unexpected response body');
        }
        return straight;
      }
      if (body['error'] != null) {
        if (kDebugMode) {
          debugPrint('[guide_route] API routing error: ${body['error']}');
        }
        return straight;
      }

      final data = unwrap<Map<String, dynamic>?>(body, (d) {
        if (d is Map<String, dynamic>) return d;
        if (d is Map) return Map<String, dynamic>.from(d);
        return null;
      });
      if (data == null) return straight;

      final geom = data['geometry'];
      if (geom is! List || geom.length < 2) return straight;

      final points = <LatLng>[];
      for (final p in geom) {
        if (p is Map) {
          final lat = p['lat'];
          final lng = p['lng'];
          if (lat is num && lng is num) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      if (points.length < 2) return straight;

      final distance = (data['distance_meters'] as num?)?.toDouble() ??
          straight.distanceMeters;
      final followsRoads = data['follows_roads'] == true;

      final steps = <GuideDirectionStep>[];
      final rawSteps = data['steps'];
      if (rawSteps is List) {
        for (final s in rawSteps) {
          if (s is Map) {
            final step = GuideDirectionStep.fromJson(
              Map<String, dynamic>.from(s),
            );
            if (step.instruction.trim().isNotEmpty) {
              steps.add(step);
            }
          }
        }
      }

      final effectiveSteps = steps.isNotEmpty
          ? steps
          : (followsRoads
              ? [
                  GuideDirectionStep(
                    instruction:
                        'Follow the blue route on the map. '
                        'If turn-by-turn text is missing, restart fc-api.',
                    distanceMeters: distance,
                  ),
                ]
              : straight.steps);

      return GuideRouteResult(
        geometry: points,
        distanceMeters: distance,
        bearingDegrees: straight.bearingDegrees,
        followsRoads: followsRoads,
        hint: followsRoads
            ? 'Turn-by-turn directions follow the road network.'
            : straight.hint,
        steps: effectiveSteps,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[guide_route] road route unavailable (straight line): $e');
      }
      return straight;
    }
  }

  /// Dio may return a [Map], or a JSON [String] for some proxies/errors.
  static Map<String, dynamic>? _coerceJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}

final guideRouteServiceProvider = Provider<GuideRouteService>((ref) {
  final dio = ref.watch(dioProvider);
  return GuideRouteService(apiDio: dio);
});
