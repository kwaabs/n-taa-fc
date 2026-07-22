import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/gnss/active_location_provider.dart';
import '../../../core/gnss/location_provider.dart';

class GpsTrackResult {
  final List<LatLng> vertices;
  final double totalDistanceMeters;

  GpsTrackResult({
    required this.vertices,
    required this.totalDistanceMeters,
  });
}

typedef OnPositionUpdate = void Function(Position position);
typedef OnVerticesUpdate = void Function(List<LatLng> vertices);

Future<GpsTrackResult?> showGpsTrackSheet({
  required BuildContext context,
  required String layerName,
  required bool isPolygon,
  OnPositionUpdate? onPosition,
  OnVerticesUpdate? onVerticesChanged,
}) {
  return showModalBottomSheet<GpsTrackResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _GpsTrackSheet(
      layerName: layerName,
      isPolygon: isPolygon,
      onPosition: onPosition,
      onVerticesChanged: onVerticesChanged,
    ),
  );
}

class _GpsTrackSheet extends ConsumerStatefulWidget {
  final String layerName;
  final bool isPolygon;
  final OnPositionUpdate? onPosition;
  final OnVerticesUpdate? onVerticesChanged;

  const _GpsTrackSheet({
    required this.layerName,
    required this.isPolygon,
    this.onPosition,
    this.onVerticesChanged,
  });

  @override
  ConsumerState<_GpsTrackSheet> createState() => _GpsTrackSheetState();
}

/// Tracking session state machine.
enum _TrackStatus {
  starting, // waiting for first fix
  recording, // actively recording
  paused, // user paused
  gpsLost, // auto-paused because GPS dropped out
  poorAccuracy, // fix is too inaccurate to record (but still being received)
  error, // permission/service error
}

class _GpsTrackSheetState extends ConsumerState<_GpsTrackSheet> {
  // ── Tuning constants ─────────────────────────────────────────
  static const Duration _minTimeBetweenSamples = Duration(seconds: 2);
  static const double _minDistanceBetweenSamplesM = 3.0;
  static const double _maxAccuracyMeters = 20.0; // reject worse than this
  static const Duration _gpsLossTimeout = Duration(seconds: 10);

  // ── State ────────────────────────────────────────────────────
  StreamSubscription<Position>? _sub;
  Timer? _gpsLossWatchdog;

  Position? _latest;
  DateTime? _lastFixTime;
  DateTime? _lastSampleTime;
  LatLng? _lastSampleLatLng;
  final List<LatLng> _vertices = [];
  double _totalDistanceM = 0.0;

  String? _error;
  bool _starting = true;
  bool _paused = false;
  bool _gpsLost = false;

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _gpsLossWatchdog?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final provider = ref.read(activeLocationProvider);
      debugPrint('[gpsTrack] using provider: ${provider.name}');

      // Phone GPS needs service+permission gates. External GNSS handled its own
      // permissions during pairing.
      if (provider is PhoneLocationProvider) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _error = 'Location services are disabled.';
            _starting = false;
          });
          return;
        }

        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          setState(() {
            _error = 'Location permission denied.';
            _starting = false;
          });
          return;
        }
      }

      // Ensure the shared provider is running (idempotent)
      await provider.start();
      debugPrint('[gpsTrack] provider started, isActive=${provider.isActive}');

      // Subscribe to the shared broadcast stream
      _sub = provider.positionStream.listen(_onPosition, onError: (e) {
        if (!mounted) return;
        setState(() => _error = 'Location error: $e');
      });

      // Watchdog: fires periodically; if no fix in N seconds, mark GPS lost.
      _gpsLossWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) return;
        final last = _lastFixTime;
        if (last == null) return;
        final age = DateTime.now().difference(last);
        if (age > _gpsLossTimeout && !_gpsLost) {
          setState(() => _gpsLost = true);
        }
      });

      if (mounted) setState(() => _starting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to start GPS: $e';
          _starting = false;
        });
      }
    }
  }

  // ── Position pipeline ────────────────────────────────────────
  void _onPosition(Position pos) {
    if (!mounted) return;

    _latest = pos;
    _lastFixTime = DateTime.now();

    // Always forward to the map (dot tracks even when paused / poor / lost).
    widget.onPosition?.call(pos);

    // GPS came back → clear gpsLost flag automatically.
    if (_gpsLost) _gpsLost = false;

    // Manual pause → don't record.
    if (_paused) {
      setState(() {});
      return;
    }

    // 🎯 Accuracy filter — silently skip readings worse than threshold.
    if (pos.accuracy > _maxAccuracyMeters) {
      setState(() {});
      return;
    }

    final now = DateTime.now();
    final candidate = LatLng(pos.latitude, pos.longitude);

    final bool shouldRecord;
    if (_lastSampleTime == null || _lastSampleLatLng == null) {
      shouldRecord = true;
    } else {
      final elapsed = now.difference(_lastSampleTime!);
      final dist = _haversineMeters(_lastSampleLatLng!, candidate);
      shouldRecord = elapsed >= _minTimeBetweenSamples &&
          dist >= _minDistanceBetweenSamplesM;
    }

    if (shouldRecord) {
      _addVertex(candidate, now);
    }

    setState(() {});
  }

  void _addVertex(LatLng v, DateTime now) {
    if (_lastSampleLatLng != null) {
      _totalDistanceM += _haversineMeters(_lastSampleLatLng!, v);
    }
    _vertices.add(v);
    _lastSampleTime = now;
    _lastSampleLatLng = v;
    widget.onVerticesChanged?.call(_polylineForMap());
  }

  /// Polyline shown on map. For polygons with ≥3 points, close the ring
  /// visually by repeating the first point at the end.
  List<LatLng> _polylineForMap() {
    if (widget.isPolygon && _vertices.length >= 3) {
      return [..._vertices, _vertices.first];
    }
    return List<LatLng>.from(_vertices);
  }

  // ── Manual controls ──────────────────────────────────────────
  void _onAddPointPressed() {
    final pos = _latest;
    if (pos == null) return;
    if (pos.accuracy > _maxAccuracyMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('GPS accuracy too poor '
              '(±${pos.accuracy.toStringAsFixed(0)} m). Point not added.'),
        ),
      );
      return;
    }
    final candidate = LatLng(pos.latitude, pos.longitude);
    _addVertex(candidate, DateTime.now());
    setState(() {});
  }

  void _onUndoPressed() {
    if (_vertices.isEmpty) return;
    _vertices.removeLast();

    if (_vertices.length < 2) {
      _totalDistanceM = 0.0;
      _lastSampleLatLng = _vertices.isEmpty ? null : _vertices.last;
    } else {
      _totalDistanceM = 0.0;
      for (int i = 1; i < _vertices.length; i++) {
        _totalDistanceM += _haversineMeters(_vertices[i - 1], _vertices[i]);
      }
      _lastSampleLatLng = _vertices.last;
    }

    widget.onVerticesChanged?.call(_polylineForMap());
    setState(() {});
  }

  void _onTogglePausePressed() {
    setState(() {
      _paused = !_paused;
      if (!_paused) {
        _lastSampleTime = null; // record next fix immediately
      }
    });
  }

  // ── Geometry helpers ─────────────────────────────────────────
  double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusM * c;
  }

  // ── Derived state ────────────────────────────────────────────
  _TrackStatus get _status {
    if (_error != null) return _TrackStatus.error;
    if (_starting) return _TrackStatus.starting;
    if (_paused) return _TrackStatus.paused;
    if (_gpsLost) return _TrackStatus.gpsLost;
    final acc = _latest?.accuracy ?? double.infinity;
    if (acc > _maxAccuracyMeters) return _TrackStatus.poorAccuracy;
    return _TrackStatus.recording;
  }

  String _statusLabel(_TrackStatus s) {
    switch (s) {
      case _TrackStatus.starting:
        return 'STARTING';
      case _TrackStatus.recording:
        return 'REC';
      case _TrackStatus.paused:
        return 'PAUSED';
      case _TrackStatus.gpsLost:
        return 'GPS LOST';
      case _TrackStatus.poorAccuracy:
        return 'POOR GPS';
      case _TrackStatus.error:
        return 'ERROR';
    }
  }

  Color _statusColor(BuildContext context, _TrackStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case _TrackStatus.recording:
        return cs.error; // red rec dot
      case _TrackStatus.paused:
        return cs.outline;
      case _TrackStatus.gpsLost:
        return cs.error;
      case _TrackStatus.poorAccuracy:
        return cs.secondary;
      case _TrackStatus.starting:
        return cs.outline;
      case _TrackStatus.error:
        return cs.error;
    }
  }

  String _qualityLabel(double accuracy) {
    if (accuracy <= 8) return 'Excellent';
    if (accuracy <= 15) return 'Good';
    if (accuracy <= 25) return 'Fair';
    return 'Poor';
  }

  Color _qualityColor(BuildContext context, double accuracy) {
    final cs = Theme.of(context).colorScheme;
    if (accuracy <= 15) return cs.tertiary;
    if (accuracy <= 25) return cs.secondary;
    return cs.error;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(1)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  bool get _canFinish {
    if (widget.isPolygon) return _vertices.length >= 3;
    return _vertices.length >= 2;
  }

  bool get _canAddPoint =>
      _latest != null && _error == null && !_starting && !_gpsLost;
  bool get _canUndo => _vertices.isNotEmpty;

  void _onStop() {
    Navigator.pop(
      context,
      GpsTrackResult(
        vertices: List<LatLng>.from(_vertices),
        totalDistanceMeters: _totalDistanceM,
      ),
    );
  }

  void _onCancel() => Navigator.pop(context, null);

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = _status;
    final statusColor = _statusColor(context, status);

    final acc = _latest?.accuracy ?? double.infinity;
    final accColor =
        _latest == null ? cs.onSurfaceVariant : _qualityColor(context, acc);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────
            Row(
              children: [
                Icon(Icons.timeline, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isPolygon ? 'Tracking polygon' : 'Tracking line',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'for ${widget.layerName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // ── GPS Lost banner ────────────────────────
            if (status == _TrackStatus.gpsLost)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gps_off, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS lost — recording paused. '
                        'Will resume automatically when fix returns.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Poor accuracy banner ───────────────────
            if (status == _TrackStatus.poorAccuracy)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: cs.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS accuracy too poor (±${acc.toStringAsFixed(0)} m). '
                        'Points are not being recorded.',
                        style: TextStyle(color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Status panel ───────────────────────────
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              )
            else if (_starting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Acquiring GPS...'),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_list_numbered,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${_vertices.length} '
                          'point${_vertices.length == 1 ? "" : "s"}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.straighten, size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          _formatDistance(_totalDistanceM),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_latest != null)
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt,
                              size: 18, color: accColor),
                          const SizedBox(width: 6),
                          Text(
                            '±${acc.toStringAsFixed(1)} m '
                            '(${_qualityLabel(acc)})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: accColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (_latest != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lat ${_latest!.latitude.toStringAsFixed(6)}, '
                        'Lng ${_latest!.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // ── Action controls ────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _starting || _error != null
                        ? null
                        : _onTogglePausePressed,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    label: Text(_paused ? 'Resume' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canAddPoint ? _onAddPointPressed : null,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Add'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canUndo ? _onUndoPressed : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Footer (Cancel / Stop) ─────────────────
            Row(
              children: [
                TextButton.icon(
                  onPressed: _onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _canFinish ? _onStop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
            if (!_canFinish && _error == null && !_starting) ...[
              const SizedBox(height: 6),
              Text(
                widget.isPolygon
                    ? 'Walk to record at least 3 points to finish.'
                    : 'Walk to record at least 2 points to finish.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
