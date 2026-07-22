import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/gnss/active_location_provider.dart';
import '../../../core/gnss/location_provider.dart';
import '../../../core/gnss/nmea_location_provider.dart';

/// Bottom sheet that acquires the current GPS fix and lets the worker
/// confirm it.
///
/// Returns the chosen [LatLng], or null if cancelled / failed.
Future<LatLng?> showGpsCaptureSheet({
  required BuildContext context,
  required String layerName,
}) {
  return showModalBottomSheet<LatLng>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _GpsCaptureSheet(layerName: layerName),
  );
}

class _GpsCaptureSheet extends ConsumerStatefulWidget {
  final String layerName;

  const _GpsCaptureSheet({
    required this.layerName,
  });

  @override
  ConsumerState<_GpsCaptureSheet> createState() => _GpsCaptureSheetState();
}

class _GpsCaptureSheetState extends ConsumerState<_GpsCaptureSheet> {
  StreamSubscription<Position>? _sub;
  Position? _latest;
  String? _error;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final provider = ref.read(activeLocationProvider);

      // Phone GPS still needs geolocator's service/permission gates.
      // External GNSS handled its own permissions during pairing.
      if (provider is PhoneLocationProvider) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (!serviceEnabled) {
          if (!mounted) return;

          setState(() {
            _error = 'Location services are disabled.';
            _checking = false;
          });
          return;
        }

        var perm = await Geolocator.checkPermission();

        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }

        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (!mounted) return;

          setState(() {
            _error = 'Location permission denied.';
            _checking = false;
          });
          return;
        }
      }

      await provider.start();

      _sub = provider.positionStream.listen(
        (pos) {
          if (!mounted) return;

          setState(() {
            _latest = pos;
            _checking = false;
          });
        },
        onError: (e) {
          if (!mounted) return;

          setState(() {
            _error = 'Location error: $e';
            _checking = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to start GPS: $e';
        _checking = false;
      });
    }
  }

  String _quality(double accuracy) {
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

  Widget _sourceBanner() {
    final provider = ref.watch(activeLocationProvider);
    final isExternal = provider is NmeaLocationProvider;
    final theme = Theme.of(context);

    final bgColor = isExternal ? Colors.purple.shade50 : Colors.blue.shade50;
    final iconColor =
        isExternal ? Colors.purple.shade700 : Colors.blue.shade700;
    final textColor =
        isExternal ? Colors.purple.shade900 : Colors.blue.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isExternal ? Icons.satellite_alt : Icons.gps_fixed,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: provider.isActive
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              provider.isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: provider.isActive
                    ? Colors.green.shade900
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.gps_fixed, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use my GPS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
          const SizedBox(height: 16),
          _sourceBanner(),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_checking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Acquiring GPS...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else if (_latest != null)
            _GpsInfo(
              position: _latest!,
              quality: _quality(_latest!.accuracy),
              qualityColor: _qualityColor(
                context,
                _latest!.accuracy,
              ),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: (_latest == null || _error != null)
                    ? null
                    : () {
                        final p = _latest!;

                        Navigator.pop(
                          context,
                          LatLng(
                            p.latitude,
                            p.longitude,
                          ),
                        );
                      },
                icon: const Icon(Icons.check),
                label: const Text('Use This'),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}



class _GpsInfo extends StatelessWidget {
  final Position position;
  final String quality;
  final Color qualityColor;

  const _GpsInfo({
    required this.position,
    required this.quality,
    required this.qualityColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place,
                color: cs.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lat ${position.latitude.toStringAsFixed(6)}, '
                  'Lng ${position.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.signal_cellular_alt,
                color: qualityColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Accuracy: ±${position.accuracy.toStringAsFixed(1)} m '
                  '($quality)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: qualityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (position.altitude != 0) ...[
            const SizedBox(height: 4),
            Text(
              'Alt: ${position.altitude.toStringAsFixed(1)} m',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}