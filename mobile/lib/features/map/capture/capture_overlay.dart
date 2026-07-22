import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'map_capture_state.dart';

/// Top banner shown during capture mode.
class CaptureBanner extends ConsumerWidget {
  const CaptureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mapCaptureProvider);
    if (!s.isActive) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String message;
    IconData icon;

    switch (s.phase) {
      case CapturePhase.awaitingMapTap:
        message = 'Tap the map to place a point in ${s.layerName ?? "layer"}';
        icon = Icons.touch_app_outlined;
        break;
      case CapturePhase.awaitingGps:
        message = 'Acquiring GPS for ${s.layerName ?? "layer"}…';
        icon = Icons.gps_fixed;
        break;
      case CapturePhase.hasCandidate:
        message =
            'Tap again to move, or Confirm to continue (${s.layerName ?? "layer"})';
        icon = Icons.adjust;
        break;
      case CapturePhase.drawingMulti:
        final n = s.vertices.length;
        if (s.kind == CaptureGeometryKind.line) {
          message = n == 0
              ? 'Tap the map to start the line in ${s.layerName ?? "layer"}'
              : n == 1
                  ? 'Tap to add the next point ($n vertex so far)'
                  : 'Tap to add more, or Finish ($n vertices so far)';
        } else {
          message = n == 0
              ? 'Tap the map to start the polygon in ${s.layerName ?? "layer"}'
              : 'Tap to add more, or Finish ($n vertices so far)';
        }
        icon = Icons.timeline;
        break;
      case CapturePhase.tracking:
        // Tracking has its own full-screen sheet (gps_track_sheet),
        // so the in-map banner stays silent.
        return const SizedBox.shrink();
      case CapturePhase.idle:
        return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: cs.primaryContainer.withOpacity(0.95),
          elevation: 3,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: cs.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CaptureActionBar extends ConsumerWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm; // single-point confirm
  final VoidCallback onUndo;
  final VoidCallback onFinish;

  // 🧲 Snap toggle
  final bool snapEnabled;
  final VoidCallback? onToggleSnap;

  const CaptureActionBar({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    required this.onUndo,
    required this.onFinish,
    this.snapEnabled = false,
    this.onToggleSnap,
  });

  // Compact button style used in the multi-tap action bar so all buttons
  // fit comfortably on small/portrait phones (no right-overflow).
  static final ButtonStyle _compactStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static final ButtonStyle _compactFilledStyle = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mapCaptureProvider);
    if (!s.isActive) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Multi-tap drawing path
    if (s.phase == CapturePhase.drawingMulti) {
      final canUndo = s.vertices.isNotEmpty;
      final canFinish = s.canFinishLine || s.canFinishPolygon;

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: cs.surface.withOpacity(0.98),
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: _compactStyle,
                  ),
                  TextButton.icon(
                    onPressed: canUndo ? onUndo : null,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo'),
                    style: _compactStyle,
                  ),

                  // 🧲 Snap toggle
                  if (onToggleSnap != null)
                    TextButton.icon(
                      onPressed: onToggleSnap,
                      icon: Icon(
                        snapEnabled
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 18,
                        color: snapEnabled ? cs.primary : cs.outline,
                      ),
                      label: Text(
                        'Snap',
                        style: TextStyle(
                          color: snapEnabled ? cs.primary : cs.outline,
                          fontWeight:
                              snapEnabled ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      style: _compactStyle,
                    ),

                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canFinish ? onFinish : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Finish'),
                    style: _compactFilledStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Single-point capture path (unchanged behavior)
    final canConfirm = s.hasCandidate;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: cs.surface.withOpacity(0.98),
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canConfirm ? onConfirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}