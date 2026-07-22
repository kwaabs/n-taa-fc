import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/settings/settings_provider.dart';

/// The capture method chosen by the user for this session.
enum CaptureMethod {
  tap,
  gps,
  tapMulti, // multi-tap drawing for lines/polygons

  trackGps, // 👈 NEW: continuous GPS tracking
}

/// The current phase of the capture state machine.
enum CapturePhase {
  /// Not capturing. Map is in normal browse mode.
  idle,

  /// Worker chose a point layer + Tap method. Waiting for them to tap the map.
  awaitingMapTap,

  /// Worker chose a point layer + GPS method. Acquiring location.
  awaitingGps,

  /// A candidate point geometry exists. Worker can confirm or recapture.
  hasCandidate,

  /// Worker is drawing a multi-vertex shape (line or polygon).
  /// They tap to add vertices, Undo to remove last, Finish to commit.
  drawingMulti,

  tracking,
}

/// What geometry type are we capturing? Drives finish behavior.
enum CaptureGeometryKind {
  point,
  line,
  polygon,
}

class MapCaptureState {
  final CapturePhase phase;
  final String? layerId;
  final String? layerName;
  final String? formId;
  final CaptureMethod? method;
  final CaptureGeometryKind? kind;
  final bool snapEnabled;

  /// For point capture: the single LatLng selected.
  final LatLng? candidate;

  /// For multi-tap capture: the ordered list of vertices.
  final List<LatLng> vertices;

  const MapCaptureState({
    this.phase = CapturePhase.idle,
    this.layerId,
    this.layerName,
    this.formId,
    this.method,
    this.kind,
    this.candidate,
    this.vertices = const [],
    this.snapEnabled = false, // 👈 add this
  });

  bool get isActive => phase != CapturePhase.idle;
  bool get hasCandidate => candidate != null;
  bool get hasVertices => vertices.isNotEmpty;
  bool get canFinishLine =>
      kind == CaptureGeometryKind.line && vertices.length >= 2;
  bool get canFinishPolygon =>
      kind == CaptureGeometryKind.polygon && vertices.length >= 3;
  bool get canFinishTracking =>
      phase == CapturePhase.tracking &&
      ((kind == CaptureGeometryKind.line && vertices.length >= 2) ||
          (kind == CaptureGeometryKind.polygon && vertices.length >= 3));

  MapCaptureState copyWith({
    CapturePhase? phase,
    String? layerId,
    String? layerName,
    String? formId,
    CaptureMethod? method,
    CaptureGeometryKind? kind,
    LatLng? candidate,
    List<LatLng>? vertices,
    bool? snapEnabled, // 👈 add this
  }) {
    return MapCaptureState(
      phase: phase ?? this.phase,
      layerId: layerId ?? this.layerId,
      layerName: layerName ?? this.layerName,
      formId: formId ?? this.formId,
      method: method ?? this.method,
      kind: kind ?? this.kind,
      candidate: candidate ?? this.candidate,
      vertices: vertices ?? this.vertices,

      snapEnabled: snapEnabled ?? this.snapEnabled, // 👈 add this
    );
  }

  MapCaptureState clearCandidate() {
    return MapCaptureState(
      phase: phase,
      layerId: layerId,
      layerName: layerName,
      formId: formId,
      method: method,
      kind: kind,
      candidate: null,
      vertices: vertices,
    );
  }

  static const idle = MapCaptureState();
}

class MapCaptureNotifier extends StateNotifier<MapCaptureState> {
  final Ref _ref;
  MapCaptureNotifier(this._ref) : super(MapCaptureState.idle);

  bool _initialSnap() {
    return _ref.read(settingsProvider).value?.snapEnabled ?? true;
  }

  void startTap({
    required String layerId,
    required String layerName,
    String? formId,
  }) {
    state = MapCaptureState(
      phase: CapturePhase.awaitingMapTap,
      layerId: layerId,
      layerName: layerName,
      formId: formId,
      method: CaptureMethod.tap,
      kind: CaptureGeometryKind.point,
      snapEnabled: _initialSnap(),
    );
  }

  void startGps({
    required String layerId,
    required String layerName,
    String? formId,
  }) {
    state = MapCaptureState(
      phase: CapturePhase.awaitingGps,
      layerId: layerId,
      layerName: layerName,
      formId: formId,
      method: CaptureMethod.gps,
      kind: CaptureGeometryKind.point,
      snapEnabled: _initialSnap(),
    );
  }

  /// Start drawing a multi-vertex line or polygon by tapping the map.
  void startMultiTap({
    required String layerId,
    required String layerName,
    required CaptureGeometryKind kind,
    String? formId,
  }) {
    state = MapCaptureState(
      phase: CapturePhase.drawingMulti,
      layerId: layerId,
      layerName: layerName,
      formId: formId,
      method: CaptureMethod.tapMulti,
      kind: kind,
      vertices: const [],
      snapEnabled: _initialSnap(),
    );
  }

  void setCandidate(LatLng latLng) {
    state = state.copyWith(
      phase: CapturePhase.hasCandidate,
      candidate: latLng,
    );
  }

  /// Append a new vertex during multi-tap drawing.
  void addVertex(LatLng latLng) {
    if (state.phase != CapturePhase.drawingMulti) return;
    state = state.copyWith(
      vertices: [...state.vertices, latLng],
    );
  }

  /// Remove the last vertex (Undo).
  void popVertex() {
    if (state.phase != CapturePhase.drawingMulti) return;
    if (state.vertices.isEmpty) return;
    final next = [...state.vertices]..removeLast();
    state = state.copyWith(vertices: next);
  }

  void cancel() {
    state = MapCaptureState.idle;
  }

  /// Toggle snapping on/off during a capture session.
  void toggleSnap() {
    state = state.copyWith(snapEnabled: !state.snapEnabled);
  }

  /// Start GPS tracking mode for a line or polygon layer.
  /// Start GPS tracking mode for a line or polygon layer.
  void startTracking({
    required String layerId,
    required String layerName,
    required CaptureGeometryKind kind,
    String? formId,
  }) {
    state = MapCaptureState(
      phase: CapturePhase.tracking,
      layerId: layerId,
      layerName: layerName,
      formId: formId,
      method: CaptureMethod.trackGps,
      kind: kind,
      vertices: const [],
      snapEnabled: _initialSnap(),
    );
  }
}

final mapCaptureProvider =
    StateNotifierProvider.autoDispose<MapCaptureNotifier, MapCaptureState>(
  (ref) => MapCaptureNotifier(ref),
);
