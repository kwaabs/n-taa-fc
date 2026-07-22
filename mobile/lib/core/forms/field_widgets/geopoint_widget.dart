import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../gnss/active_location_provider.dart';
import '../../gnss/location_provider.dart';
import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class GeoPointWidget extends ConsumerStatefulWidget {
  final FormFieldSpec field;
  const GeoPointWidget({super.key, required this.field});

  @override
  ConsumerState<GeoPointWidget> createState() => _GeoPointWidgetState();
}

class _GeoPointWidgetState extends ConsumerState<GeoPointWidget> {
  // Capture state
  bool _capturing = false;
  String? _captureError;

  // Live acquisition telemetry
  int _elapsedSeconds = 0;
  Position? _bestFix;
  StreamSubscription<Position>? _positionSub;
  Timer? _tickTimer;

  // Timeouts and accuracy tiers
  static const int _totalBudgetSec = 45;
  static const double _accuracyTier1 = 10;
  static const double _accuracyTier2 = 25;
  static const double _accuracyTier3 = 50;

  double _currentAccuracyTarget() {
    if (_elapsedSeconds < 15) return _accuracyTier1;
    if (_elapsedSeconds < 30) return _accuracyTier2;
    return _accuracyTier3;
  }

  @override
  void dispose() {
    _cancelCapture(silent: true);
    super.dispose();
  }

  Future<void> _capture(FormController ctrl) async {
    setState(() {
      _capturing = true;
      _captureError = null;
      _elapsedSeconds = 0;
      _bestFix = null;
    });

    try {
      final provider = ref.read(activeLocationProvider);
      debugPrint('[geopoint] using provider: ${provider.name}');

      // Phone GPS needs service+permission gates. External GNSS handled its own
      // permissions during pairing.
      if (provider is PhoneLocationProvider) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          throw Exception(
              'Location services are disabled. Enable GPS in device settings.');
        }

        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever) {
          throw Exception(
              'Location permission permanently denied. Enable it in app settings.');
        }
        if (perm == LocationPermission.denied) {
          throw Exception('Location permission was denied.');
        }
      }

      // Ensure the provider is running (idempotent)
      await provider.start();
      debugPrint('[geopoint] provider started, isActive=${provider.isActive}');

      // Seed with last-known if available
      final last = provider.lastKnownPosition;
      if (last != null && mounted) {
        final ageSec = DateTime.now().difference(last.timestamp).inSeconds;
        if (ageSec < 300) {
          setState(() => _bestFix = last);
          debugPrint(
              '[geopoint] seeded from lastKnown: ±${last.accuracy.toStringAsFixed(1)}m (age ${ageSec}s)');
        }
      }

      final completer = Completer<Position>();

      // Tick timer
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _elapsedSeconds++);
        debugPrint('[geopoint] tick=${_elapsedSeconds}s '
            'best=${_bestFix?.accuracy.toStringAsFixed(1) ?? "none"}m '
            'target=${_currentAccuracyTarget().toStringAsFixed(0)}m');
        if (_elapsedSeconds >= _totalBudgetSec) {
          t.cancel();
          if (!completer.isCompleted) {
            if (_bestFix != null) {
              completer.complete(_bestFix);
            } else {
              completer.completeError(
                Exception(
                    'Could not get a GPS fix within ${_totalBudgetSec}s. '
                    'Move to a more open area and try again.'),
              );
            }
          }
        }
      });

      // Listen to the shared provider stream
      _positionSub = provider.positionStream.listen((pos) {
        if (!mounted) return;
        debugPrint(
            '[geopoint] fix: lat=${pos.latitude} lng=${pos.longitude} acc=${pos.accuracy}m');

        if (_bestFix == null || pos.accuracy < _bestFix!.accuracy) {
          setState(() => _bestFix = pos);
        }

        final target = _currentAccuracyTarget();
        if (pos.accuracy <= target && !completer.isCompleted) {
          completer.complete(pos);
        }
      }, onError: (e) {
        debugPrint('[geopoint] stream error: $e');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      });

      final pos = await completer.future;

      await _positionSub?.cancel();
      _positionSub = null;
      _tickTimer?.cancel();
      _tickTimer = null;

      ctrl.setValue(widget.field.id, {
        'type': 'Point',
        'coordinates': [pos.longitude, pos.latitude],
        'accuracy': pos.accuracy,
        'altitude': pos.altitude,
        'captured_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[geopoint] capture failed: $e');
      if (mounted) {
        setState(() => _captureError =
            e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      await _positionSub?.cancel();
      _positionSub = null;
      _tickTimer?.cancel();
      _tickTimer = null;
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _useCurrentBest(FormController ctrl) {
    final best = _bestFix;
    if (best == null) return;
    ctrl.setValue(widget.field.id, {
      'type': 'Point',
      'coordinates': [best.longitude, best.latitude],
      'accuracy': best.accuracy,
      'altitude': best.altitude,
      'captured_at': DateTime.now().toIso8601String(),
    });
    _cancelCapture();
  }

  void _cancelCapture({bool silent = false}) {
    _positionSub?.cancel();
    _positionSub = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    if (mounted && !silent) {
      setState(() {
        _capturing = false;
        _elapsedSeconds = 0;
        _bestFix = null;
      });
    }
  }

  void _fakeCapture(FormController ctrl) {
    // Debug-only: injects a hardcoded fix near Accra center.
    ctrl.setValue(widget.field.id, {
      'type': 'Point',
      'coordinates': [-0.187, 5.6037],
      'accuracy': 5.0,
      'altitude': 61.0,
      'captured_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final raw = ctrl.getValue(widget.field.id);
    final error = ctrl.getError(widget.field.id);
    final theme = Theme.of(context);

    Map<String, dynamic>? captured;
    if (raw is Map) {
      captured = Map<String, dynamic>.from(raw);
    }

    return FieldLabel(
      field: widget.field,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (captured != null && captured['coordinates'] is List) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat: ${(captured['coordinates'] as List)[1].toStringAsFixed(6)}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        Text(
                          'Lng: ${(captured['coordinates'] as List)[0].toStringAsFixed(6)}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        if (captured['accuracy'] != null)
                          Text(
                            'Accuracy: ${(captured['accuracy'] as num).toStringAsFixed(1)} m',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => ctrl.setValue(widget.field.id, null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (_capturing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Acquiring GPS · ${_elapsedSeconds}s / ${_totalBudgetSec}s',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bestFix == null
                        ? 'Searching for satellites…'
                        : 'Best so far: ±${_bestFix!.accuracy.toStringAsFixed(1)} m '
                            '(target ≤${_currentAccuracyTarget().toStringAsFixed(0)} m)',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_bestFix != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _useCurrentBest(ctrl),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Use current fix'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _cancelCapture(),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _cancelCapture(),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (!_capturing) ...[
            FilledButton.icon(
              onPressed: () => _capture(ctrl),
              icon: Icon(captured == null ? Icons.gps_fixed : Icons.refresh),
              label: Text(captured == null ? 'Capture Location' : 'Recapture'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _fakeCapture(ctrl),
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('DEBUG: Inject fake fix'),
              ),
            ],
          ],

          if (_captureError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _captureError!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _capture(ctrl),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}