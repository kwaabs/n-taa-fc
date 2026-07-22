import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/gnss/location_provider.dart';

/// Controller that renders the current user location on the map.
///
/// Given a [MapLibreMapController] and a [LocationProvider], it subscribes
/// to the provider's position stream and maintains three visual elements:
///
///   - A translucent accuracy ring (larger circle, low opacity)
///   - A pulsing outer ring (grows and fades)
///   - A solid blue dot (small circle, opaque)
///
/// The pulsing effect is driven by a periodic timer that adjusts the outer
/// ring's radius and opacity.
///
/// Call [start] when the setting is enabled, and [stop] when disabled or
/// when the screen is disposed. Multiple starts are safe.
///
/// This is intentionally NOT a widget — it's a controller. The map screen
/// owns it and drives its lifecycle.
class MyLocationLayer {
  final MapLibreMapController mapController;
  final LocationProvider locationProvider;

  StreamSubscription<Position>? _positionSub;
  Timer? _pulseTimer;

  Circle? _accuracyCircle;
  Circle? _pulseCircle;
  Circle? _dotCircle;

  Position? _lastPosition;

  // Pulse animation state
  double _pulseRadius = 8;
  double _pulseOpacity = 0.6;
  bool _pulseGrowing = true;

  bool _running = false;
  bool _permissionRequested = false;

  MyLocationLayer({
    required this.mapController,
    required this.locationProvider,
  });

  bool get isRunning => _running;

  /// Start streaming location. Idempotent.
  Future<bool> start({
    void Function(String reason)? onCannotStart,
  }) async {
    debugPrint('[myLocation] start() called, _running=$_running');
    if (_running) return true;

    // Phone GPS needs service+permission gates. External GNSS handled its own
    // permissions during pairing.
    if (locationProvider is PhoneLocationProvider) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[myLocation] service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        onCannotStart?.call('Location services are disabled on this device.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      debugPrint('[myLocation] initial permission: $permission');
      if (permission == LocationPermission.denied) {
        if (_permissionRequested) {
          debugPrint('[myLocation] already asked once, giving up');
          onCannotStart?.call('Location permission denied.');
          return false;
        }
        _permissionRequested = true;
        permission = await Geolocator.requestPermission();
        debugPrint('[myLocation] after request: $permission');
        if (permission == LocationPermission.denied) {
          onCannotStart?.call('Location permission denied.');
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        onCannotStart?.call(
          'Location permission permanently denied. Enable in system settings.',
        );
        return false;
      }
    }

    debugPrint('[myLocation] using provider: ${locationProvider.name}');

    // Ensure the shared provider is running (idempotent — safe if geopoint
    // widget or other consumers already started it).
    try {
      await locationProvider.start();
      debugPrint(
          '[myLocation] provider started, isActive=${locationProvider.isActive}');
    } catch (e) {
      debugPrint('[myLocation] failed to start provider: $e');
      onCannotStart?.call('Could not start location: $e');
      return false;
    }

    // Subscribe to the shared broadcast stream
    _positionSub = locationProvider.positionStream.listen(
      _onPosition,
      onError: (e) {
        debugPrint('[myLocation] stream error: $e');
      },
    );

    _pulseTimer = Timer.periodic(
      const Duration(milliseconds: 60),
      (_) => _tickPulse(),
    );

    _running = true;
    debugPrint('[myLocation] running=true, waiting for positions...');

    // Seed with last-known position if the provider already has one
    // (e.g., another consumer started the stream earlier).
    final last = locationProvider.lastKnownPosition;
    if (last != null) {
      debugPrint('[myLocation] seeding from lastKnownPosition');
      await _onPosition(last);
    }

    return true;
  }

  /// Stop rendering. Does NOT stop the shared provider — other consumers
  /// (form geopoint capture, GPS tracking) may still be using it.
  Future<void> stop() async {
    _running = false;
    await _positionSub?.cancel();
    _positionSub = null;
    _pulseTimer?.cancel();
    _pulseTimer = null;

    await _removeCircles();

    _lastPosition = null;
    _pulseRadius = 8;
    _pulseOpacity = 0.6;
    _pulseGrowing = true;
  }

  Future<void> _removeCircles() async {
    if (_accuracyCircle != null) {
      try {
        await mapController.removeCircle(_accuracyCircle!);
      } catch (_) {}
      _accuracyCircle = null;
    }
    if (_pulseCircle != null) {
      try {
        await mapController.removeCircle(_pulseCircle!);
      } catch (_) {}
      _pulseCircle = null;
    }
    if (_dotCircle != null) {
      try {
        await mapController.removeCircle(_dotCircle!);
      } catch (_) {}
      _dotCircle = null;
    }
  }

  Future<void> _onPosition(Position pos) async {
    debugPrint('[myLocation] got position: '
        'lat=${pos.latitude.toStringAsFixed(5)} '
        'lng=${pos.longitude.toStringAsFixed(5)} '
        'acc=${pos.accuracy.toStringAsFixed(1)}m');
    _lastPosition = pos;
    final latLng = LatLng(pos.latitude, pos.longitude);
    final accuracyRadiusPx = _accuracyRingRadiusPx(pos.accuracy);

    // Accuracy ring
    try {
      if (_accuracyCircle == null) {
        _accuracyCircle = await mapController.addCircle(
          CircleOptions(
            geometry: latLng,
            circleRadius: accuracyRadiusPx,
            circleColor: '#2563EB',
            circleOpacity: 0.15,
            circleStrokeColor: '#2563EB',
            circleStrokeWidth: 1.5,
            circleStrokeOpacity: 0.35,
          ),
        );
      } else {
        await mapController.updateCircle(
          _accuracyCircle!,
          CircleOptions(
            geometry: latLng,
            circleRadius: accuracyRadiusPx,
          ),
        );
      }
    } catch (e, s) {
      debugPrint('[myLocation] accuracyCircle FAILED: $e\n$s');
    }

    // Pulse ring
    try {
      if (_pulseCircle == null) {
        _pulseCircle = await mapController.addCircle(
          CircleOptions(
            geometry: latLng,
            circleRadius: _pulseRadius,
            circleColor: '#2563EB',
            circleOpacity: 0.0,
            circleStrokeColor: '#2563EB',
            circleStrokeWidth: 2.0,
            circleStrokeOpacity: _pulseOpacity,
          ),
        );
      } else {
        await mapController.updateCircle(
          _pulseCircle!,
          CircleOptions(geometry: latLng),
        );
      }
    } catch (e, s) {
      debugPrint('[myLocation] pulseCircle FAILED: $e\n$s');
    }

    // Solid dot
    try {
      if (_dotCircle == null) {
        _dotCircle = await mapController.addCircle(
          CircleOptions(
            geometry: latLng,
            circleRadius: 7,
            circleColor: '#2563EB',
            circleOpacity: 1.0,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.5,
          ),
        );
      } else {
        await mapController.updateCircle(
          _dotCircle!,
          CircleOptions(geometry: latLng),
        );
      }
    } catch (e, s) {
      debugPrint('[myLocation] dotCircle FAILED: $e\n$s');
    }
  }

  double _accuracyRingRadiusPx(double accuracyMeters) {
    if (accuracyMeters <= 0) return 12;
    if (accuracyMeters < 5) return 12;
    if (accuracyMeters < 15) return 18;
    if (accuracyMeters < 30) return 26;
    if (accuracyMeters < 60) return 34;
    return 44;
  }

  void _tickPulse() {
    if (!_running || _pulseCircle == null) return;

    const minR = 8.0;
    const maxR = 22.0;
    const step = 0.4;

    if (_pulseGrowing) {
      _pulseRadius += step;
      _pulseOpacity = 0.6 * (1 - (_pulseRadius - minR) / (maxR - minR));
      if (_pulseRadius >= maxR) _pulseGrowing = false;
    } else {
      _pulseRadius -= step;
      _pulseOpacity = 0.6 * (1 - (_pulseRadius - minR) / (maxR - minR));
      if (_pulseRadius <= minR) _pulseGrowing = true;
    }
    _pulseOpacity = _pulseOpacity.clamp(0.0, 0.6);

    () async {
      try {
        await mapController.updateCircle(
          _pulseCircle!,
          CircleOptions(
            circleRadius: _pulseRadius,
            circleStrokeOpacity: _pulseOpacity,
          ),
        );
      } catch (_) {}
    }();
  }

  /// Returns the current known position, if any. Useful for a "Center on my
  /// location" button.
  Position? get currentPosition => _lastPosition;
}