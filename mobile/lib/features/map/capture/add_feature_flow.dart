import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/db_provider.dart';
import 'map_capture_state.dart';

class CaptureSelection {
  final String layerId;
  final String layerName;
  final String? formId;
  final CaptureMethod method;
  final CaptureGeometryKind kind;

  const CaptureSelection({
    required this.layerId,
    required this.layerName,
    required this.formId,
    required this.method,
    required this.kind,
  });
}

class AddFeatureFlow {
  static Future<CaptureSelection?> run({
    required BuildContext context,
    required WidgetRef ref,
    required String projectId,
  }) async {
    final layers = await _fetchEditableLayers(ref, projectId);

    if (layers.isEmpty) {
      _toast(context, 'No editable layers in this project.');
      return null;
    }

    Layer? chosen;
    if (layers.length == 1) {
      chosen = layers.first;
    } else {
      chosen = await _showLayerPicker(context, layers);
      if (chosen == null) return null;
    }

    final kind = _geometryKind(chosen.geometryType);
    if (kind == null) {
      _toast(context, 'Layer "${chosen.name}" has unsupported geometry type.');
      return null;
    }

    final method = await _showMethodSheet(context, chosen.name, kind);
    if (method == null) return null;

    return CaptureSelection(
      layerId: chosen.id,
      layerName: chosen.name,
      formId: chosen.formId,
      method: method,
      kind: kind,
    );
  }

  static CaptureGeometryKind? _geometryKind(String geometryType) {
    switch (geometryType.toLowerCase()) {
      case 'point':
        return CaptureGeometryKind.point;
      case 'line':
        return CaptureGeometryKind.line;
      case 'polygon':
        return CaptureGeometryKind.polygon;
      default:
        return null;
    }
  }

  static Future<List<Layer>> _fetchEditableLayers(
    WidgetRef ref,
    String projectId,
  ) async {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return const [];

    // Slice 1 supported only points. Slice 2 expands to include lines too.
    final rows = await (db.select(db.layers)
          ..where((l) => l.projectId.equals(projectId))
          ..where((l) => l.geometryType.isIn(['point', 'line', 'polygon'])))
        .get();

    return rows;
  }

  static Future<Layer?> _showLayerPicker(
    BuildContext context,
    List<Layer> layers,
  ) {
    return showModalBottomSheet<Layer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to layer',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: layers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final l = layers[i];
                      final geomLabel = _geometryLabel(l.geometryType);
                      final icon = _geometryIcon(l.geometryType);
                      return ListTile(
                        leading: Icon(icon),
                        title: Text(l.name),
                        subtitle: Text(geomLabel),
                        onTap: () => Navigator.pop(ctx, l),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _geometryLabel(String geometryType) {
    switch (geometryType.toLowerCase()) {
      case 'point':
        return 'Point layer';
      case 'line':
        return 'Line layer';
      case 'polygon':
        return 'Polygon layer';
      default:
        return geometryType;
    }
  }

  static IconData _geometryIcon(String geometryType) {
    switch (geometryType.toLowerCase()) {
      case 'point':
        return Icons.place_outlined;
      case 'line':
        return Icons.timeline;
      case 'polygon':
        return Icons.crop_square;
      default:
        return Icons.layers_outlined;
    }
  }

  static Future<CaptureMethod?> _showMethodSheet(
    BuildContext context,
    String layerName,
    CaptureGeometryKind kind,
  ) {
    return showModalBottomSheet<CaptureMethod>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final options = _methodOptions(kind);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capture method',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'for $layerName',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                for (final opt in options)
                  ListTile(
                    leading: Icon(opt.icon),
                    title: Text(opt.title),
                    subtitle: Text(opt.subtitle),
                    onTap: () => Navigator.pop(ctx, opt.method),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static List<_MethodOption> _methodOptions(CaptureGeometryKind kind) {
    switch (kind) {
      case CaptureGeometryKind.point:
        return const [
          _MethodOption(
            method: CaptureMethod.tap,
            icon: Icons.touch_app_outlined,
            title: 'Tap on map',
            subtitle: 'Place the point by tapping the map.',
          ),
          _MethodOption(
            method: CaptureMethod.gps,
            icon: Icons.gps_fixed,
            title: 'Use my GPS',
            subtitle: 'Place the point at current location.',
          ),
        ];
      case CaptureGeometryKind.line:
        return const [
          _MethodOption(
            method: CaptureMethod.tapMulti,
            icon: Icons.timeline,
            title: 'Tap to draw',
            subtitle: 'Tap each vertex along the line, then Finish.',
          ),
          _MethodOption(
            method: CaptureMethod.trackGps,
            icon: Icons.directions_walk,
            title: 'Track with GPS',
            subtitle:
                'Walk along the line; phone records points automatically.',
          ),
        ];
      case CaptureGeometryKind.polygon:
        return const [
          _MethodOption(
            method: CaptureMethod.tapMulti,
            icon: Icons.crop_square,
            title: 'Tap to draw',
            subtitle: 'Tap each vertex around the polygon, then Finish.',
          ),
          _MethodOption(
            method: CaptureMethod.trackGps,
            icon: Icons.directions_walk,
            title: 'Track with GPS',
            subtitle: 'Walk the perimeter; phone records points automatically.',
          ),
        ];
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _MethodOption {
  final CaptureMethod method;
  final IconData icon;
  final String title;
  final String subtitle;

  const _MethodOption({
    required this.method,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
