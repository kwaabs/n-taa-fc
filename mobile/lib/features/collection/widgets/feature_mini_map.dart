import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_provider.dart';
import '../../map/map_style.dart';

/// A read-only mini map that displays a single feature's geometry.
///
/// - Point → centered pin at coord, zoom 17
/// - Line / polygon → fit to bounds
/// - Uses the current basemap from settings
/// - Optional [onOpenFullMap] callback for an "expand" button overlay
class FeatureMiniMap extends ConsumerStatefulWidget {
  /// GeoJSON-like geometry map: { "type": "...", "coordinates": [...] }
  final Map<String, dynamic> geometry;

  /// Height of the map. Width fills the parent.
  final double height;

  /// Optional: callback for the "open in full map" button (top-right overlay).
  final VoidCallback? onOpenFullMap;

  const FeatureMiniMap({
    super.key,
    required this.geometry,
    this.height = 240,
    this.onOpenFullMap,
  });

  @override
  ConsumerState<FeatureMiniMap> createState() => _FeatureMiniMapState();
}

class _FeatureMiniMapState extends ConsumerState<FeatureMiniMap> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final basemapId = settings.basemap;

    // Compute initial camera from geometry
    final (initLat, initLng, initZoom) = _computeInitialCamera(widget.geometry);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            MapLibreMap(
              styleString: buildBasemapStyle(basemap: basemapId),
              initialCameraPosition: CameraPosition(
                target: LatLng(initLat, initLng),
                zoom: initZoom,
              ),
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              trackCameraPosition: false,
              onMapCreated: (c) => _controller = c,
              onStyleLoadedCallback: () async {
                _styleLoaded = true;
                await _renderGeometry();
              },
            ),
            if (widget.onOpenFullMap != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: widget.onOpenFullMap,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.open_in_full, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renderGeometry() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;

    final type = widget.geometry['type'] as String?;
    final coords = widget.geometry['coordinates'];
    if (type == null || coords == null) return;

    try {
      if (type == 'Point' && coords is List && coords.length >= 2) {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        await controller.addCircle(CircleOptions(
          geometry: LatLng(lat, lng),
          circleRadius: 8,
          circleColor: '#1976D2',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ));
      } else if (type == 'LineString' && coords is List) {
        final line = _coordsToLatLngList(coords);
        if (line.isNotEmpty) {
          await controller.addLine(LineOptions(
            geometry: line,
            lineColor: '#1976D2',
            lineWidth: 3,
          ));
          await _fitToBounds(line);
        }
      } else if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        final ring = _coordsToLatLngList(coords[0] as List);
        if (ring.isNotEmpty) {
          await controller.addFill(FillOptions(
            geometry: [ring],
            fillColor: '#1976D2',
            fillOpacity: 0.3,
            fillOutlineColor: '#1976D2',
          ));
          await _fitToBounds(ring);
        }
      }
    } catch (e) {
      debugPrint('[FeatureMiniMap] render failed: $e');
    }
  }

  List<LatLng> _coordsToLatLngList(List coords) {
    final result = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        result.add(LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ));
      }
    }
    return result;
  }

  Future<void> _fitToBounds(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 30, right: 30, top: 30, bottom: 30,
      ),
    );
  }

  static (double, double, double) _computeInitialCamera(
      Map<String, dynamic> geom) {
    final type = geom['type'];
    final coords = geom['coordinates'];

    if (type == 'Point' && coords is List && coords.length >= 2) {
      return (
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
        17.0,
      );
    }
    if (coords is List && coords.isNotEmpty) {
      dynamic first = coords[0];
      while (first is List && first.isNotEmpty && first[0] is List) {
        first = first[0];
      }
      if (first is List && first.length >= 2) {
        return (
          (first[1] as num).toDouble(),
          (first[0] as num).toDouble(),
          15.0,
        );
      }
    }
    return (0.0, 0.0, 1.0);
  }
}