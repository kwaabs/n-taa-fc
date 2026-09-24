/// Parsed layer style for map rendering (from published `layers.style` JSON).
class LayerMapAppearance {
  final Map<String, dynamic> paint;
  final double minZoom;
  final double maxZoom;
  final bool visibleByDefault;

  const LayerMapAppearance({
    this.paint = const {},
    this.minZoom = 0,
    this.maxZoom = 22,
    this.visibleByDefault = true,
  });

  static const fallback = LayerMapAppearance();
}

LayerMapAppearance parseLayerMapAppearance(Map<String, dynamic>? styleJson) {
  if (styleJson == null) return LayerMapAppearance.fallback;

  var minZoom = 0.0;
  var maxZoom = 22.0;
  var visibleByDefault = true;

  final visibility = styleJson['visibility'];
  if (visibility is Map) {
    final vis = visibility is Map<String, dynamic>
        ? visibility
        : Map<String, dynamic>.from(visibility);
    final minV = vis['min_zoom'];
    final maxV = vis['max_zoom'];
    if (minV is num) minZoom = minV.toDouble();
    if (maxV is num) maxZoom = maxV.toDouble();
    final vbd = vis['visible_by_default'];
    if (vbd is bool) visibleByDefault = vbd;
  }

  if (minZoom < 0) minZoom = 0;
  if (maxZoom > 24) maxZoom = 24;
  if (minZoom > maxZoom) {
    final t = minZoom;
    minZoom = maxZoom;
    maxZoom = t;
  }

  Map<String, dynamic> paint = const {};
  final def = styleJson['default'];
  if (def is Map) {
    paint = Map<String, dynamic>.from(def);
  }

  return LayerMapAppearance(
    paint: paint,
    minZoom: minZoom,
    maxZoom: maxZoom,
    visibleByDefault: visibleByDefault,
  );
}
