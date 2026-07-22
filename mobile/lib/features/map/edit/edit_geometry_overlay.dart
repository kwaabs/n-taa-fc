import 'package:flutter/material.dart';

// If your project uses a different LatLng import, swap accordingly.

/// State tracking an in-progress geometry edit on the map.
class GeomEditState {
  /// The source_ref (external id) of the feature being edited — used for display.
  final String sourceRef;

  /// The original geometry as captured when edit started (dimmed pin location).
  final Map<String, dynamic> originalGeometry;

  /// Where the user has proposed to move it. Null until first tap.
  Map<String, dynamic>? proposedGeometry;

  /// The CollectedFeatures.clientId we're updating, if known.
  /// May be null if no edit row exists yet — caller will create one.
  final String? existingClientId;

  GeomEditState({
    required this.sourceRef,
    required this.originalGeometry,
    this.existingClientId,
    this.proposedGeometry,
  });

  Map<String, dynamic> get effectiveGeometry =>
      proposedGeometry ?? originalGeometry;

  bool get hasProposed => proposedGeometry != null;
}

/// Bottom overlay shown during geometry-edit mode.
/// Mirrors the visual language of CaptureOverlay/CaptureBanner.
class EditGeometryOverlay extends StatelessWidget {
  final GeomEditState state;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const EditGeometryOverlay({
    super.key,
    required this.state,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_location_alt_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editing location',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          state.sourceRef,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (state.hasProposed)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _formatProposedCoords(state.proposedGeometry!),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (state.hasProposed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                state.hasProposed
                    ? 'Tap the map again to refine, or Save.'
                    : 'Tap anywhere on the map to set the new position.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.hasProposed ? onSave : null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatProposedCoords(Map<String, dynamic> geom) {
  final coords = geom['coordinates'];
  if (coords is List && coords.length >= 2) {
    final lon = coords[0];
    final lat = coords[1];
    if (lon is num && lat is num) {
      return '→ ${lon.toStringAsFixed(6)}, ${lat.toStringAsFixed(6)}';
    }
  }
  return '→ updated';
}

/// State tracking an in-progress LINE or POLYGON vertex edit.
///
/// Holds the working list of vertices (lng, lat pairs) that the user is
/// shaping. Each interaction (move, insert, delete, translate) mutates this
/// list. Save serializes it back to GeoJSON.
class GeomEditStateLP {
  /// 'LineString' or 'Polygon'
  final String geometryType;

  /// External row id from the source DB — used for display + reconciliation
  final String sourceRef;

  /// Snapshot of the geometry as it was when edit started (for cancel + diff)
  final Map<String, dynamic> originalGeometry;

  /// The CollectedFeatures.clientId we're updating, if known.
  final String? existingClientId;

  /// Current working vertex list. For polygons, do NOT include a closing
  /// vertex equal to the first — we add that automatically on save.
  /// Coordinates: [[lng, lat], [lng, lat], ...].
  List<List<double>> vertices;

  /// Index of the currently selected vertex, or null if none.
  int? selectedIndex;

  /// True when the user is in translate mode (long-press body, tap to anchor).
  bool isTranslating;

  /// During translate mode: the anchor point (where the long-press hit).
  /// On next tap, the whole shape shifts by (tap − anchor).
  List<double>? translateAnchor;

  GeomEditStateLP({
    required this.geometryType,
    required this.sourceRef,
    required this.originalGeometry,
    required this.vertices,
    this.existingClientId,
    this.selectedIndex,
    this.isTranslating = false,
    this.translateAnchor,
  });

  bool get isLine => geometryType == 'LineString';
  bool get isPolygon => geometryType == 'Polygon';

  int get minVertices => isPolygon ? 3 : 2;

  bool get hasSelection => selectedIndex != null;

  /// Build the working geometry as GeoJSON for saving / live preview.
  /// Polygons get their first vertex repeated as last (close the ring).
  Map<String, dynamic> toGeoJson() {
    if (isLine) {
      return {
        'type': 'LineString',
        'coordinates': vertices.map((v) => [v[0], v[1]]).toList(),
      };
    }
    // Polygon — close the ring
    final ring = vertices.map((v) => [v[0], v[1]]).toList();
    if (ring.isNotEmpty) {
      ring.add([ring.first[0], ring.first[1]]);
    }
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }

  /// Deep-copy mutation helper — Riverpod prefers immutable updates, but our
  /// edit state is local to one State<> instance so direct mutation is fine.
  /// This is here for setState() callbacks that need a "fresh" reference.
  GeomEditStateLP copy() {
    return GeomEditStateLP(
      geometryType: geometryType,
      sourceRef: sourceRef,
      originalGeometry: originalGeometry,
      existingClientId: existingClientId,
      vertices: vertices.map((v) => [v[0], v[1]]).toList(),
      selectedIndex: selectedIndex,
      isTranslating: isTranslating,
      translateAnchor: translateAnchor == null
          ? null
          : [translateAnchor![0], translateAnchor![1]],
    );
  }
}

/// Extracts a flat list of [lng, lat] pairs from a GeoJSON geometry of
/// type LineString or Polygon. For polygons, the closing vertex is dropped
/// (we round-trip it on save).
List<List<double>> extractVertices(Map<String, dynamic> geom) {
  final type = geom['type'];
  final coords = geom['coordinates'];

  if (type == 'LineString' && coords is List) {
    return [
      for (final pt in coords)
        if (pt is List && pt.length >= 2)
          [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()],
    ];
  }

  if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    final ring = coords[0];
    if (ring is List) {
      final pts = <List<double>>[
        for (final pt in ring)
          if (pt is List && pt.length >= 2)
            [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()],
      ];
      // Drop closing vertex if it matches first
      if (pts.length > 1 &&
          pts.first[0] == pts.last[0] &&
          pts.first[1] == pts.last[1]) {
        pts.removeLast();
      }
      return pts;
    }
  }

  return [];
}

/// Bottom overlay shown during line/polygon vertex-edit mode.
class EditGeometryOverlayLP extends StatelessWidget {
  final GeomEditStateLP state;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const EditGeometryOverlayLP({
    super.key,
    required this.state,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String hint;
    if (state.isTranslating) {
      hint = 'Tap target — shape will shift';
    } else if (state.selectedIndex != null) {
      hint = 'Tap empty space to move vertex • Tap another vertex to switch';
    } else {
      hint =
          'Tap a vertex (orange) to select • Tap a midpoint (small) to add • '
          'Long-press a vertex to delete • Long-press the body to translate';
    }

    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    state.isLine ? Icons.timeline : Icons.pentagon_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isLine ? 'Editing line' : 'Editing polygon',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${state.sourceRef} · ${state.vertices.length} vertices',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isTranslating)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TRANSLATE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
