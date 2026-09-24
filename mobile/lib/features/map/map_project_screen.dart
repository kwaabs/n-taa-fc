import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect, ImageByteFormat;
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';

import '../projects/project_model.dart';
import '../projects/form_detail_screen.dart';
import '../projects/bundle_downloader.dart';
import '../projects/bundle_repository.dart';
import '../collection/feature_repository.dart';
import 'capture/add_feature_flow.dart';

import 'capture/map_capture_state.dart';
import 'capture/capture_overlay.dart';
import 'capture/gps_capture_sheet.dart';
import 'capture/gps_track_sheet.dart';
import 'edit/edit_geometry_overlay.dart';

import '../../core/gnss/active_location_provider.dart';

import '../../core/db/db_provider.dart';
import '../../core/db/app_database.dart' as db;
import '../../core/geo/aoi_geometry.dart';
import '../../core/settings/basemap_options.dart';
import '../../core/settings/settings_provider.dart';

import '../../core/layout/responsive_layout.dart';
import 'map_side_panel.dart';
import 'my_location_layer.dart';
import 'tablet_map_legend.dart';

import 'map_providers.dart';
import 'layer_style_parse.dart';
import 'map_style.dart';

import '../search/guide_route_service.dart';
import '../search/search_panel.dart';
import '../search/search_state.dart';

enum _TabletMode { layers, search, form, feature }

class _PanelFormArgs {
  final db.Form form;
  final String? existingClientId;
  final Map<String, dynamic>? initialGeometry;
  final String? initialLayerId;
  final Map<String, dynamic>? initialAttributes;
  final String? referenceSourceRef;
  final String? referenceDataSourceId;
  final Map<String, dynamic>? referenceOriginalAttributes;
  final Map<String, dynamic>? referenceOriginalGeometry;

  const _PanelFormArgs({
    required this.form,
    this.existingClientId,
    this.initialGeometry,
    this.initialLayerId,
    this.initialAttributes,
    this.referenceSourceRef,
    this.referenceDataSourceId,
    this.referenceOriginalAttributes,
    this.referenceOriginalGeometry,
  });
}

class _PanelFeature {
  final String? layerId;
  final String? featureId;
  final Map<String, dynamic> attributes;
  final String? source;
  final String? sourceRef;
  final String layerName;
  final String? subtitle;
  final List<String> keys;
  final bool layerEditable;

  const _PanelFeature({
    required this.layerId,
    required this.featureId,
    required this.attributes,
    required this.source,
    required this.sourceRef,
    required this.layerName,
    required this.subtitle,
    required this.keys,
    required this.layerEditable,
  });
}

class _GuideInfo {
  final String title;
  final double? distanceMeters;
  final double? bearingDegrees;
  final String hint;
  final List<GuideDirectionStep> steps;

  const _GuideInfo({
    required this.title,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.hint,
    this.steps = const [],
  });
}

class MapProjectScreen extends ConsumerStatefulWidget {
  final Project project;

  const MapProjectScreen({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<MapProjectScreen> createState() => _MapProjectScreenState();
}

class _MapProjectScreenState extends ConsumerState<MapProjectScreen> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _legendOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      invalidateProjectMapProviders(ref.invalidate, widget.project.id);
    });
  }
  // Tablet-only: whether the side panel is expanded (true) or shown as
// the collapsed icon rail (false).
  bool _tabletPanelExpanded = false;
  _TabletMode _tabletMode = _TabletMode.layers;
  _PanelFormArgs? _panelFormArgs;
  Completer<Map<String, dynamic>?>? _panelFormCompleter;
  _PanelFeature? _panelFeature;
  bool _rendering = false;
  String? _layerFetchStatus;
  bool _fetchingLayers = false;
  final Set<String> _layerFetchAttempted = {};
  /// Layers waiting for an incremental map update while a full render runs.
  final Set<String> _pendingIncrementalLayerIds = {};
  /// Last render mode per layer: `tiles`, `collected`, or `none`.
  final Map<String, String> _layerRenderMode = {};
  /// Serializes MapLibre mutations so incremental + full renders do not overlap.
  Future<void> _mapRenderChain = Future.value();
  Circle? _candidateCircle; // current candidate marker on the map (if any)
  Circle? _editOriginalCircle; // 🟠 highlighted original position
  Circle? _editProposedCircle; // 🟢 user's proposed new position
  MyLocationLayer? _myLocationLayer;
  bool _myLocationLastEnabled = false;
  Line? _drawingLine;
  // Live GPS tracking on map
  Line? _trackingLine;
  Circle? _trackingPositionDot;

  /// Temp marker showing the currently-selected search result.
  Circle? _selectedResultMarker;
  static const _selSrcId = 'fc-feature-selection-src';
  static const _selHaloLineId = 'fc-feature-selection-halo-line';
  static const _selCoreLineId = 'fc-feature-selection-core-line';
  static const _selHaloFillId = 'fc-feature-selection-halo-fill';
  static const _selPointHaloId = 'fc-feature-selection-point-halo';
  static const _selPointCoreId = 'fc-feature-selection-point-core';
  // Found/selected target — purple, distinct from blue "me" and green guide.
  static const _selCoreColor = '#7C3AED';
  static const _selHaloColor = '#C4B5FD';
  final List<String> _selectionOverlayLayerIds = [];
  bool _selectionOverlayActive = false;
  Timer? _selectionPulseTimer;
  double _pulsePhase = 0.0;
  static const double _selPointHaloMinRadius = 14;
  static const double _selPointHaloMaxRadius = 26;
  static const _guideSrcId = 'guide-route-s';
  static const _guideHaloLayerId = 'guide-route-halo';
  static const _guideLayerId = 'guide-route-l';
  static const _guideLineColor = '#22C55E';
  static const _guideHaloColor = '#86EFAC';
  static const _guideDashSequence = <List<double>>[
    [0, 4, 3],
    [0.5, 4, 2.5],
    [1, 4, 2],
    [1.5, 4, 1.5],
    [2, 4, 1],
    [2.5, 4, 0.5],
    [3, 4, 0],
    [0, 0.5, 3, 3.5],
  ];

  bool _guideRouteLayerActive = false;
  Timer? _guideDashTimer;
  int _guideDashFrame = 0;
  double _guideLineWidth = 5.0;
  _GuideInfo? _guideInfo;
  int _guideRequestId = 0;
// D6.3b: line/polygon render handles for edit mode
  Line? _editGhostLine;
  Fill? _editGhostFill;
  Line? _editGhostFillStroke;
  Line? _editLiveLine;
  Fill? _editLiveFill;
  Line? _editLiveFillStroke;

  // D6.3c: vertex handle circles (one per vertex)
  final List<Circle> _editVertexHandles = [];

  bool _trackingFollowCamera = true;
  final List<Circle> _drawingVertexCircles = [];

  // D6.3e: midpoint hint circles (one per segment)
  final List<Circle> _editMidpointHandles = [];

  Map<String, bool> _visible = {};

  /// When true, rotation + tilt gestures are disabled (map stays north-up).
  bool _rotationLocked = false;

  GeomEditState? _editState;
  GeomEditStateLP? _editStateLP;

  final Map<String, List<String>> _mapLayerIdsByProjectLayer = {};
  final Map<String, List<String>> _mapSourceIdsByProjectLayer = {};

  // Last computed bounds — used by the recenter button
  _BoundsAccumulator? _lastBounds;

  String _pointLayerId(String pl) => 'pt-l-$pl';
  String _pointSrcId(String pl) => 'pt-s-$pl';
  String _lineLayerId(String pl) => 'ln-l-$pl';
  String _lineSrcId(String pl) => 'ln-s-$pl';
  String _polyFillId(String pl) => 'pg-f-$pl';
  String _polyOutlineId(String pl) => 'pg-o-$pl';
  String _polySrcId(String pl) => 'pg-s-$pl';

  static const _aoiKey = '__aoi__';
  static const _aoiSrcId = 'aoi-s';
  static const _aoiOutlineId = 'aoi-o';

  @override
  void dispose() {
    try {
      _controller?.onFeatureTapped.remove(_handleFeatureTap);
    } catch (_) {}
    _removeGuideLine();
    _stopSelectionPulse();
    _myLocationLayer?.stop();
    final completer = _panelFormCompleter;
    _panelFormCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    super.dispose();
  }

  double get _tabletPanelWidth {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    if (_tabletMode == _TabletMode.form ||
        _tabletMode == _TabletMode.feature) {
      return narrow ? 360.0 : 440.0;
    }
    return narrow ? 320.0 : 380.0;
  }

  /// Opens search and drops previous result list so reopening feels fresh.
  void _openSearchPanel({bool expandIfNeeded = true}) {
    ref.read(searchQueryProvider(widget.project.id).notifier).clearResults();
    unawaited(_clearSelectedResultMarker());
    unawaited(_clearFeatureSelectionHighlight());
    setState(() {
      _tabletMode = _TabletMode.search;
      if (expandIfNeeded) _tabletPanelExpanded = true;
    });
  }

  Widget _buildTabletPanelBody({
    required AsyncValue<Map<String, String>> layerNamesAsync,
  }) {
    switch (_tabletMode) {
      case _TabletMode.layers:
        return TabletMapLegend(
          visible: _visible,
          layerNamesAsync: layerNamesAsync,
          onToggle: _toggleLayer,
        );
      case _TabletMode.search:
        return SearchPanel(
          projectId: widget.project.id,
          onResultTap: _onSearchResultTap,
          onResultDirections: _onSearchResultDirections,
          onGoToLocation: _onGoToLocation,
        );
      case _TabletMode.form:
        final args = _panelFormArgs;
        if (args == null) {
          return const Center(child: Text('No form open'));
        }
        return FormDetailScreen(
          key: ValueKey(
            'panel-form-${args.form.id}-${args.existingClientId ?? 'new'}-'
            '${args.referenceSourceRef ?? ''}',
          ),
          form: args.form,
          existingClientId: args.existingClientId,
          initialGeometry: args.initialGeometry,
          initialLayerId: args.initialLayerId,
          initialAttributes: args.initialAttributes,
          referenceSourceRef: args.referenceSourceRef,
          referenceDataSourceId: args.referenceDataSourceId,
          referenceOriginalAttributes: args.referenceOriginalAttributes,
          referenceOriginalGeometry: args.referenceOriginalGeometry,
          embedded: true,
          onFinished: _finishPanelForm,
        );
      case _TabletMode.feature:
        final feature = _panelFeature;
        if (feature == null) {
          return const Center(child: Text('No feature selected'));
        }
        String formatVal(dynamic v) {
          if (v == null) return '—';
          if (v is String) return v.isEmpty ? '—' : v;
          if (v is num || v is bool) return v.toString();
          try {
            return jsonEncode(v);
          } catch (_) {
            return v.toString();
          }
        }
        return _buildFeatureInspector(
          layerId: feature.layerId,
          featureId: feature.featureId,
          attributes: feature.attributes,
          source: feature.source,
          sourceRef: feature.sourceRef,
          layerName: feature.layerName,
          subtitle: feature.subtitle,
          keys: feature.keys,
          layerEditable: feature.layerEditable,
          formatVal: formatVal,
          dismissSheet: false,
        );
    }
  }

  // ─────────────────────────────────────────────
  // Rendering
  // ─────────────────────────────────────────────
  /// Tries to get the on-disk .mbtiles path for a reference layer, or null.
  /// Uses the layerTilesPathProvider Riverpod cache.
  Future<String?> _tilesPathFor(String layerId) async {
    return ref.read(
      layerTilesPathProvider(
        (projectId: widget.project.id, layerId: layerId),
      ).future,
    );
  }

  /// MapLibre mbtiles URLs require forward slashes (Windows paths break otherwise).
  String _mbtilesTileUrl(String absolutePath) {
    return 'mbtiles://${absolutePath.replaceAll(r'\', '/')}';
  }

  /// Lazily fetch reference packs for visible layers that have no local tiles.
  /// Caps auto-download so opening a 100-layer project does not pull everything.
  /// Does not block the initial map paint — callers should render first, then
  /// invoke this with [unawaited].
  Future<void> _ensureVisibleLayerPacks({int maxLayers = 15}) async {
    if (_fetchingLayers) return;
    final repo = ref.read(bundleRepositoryProvider);
    if (repo == null) return;
    final downloader = ref.read(bundleDownloaderProvider);

    _fetchingLayers = true;
    try {
      await downloader.invalidateStaleLayerPacksIfNeeded(widget.project.id);
      final layers = await ref.read(
        localLayersMetaProvider(widget.project.id).future,
      );
      PacksManifest? manifest;
      try {
        manifest = await repo.getPacksManifest(projectId: widget.project.id);
      } catch (_) {}

      // Always hash-check visible layers. Old code skipped any layer that
      // already had mbtiles on disk, so stale clustered tiles never refreshed
      // after server tippecanoe / pack-format changes.
      final needFetch = <LocalLayerMeta>[];
      for (final layer in layers) {
        if (_visible[layer.id] == false) continue;
        if (_layerFetchAttempted.contains(layer.id)) continue;
        needFetch.add(layer);
        if (needFetch.length >= maxLayers) break;
      }

      var index = 0;
      for (final layer in needFetch) {
        index++;
        if (mounted) {
          setState(
            () => _layerFetchStatus =
                'Map data ${index}/${needFetch.length}: ${layer.name}…',
          );
        }
        try {
          final beforeTiles = await _tilesPathFor(layer.id);
          final merged = await downloader.ensureLayerReferencePack(
            projectId: widget.project.id,
            layerId: layer.id,
            repo: repo,
            remoteHash: manifest?.layerHashes[layer.id],
          );
          ref.invalidate(
            layerTilesPathProvider(
              (projectId: widget.project.id, layerId: layer.id),
            ),
          );
          final tiles = await _tilesPathFor(layer.id);
          _layerFetchAttempted.add(layer.id);
          final refreshed = merged.downloadedBytes > 0 ||
              (beforeTiles == null && tiles != null);
          if (tiles != null && refreshed && mounted && _styleLoaded) {
            // Drop cached tile layers so the new mbtiles are remounted.
            _layerRenderMode.remove(layer.id);
            unawaited(
              _renderFeatures(
                fitCamera: false,
                onlyLayerId: layer.id,
              ),
            );
          } else if (tiles == null) {
            debugPrint(
              '[map] layer pack for ${layer.id} merged without mbtiles',
            );
          }
        } catch (e) {
          debugPrint('[map] layer pack fetch failed ${layer.id}: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not download ${layer.name}: $e'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        // Yield so taps/animations can run between layer downloads.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      _fetchingLayers = false;
      if (mounted) setState(() => _layerFetchStatus = null);
    }
  }

  /// Queue map layer work on a single chain so MapLibre calls never overlap.
  Future<void> _renderFeatures({
    bool fitCamera = true,
    String? onlyLayerId,
  }) {
    final completer = Completer<void>();
    _mapRenderChain = _mapRenderChain.then((_) async {
      try {
        if (onlyLayerId != null) {
          await _renderIncrementalLayer(onlyLayerId);
        } else {
          await _renderAllLayers(fitCamera: fitCamera);
        }
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        debugPrint('[map] render failed: $e\n$st');
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _renderIncrementalLayer(String layerId) async {
    if (_rendering) {
      _pendingIncrementalLayerIds.add(layerId);
      return;
    }
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;

    final database = ref.read(appDatabaseProvider);
    if (database == null) return;

    final layers = await ref.read(
      localLayersMetaProvider(widget.project.id).future,
    );
    LocalLayerMeta? layerMeta;
    for (final l in layers) {
      if (l.id == layerId) {
        layerMeta = l;
        break;
      }
    }
    if (layerMeta == null) return;
    if (_visible[layerId] == false) {
      await _removeProjectLayerFromMap(controller, layerId);
      return;
    }

    final collected = await loadCollectedFeaturesForLayer(
      database,
      widget.project.id,
      layerId,
    );
    final collectedByLayer = <String, List<LocalMapFeature>>{
      layerId: collected,
    };

    final overrideLayerIds =
        await loadOverrideLayerIds(database, widget.project.id);
    final appearances = await _loadLayerAppearances(widget.project.id);
    final editingSourceRef = _editState?.sourceRef ?? _editStateLP?.sourceRef;
    final editingLayerId = _editLayerId;
    final geoBounds = _BoundsAccumulator();

    await _renderProjectLayerOnMap(
      controller: controller,
      database: database,
      layer: layerMeta,
      collectedByLayer: collectedByLayer,
      overrideLayerIds: overrideLayerIds,
      appearances: appearances,
      editingSourceRef: editingSourceRef,
      editingLayerId: editingLayerId,
      geoBounds: geoBounds,
    );
  }

  Future<void> _renderAllLayers({bool fitCamera = true}) async {
    if (_rendering) return;
    _rendering = true;

    try {
      final controller = _controller;
      if (controller == null || !_styleLoaded) return;

      final database = ref.read(appDatabaseProvider);
      if (database == null) return;

      // Lightweight metadata only — do NOT load all reference geometries.
      final layers = await ref.read(
        localLayersMetaProvider(widget.project.id).future,
      );
      final collectedFeatures = await ref.read(
        localCollectedFeaturesProvider(widget.project.id).future,
      );
      final collectedByLayer = <String, List<LocalMapFeature>>{};
      for (final f in collectedFeatures) {
        collectedByLayer.putIfAbsent(f.layerId, () => []).add(f);
      }

      final overrideLayerIds =
          await loadOverrideLayerIds(database, widget.project.id);

      final editingSourceRef = _editState?.sourceRef ?? _editStateLP?.sourceRef;
      final editingLayerId = _editLayerId;

      final appearances = await _loadLayerAppearances(widget.project.id);

      debugPrint(
        '[map] render tiles-first: ${layers.length} layers, '
        '${collectedFeatures.length} collected, '
        '${overrideLayerIds.length} override layers',
      );

      await _cleanupAll(controller);
      _layerRenderMode.clear();

      final aoiGeom = await _loadAoiGeometry();
      final aoiBounds = _BoundsAccumulator();
      if (aoiGeom != null) {
        _accumulate(aoiGeom, aoiBounds);
        await _addAoiOverlay(controller, aoiGeom);
      }

      if (_visible.isEmpty) {
        _visible = {
          for (final l in layers)
            l.id: appearances[l.id]?.visibleByDefault ?? true,
        };
      } else {
        for (final l in layers) {
          _visible.putIfAbsent(
            l.id,
            () => appearances[l.id]?.visibleByDefault ?? true,
          );
        }
      }

      final geoBounds = _BoundsAccumulator();

      // Pass 1: mbtiles layers first so the map becomes usable quickly.
      for (final layer in layers) {
        if (_visible[layer.id] == false) continue;
        if (await _tilesPathFor(layer.id) == null) continue;
        await _renderProjectLayerOnMap(
          controller: controller,
          database: database,
          layer: layer,
          collectedByLayer: collectedByLayer,
          overrideLayerIds: overrideLayerIds,
          appearances: appearances,
          editingSourceRef: editingSourceRef,
          editingLayerId: editingLayerId,
          geoBounds: geoBounds,
        );
        await Future<void>.delayed(Duration.zero);
      }

      // Pass 2: layers still waiting on mbtiles (collected overlay only).
      for (final layer in layers) {
        if (_visible[layer.id] == false) continue;
        if (await _tilesPathFor(layer.id) != null) continue;
        await _renderProjectLayerOnMap(
          controller: controller,
          database: database,
          layer: layer,
          collectedByLayer: collectedByLayer,
          overrideLayerIds: overrideLayerIds,
          appearances: appearances,
          editingSourceRef: editingSourceRef,
          editingLayerId: editingLayerId,
          geoBounds: geoBounds,
        );
        await Future<void>.delayed(Duration.zero);
      }

      final fitBounds = aoiBounds.hasData ? aoiBounds : geoBounds;
      if (fitBounds.hasData) _lastBounds = fitBounds;
      if (fitCamera && fitBounds.hasData) {
        await _fitToBounds(controller, fitBounds);
      }
    } finally {
      _rendering = false;
      if (_pendingIncrementalLayerIds.isNotEmpty && mounted) {
        final pending = List<String>.from(_pendingIncrementalLayerIds);
        _pendingIncrementalLayerIds.clear();
        for (final id in pending) {
          unawaited(_renderFeatures(onlyLayerId: id, fitCamera: false));
        }
      }
    }
  }

  Future<void> _renderProjectLayerOnMap({
    required MapLibreMapController controller,
    required db.AppDatabase database,
    required LocalLayerMeta layer,
    required Map<String, List<LocalMapFeature>> collectedByLayer,
    required Set<String> overrideLayerIds,
    required Map<String, LayerMapAppearance> appearances,
    required String? editingSourceRef,
    required String? editingLayerId,
    required _BoundsAccumulator geoBounds,
  }) async {
    final appearance = appearances[layer.id] ?? LayerMapAppearance.fallback;
    final style = appearance.paint;
    final color = _safeColor(style['color'], '#2563EB');
    final opacity = _safeDouble(style['opacity'], 0.9);
    final size = _safeDouble(style['size'], 6);
    final dashArray = _dashArrayFor(style['line_style'] as String?);
    final iconSvg = style['icon_svg'] as String?;
    final layerMinZoom = appearance.minZoom;
    final layerMaxZoom = appearance.maxZoom;

    final tilesPath = await _tilesPathFor(layer.id);
    final hasOverrides = overrideLayerIds.contains(layer.id);
    final useTiles = tilesPath != null && !hasOverrides;

    if (_layerRenderMode[layer.id] == 'tiles' && useTiles) {
      return;
    }

    await _removeProjectLayerFromMap(controller, layer.id);

    if (useTiles) {
      await _addTiledLayer(
        controller: controller,
        projectLayerId: layer.id,
        geometryType: layer.geometryType,
        tilesPath: tilesPath,
        color: color,
        opacity: opacity,
        size: size,
        dashArray: dashArray,
        iconSvg: iconSvg,
        layerMinZoom: layerMinZoom,
        layerMaxZoom: layerMaxZoom,
      );
      _layerRenderMode[layer.id] = 'tiles';
      final collected = collectedByLayer[layer.id] ?? const [];
      if (collected.isNotEmpty) {
        final bucket = _bucketFeatures(
          collected,
          editingSourceRef: editingSourceRef,
          editingLayerId: editingLayerId,
          bounds: geoBounds,
        );
        await _addGeoJsonBucket(
          controller: controller,
          projectLayerId: layer.id,
          bucket: bucket,
          color: color,
          opacity: opacity,
          size: size,
          dashArray: dashArray,
          iconSvg: iconSvg,
          sourcePrefix: 'col',
          layerMinZoom: layerMinZoom,
          layerMaxZoom: layerMaxZoom,
        );
      }
      return;
    }

    // Reference geometry is mbtiles-only on mobile — no GeoJSON fallback.
    final collected = collectedByLayer[layer.id] ?? const [];
    if (collected.isEmpty) {
      _layerRenderMode[layer.id] = 'none';
      return;
    }
    final bucket = _bucketFeatures(
      collected,
      editingSourceRef: editingSourceRef,
      editingLayerId: editingLayerId,
      bounds: geoBounds,
    );
    await _addGeoJsonBucket(
      controller: controller,
      projectLayerId: layer.id,
      bucket: bucket,
      color: color,
      opacity: opacity,
      size: size,
      dashArray: dashArray,
      iconSvg: iconSvg,
      sourcePrefix: 'col',
      layerMinZoom: layerMinZoom,
      layerMaxZoom: layerMaxZoom,
    );
    _layerRenderMode[layer.id] = 'collected';
  }

  _LayerBucket _bucketFeatures(
    List<LocalMapFeature> features, {
    String? editingSourceRef,
    String? editingLayerId,
    required _BoundsAccumulator bounds,
  }) {
    final bucket = _LayerBucket();
    for (final f in features) {
      if (editingSourceRef != null &&
          f.sourceRef == editingSourceRef &&
          (editingLayerId == null || f.layerId == editingLayerId)) {
        continue;
      }
      var geom = _asMap(f.geometry);
      if (geom == null) continue;
      geom = _maybePromoteClosedLineToPolygon(geom);
      final type = geom['type'];
      final geoJsonFeature = _geoJsonFeature(geom, f);
      if (type == 'Point' || type == 'MultiPoint') {
        bucket.points.add(geoJsonFeature);
      } else if (type == 'LineString' || type == 'MultiLineString') {
        bucket.lines.add(geoJsonFeature);
      } else if (type == 'Polygon' || type == 'MultiPolygon') {
        bucket.polys.add(geoJsonFeature);
      } else {
        continue;
      }
      _accumulate(geom, bounds);
    }
    return bucket;
  }

  /// Map layer geometry_type values to map render buckets.
  String _normalizeGeometryKind(String raw) {
    switch (raw.toLowerCase()) {
      case 'point':
      case 'multipoint':
        return 'point';
      case 'line':
      case 'linestring':
      case 'multilinestring':
        return 'line';
      case 'polygon':
      case 'multipolygon':
        return 'polygon';
      default:
        return raw.toLowerCase();
    }
  }

  Future<void> _addTiledLayer({
    required MapLibreMapController controller,
    required String projectLayerId,
    required String geometryType,
    required String tilesPath,
    required String color,
    required double opacity,
    required double size,
    required List<double>? dashArray,
    required String? iconSvg,
    double layerMinZoom = 0,
    double layerMaxZoom = 22,
  }) async {
    final kind = _normalizeGeometryKind(geometryType);
    final layerIds = <String>[];
    final sourceIds = <String>[];

    try {
      if (kind == 'point') {
        final srcId = _pointSrcId(projectLayerId);
        final layerId = _pointLayerId(projectLayerId);
        await controller.addSource(
          srcId,
          VectorSourceProperties(
            tiles: [_mbtilesTileUrl(tilesPath)],
            minzoom: 0,
            maxzoom: 16,
          ),
        );
        Uint8List? iconBytes;
        if (iconSvg != null && iconSvg.isNotEmpty) {
          iconBytes = await _rasterizeSvg(iconSvg, 64);
        }
        if (iconBytes != null) {
          final imgId = _iconImageId(projectLayerId, color, size);
          try {
            await controller.addImage(imgId, iconBytes);
          } catch (_) {}
          await controller.addSymbolLayer(
            srcId,
            layerId,
            SymbolLayerProperties(
              iconImage: imgId,
              iconSize: _iconSizeFor(size),
              iconOpacity: opacity,
              iconAllowOverlap: true,
              iconIgnorePlacement: true,
            ),
            sourceLayer: 'reference_features',
            minzoom: layerMinZoom,
            maxzoom: layerMaxZoom,
          );
        } else {
          await controller.addCircleLayer(
            srcId,
            layerId,
            CircleLayerProperties(
              circleRadius: size / 2,
              circleColor: color,
              circleOpacity: opacity,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 1.5,
            ),
            sourceLayer: 'reference_features',
            minzoom: layerMinZoom,
            maxzoom: layerMaxZoom,
          );
        }
        sourceIds.add(srcId);
        layerIds.add(layerId);
        debugPrint('[map] points via mbtiles for $projectLayerId');
      } else if (kind == 'line') {
        final srcId = _lineSrcId(projectLayerId);
        final layerId = _lineLayerId(projectLayerId);
        await controller.addSource(
          srcId,
          VectorSourceProperties(
            tiles: [_mbtilesTileUrl(tilesPath)],
            minzoom: 0,
            maxzoom: 16,
          ),
        );
        await controller.addLineLayer(
          srcId,
          layerId,
          LineLayerProperties(
            lineColor: color,
            lineWidth: size,
            lineOpacity: opacity,
            lineDasharray: dashArray,
          ),
          sourceLayer: 'reference_features',
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        sourceIds.add(srcId);
        layerIds.add(layerId);
        debugPrint('[map] lines via mbtiles for $projectLayerId');
      } else if (kind == 'polygon') {
        final srcId = _polySrcId(projectLayerId);
        final fillId = _polyFillId(projectLayerId);
        final outlineId = _polyOutlineId(projectLayerId);
        await controller.addSource(
          srcId,
          VectorSourceProperties(
            tiles: [_mbtilesTileUrl(tilesPath)],
            minzoom: 0,
            maxzoom: 16,
          ),
        );
        await controller.addFillLayer(
          srcId,
          fillId,
          FillLayerProperties(
            fillColor: color,
            fillOpacity: opacity * 0.4,
          ),
          sourceLayer: 'reference_features',
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        await controller.addLineLayer(
          srcId,
          outlineId,
          LineLayerProperties(
            lineColor: color,
            lineWidth: 2.0,
            lineOpacity: opacity,
            lineDasharray: dashArray,
          ),
          sourceLayer: 'reference_features',
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        sourceIds.add(srcId);
        layerIds.addAll([fillId, outlineId]);
        debugPrint('[map] polygons via mbtiles for $projectLayerId');
      } else {
        debugPrint(
          '[map] unknown geometry_type=$geometryType for $projectLayerId',
        );
      }
    } catch (e) {
      debugPrint('[map] failed tiled layer $projectLayerId: $e');
    }

    if (sourceIds.isNotEmpty) {
      _mapSourceIdsByProjectLayer[projectLayerId] = [
        ...?_mapSourceIdsByProjectLayer[projectLayerId],
        ...sourceIds,
      ];
    }
    if (layerIds.isNotEmpty) {
      _mapLayerIdsByProjectLayer[projectLayerId] = [
        ...?_mapLayerIdsByProjectLayer[projectLayerId],
        ...layerIds,
      ];
    }
  }

  Future<void> _addGeoJsonBucket({
    required MapLibreMapController controller,
    required String projectLayerId,
    required _LayerBucket bucket,
    required String color,
    required double opacity,
    required double size,
    required List<double>? dashArray,
    required String? iconSvg,
    String sourcePrefix = '',
    double layerMinZoom = 0,
    double layerMaxZoom = 22,
  }) async {
    final layerIds = <String>[];
    final sourceIds = <String>[];
    final prefix = sourcePrefix.isEmpty ? '' : '$sourcePrefix-';

    if (bucket.points.isNotEmpty) {
      final srcId = '$prefix${_pointSrcId(projectLayerId)}';
      final layerId = '$prefix${_pointLayerId(projectLayerId)}';
      try {
        await controller.addSource(
          srcId,
          GeojsonSourceProperties(
            data: {
              'type': 'FeatureCollection',
              'features': bucket.points,
            },
          ),
        );
        Uint8List? iconBytes;
        if (iconSvg != null && iconSvg.isNotEmpty) {
          iconBytes = await _rasterizeSvg(iconSvg, 64);
        }
        if (iconBytes != null) {
          final imgId = _iconImageId('$prefix$projectLayerId', color, size);
          try {
            await controller.addImage(imgId, iconBytes);
          } catch (_) {}
          await controller.addSymbolLayer(
            srcId,
            layerId,
            SymbolLayerProperties(
              iconImage: imgId,
              iconSize: _iconSizeFor(size),
              iconOpacity: opacity,
              iconAllowOverlap: true,
              iconIgnorePlacement: true,
            ),
            minzoom: layerMinZoom,
            maxzoom: layerMaxZoom,
          );
        } else {
          await controller.addCircleLayer(
            srcId,
            layerId,
            CircleLayerProperties(
              circleRadius: size / 2,
              circleColor: color,
              circleOpacity: opacity,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 1.5,
            ),
            minzoom: layerMinZoom,
            maxzoom: layerMaxZoom,
          );
        }
        sourceIds.add(srcId);
        layerIds.add(layerId);
      } catch (e) {
        debugPrint('[map] geojson points failed $projectLayerId: $e');
      }
    }

    if (bucket.lines.isNotEmpty) {
      final srcId = '$prefix${_lineSrcId(projectLayerId)}';
      final layerId = '$prefix${_lineLayerId(projectLayerId)}';
      try {
        await controller.addSource(
          srcId,
          GeojsonSourceProperties(
            data: {
              'type': 'FeatureCollection',
              'features': bucket.lines,
            },
          ),
        );
        await controller.addLineLayer(
          srcId,
          layerId,
          LineLayerProperties(
            lineColor: color,
            lineWidth: size,
            lineOpacity: opacity,
            lineDasharray: dashArray,
          ),
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        sourceIds.add(srcId);
        layerIds.add(layerId);
      } catch (e) {
        debugPrint('[map] geojson lines failed $projectLayerId: $e');
      }
    }

    if (bucket.polys.isNotEmpty) {
      final srcId = '$prefix${_polySrcId(projectLayerId)}';
      final fillId = '$prefix${_polyFillId(projectLayerId)}';
      final outlineId = '$prefix${_polyOutlineId(projectLayerId)}';
      try {
        await controller.addSource(
          srcId,
          GeojsonSourceProperties(
            data: {
              'type': 'FeatureCollection',
              'features': bucket.polys,
            },
          ),
        );
        await controller.addFillLayer(
          srcId,
          fillId,
          FillLayerProperties(
            fillColor: color,
            fillOpacity: opacity * 0.4,
          ),
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        await controller.addLineLayer(
          srcId,
          outlineId,
          LineLayerProperties(
            lineColor: color,
            lineWidth: 2.0,
            lineOpacity: opacity,
            lineDasharray: dashArray,
          ),
          minzoom: layerMinZoom,
          maxzoom: layerMaxZoom,
        );
        sourceIds.add(srcId);
        layerIds.addAll([fillId, outlineId]);
      } catch (e) {
        debugPrint('[map] geojson polys failed $projectLayerId: $e');
      }
    }

    if (sourceIds.isNotEmpty) {
      _mapSourceIdsByProjectLayer[projectLayerId] = [
        ...?_mapSourceIdsByProjectLayer[projectLayerId],
        ...sourceIds,
      ];
    }
    if (layerIds.isNotEmpty) {
      _mapLayerIdsByProjectLayer[projectLayerId] = [
        ...?_mapLayerIdsByProjectLayer[projectLayerId],
        ...layerIds,
      ];
    }
  }

  Future<void> _fitToBounds(
    MapLibreMapController controller,
    _BoundsAccumulator bounds,
  ) async {
    if (!bounds.hasData) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(bounds.south!, bounds.west!),
            northeast: LatLng(bounds.north!, bounds.east!),
          ),
          left: 30,
          right: 30,
          top: 30,
          bottom: 30,
        ),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadAoiGeometry() async {
    // Prefer offline DB (seeded from bundle project.json).
    final database = ref.read(appDatabaseProvider);
    if (database != null) {
      final row = await database.getProject(widget.project.id);
      final fromDb = _asMap(row?.areaOfInterest);
      if (fromDb != null) return fromDb;
    }
    // Fallback: in-memory project DTO (if Get included AOI).
    return widget.project.areaOfInterest;
  }

  Future<void> _addAoiOverlay(
    MapLibreMapController controller,
    Map<String, dynamic> aoiGeom,
  ) async {
    try {
      await controller.addSource(
        _aoiSrcId,
        GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {'kind': 'aoi'},
                'geometry': aoiGeom,
              },
            ],
          },
        ),
      );
      await controller.addLineLayer(
        _aoiSrcId,
        _aoiOutlineId,
        const LineLayerProperties(
          lineColor: '#000000',
          lineWidth: 4.0,
          lineOpacity: 1.0,
        ),
      );
      _mapSourceIdsByProjectLayer[_aoiKey] = [_aoiSrcId];
      _mapLayerIdsByProjectLayer[_aoiKey] = [_aoiOutlineId];
      debugPrint('[map] AOI overlay added');
    } catch (e) {
      debugPrint('[map] failed to add AOI overlay: $e');
    }
  }

  Future<void> _refreshMultiTapDrawing() async {
    final controller = _controller;
    if (controller == null) return;

    final capture = ref.read(mapCaptureProvider);
    final vertices = capture.vertices;

    // Always clean up first
    if (_drawingLine != null) {
      try {
        await controller.removeLine(_drawingLine!);
      } catch (_) {}
      _drawingLine = null;
    }
    for (final c in _drawingVertexCircles) {
      try {
        await controller.removeCircle(c);
      } catch (_) {}
    }
    _drawingVertexCircles.clear();

    // No vertices yet → nothing to draw
    if (vertices.isEmpty) return;

    // Render the polyline if we have 2+ vertices
    if (vertices.length >= 2) {
      try {
        _drawingLine = await controller.addLine(
          LineOptions(
            geometry: vertices,
            lineColor: '#2563EB',
            lineWidth: 3.0,
            lineOpacity: 0.9,
          ),
        );
      } catch (_) {}
    }

    // Render each vertex as a small green dot
    for (final v in vertices) {
      try {
        final c = await controller.addCircle(
          CircleOptions(
            geometry: v,
            circleRadius: 6,
            circleColor: '#22C55E',
            circleStrokeColor: '#064E3B',
            circleStrokeWidth: 1.5,
          ),
        );
        _drawingVertexCircles.add(c);
      } catch (_) {}
    }
  }

  Future<void> _onMultiTapUndo() async {
    ref.read(mapCaptureProvider.notifier).popVertex();
    await _refreshMultiTapDrawing();
  }

  Future<void> _onMultiTapFinishConfirmed() async {
    final capture = ref.read(mapCaptureProvider);
    if (capture.phase != CapturePhase.drawingMulti) return;

    // Defensive check
    if (capture.kind == CaptureGeometryKind.line && !capture.canFinishLine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('A line needs at least 2 vertices.'),
        ),
      );
      return;
    }

    if (capture.kind == CaptureGeometryKind.polygon &&
        !capture.canFinishPolygon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('A polygon needs at least 3 vertices.'),
        ),
      );
      return;
    }

    // Build GeoJSON geometry
    final coords =
        capture.vertices.map((v) => [v.longitude, v.latitude]).toList();

    Map<String, dynamic> geometry;
    switch (capture.kind) {
      case CaptureGeometryKind.line:
        geometry = {
          'type': 'LineString',
          'coordinates': coords,
        };
        break;
      case CaptureGeometryKind.polygon:
        // Build a proper GeoJSON Polygon:
        //  - coordinates is [[ring]] (3 levels of nesting)
        //  - ring must be closed (first point == last point)
        if (coords.length < 3) {
          // Safety: not enough points for a valid polygon
          return;
        }
        final ring = <List<double>>[
          ...coords.map((c) => [c[0], c[1]]),
          [coords.first[0], coords.first[1]], // close the ring
        ];
        geometry = {
          'type': 'Polygon',
          'coordinates': [ring],
        };
        break;

      case CaptureGeometryKind.point:
      case null:
        // Shouldn't happen for multi-tap
        return;
    }

    // Open form using same flow as point capture
    final opened = await _openFormForMultiTapCapture(
      layerId: capture.layerId!,
      layerName: capture.layerName ?? 'Layer',
      geometry: geometry,
    );

    if (opened) {
      await _clearMultiTapDrawing();
    }
  }

  /// Returns true if the form was opened (user proceeded).
  Future<bool> _openFormForMultiTapCapture({
    required String layerId,
    required String layerName,
    required Map<String, dynamic> geometry,
  }) async {
    // Find the form linked to this layer
    final db = ref.read(appDatabaseProvider);
    if (db == null) {
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    final layer = await (db.select(db.layers)
          ..where((l) => l.id.equals(layerId)))
        .getSingleOrNull();
    if (layer == null) {
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    final formId = layer.formId;
    if (formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              'Layer "$layerName" has no linked form. Configure one in admin.',
            ),
          ),
        );
      }
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    final form = await (db.select(db.forms)..where((f) => f.id.equals(formId)))
        .getSingleOrNull();
    if (form == null) {
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    if (!mounted) {
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    final proceed = await _confirmIfOutsideAoi(geometry);
    if (!proceed) return false;

    if (!mounted) {
      ref.read(mapCaptureProvider.notifier).cancel();
      return false;
    }

    await _presentForm(
      form: form,
      initialGeometry: geometry,
      initialLayerId: layerId,
    );

    ref.read(mapCaptureProvider.notifier).cancel();
    return true;
  }

  Future<void> _clearMultiTapDrawing() async {
    final controller = _controller;
    if (controller == null) return;

    if (_drawingLine != null) {
      try {
        await controller.removeLine(_drawingLine!);
      } catch (_) {}
      _drawingLine = null;
    }
    for (final c in _drawingVertexCircles) {
      try {
        await controller.removeCircle(c);
      } catch (_) {}
    }
    _drawingVertexCircles.clear();
  }

  Future<void> _onTrackingPosition(Position pos) async {
    final controller = _controller;
    if (controller == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);

    // Update or create the current-position dot
    if (_trackingPositionDot == null) {
      try {
        _trackingPositionDot = await controller.addCircle(
          CircleOptions(
            geometry: latLng,
            circleRadius: 8,
            circleColor: '#1E40AF',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
            circleOpacity: 0.95,
          ),
        );
      } catch (_) {}
    } else {
      try {
        await controller.updateCircle(
          _trackingPositionDot!,
          CircleOptions(geometry: latLng),
        );
      } catch (_) {}
    }

    // Auto-follow camera
    if (_trackingFollowCamera) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLng(latLng),
          duration: const Duration(milliseconds: 400),
        );
      } catch (_) {}
    }
  }

  Future<void> _onTrackingVerticesChanged(List<LatLng> vertices) async {
    final controller = _controller;
    if (controller == null) return;

    // Need at least 2 vertices to draw a line
    if (vertices.length < 2) {
      if (_trackingLine != null) {
        try {
          await controller.removeLine(_trackingLine!);
        } catch (_) {}
        _trackingLine = null;
      }
      return;
    }

    if (_trackingLine == null) {
      try {
        _trackingLine = await controller.addLine(
          LineOptions(
            geometry: vertices,
            lineColor: '#1E40AF',
            lineWidth: 4.0,
            lineOpacity: 0.9,
          ),
        );
      } catch (_) {}
    } else {
      try {
        await controller.updateLine(
          _trackingLine!,
          LineOptions(geometry: vertices),
        );
      } catch (_) {}
    }
  }

  Future<void> _clearTrackingOverlay() async {
    final controller = _controller;
    if (controller == null) return;

    if (_trackingLine != null) {
      try {
        await controller.removeLine(_trackingLine!);
      } catch (_) {}
      _trackingLine = null;
    }
    if (_trackingPositionDot != null) {
      try {
        await controller.removeCircle(_trackingPositionDot!);
      } catch (_) {}
      _trackingPositionDot = null;
    }
  }

  Future<void> _onAddFeaturePressed() async {
    final selection = await AddFeatureFlow.run(
      context: context,
      ref: ref,
      projectId: widget.project.id,
    );
    if (selection == null) return;

    final notifier = ref.read(mapCaptureProvider.notifier);
    switch (selection.method) {
      case CaptureMethod.tap:
        notifier.startTap(
          layerId: selection.layerId,
          layerName: selection.layerName,
          formId: selection.formId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                'Tap mode started for ${selection.layerName}.',
              ),
            ),
          );
        }
        break;

      case CaptureMethod.gps:
        notifier.startGps(
          layerId: selection.layerId,
          layerName: selection.layerName,
          formId: selection.formId,
        );

        if (!mounted) return;
        final picked = await showGpsCaptureSheet(
          context: context,
          layerName: selection.layerName,
        );

        if (picked == null) {
          notifier.cancel();
          return;
        }

        await _placeCaptureCandidate(picked);
        await _openFormForCapture();
        break;

      case CaptureMethod.tapMulti:
        notifier.startMultiTap(
          layerId: selection.layerId,
          layerName: selection.layerName,
          kind: selection.kind,
          formId: selection.formId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                'Drawing mode started for ${selection.layerName}. '
                'Tap the map to add vertices.',
              ),
            ),
          );
        }
        break;

      case CaptureMethod.trackGps:
        notifier.startTracking(
          layerId: selection.layerId,
          layerName: selection.layerName,
          kind: selection.kind,
          formId: selection.formId,
        );

        if (!mounted) return;
        _trackingFollowCamera = true; // reset for new session
        final result = await showGpsTrackSheet(
          context: context,
          layerName: selection.layerName,
          isPolygon: selection.kind == CaptureGeometryKind.polygon,
          onPosition: _onTrackingPosition,
          onVerticesChanged: _onTrackingVerticesChanged,
        );

        // Clean up the live overlay regardless of save/cancel
        await _clearTrackingOverlay();

        if (result == null || result.vertices.isEmpty) {
          notifier.cancel();
          return;
        }

        final coords =
            result.vertices.map((v) => [v.longitude, v.latitude]).toList();

        Map<String, dynamic> geometry;
        if (selection.kind == CaptureGeometryKind.polygon) {
          if (coords.length < 3) {
            notifier.cancel();
            return;
          }
          final ring = <List<double>>[
            ...coords.map((c) => [c[0], c[1]]),
            [coords.first[0], coords.first[1]],
          ];
          geometry = {
            'type': 'Polygon',
            'coordinates': [ring],
          };
        } else {
          geometry = {
            'type': 'LineString',
            'coordinates': coords,
          };
        }

        await _openFormForMultiTapCapture(
          layerId: selection.layerId,
          layerName: selection.layerName,
          geometry: geometry,
        );
        // If user cancelled outside-AOI warning, drop capture session.
        if (ref.read(mapCaptureProvider).phase != CapturePhase.idle) {
          notifier.cancel();
        }
        break;
    }
  }

  Future<void> _onMultiTapFinish() async {
    final capture = ref.read(mapCaptureProvider);
    if (capture.phase != CapturePhase.drawingMulti) return;
    if (capture.kind == CaptureGeometryKind.line && !capture.canFinishLine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('A line needs at least 2 vertices.'),
        ),
      );
      return;
    }

    final coords = capture.vertices
        .map((v) =>
            '(${v.longitude.toStringAsFixed(5)}, ${v.latitude.toStringAsFixed(5)})')
        .toList()
        .join(', ');

    // Message 2 will replace this with form open + sync.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            'Captured ${capture.vertices.length}-vertex line: $coords. '
            'Polyline preview + form prefill coming in Message 2.',
          ),
        ),
      );
    }

    ref.read(mapCaptureProvider.notifier).cancel();
  }

  Future<void> _resetRotation() async {
    final controller = _controller;
    if (controller == null) return;
    // Reset bearing to 0 (north) and tilt to 0 (flat)
    final pos = await controller.cameraPosition;
    if (pos == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos.target,
          zoom: pos.zoom,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  void _toggleRotationLock() {
    setState(() => _rotationLocked = !_rotationLocked);
    if (_rotationLocked) {
      _resetRotation(); // snap north-up when locking
    }
  }

  Future<void> _removeProjectLayerFromMap(
    MapLibreMapController controller,
    String projectLayerId,
  ) async {
    if (projectLayerId == _aoiKey) return;
    final layerIds = _mapLayerIdsByProjectLayer.remove(projectLayerId);
    final sourceIds = _mapSourceIdsByProjectLayer.remove(projectLayerId);
    for (final id in layerIds ?? const <String>[]) {
      try {
        await controller.removeLayer(id);
      } catch (e) {
        debugPrint('[map] FAILED remove layer $id: $e');
      }
    }
    for (final id in sourceIds ?? const <String>[]) {
      try {
        await controller.removeSource(id);
      } catch (e) {
        debugPrint('[map] FAILED remove source $id: $e');
      }
    }
    _layerRenderMode.remove(projectLayerId);
  }

  Future<void> _cleanupAll(MapLibreMapController controller) async {
    final layerCount =
        _mapLayerIdsByProjectLayer.values.expand((x) => x).length;
    final sourceCount =
        _mapSourceIdsByProjectLayer.values.expand((x) => x).length;
    debugPrint(
        '[map] cleanup: removing $layerCount layers, $sourceCount sources');

    for (final ids in _mapLayerIdsByProjectLayer.values) {
      for (final id in ids) {
        try {
          await controller.removeLayer(id);
          debugPrint('[map] removed layer $id');
        } catch (e) {
          debugPrint('[map] FAILED remove layer $id: $e');
        }
      }
    }
    for (final ids in _mapSourceIdsByProjectLayer.values) {
      for (final id in ids) {
        try {
          await controller.removeSource(id);
          debugPrint('[map] removed source $id');
        } catch (e) {
          debugPrint('[map] FAILED remove source $id: $e');
        }
      }
    }
    _mapLayerIdsByProjectLayer.clear();
    _mapSourceIdsByProjectLayer.clear();
  }

  Future<void> _placeCaptureCandidate(LatLng latLng) async {
    final controller = _controller;
    if (controller == null) return;

    // Remove previous candidate marker, if any
    await _removeCaptureCandidate();

    // Add a fresh candidate circle and remember it
    try {
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: latLng,
          circleRadius: 10,
          circleColor: '#22C55E',
          circleStrokeColor: '#064E3B',
          circleStrokeWidth: 2,
        ),
      );
      _candidateCircle = circle;
    } catch (_) {
      // best-effort
    }

    // Update state machine
    ref.read(mapCaptureProvider.notifier).setCandidate(latLng);
  }

  Future<void> _removeCaptureCandidate() async {
    final controller = _controller;
    final circle = _candidateCircle;
    if (controller == null || circle == null) return;

    try {
      await controller.removeCircle(circle);
    } catch (_) {
      // best-effort
    }
    _candidateCircle = null;
  }

  Future<void> _onCaptureCancel() async {
    await _removeCaptureCandidate();
    ref.read(mapCaptureProvider.notifier).cancel();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Capture cancelled.'),
        ),
      );
    }
  }

  Future<void> _onCaptureConfirm() async {
    await _openFormForCapture();
  }

  bool _useMapSidePanel(BuildContext context) {
    return LayoutOf(context).useTabletMapChrome;
  }

  Future<Map<String, dynamic>?> _presentForm({
    required db.Form form,
    String? existingClientId,
    Map<String, dynamic>? initialGeometry,
    String? initialLayerId,
    Map<String, dynamic>? initialAttributes,
    String? referenceSourceRef,
    String? referenceDataSourceId,
    Map<String, dynamic>? referenceOriginalAttributes,
    Map<String, dynamic>? referenceOriginalGeometry,
  }) async {
    if (!mounted) return null;

    if (_useMapSidePanel(context)) {
      // Replace any in-progress panel form without awaiting its future.
      final prev = _panelFormCompleter;
      if (prev != null && !prev.isCompleted) {
        prev.complete(null);
      }
      final completer = Completer<Map<String, dynamic>?>();
      setState(() {
        _panelFormArgs = _PanelFormArgs(
          form: form,
          existingClientId: existingClientId,
          initialGeometry: initialGeometry,
          initialLayerId: initialLayerId,
          initialAttributes: initialAttributes,
          referenceSourceRef: referenceSourceRef,
          referenceDataSourceId: referenceDataSourceId,
          referenceOriginalAttributes: referenceOriginalAttributes,
          referenceOriginalGeometry: referenceOriginalGeometry,
        );
        _panelFormCompleter = completer;
        _panelFeature = null;
        _tabletMode = _TabletMode.form;
        _tabletPanelExpanded = true;
      });
      return completer.future;
    }

    return Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => FormDetailScreen(
          form: form,
          existingClientId: existingClientId,
          initialGeometry: initialGeometry,
          initialLayerId: initialLayerId,
          initialAttributes: initialAttributes,
          referenceSourceRef: referenceSourceRef,
          referenceDataSourceId: referenceDataSourceId,
          referenceOriginalAttributes: referenceOriginalAttributes,
          referenceOriginalGeometry: referenceOriginalGeometry,
        ),
      ),
    );
  }

  void _finishPanelForm(Map<String, dynamic>? result) {
    final completer = _panelFormCompleter;
    _panelFormCompleter = null;
    if (mounted) {
      setState(() {
        _panelFormArgs = null;
        if (_tabletMode == _TabletMode.form) {
          _tabletMode = _TabletMode.layers;
        }
      });
    } else {
      _panelFormArgs = null;
    }
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<void> _openFormForCapture() async {
    final capture = ref.read(mapCaptureProvider);
    final candidate = capture.candidate;
    final layerId = capture.layerId;
    if (candidate == null || layerId == null) return;

    // Find the form linked to this layer
    final db = ref.read(appDatabaseProvider);
    if (db == null) {
      await _cleanupAfterFormClose();
      return;
    }

    final layer = await (db.select(db.layers)
          ..where((l) => l.id.equals(layerId)))
        .getSingleOrNull();
    if (layer == null) {
      await _cleanupAfterFormClose();
      return;
    }

    final formId = layer.formId;
    if (formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              'Layer "${capture.layerName}" has no linked form. '
              'Configure one in admin.',
            ),
          ),
        );
      }
      await _cleanupAfterFormClose();
      return;
    }

    final form = await (db.select(db.forms)..where((f) => f.id.equals(formId)))
        .getSingleOrNull();
    if (form == null) {
      await _cleanupAfterFormClose();
      return;
    }

    // Build the GeoJSON Point geometry from the candidate LatLng
    final geometry = <String, dynamic>{
      'type': 'Point',
      'coordinates': [candidate.longitude, candidate.latitude],
    };

    if (!mounted) {
      await _cleanupAfterFormClose();
      return;
    }

    final proceed = await _confirmIfOutsideAoi(geometry);
    if (!proceed) {
      // Keep candidate on map so the user can move it.
      return;
    }

    if (!mounted) {
      await _cleanupAfterFormClose();
      return;
    }

    await _presentForm(
      form: form,
      initialGeometry: geometry,
      initialLayerId: layerId,
    );

    // After the form screen pops back, clean up regardless of save/cancel
    await _cleanupAfterFormClose();
  }

  /// Returns false if the user cancelled after an outside-AOI warning.
  Future<bool> _confirmIfOutsideAoi(Map<String, dynamic> geometry) async {
    final aoi = await _loadAoiGeometry();
    if (aoi == null || !geometryOutsideAoi(geometry, aoi)) return true;
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Outside project area'),
        content: const Text(
          'This location is outside the project boundary. '
          'Move it inside, or save anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _cleanupAfterFormClose() async {
    await _removeCaptureCandidate();
    ref.read(mapCaptureProvider.notifier).cancel();
  }

  Future<void> _onEditReferencePressed({
    required String? layerId,
    required String? featureId,
    required String? sourceRef,
    required Map<String, dynamic> attributes,
  }) async {
    if (layerId == null || featureId == null) return;

    final db = ref.read(appDatabaseProvider);
    if (db == null) return;

    // 1. Find the layer + its form
    final layer = await (db.select(db.layers)
          ..where((l) => l.id.equals(layerId)))
        .getSingleOrNull();
    final project = await (db.select(db.projects)
          ..where((p) => p.id.equals(widget.project.id)))
        .getSingleOrNull();
    if (project?.aoiLayerId != null && project!.aoiLayerId == layerId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            content: Text(
              'This layer is used as the project AOI and cannot be edited.',
            ),
          ),
        );
      }
      return;
    }
    if (layer == null || layer.formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              'Layer "${layer?.name ?? layerId}" has no linked form — '
              'cannot edit.',
            ),
          ),
        );
      }
      return;
    }

    final form = await (db.select(db.forms)
          ..where((f) => f.id.equals(layer.formId!)))
        .getSingleOrNull();
    if (form == null) return;

    // 2. Find the source reference feature.
    //    Try by featureId first (when tapping an unedited reference dot);
    //    if not found, try by sourceRef + layerId (when tapping a moved/edited
    //    dot, whose id belongs to collected_features, not reference_features).
    var refRow = await (db.select(db.referenceFeatures)
          ..where((r) => r.id.equals(featureId)))
        .getSingleOrNull();

    // Also accept namespaced ids: "$layerId:$rawId"
    if (refRow == null && layerId != null && featureId.isNotEmpty) {
      final namespaced = '$layerId:$featureId';
      refRow = await (db.select(db.referenceFeatures)
            ..where((r) => r.id.equals(namespaced)))
          .getSingleOrNull();
    }

    if (refRow == null && sourceRef != null) {
      var q = db.select(db.referenceFeatures)
        ..where((r) => r.sourceRef.equals(sourceRef));
      if (layerId != null) {
        q = q..where((r) => r.layerId.equals(layerId));
      }
      refRow = await q.getSingleOrNull();
    }

    if (refRow == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text(
              'Cannot find source reference for this feature.',
            ),
          ),
        );
      }
      return;
    }

    final ref0 = refRow; // narrow to non-null for the rest of the function

    // 3. Decode original attributes + geometry from the reference row.
    //    These are SNAPSHOTS — never overwritten — used for diff/reconciliation.
    Map<String, dynamic>? origAttrs;
    Map<String, dynamic>? origGeom;
    try {
      final decodedAttrs = jsonDecode(ref0.attributes);
      if (decodedAttrs is Map) {
        origAttrs = Map<String, dynamic>.from(decodedAttrs);
      }
    } catch (_) {}
    try {
      final decodedGeom = jsonDecode(ref0.geometry);
      if (decodedGeom is Map) {
        origGeom = Map<String, dynamic>.from(decodedGeom);
      }
    } catch (_) {}

    // 4. Check if there's already a pending edit row for this sourceRef.
    //    If yes, capture its current geometry + attributes so the form
    //    PRE-FILLS with whatever the user changed last time (spontaneous
    //    re-edit support). The reference snapshots stay untouched.
    String? existingClientId;
    Map<String, dynamic>? priorGeom;
    Map<String, dynamic>? priorAttrs;
    if (ref0.sourceRef != null) {
      final existingEdit = await (db.select(db.collectedFeatures)
            ..where((c) => c.projectId.equals(widget.project.id))
            ..where((c) => c.layerId.equals(ref0.layerId))
            ..where((c) => c.sourceRef.equals(ref0.sourceRef!))
            ..where((c) => c.deletedAt.isNull()))
          .getSingleOrNull();
      if (existingEdit != null) {
        existingClientId = existingEdit.clientId;

        // Parse prior geometry edit, if any
        if (existingEdit.geometry != null &&
            existingEdit.geometry!.isNotEmpty) {
          try {
            final parsed = jsonDecode(existingEdit.geometry!);
            if (parsed is Map) {
              priorGeom = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        }

        // Parse prior attribute edits, if any
        if (existingEdit.attributes.isNotEmpty) {
          try {
            final parsed = jsonDecode(existingEdit.attributes);
            if (parsed is Map) {
              priorAttrs = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        }
      }
    }

    // 5. What the form/edit mode STARTS WITH (prior edit if any, else reference)
    final initialGeom = priorGeom ?? origGeom;
    final initialAttrs = priorAttrs ?? attributes;

    if (!mounted) return;

    // 6. Push the form.
    //    - initial* values are what the user sees & can keep tweaking.
    //    - referenceOriginal* values are the snapshots backend reconciliation
    //      diffs against. They never change once captured.
    final result = await _presentForm(
      form: form,
      existingClientId: existingClientId,
      initialGeometry: initialGeom,
      initialLayerId: layerId,
      initialAttributes: initialAttrs,
      referenceSourceRef: ref0.sourceRef,
      referenceDataSourceId: ref0.dataSourceId,
      referenceOriginalAttributes: origAttrs,
      referenceOriginalGeometry: origGeom,
    );

    // 7. Handle the form result. If user tapped the Edit-location banner,
    //    route to point edit (D6.2) or vertex edit (D6.3) based on geom type.
    //    The 'original_geometry' carried in the result is the form's
    //    initialGeometry — i.e., prior edit if it exists, so geometry editing
    //    can keep building on prior changes.
    if (result != null && result['__edit_geometry__'] == true && mounted) {
      final geom = result['original_geometry'] as Map<String, dynamic>?;
      final geomType = geom?['type']?.toString();

      if (geomType == 'LineString' || geomType == 'Polygon') {
        _enterEditModeLP(
          sourceRef: result['source_ref'] as String,
          originalGeometry: geom!,
          originalAttributes: origAttrs,
          existingClientId: result['existing_client_id'] as String?,
          layerId: layerId,
          formId: form.id,
          formVersion: form.version,
          dataSourceId: ref0.dataSourceId,
        );
      } else {
        _enterEditMode(
          sourceRef: result['source_ref'] as String,
          originalGeometry: geom,
          originalAttributes: origAttrs,
          existingClientId: result['existing_client_id'] as String?,
          layerId: layerId,
          formId: form.id,
          formVersion: form.version,
          dataSourceId: ref0.dataSourceId,
        );
      }
    }
  }

  Future<void> _onMarkDeletedPressed({
    required String? layerId,
    required String? featureId,
    required String? sourceRef,
    required Map<String, dynamic> attributes,
  }) async {
    if (layerId == null || featureId == null) return;

    final database = ref.read(appDatabaseProvider);
    if (database == null) return;

    // 1. Load layer + form (need formId/formVersion for the tombstone row)
    final layer = await (database.select(database.layers)
          ..where((l) => l.id.equals(layerId)))
        .getSingleOrNull();
    final project = await (database.select(database.projects)
          ..where((p) => p.id.equals(widget.project.id)))
        .getSingleOrNull();
    if (project?.aoiLayerId != null && project!.aoiLayerId == layerId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            content: Text(
              'This layer is used as the project AOI and cannot be modified.',
            ),
          ),
        );
      }
      return;
    }
    if (layer == null || layer.formId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              'Layer "${layer?.name ?? layerId}" has no linked form — '
              'cannot mark deleted.',
            ),
          ),
        );
      }
      return;
    }
    final form = await (database.select(database.forms)
          ..where((f) => f.id.equals(layer.formId!)))
        .getSingleOrNull();
    if (form == null) return;

    // 2. Load the reference feature for sourceRef + originals
    var refRow = await (database.select(database.referenceFeatures)
          ..where((r) => r.id.equals(featureId)))
        .getSingleOrNull();
    if (refRow == null) {
      final namespaced = '$layerId:$featureId';
      refRow = await (database.select(database.referenceFeatures)
            ..where((r) => r.id.equals(namespaced)))
          .getSingleOrNull();
    }
    if (refRow == null && sourceRef != null) {
      refRow = await (database.select(database.referenceFeatures)
            ..where((r) => r.layerId.equals(layerId))
            ..where((r) => r.sourceRef.equals(sourceRef)))
          .getSingleOrNull();
    }
    if (refRow == null || refRow.sourceRef == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text(
              'This feature has no source reference and cannot be marked deleted.',
            ),
          ),
        );
      }
      return;
    }

    Map<String, dynamic>? origAttrs;
    Map<String, dynamic>? origGeom;
    try {
      final decoded = jsonDecode(refRow.attributes);
      if (decoded is Map) origAttrs = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    try {
      final decoded = jsonDecode(refRow.geometry);
      if (decoded is Map) origGeom = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    // 3. Build a helpful display name for the dialog
    String label = refRow.sourceRef!;
    for (final key in const ['name', 'title', 'label']) {
      final v = attributes[key];
      if (v is String && v.isNotEmpty) {
        label = v;
        break;
      }
    }

    if (!mounted) return;

    // 4. Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Mark feature deleted?'),
          content: Text(
            '"$label" will be marked for deletion. The change will sync to '
            'the office for review and reconciliation with the source data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // 5. Create the tombstone
    final repo = ref.read(collectedFeatureRepoProvider);
    if (repo == null) return;
    try {
      await repo.markReferenceDeleted(
        projectId: widget.project.id,
        layerId: layerId,
        formId: form.id,
        formVersion: form.version,
        sourceRef: refRow.sourceRef!,
        dataSourceId: refRow.dataSourceId,
        originalAttributes: origAttrs,
        originalGeometry: origGeom,
      );

      // Refresh map: invalidate both providers so render filters re-apply
      ref.invalidate(localReferenceFeaturesProvider(widget.project.id));
      ref.invalidate(localCollectedFeaturesProvider(widget.project.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('"$label" marked deleted — pending sync.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text('Failed to mark deleted: $e'),
          ),
        );
      }
    }
  }

  Future<void> _onSearchResultTap(SearchResult result) async {
    // Fly + highlight only. Directions are opt-in via the result row action.
    await _focusSearchResult(result, withDirections: false);
  }

  Future<void> _onSearchResultDirections(SearchResult result) async {
    await _focusSearchResult(result, withDirections: true);
  }

  Future<void> _focusSearchResult(
    SearchResult result, {
    required bool withDirections,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    final geom = result.geometryJson;
    if (geom == null || geom.isEmpty) return;

    try {
      final parsed = jsonDecode(geom);
      if (parsed is Map) {
        final coords = _extractCenterCoords(parsed);
        if (coords != null) {
          final latLng = LatLng(coords.$2, coords.$1);
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 17),
          );
          await _setFeatureSelectionHighlight(
            Map<String, dynamic>.from(parsed),
          );
          if (withDirections) {
            await _updateGuideToTarget(latLng);
          } else {
            await _clearSelectedResultMarker();
          }
        }
      }
    } catch (e) {
      debugPrint('[search] fly-to failed: $e');
    }
  }

  Future<void> _onGoToLocation(double lat, double lng) async {
    final controller = _controller;
    if (controller == null) return;

    final latLng = LatLng(lat, lng);
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );
      await _setSelectedResultMarker(latLng);
      // Coordinate "Go" is an explicit navigate action — show guide.
      await _updateGuideToTarget(latLng);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              'At ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[search] go-to location failed: $e');
    }
  }

  Future<void> _clearFeatureSelectionHighlight() async {
    final controller = _controller;
    if (controller == null || !_selectionOverlayActive) return;
    _stopSelectionPulse();
    for (final id in _selectionOverlayLayerIds) {
      try {
        await controller.removeLayer(id);
      } catch (_) {}
    }
    _selectionOverlayLayerIds.clear();
    try {
      await controller.removeSource(_selSrcId);
    } catch (_) {}
    _selectionOverlayActive = false;
  }

  Future<void> _setFeatureSelectionHighlight(
    Map<String, dynamic>? geometry,
  ) async {
    await _clearFeatureSelectionHighlight();
    if (geometry == null) return;
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;

    var normalized = _asMap(geometry);
    if (normalized == null) return;
    normalized = _maybePromoteClosedLineToPolygon(normalized);
    final type = normalized['type']?.toString() ?? '';

    try {
      await controller.addSource(
        _selSrcId,
        GeojsonSourceProperties(
          data: {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': normalized,
                'properties': <String, dynamic>{},
              },
            ],
          },
        ),
      );

      if (type == 'Point' || type == 'MultiPoint') {
        await controller.addCircleLayer(
          _selSrcId,
          _selPointHaloId,
          CircleLayerProperties(
            circleRadius: 18,
            circleColor: _selHaloColor,
            circleOpacity: 0.4,
            circleStrokeWidth: 0,
          ),
        );
        await controller.addCircleLayer(
          _selSrcId,
          _selPointCoreId,
          CircleLayerProperties(
            circleRadius: 8,
            circleColor: _selCoreColor,
            circleOpacity: 0.95,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.5,
          ),
        );
        _selectionOverlayLayerIds.addAll([_selPointHaloId, _selPointCoreId]);
        _startSelectionPulse();
      } else if (type == 'LineString' || type == 'MultiLineString') {
        await controller.addLineLayer(
          _selSrcId,
          _selHaloLineId,
          LineLayerProperties(
            lineColor: _selHaloColor,
            lineWidth: 12,
            lineOpacity: 0.5,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
        await controller.addLineLayer(
          _selSrcId,
          _selCoreLineId,
          LineLayerProperties(
            lineColor: _selCoreColor,
            lineWidth: 4.5,
            lineOpacity: 1,
            lineCap: 'round',
            lineJoin: 'round',
          ),
        );
        _selectionOverlayLayerIds.addAll([_selHaloLineId, _selCoreLineId]);
      } else if (type == 'Polygon' || type == 'MultiPolygon') {
        await controller.addFillLayer(
          _selSrcId,
          _selHaloFillId,
          FillLayerProperties(
            fillColor: _selHaloColor,
            fillOpacity: 0.28,
          ),
        );
        await controller.addLineLayer(
          _selSrcId,
          _selCoreLineId,
          LineLayerProperties(
            lineColor: _selCoreColor,
            lineWidth: 3.5,
            lineOpacity: 1,
          ),
        );
        _selectionOverlayLayerIds.addAll([_selHaloFillId, _selCoreLineId]);
      }
      _selectionOverlayActive = true;
    } catch (e) {
      debugPrint('[map] selection highlight failed: $e');
    }
  }

  /// Animates the purple "found" halo with a growing, fading pulse so the
  /// selected point marker draws the eye. Only used for Point/MultiPoint
  /// selections — line/polygon halos stay static since a moving radius
  /// doesn't read the same on those shapes.
  void _startSelectionPulse() {
    _selectionPulseTimer?.cancel();
    _pulsePhase = 0.0;
    _selectionPulseTimer =
        Timer.periodic(const Duration(milliseconds: 60), (timer) {
      final controller = _controller;
      if (!mounted ||
          controller == null ||
          !_selectionOverlayActive ||
          !_selectionOverlayLayerIds.contains(_selPointHaloId)) {
        timer.cancel();
        return;
      }

      _pulsePhase += 0.12;
      // 0..1 smooth oscillation
      final t = (sin(_pulsePhase) + 1) / 2;

      final radius = _selPointHaloMinRadius +
          t * (_selPointHaloMaxRadius - _selPointHaloMinRadius);
      final opacity = 0.55 - t * 0.35; // grows while fading — classic "ping"

      controller
          .setLayerProperties(
            _selPointHaloId,
            CircleLayerProperties(
              circleRadius: radius,
              circleColor: _selHaloColor,
              circleOpacity: opacity,
              circleStrokeWidth: 0,
            ),
          )
          .catchError((_) {});
    });
  }

  void _stopSelectionPulse() {
    _selectionPulseTimer?.cancel();
    _selectionPulseTimer = null;
  }

  /// Draws a temporary marker at the given position to indicate the selected
  /// search result. Replaces any prior marker.
  Future<void> _setSelectedResultMarker(LatLng position) async {
    final controller = _controller;
    if (controller == null) return;

    // Remove previous marker if any
    final prior = _selectedResultMarker;
    if (prior != null) {
      try {
        await controller.removeCircle(prior);
      } catch (_) {}
      _selectedResultMarker = null;
    }

    // Bright, high-contrast marker — orange with white border
    try {
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: position,
          circleRadius: 12,
          circleColor: _selCoreColor,
          circleOpacity: 0.9,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
      );
      _selectedResultMarker = circle;
    } catch (e) {
      debugPrint('[search] failed to draw result marker: $e');
    }
  }

  Future<void> _updateGuideToTarget(LatLng target) async {
    final controller = _controller;
    if (controller == null) return;

    final requestId = ++_guideRequestId;
    await _removeGuideLine();

    final showMyLoc = ref.read(settingsProvider).value?.showMyLocation ?? false;
    final current = _myLocationLayer?.currentPosition;
    if (current == null) {
      if (!mounted) return;
      setState(() {
        _guideInfo = _GuideInfo(
          title: 'Guide',
          distanceMeters: null,
          bearingDegrees: null,
          hint: showMyLoc
              ? 'Waiting for GPS fix to show distance and heading.'
              : 'Turn on My Location to show distance and heading.',
        );
      });
      return;
    }

    final routeService = ref.read(guideRouteServiceProvider);
    final straight = routeService.straightLine(
      fromLat: current.latitude,
      fromLng: current.longitude,
      toLat: target.latitude,
      toLng: target.longitude,
    );

    await _applyGuideRoute(straight, requestId);
    if (!mounted || requestId != _guideRequestId) return;

    setState(() {
      _guideInfo = _GuideInfo(
        title: 'Guide',
        distanceMeters: straight.distanceMeters,
        bearingDegrees: straight.bearingDegrees,
        hint: 'Straight line shown — loading road route…',
        steps: straight.steps,
      );
    });

    final road = await routeService.route(
      fromLat: current.latitude,
      fromLng: current.longitude,
      toLat: target.latitude,
      toLng: target.longitude,
    );

    if (!mounted || requestId != _guideRequestId) return;
    if (!road.followsRoads) return;

    await _applyGuideRoute(road, requestId);
    if (!mounted || requestId != _guideRequestId) return;
    setState(() {
      _guideInfo = _GuideInfo(
        title: 'Road guide',
        distanceMeters: road.distanceMeters,
        bearingDegrees: road.bearingDegrees,
        hint: road.hint,
        steps: road.steps,
      );
    });
  }

  Map<String, dynamic> _guideRouteGeoJson(List<LatLng> geometry) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': const {'kind': 'guide-route'},
          'geometry': {
            'type': 'LineString',
            'coordinates': geometry
                .map((p) => [p.longitude, p.latitude])
                .toList(growable: false),
          },
        },
      ],
    };
  }

  LineLayerProperties _guideHaloLayerProps() {
    return LineLayerProperties(
      lineColor: _guideHaloColor,
      lineWidth: _guideLineWidth + 5.0,
      lineOpacity: 0.7,
      lineCap: 'round',
      lineJoin: 'round',
      lineBlur: 0.5,
    );
  }

  LineLayerProperties _guideLineLayerProps({List<double>? dash}) {
    return LineLayerProperties(
      lineColor: _guideLineColor,
      lineWidth: _guideLineWidth,
      lineOpacity: 0.95,
      lineCap: 'round',
      lineJoin: 'round',
      lineDasharray: dash ?? _guideDashSequence.first,
    );
  }

  void _startGuideDashAnimation() {
    _guideDashTimer?.cancel();
    _guideDashFrame = 0;
    _guideDashTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted || !_guideRouteLayerActive) {
        timer.cancel();
        return;
      }
      final controller = _controller;
      if (controller == null) return;
      _guideDashFrame++;
      final dash = _guideDashSequence[
          _guideDashFrame % _guideDashSequence.length];
      controller
          .setLayerProperties(
            _guideLayerId,
            _guideLineLayerProps(dash: dash),
          )
          .catchError((_) {});
    });
  }

  Future<void> _applyGuideRoute(GuideRouteResult route, int requestId) async {
    if (requestId != _guideRequestId) return;
    final controller = _controller;
    if (controller == null) return;

    if (route.geometry.length < 2) return;

    _guideLineWidth = route.followsRoads ? 5.5 : 5.0;
    final geojson = _guideRouteGeoJson(route.geometry);
    final haloProps = _guideHaloLayerProps();
    final layerProps = _guideLineLayerProps();

    try {
      if (_guideRouteLayerActive) {
        await controller.setGeoJsonSource(_guideSrcId, geojson);
        await controller.setLayerProperties(_guideHaloLayerId, haloProps);
        await controller.setLayerProperties(_guideLayerId, layerProps);
      } else {
        await controller.addSource(
          _guideSrcId,
          GeojsonSourceProperties(data: geojson),
        );
        // Halo underneath, dashed green on top.
        await controller.addLineLayer(
          _guideSrcId,
          _guideHaloLayerId,
          haloProps,
        );
        await controller.addLineLayer(
          _guideSrcId,
          _guideLayerId,
          layerProps,
        );
        _guideRouteLayerActive = true;
        _startGuideDashAnimation();
      }
    } catch (e) {
      debugPrint('[search] failed to draw guide line: $e');
    }
  }

  Future<void> _removeGuideLine() async {
    _guideDashTimer?.cancel();
    _guideDashTimer = null;
    final controller = _controller;
    if (controller == null || !_guideRouteLayerActive) {
      _guideRouteLayerActive = false;
      return;
    }
    _guideRouteLayerActive = false;
    try {
      await controller.removeLayer(_guideLayerId);
      await controller.removeLayer(_guideHaloLayerId);
      await controller.removeSource(_guideSrcId);
    } catch (_) {}
  }

  Future<void> _clearGuide() async {
    _guideRequestId++;
    await _removeGuideLine();
    if (!mounted) return;
    setState(() => _guideInfo = null);
  }

  /// Clear the search-result marker.
  Future<void> _clearSelectedResultMarker() async {
    final controller = _controller;
    final prior = _selectedResultMarker;
    if (controller != null && prior != null) {
      try {
        await controller.removeCircle(prior);
      } catch (_) {}
    }
    _selectedResultMarker = null;
    await _clearGuide();
  }

  // ─────────────────────────────────────────────
  // Camera helpers
  // ─────────────────────────────────────────────
  Future<void> _recenter() async {
    final controller = _controller;
    if (controller == null) return;

    // 1. Prefer user location if the my-location layer is active and has a fix
    final myLocPos = _myLocationLayer?.currentPosition;
    final showMyLoc = ref.read(settingsProvider).value?.showMyLocation ?? false;

    if (showMyLoc && myLocPos != null) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(myLocPos.latitude, myLocPos.longitude),
            17,
          ),
        );
      } catch (e) {
        debugPrint('[recenter] animateCamera(user) failed: $e');
      }
      return;
    }

    // 2. Fall back to data bounds
    final bounds = _lastBounds;
    if (bounds != null && bounds.hasData) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(bounds.south!, bounds.west!),
              northeast: LatLng(bounds.north!, bounds.east!),
            ),
            left: 30,
            right: 30,
            top: 30,
            bottom: 30,
          ),
        );
      } catch (e) {
        debugPrint('[recenter] animateCamera(bounds) failed: $e');
      }
      return;
    }

    // 3. Nothing to recenter to — tell the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Nothing to recenter to yet — waiting for data or GPS fix.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

// ─────────────────────────────────────────────
  // Tap handling
  // ─────────────────────────────────────────────

  /// Tries to find the nearest existing feature vertex within [tolerancePx]
  /// screen pixels of [tapPoint]. Returns the snapped LatLng, or `null`
  /// if no candidate is close enough.
  Future<LatLng?> _findSnapTarget(
    Point<double> tapPoint, {
    double tolerancePx = 20.0,
  }) async {
    final controller = _controller;
    if (controller == null) return null;

    // Convert tap pixel back to lat/lng + compute a small bounding box
    // around it (~2x tolerance in degrees, rough but fine for snapping).
    final tapLatLng = await controller.toLatLng(tapPoint);
    final visibleBounds = await controller.getVisibleRegion();

    // Approximate degrees-per-pixel from the visible region:
    final mapHeightPx = MediaQuery.of(context).size.height;
    final latRange =
        visibleBounds.northeast.latitude - visibleBounds.southwest.latitude;
    final degPerPx = latRange.abs() / mapHeightPx;
    final pad = tolerancePx * 2 * degPerPx;

    final minLat = tapLatLng.latitude - pad;
    final maxLat = tapLatLng.latitude + pad;
    final minLng = tapLatLng.longitude - pad;
    final maxLng = tapLatLng.longitude + pad;

    // Avoid loading every reference feature into RAM for snap — that OOM-kills
    // large projects. Snap against collected features only; reference verts
    // remain available via map tiles for visual snapping context.
    final allFeatures =
        ref.read(localCollectedFeaturesProvider(widget.project.id)).value ??
            const <LocalMapFeature>[];

    LatLng? bestLatLng;
    double bestDistSq = double.infinity;
    final tolSq = tolerancePx * tolerancePx;
    int checked = 0;

    for (final f in allFeatures) {
      if (_visible[f.layerId] == false) continue;

      var geom = _asMap(f.geometry);
      if (geom == null) continue;
      geom = _maybePromoteClosedLineToPolygon(geom);

      await _forEachVertex(geom, (lat, lng) async {
        // 🎯 Bounding box pre-filter (cheap, no async call)
        if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
          return;
        }
        checked++;

        final screen = await controller.toScreenLocation(LatLng(lat, lng));
        final dx = screen.x - tapPoint.x;
        final dy = screen.y - tapPoint.y;
        final dSq = dx * dx + dy * dy;

        if (dSq < bestDistSq && dSq <= tolSq) {
          bestDistSq = dSq;
          bestLatLng = LatLng(lat, lng);
        }
      });
    }

    debugPrint('[snap] scanned $checked candidate vertices, '
        'result: ${bestLatLng == null ? "none" : "snapped"}');
    return bestLatLng;
  }

  /// Walks all vertex coordinates of a GeoJSON geometry and invokes [onVertex]
  /// for each (lat, lng). Async to allow `toScreenLocation` inside.
  Future<void> _forEachVertex(
    Map<String, dynamic> geom,
    Future<void> Function(double lat, double lng) onVertex,
  ) async {
    final coords = geom['coordinates'];
    if (coords == null) return;
    final type = geom['type'];

    Future<void> visitPoint(dynamic c) async {
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        await onVertex((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }
    }

    switch (type) {
      case 'Point':
        await visitPoint(coords);
        break;
      case 'MultiPoint':
      case 'LineString':
        if (coords is List) {
          for (final c in coords) {
            await visitPoint(c);
          }
        }
        break;
      case 'MultiLineString':
      case 'Polygon':
        if (coords is List) {
          for (final ring in coords) {
            if (ring is List) {
              for (final c in ring) {
                await visitPoint(c);
              }
            }
          }
        }
        break;
      case 'MultiPolygon':
        if (coords is List) {
          for (final poly in coords) {
            if (poly is List) {
              for (final ring in poly) {
                if (ring is List) {
                  for (final c in ring) {
                    await visitPoint(c);
                  }
                }
              }
            }
          }
        }
        break;
    }
  }

  Future<void> _onMapClick(Point<double> point, LatLng coords) async {
    // ── D6.2: edit mode intercepts taps ──
    if (_editState != null) {
      _onEditTap(coords.longitude, coords.latitude);
      return;
    }

    // ── D6.3: line/polygon vertex edit intercepts taps ──
    if (_editStateLP != null) {
      await _onEditTapLP(coords.longitude, coords.latitude);
      return;
    }

    // If we're in capture mode, hijack the tap
    final capture = ref.read(mapCaptureProvider);

    // Single-point capture (Slice 1)
    if (capture.isActive &&
        (capture.phase == CapturePhase.awaitingMapTap ||
            capture.phase == CapturePhase.hasCandidate)) {
      await _placeCaptureCandidate(coords);
      return;
    }

    // Multi-tap drawing (Slice 2)
    if (capture.isActive && capture.phase == CapturePhase.drawingMulti) {
      LatLng vertex = coords;

      // 🧲 Snap to nearest existing vertex (if enabled and close enough)
      if (capture.snapEnabled) {
        final snapped = await _findSnapTarget(point);
        if (snapped != null) {
          vertex = snapped;
          debugPrint('[snap] vertex snapped to '
              '(${snapped.latitude}, ${snapped.longitude})');
        }
      }

      ref.read(mapCaptureProvider.notifier).addVertex(vertex);
      await _refreshMultiTapDrawing();
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    final layerIds =
        _mapLayerIdsByProjectLayer.values.expand((e) => e).toList();
    if (layerIds.isEmpty) return;

    // Delegate to the shared hit-test + bottom-sheet logic so a plain map
    // tap on a rendered feature actually shows its attributes.
    await _queryAndShow(point, null, coords);
  }

  Future<void> _onMapLongClick(Point<double> point, LatLng coords) async {
    // D6.3f: line/polygon vertex delete
    if (_editStateLP != null) {
      await _onEditLongPressLP(coords.longitude, coords.latitude);
      return;
    }

    // Future: D6.3g translate mode for point edit, D6.2 long-press to undo, etc.
    // For now, nothing else.
  }

  void _handleFeatureTap(
    Point<double> point,
    LatLng coordinates,
    String layerId,
    String featureId,
    Annotation? annotation,
  ) {
    // ── D6.3 / D6.2: edit modes intercept feature taps. Don't open the
    //                attribute sheet; the edit handler processes the tap.
    if (_editStateLP != null) {
      _onEditTapLP(coordinates.longitude, coordinates.latitude);
      return;
    }
    if (_editState != null) {
      _onEditTap(coordinates.longitude, coordinates.latitude);
      return;
    }

    // 🚫 Ignore feature taps while in capture mode. During capture, taps
    // should add vertices / place candidates — not open the attribute sheet.
    final capture = ref.read(mapCaptureProvider);
    if (capture.isActive) return;

    String? matchedLayerId;
    for (final entry in _mapLayerIdsByProjectLayer.entries) {
      if (entry.value.contains(layerId)) {
        matchedLayerId = entry.key;
        break;
      }
    }
    _queryAndShow(point, matchedLayerId, coordinates);
  }

  void _enterEditMode({
    required String sourceRef,
    required Map<String, dynamic>? originalGeometry,
    required Map<String, dynamic>? originalAttributes,
    required String? existingClientId,
    required String layerId,
    required String formId,
    required int formVersion,
    required String? dataSourceId,
  }) {
    if (originalGeometry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot edit: no original geometry to track')),
      );
      return;
    }

    setState(() {
      _editState = GeomEditState(
        sourceRef: sourceRef,
        originalGeometry: originalGeometry,
        existingClientId: existingClientId,
      );
      _editLayerId = layerId;
      _editFormId = formId;
      _editFormVersion = formVersion;
      _editDataSourceId = dataSourceId;
      _editOriginalAttributes = originalAttributes ?? const {};
    });

    // 🟠 Drop the highlight + auto-zoom to original location
    _addOriginalEditMarker();

    // Re-render so _renderFeatures' local-state filter hides the original
    if (_styleLoaded) {
      _renderFeatures(fitCamera: false);
    }
  }

  void _enterEditModeLP({
    required String sourceRef,
    required Map<String, dynamic> originalGeometry,
    required Map<String, dynamic>? originalAttributes,
    required String? existingClientId,
    required String layerId,
    required String formId,
    required int formVersion,
    required String? dataSourceId,
  }) {
    final geomType = originalGeometry['type']?.toString();
    if (geomType != 'LineString' && geomType != 'Polygon') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unsupported geometry type for edit: $geomType')),
      );
      return;
    }

    final initialVertices = extractVertices(originalGeometry);
    if (initialVertices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot edit: original geometry has no vertices')),
      );
      return;
    }

    setState(() {
      _editStateLP = GeomEditStateLP(
        geometryType: geomType!,
        sourceRef: sourceRef,
        originalGeometry: originalGeometry,
        existingClientId: existingClientId,
        vertices: initialVertices,
      );
      _editLayerId = layerId;
      _editFormId = formId;
      _editFormVersion = formVersion;
      _editDataSourceId = dataSourceId;
      _editOriginalAttributes = originalAttributes ?? const {};
    });

    // Re-render so _renderFeatures' local-state filter hides the original
    if (_styleLoaded) {
      _renderFeatures(fitCamera: false);
    }

    // Trigger the visual edit layers — ghost + live shape
    _renderEditLP();
    _fitCameraToEditLP();
  }

  Future<void> _exitEditMode() async {
    await _clearEditMarkers();

    if (!mounted) return;

    setState(() {
      _editState = null;
      _editLayerId = null;
      _editFormId = null;
      _editFormVersion = null;
      _editDataSourceId = null;
      _editOriginalAttributes = null;
    });

    // _renderFeatures' local-state filter now sees _editState == null,
    // so the original feature comes back into the render.
    if (mounted && _styleLoaded) {
      await _renderFeatures(fitCamera: false);
    }
  }

  Future<void> _exitEditModeLP() async {
    await _clearEditLPLayers();

    if (!mounted) return;

    setState(() {
      _editStateLP = null;
      _editLayerId = null;
      _editFormId = null;
      _editFormVersion = null;
      _editDataSourceId = null;
      _editOriginalAttributes = null;
    });

    // _renderFeatures' local-state filter now sees _editStateLP == null,
    // so the original feature comes back into the render.
    if (mounted && _styleLoaded) {
      await _renderFeatures(fitCamera: false);
    }
  }

  Future<void> _syncMyLocation(bool enabled) async {
    debugPrint('[myLocation] _syncMyLocation called, enabled=$enabled, '
        'controller=${_controller != null}, styleLoaded=$_styleLoaded');
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      debugPrint('[myLocation] deferring — controller or style not ready');
      return;
    }

    if (enabled) {
      _myLocationLayer ??= MyLocationLayer(
        mapController: controller,
        locationProvider: ref.read(activeLocationProvider),
      );
      final ok = await _myLocationLayer!.start(
        onCannotStart: (reason) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              content: Text(reason),
            ),
          );
          ref.read(settingsProvider.notifier).setShowMyLocation(false);
        },
      );
      if (!ok) {
        _myLocationLayer = null;
      }
    } else {
      await _myLocationLayer?.stop();
      _myLocationLayer = null;
    }
  }

  // Stash params we need at save time:
  String? _editLayerId;
  String? _editFormId;
  int? _editFormVersion;
  String? _editDataSourceId;
  Map<String, dynamic>? _editOriginalAttributes;

  void _onEditTap(double lng, double lat) {
    if (_editState == null) return;

    setState(() {
      _editState = GeomEditState(
        sourceRef: _editState!.sourceRef,
        originalGeometry: _editState!.originalGeometry,
        existingClientId: _editState!.existingClientId,
        proposedGeometry: {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
      );
    });

    // The orange marker IS the feature — move it (don't create a new one)
    _moveOriginalMarker(lng, lat);
  }

  /// Handles a map tap during line/polygon edit mode.
  /// D6.3c: tap a vertex → select. Tap empty + no selection → no-op (yet).
  /// D6.3d will add: tap empty + has selection → move vertex.
  /// Handles a map tap during line/polygon edit mode.
  ///
  /// - Tap on a vertex → toggle selection
  /// - Tap empty space + has selection → move that vertex there
  /// - Tap empty space + no selection → no-op (D6.3e will use this for midpoint insert)
  /// Handles a map tap during line/polygon edit mode.
  ///
  /// Priority:
  ///   1. Vertex → toggle selection
  ///   2. Midpoint → insert a new vertex there + select it
  ///   3. Empty + has selection → move that vertex
  ///   4. Empty + no selection → no-op
  Future<void> _onEditTapLP(double lng, double lat) async {
    final state = _editStateLP;
    if (state == null) return;

    // ── D6.3g: translate mode — apply the shift then exit ──
    if (state.isTranslating && state.translateAnchor != null) {
      final dLng = lng - state.translateAnchor![0];
      final dLat = lat - state.translateAnchor![1];
      setState(() {
        for (int i = 0; i < state.vertices.length; i++) {
          state.vertices[i] = [
            state.vertices[i][0] + dLng,
            state.vertices[i][1] + dLat,
          ];
        }
        state.isTranslating = false;
        state.translateAnchor = null;
      });
      await _renderEditLP();
      return;
    }

    debugPrint('[D6.3 TAP] lng=$lng lat=$lat');

    // 1. Vertex hit?
    final hitVertex = _nearestVertexIndex(lng, lat);
    if (hitVertex != null) {
      setState(() {
        if (state.selectedIndex == hitVertex) {
          state.selectedIndex = null;
        } else {
          state.selectedIndex = hitVertex;
        }
      });
      await _renderVertexHandles();
      return;
    }

    // 2. Midpoint hit? Insert vertex there.
    final hitMidpoint = _nearestMidpointSegmentIndex(lng, lat);
    if (hitMidpoint != null) {
      final insertAt = hitMidpoint + 1; // insert AFTER the segment-start vertex
      setState(() {
        state.vertices.insert(insertAt, [lng, lat]);
        state.selectedIndex = insertAt; // auto-select the new vertex
      });
      await _renderEditLP(); // re-render shape + handles + midpoints
      return;
    }

    // 3. Empty + has selection → move that vertex
    if (state.selectedIndex != null) {
      setState(() {
        state.vertices[state.selectedIndex!] = [lng, lat];
      });
      await _renderEditLP();
      return;
    }

    // 4. Empty + no selection → no-op (D6.3f/g will use long-press for delete/translate)
  }

  /// Handles a map long-press during line/polygon edit mode.
  ///
  /// - Long-press on a vertex → confirm + delete (with min-vertex guard)
  /// - Long-press anywhere else → no-op (D6.3g will use this for translate)
  Future<void> _onEditLongPressLP(double lng, double lat) async {
    final state = _editStateLP;
    if (state == null) return;

    final hitVertex = _nearestVertexIndex(lng, lat);
    if (hitVertex == null) {
      // Long-press on body (not a vertex) → enter translate mode
      setState(() {
        _editStateLP!.isTranslating = true;
        _editStateLP!.translateAnchor = [lng, lat];
        _editStateLP!.selectedIndex = null;
      });
      await _renderVertexHandles(); // clear any selection visually
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('Translate mode — tap the new position'),
          ),
        );
      }
      return;
    }

    // Min-vertex guard
    if (state.vertices.length <= state.minVertices) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            'Cannot delete — ${state.geometryType} needs at least '
            '${state.minVertices} vertices.',
          ),
        ),
      );
      return;
    }

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text('Delete vertex?'),
          content: Text(
            'Remove vertex ${hitVertex + 1} of ${state.vertices.length} from this '
            '${state.geometryType.toLowerCase()}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      state.vertices.removeAt(hitVertex);
      // Clear selection if it was the deleted vertex or any later (indices shift)
      if (state.selectedIndex != null) {
        if (state.selectedIndex == hitVertex) {
          state.selectedIndex = null;
        } else if (state.selectedIndex! > hitVertex) {
          state.selectedIndex = state.selectedIndex! - 1;
        }
      }
    });

    await _renderEditLP();
  }

// ── D6.2 polish: visual markers + auto-zoom ──
  Future<void> _addOriginalEditMarker() async {
    final state = _editState;
    final controller = _controller;
    if (state == null || controller == null) return;

    // Belt-and-suspenders: remove any prior orange marker before adding a new one
    if (_editOriginalCircle != null) {
      try {
        await controller.removeCircle(_editOriginalCircle!);
      } catch (_) {}
      _editOriginalCircle = null;
    }

    final origCoords = state.originalGeometry['coordinates'];
    if (origCoords is! List || origCoords.length < 2) return;

    final lon = (origCoords[0] as num).toDouble();
    final lat = (origCoords[1] as num).toDouble();

    _editOriginalCircle = await controller.addCircle(
      CircleOptions(
        geometry: LatLng(lat, lon),
        circleColor: '#f59e0b', // amber
        circleRadius: 14,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
        circleOpacity: 0.9,
      ),
    );

    // Auto-zoom in so the user sees what they're editing
    // In _addOriginalEditMarker, just before animateCamera:
    debugPrint(
        '[D6.2] auto-zoom to lat=$lat lon=$lon (current zoom should change to 17.5)');
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lon), 17.5),
    );
    debugPrint('[D6.2] animateCamera completed');
  }

  Future<void> _clearEditMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    if (_editOriginalCircle != null) {
      try {
        await controller.removeCircle(_editOriginalCircle!);
      } catch (_) {}
      _editOriginalCircle = null;
    }

    if (_editProposedCircle != null) {
      try {
        await controller.removeCircle(_editProposedCircle!);
      } catch (_) {}
      _editProposedCircle = null;
    }
  }

  /// Renders both the dimmed original (ghost) and the live working shape
  /// for the current line/polygon edit. Called whenever state mutates.
  Future<void> _renderEditLP() async {
    final state = _editStateLP;
    final controller = _controller;
    if (state == null || controller == null) return;

    await _clearEditLPLayers();

    // Build ghost coordinates from original geometry
    final ghostCoords = extractVertices(state.originalGeometry);
    final liveCoords = state.vertices;

    // Helper closures
    Future<Line> drawLine(
      List<List<double>> coords, {
      required String color,
      required double width,
      required double opacity,
    }) async {
      return controller.addLine(
        LineOptions(
          geometry: [
            for (final v in coords) LatLng(v[1], v[0]),
          ],
          lineColor: color,
          lineWidth: width,
          lineOpacity: opacity,
        ),
      );
    }

    Future<Fill> drawFill(
      List<List<double>> coords, {
      required String color,
      required double opacity,
    }) async {
      // Polygon ring with closing vertex
      final ring = [
        for (final v in coords) LatLng(v[1], v[0]),
        if (coords.isNotEmpty) LatLng(coords.first[1], coords.first[0]),
      ];
      return controller.addFill(
        FillOptions(
          geometry: [ring],
          fillColor: color,
          fillOpacity: opacity,
        ),
      );
    }

    if (state.isLine) {
      // Ghost: dimmed gray original
      if (ghostCoords.length >= 2) {
        _editGhostLine = await drawLine(
          ghostCoords,
          color: '#9ca3af', // gray-400
          width: 3,
          opacity: 0.5,
        );
      }
      // Live: solid blue working shape
      if (liveCoords.length >= 2) {
        _editLiveLine = await drawLine(
          liveCoords,
          color: '#2563eb', // blue-600
          width: 4,
          opacity: 0.95,
        );
      }
    } else if (state.isPolygon) {
      // Ghost fill + stroke
      if (ghostCoords.length >= 3) {
        _editGhostFill = await drawFill(
          ghostCoords,
          color: '#9ca3af',
          opacity: 0.15,
        );
        _editGhostFillStroke = await drawLine(
          [...ghostCoords, ghostCoords.first],
          color: '#9ca3af',
          width: 2,
          opacity: 0.6,
        );
      }
      // Live fill + stroke
      if (liveCoords.length >= 3) {
        _editLiveFill = await drawFill(
          liveCoords,
          color: '#2563eb',
          opacity: 0.25,
        );
        _editLiveFillStroke = await drawLine(
          [...liveCoords, liveCoords.first],
          color: '#2563eb',
          width: 3,
          opacity: 0.95,
        );
      }
    }

    await _renderVertexHandles();
    await _renderMidpointHandles();
  }

  /// Renders one orange circle handle per working vertex. The currently
  /// selected vertex (if any) renders larger and brighter.
  Future<void> _renderVertexHandles() async {
    final state = _editStateLP;
    final controller = _controller;
    if (state == null || controller == null) return;

    // Clear existing
    for (final h in _editVertexHandles) {
      try {
        await controller.removeCircle(h);
      } catch (_) {}
    }
    _editVertexHandles.clear();

    for (int i = 0; i < state.vertices.length; i++) {
      final v = state.vertices[i];
      final isSelected = state.selectedIndex == i;
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(v[1], v[0]),
          circleColor:
              isSelected ? '#dc2626' : '#f59e0b', // red-600 vs amber-500
          circleRadius: isSelected ? 11 : 8,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2.5,
          circleOpacity: 1.0,
        ),
      );
      _editVertexHandles.add(circle);
    }
  }

  /// Renders small ghosted circles at the midpoint of each segment.
  /// Tapping one inserts a new vertex there.
  Future<void> _renderMidpointHandles() async {
    final state = _editStateLP;
    final controller = _controller;
    if (state == null || controller == null) return;

    // Clear existing
    for (final h in _editMidpointHandles) {
      try {
        await controller.removeCircle(h);
      } catch (_) {}
    }
    _editMidpointHandles.clear();

    if (state.vertices.length < 2) return;

    // For a line, iterate i → i+1
    // For a polygon, also do last → first (closing segment)
    final segmentCount =
        state.isPolygon ? state.vertices.length : state.vertices.length - 1;

    for (int i = 0; i < segmentCount; i++) {
      final a = state.vertices[i];
      final b = state.vertices[(i + 1) % state.vertices.length];
      final midLng = (a[0] + b[0]) / 2.0;
      final midLat = (a[1] + b[1]) / 2.0;

      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(midLat, midLng),
          circleColor: '#ffffff', // white inner
          circleRadius: 5,
          circleStrokeColor: '#f59e0b', // amber outline
          circleStrokeWidth: 2,
          circleOpacity: 0.85,
        ),
      );
      _editMidpointHandles.add(circle);
    }
  }

  /// Removes all LP render layers (ghost + live).
  Future<void> _clearEditLPLayers() async {
    final controller = _controller;
    if (controller == null) return;

    // Ghost + live shape lines and fills
    if (_editGhostLine != null) {
      try {
        await controller.removeLine(_editGhostLine!);
      } catch (_) {}
      _editGhostLine = null;
    }
    if (_editGhostFillStroke != null) {
      try {
        await controller.removeLine(_editGhostFillStroke!);
      } catch (_) {}
      _editGhostFillStroke = null;
    }
    if (_editGhostFill != null) {
      try {
        await controller.removeFill(_editGhostFill!);
      } catch (_) {}
      _editGhostFill = null;
    }
    if (_editLiveLine != null) {
      try {
        await controller.removeLine(_editLiveLine!);
      } catch (_) {}
      _editLiveLine = null;
    }
    if (_editLiveFillStroke != null) {
      try {
        await controller.removeLine(_editLiveFillStroke!);
      } catch (_) {}
      _editLiveFillStroke = null;
    }
    if (_editLiveFill != null) {
      try {
        await controller.removeFill(_editLiveFill!);
      } catch (_) {}
      _editLiveFill = null;
    }

    // Vertex handles (orange/red circles)
    for (final h in _editVertexHandles) {
      try {
        await controller.removeCircle(h);
      } catch (_) {}
    }
    _editVertexHandles.clear();

    // Midpoint handles (small ghosted circles)
    for (final h in _editMidpointHandles) {
      try {
        await controller.removeCircle(h);
      } catch (_) {}
    }
    _editMidpointHandles.clear();
  }

  /// Returns the index of the vertex nearest to (lng, lat) within
  /// [thresholdDeg] degrees. Returns null if none in range.
  /// At zoom 17.5, ~0.0001 degree ≈ 11 meters — a comfortable tap radius.
  int? _nearestVertexIndex(double lng, double lat,
      {double thresholdDeg = 0.005}) {
    final state = _editStateLP;
    if (state == null) return null;

    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < state.vertices.length; i++) {
      final v = state.vertices[i];
      // Simple planar distance — fine at small scale
      final dx = v[0] - lng;
      final dy = v[1] - lat;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    // thresholdDeg squared
    if (bestDist > thresholdDeg * thresholdDeg) return null;
    return best;
  }

  /// Returns the segment index whose midpoint is closest to (lng, lat)
  /// within threshold. The "segment index" is the index of the FIRST vertex
  /// of that segment — so if it returns 3, the new vertex will be inserted
  /// between vertex 3 and vertex 4 (or 0 for closing segments in polygons).
  int? _nearestMidpointSegmentIndex(double lng, double lat,
      {double thresholdDeg = 0.005}) {
    final state = _editStateLP;
    if (state == null || state.vertices.length < 2) return null;

    final segmentCount =
        state.isPolygon ? state.vertices.length : state.vertices.length - 1;

    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < segmentCount; i++) {
      final a = state.vertices[i];
      final b = state.vertices[(i + 1) % state.vertices.length];
      final midLng = (a[0] + b[0]) / 2.0;
      final midLat = (a[1] + b[1]) / 2.0;
      final dx = midLng - lng;
      final dy = midLat - lat;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (bestDist > thresholdDeg * thresholdDeg) return null;
    return best;
  }

  /// Computes bounds of all working vertices + ghost vertices,
  /// then auto-zooms the camera to fit them.
  Future<void> _fitCameraToEditLP() async {
    final state = _editStateLP;
    final controller = _controller;
    if (state == null || controller == null) return;

    final allVerts = [
      ...state.vertices,
      ...extractVertices(state.originalGeometry),
    ];
    if (allVerts.isEmpty) return;

    double minLng = allVerts.first[0], maxLng = allVerts.first[0];
    double minLat = allVerts.first[1], maxLat = allVerts.first[1];
    for (final v in allVerts) {
      if (v[0] < minLng) minLng = v[0];
      if (v[0] > maxLng) maxLng = v[0];
      if (v[1] < minLat) minLat = v[1];
      if (v[1] > maxLat) maxLat = v[1];
    }

    // Small padding around the bounds
    final lngPad = (maxLng - minLng) * 0.2 + 0.0005;
    final latPad = (maxLat - minLat) * 0.2 + 0.0005;

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPad, minLng - lngPad),
          northeast: LatLng(maxLat + latPad, maxLng + lngPad),
        ),
        left: 40,
        top: 40,
        right: 40,
        bottom: 160,
      ),
    );
  }

  Future<void> _saveEditGeometry() async {
    final state = _editState;
    if (state == null || state.proposedGeometry == null) return;

    final repo = ref.read(collectedFeatureRepoProvider);
    if (repo == null) return;

    try {
      await repo.updateGeometry(
        projectId: widget.project.id,
        layerId: _editLayerId!,
        formId: _editFormId!,
        formVersion: _editFormVersion!,
        sourceRef: state.sourceRef,
        dataSourceId: _editDataSourceId,
        originalGeometry: state.originalGeometry,
        newGeometry: state.proposedGeometry!,
        originalAttributes: _editOriginalAttributes ?? const {},
      );

      // Refresh the map so the moved point shows at its new location
      ref.invalidate(localReferenceFeaturesProvider(widget.project.id));
      ref.invalidate(localCollectedFeaturesProvider(widget.project.id));

      // 👇 Force an immediate re-render — invalidates alone are lazy
      if (mounted && _styleLoaded) {
        await _renderFeatures(fitCamera: false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated — pending sync'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      _exitEditMode();
    }
  }

  Future<void> _saveEditGeometryLP() async {
    final state = _editStateLP;
    if (state == null) return;

    if (state.vertices.length < state.minVertices) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot save — ${state.geometryType} needs at least '
            '${state.minVertices} vertices.',
          ),
        ),
      );
      return;
    }

    final repo = ref.read(collectedFeatureRepoProvider);
    if (repo == null) return;

    try {
      await repo.updateGeometry(
        projectId: widget.project.id,
        layerId: _editLayerId!,
        formId: _editFormId!,
        formVersion: _editFormVersion!,
        sourceRef: state.sourceRef,
        dataSourceId: _editDataSourceId,
        originalGeometry: state.originalGeometry,
        newGeometry: state.toGeoJson(),
        originalAttributes: _editOriginalAttributes ?? const {},
      );

      // Refresh the map immediately so the edit shows at the new location
      ref.invalidate(localReferenceFeaturesProvider(widget.project.id));
      ref.invalidate(localCollectedFeaturesProvider(widget.project.id));
      if (mounted && _styleLoaded) {
        await _renderFeatures(fitCamera: false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${state.geometryType} updated — pending sync',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      _exitEditModeLP();
    }
  }

  Future<void> _queryAndShow(
    Point<double> point,
    String? hintLayerId, [
    LatLng? tapCoords,
  ]) async {
    final controller = _controller;
    if (controller == null) return;

    final layerIds =
        _mapLayerIdsByProjectLayer.values.expand((e) => e).toList();
    if (layerIds.isEmpty) return;

    try {
      // Query per project layer so we know which layer a hit belongs to.
      // Prefer non-cluster features with fc_ref over tippecanoe cluster proxies.
      Map<String, dynamic>? feature;
      Map<String, dynamic> props = const {};
      String? layerId = hintLayerId;
      var totalHits = 0;

      final layersToQuery = hintLayerId != null
          ? <MapEntry<String, List<String>>>[
              MapEntry(
                hintLayerId,
                _mapLayerIdsByProjectLayer[hintLayerId] ?? const [],
              ),
            ]
          : _mapLayerIdsByProjectLayer.entries.toList();

      for (final entry in layersToQuery) {
        final styleIds = entry.value;
        if (styleIds.isEmpty) continue;
        List<dynamic> layerHits = const [];
        try {
          layerHits = await controller.queryRenderedFeaturesInRect(
            Rect.fromLTRB(
              point.x - 14,
              point.y - 14,
              point.x + 14,
              point.y + 14,
            ),
            styleIds,
            null,
          );
        } catch (_) {
          try {
            layerHits =
                await controller.queryRenderedFeatures(point, styleIds, null);
          } catch (_) {}
        }
        totalHits += layerHits.length;
        final picked = _pickBestTapFeature(layerHits);
        if (picked != null) {
          feature = picked.$1;
          props = picked.$2;
          layerId = entry.key;
          break;
        }
      }

      debugPrint('[map] featureTap hits=$totalHits layer=$layerId '
          'props=${props.keys.toList()}');

      if (feature == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              content: Text('No feature here. Try tapping closer.'),
            ),
          );
        }
        return;
      }

      // ── Vector tile hits carry fc_ref / _source_ref; full attributes live in
      // SQLite (reference_search index). GeoJSON-collected hits use nested
      // _attributes / _featureId keys.
      String? featureId = props['_featureId']?.toString();
      Map<String, dynamic> attributes = const {};
      String? source = props['_source']?.toString();
      String? sourceRef = _nonEmptyString(props['fc_ref']) ??
          _nonEmptyString(props['_source_ref']) ??
          _nonEmptyString(props['_sourceRef']) ??
          _nonEmptyString(props['source_ref']) ??
          _nonEmptyString(feature['id']);

      layerId ??= props['_layerId']?.toString();
      layerId ??= _projectLayerIdFromMapHit(feature);

      final isVectorTileHit =
          props['_featureId'] == null && props['_attributes'] == null;

      if (kDebugMode) {
        debugPrint(
          '[map] tap props keys=${props.keys.toList()} '
          'fc_ref=${props['fc_ref']} source=${feature?['source']} '
          'layerId=$layerId',
        );
      }

      if (isVectorTileHit) {
        source ??= 'reference';
      } else {
        final rawAttrs = props['_attributes'];
        if (rawAttrs is String) {
          try {
            final parsed = jsonDecode(rawAttrs);
            if (parsed is Map) {
              attributes = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        } else if (rawAttrs is Map) {
          attributes = Map<String, dynamic>.from(rawAttrs);
        }
        sourceRef ??= _nonEmptyString(props['_sourceRef']);
      }

      Map<String, dynamic>? highlightGeom;
      try {
        final database = ref.read(appDatabaseProvider);
        if (database != null) {
          db.ReferenceFeature? row;
          if (featureId != null && featureId.isNotEmpty) {
            row = await (database.select(database.referenceFeatures)
                  ..where((r) => r.id.equals(featureId!))
                  ..where((r) => r.projectId.equals(widget.project.id)))
                .getSingleOrNull();
          }
          if (row == null &&
              sourceRef != null &&
              sourceRef.isNotEmpty) {
            var q = database.select(database.referenceFeatures)
              ..where((r) => r.projectId.equals(widget.project.id))
              ..where((r) => r.sourceRef.equals(sourceRef!));
            if (layerId != null) {
              q = q..where((r) => r.layerId.equals(layerId!));
            }
            final matches = await q.get();
            row = matches.isEmpty ? null : matches.first;
            if (row == null && layerId != null) {
              row = await (database.select(database.referenceFeatures)
                    ..where(
                      (r) => r.id.equals('$layerId:$sourceRef'),
                    ))
                  .getSingleOrNull();
            }
            // source_ref may be stored under a different casing / id shape
          }

          // Old mbtiles without fc_ref: nearest Point in SQLite for this layer.
          if (row == null &&
              layerId != null &&
              tapCoords != null) {
            row = await _nearestReferenceFeature(
              database: database,
              layerId: layerId!,
              lng: tapCoords.longitude,
              lat: tapCoords.latitude,
            );
            if (row != null) {
              debugPrint(
                '[map] tap resolved by proximity: id=${row.id} '
                'source_ref=${row.sourceRef}',
              );
            }
          }

          if (row != null) {
            featureId = row.id;
            layerId = row.layerId;
            source ??= 'reference';
            sourceRef ??= row.sourceRef;
            try {
              final parsedAttrs = jsonDecode(row.attributes);
              if (parsedAttrs is Map) {
                attributes = Map<String, dynamic>.from(parsedAttrs);
              }
            } catch (_) {}
            try {
              final parsedGeom = jsonDecode(row.geometry);
              if (parsedGeom is Map) {
                highlightGeom = Map<String, dynamic>.from(parsedGeom);
              }
            } catch (_) {}
            debugPrint('[map] tap resolved from SQLite: id=$featureId '
                'layer=$layerId attrs=${attributes.length}');
          } else {
            debugPrint('[map] tap: no SQLite row for source_ref=$sourceRef '
                'layer=$layerId props=${props.keys.toList()}');
          }
        }
      } catch (e) {
        debugPrint('[map] SQLite tap enrichment failed: $e');
      }

      if (highlightGeom == null && feature != null) {
        final g = feature['geometry'];
        if (g is Map) {
          highlightGeom = Map<String, dynamic>.from(g);
        }
      }

      if (sourceRef != null && sourceRef.isEmpty) sourceRef = null;
      debugPrint('[D0.2 DEBUG] tap props: source=$source, attrs=${attributes.length}');

      if (!mounted) return;
      if (highlightGeom != null) {
        await _setFeatureSelectionHighlight(highlightGeom);
      }
      await _showFeatureSheet(
        layerId: layerId,
        featureId: featureId,
        attributes: attributes,
        source: source,
        sourceRef: sourceRef,
      );
    } catch (e) {
      debugPrint('[map] featureTap error: $e');
    }
  }

  Future<void> _moveOriginalMarker(double lng, double lat) async {
    final controller = _controller;
    if (controller == null) return;

    // If there's no orange marker for some reason, create one rather than no-op
    if (_editOriginalCircle == null) {
      _editOriginalCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(lat, lng),
          circleColor: '#f59e0b',
          circleRadius: 14,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
          circleOpacity: 0.9,
        ),
      );
      return;
    }

    // Otherwise, move the existing one (don't duplicate)
    await controller.updateCircle(
      _editOriginalCircle!,
      CircleOptions(geometry: LatLng(lat, lng)),
    );
  }

  Future<void> _showFeatureSheet({
    required String? layerId,
    required String? featureId,
    required Map<String, dynamic> attributes,
    String? source, // 👈 NEW
    String? sourceRef, // 👈 NEW
  }) async {
    final layerNamesAsync =
        ref.read(localLayerNamesProvider(widget.project.id));
    final layerNames = layerNamesAsync.value ?? const <String, String>{};
    final layerName =
        layerId != null ? (layerNames[layerId] ?? 'Layer') : 'Feature';

    // Linked layers may have is_editable=false on the server but still allow
    // reference edits. Only the AOI source layer is fully locked.
    var layerEditable = true;
    if (layerId != null) {
      final db = ref.read(appDatabaseProvider);
      if (db != null) {
        final project = await (db.select(db.projects)
              ..where((p) => p.id.equals(widget.project.id)))
            .getSingleOrNull();
        if (project?.aoiLayerId != null && project!.aoiLayerId == layerId) {
          layerEditable = false;
        }
      }
    }
    if (!mounted) return;

    // Best distinguishing attribute for a subtitle
    String? subtitle;
    for (final k in [
      'substation_name',
      'name',
      'asset_name',
      'location_description',
      'circuit_id',
      'district'
    ]) {
      final v = attributes[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        subtitle = v.toString();
        break;
      }
    }
    // Sort attributes: preferred name-like keys first, then alphabetical
    const preferred = <String>[
      'name',
      'title',
      'label',
      'asset_name',
      'circuit_id',
      'district',
      'region',
      'unique_id',
      'unique_number',
      'manufacturer',
      'serial_number',
      'status',
    ];

    final keys = attributes.keys.toList();
    keys.sort((a, b) {
      final ai = preferred.indexOf(a.toLowerCase());
      final bi = preferred.indexOf(b.toLowerCase());
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    String formatVal(dynamic v) {
      if (v == null) return '—';
      if (v is String) return v.isEmpty ? '—' : v;
      if (v is num || v is bool) return v.toString();
      try {
        return jsonEncode(v);
      } catch (_) {
        return v.toString();
      }
    }

    if (_useMapSidePanel(context)) {
      setState(() {
        _panelFeature = _PanelFeature(
          layerId: layerId,
          featureId: featureId,
          attributes: attributes,
          source: source,
          sourceRef: sourceRef,
          layerName: layerName,
          subtitle: subtitle,
          keys: keys,
          layerEditable: layerEditable,
        );
        _tabletMode = _TabletMode.feature;
        _tabletPanelExpanded = true;
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.25,
          maxChildSize: 0.95,
          builder: (context, scroll) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildFeatureInspector(
                scrollController: scroll,
                layerId: layerId,
                featureId: featureId,
                attributes: attributes,
                source: source,
                sourceRef: sourceRef,
                layerName: layerName,
                subtitle: subtitle,
                keys: keys,
                layerEditable: layerEditable,
                formatVal: formatVal,
                dismissSheet: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureInspector({
    ScrollController? scrollController,
    required String? layerId,
    required String? featureId,
    required Map<String, dynamic> attributes,
    required String? source,
    required String? sourceRef,
    required String layerName,
    required String? subtitle,
    required List<String> keys,
    required bool layerEditable,
    required String Function(dynamic) formatVal,
    required bool dismissSheet,
  }) {
    final theme = Theme.of(context);

    void closeThen(VoidCallback action) {
      if (dismissSheet) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _panelFeature = null;
          if (_tabletMode == _TabletMode.feature) {
            _tabletMode = _TabletMode.layers;
          }
        });
      }
      action();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (!dismissSheet)
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _panelFeature = null;
                    if (_tabletMode == _TabletMode.feature) {
                      _tabletMode = _TabletMode.layers;
                    }
                  });
                },
              ),
          ],
        ),
        if (featureId != null) ...[
          const SizedBox(height: 2),
          Text(
            'id: $featureId',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: keys.isEmpty
              ? Center(
                  child: Text(
                    'No attributes available for this feature.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  itemCount: keys.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final k = keys[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            formatVal(attributes[k]),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (layerEditable &&
            (source == 'reference' ||
                (source == 'collected' && sourceRef != null))) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    closeThen(() {
                      _onEditReferencePressed(
                        layerId: layerId,
                        featureId: featureId,
                        sourceRef: sourceRef,
                        attributes: attributes,
                      );
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    closeThen(() {
                      _onMarkDeletedPressed(
                        layerId: layerId,
                        featureId: featureId,
                        sourceRef: sourceRef,
                        attributes: attributes,
                      );
                    });
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Mark deleted',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: theme.colorScheme.error.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else if (!layerEditable &&
            (source == 'reference' ||
                (source == 'collected' && sourceRef != null))) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            'This layer is the project AOI and cannot be edited in the field.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Extract a representative (lng, lat) tuple from any GeoJSON geometry
  /// for centering the map on it.
  (double, double)? _extractCenterCoords(Map<dynamic, dynamic> geom) {
    final type = geom['type'];
    final coords = geom['coordinates'];
    if (coords == null) return null;

    try {
      switch (type) {
        case 'Point':
          if (coords is List && coords.length >= 2) {
            return (
              (coords[0] as num).toDouble(),
              (coords[1] as num).toDouble(),
            );
          }
          break;
        case 'LineString':
        case 'MultiPoint':
          if (coords is List && coords.isNotEmpty) {
            final first = coords[0];
            if (first is List && first.length >= 2) {
              return (
                (first[0] as num).toDouble(),
                (first[1] as num).toDouble(),
              );
            }
          }
          break;
        case 'Polygon':
        case 'MultiLineString':
          if (coords is List && coords.isNotEmpty) {
            final ring = coords[0];
            if (ring is List && ring.isNotEmpty) {
              final first = ring[0];
              if (first is List && first.length >= 2) {
                return (
                  (first[0] as num).toDouble(),
                  (first[1] as num).toDouble(),
                );
              }
            }
          }
          break;
        case 'MultiPolygon':
          if (coords is List && coords.isNotEmpty) {
            final poly = coords[0];
            if (poly is List && poly.isNotEmpty) {
              final ring = poly[0];
              if (ring is List && ring.isNotEmpty) {
                final first = ring[0];
                if (first is List && first.length >= 2) {
                  return (
                    (first[0] as num).toDouble(),
                    (first[1] as num).toDouble(),
                  );
                }
              }
            }
          }
          break;
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  Map<String, dynamic> _geoJsonFeature(
    Map<String, dynamic> geom,
    LocalMapFeature f,
  ) {
    // Normalize attributes to a real map regardless of source shape
    Map<String, dynamic> attrs = const {};
    final dynamic raw = f.attributes;

    if (raw is Map<String, dynamic>) {
      attrs = raw;
    } else if (raw is Map) {
      attrs = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final str = raw as String;
      try {
        final parsed = jsonDecode(str);
        if (parsed is Map<String, dynamic>) {
          attrs = parsed;
        } else if (parsed is Map) {
          attrs = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }

    return {
      'type': 'Feature',
      'geometry': geom,
      'properties': {
        '_layerId': f.layerId,
        '_featureId': f.id,
        '_attributes': jsonEncode(attrs),
        '_source': f.source, // 👈 NEW: 'reference' | 'collected'
        '_sourceRef':
            f.sourceRef ?? '', // 👈 NEW: for D0.3 — the external row id
      },
    };
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) {
      try {
        final parsed = jsonDecode(v);
        if (parsed is Map<String, dynamic>) return parsed;
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return null;
  }

  /// Safety guard: if a LineString has a closed ring (first point == last point,
  /// at least 4 coords), treat it as a Polygon. This protects against legacy
  /// data or third-party imports where polygons were accidentally stored as
  /// LineStrings.
  Map<String, dynamic> _maybePromoteClosedLineToPolygon(
    Map<String, dynamic> geom,
  ) {
    if (geom['type'] != 'LineString') return geom;

    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 4) return geom;

    final first = coords.first;
    final last = coords.last;
    if (first is! List || last is! List) return geom;
    if (first.length < 2 || last.length < 2) return geom;

    final closed = (first[0] as num) == (last[0] as num) &&
        (first[1] as num) == (last[1] as num);
    if (!closed) return geom;

    // Promote: wrap coords as a single outer ring.
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  void _accumulate(Map<String, dynamic> geom, _BoundsAccumulator b) {
    final coords = geom['coordinates'];
    if (coords == null) return;
    final type = geom['type'];
    switch (type) {
      case 'Point':
        _addLngLat(coords, b);
        break;
      case 'MultiPoint':
      case 'LineString':
        if (coords is List) {
          for (final c in coords) {
            _addLngLat(c, b);
          }
        }
        break;
      case 'MultiLineString':
      case 'Polygon':
        if (coords is List) {
          for (final ring in coords) {
            if (ring is List) {
              for (final c in ring) {
                _addLngLat(c, b);
              }
            }
          }
        }
        break;
      case 'MultiPolygon':
        if (coords is List) {
          for (final poly in coords) {
            if (poly is List) {
              for (final ring in poly) {
                if (ring is List) {
                  for (final c in ring) {
                    _addLngLat(c, b);
                  }
                }
              }
            }
          }
        }
        break;
    }
  }

  void _addLngLat(dynamic c, _BoundsAccumulator b) {
    if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
      b.add((c[0] as num).toDouble(), (c[1] as num).toDouble());
    }
  }

  String? _typeOf(dynamic geometry) {
    final m = _asMap(geometry);
    if (m == null) return null;
    final t = m['type'];
    return t is String ? t : null;
  }

  Future<void> _toggleLayer(String layerId, bool value) async {
    setState(() {
      _visible[layerId] = value;
    });
    if (value) {
      final tiles = await _tilesPathFor(layerId);
      if (tiles == null) {
        final repo = ref.read(bundleRepositoryProvider);
        if (repo != null) {
          _layerFetchAttempted.remove(layerId);
          if (mounted) {
            setState(() => _layerFetchStatus = 'Downloading layer…');
          }
          try {
            PacksManifest? manifest;
            try {
              manifest =
                  await repo.getPacksManifest(projectId: widget.project.id);
            } catch (_) {}
            await ref.read(bundleDownloaderProvider).ensureLayerReferencePack(
                  projectId: widget.project.id,
                  layerId: layerId,
                  repo: repo,
                  remoteHash: manifest?.layerHashes[layerId],
                );
            _layerFetchAttempted.add(layerId);
            ref.invalidate(
              layerTilesPathProvider(
                (projectId: widget.project.id, layerId: layerId),
              ),
            );
          } catch (e) {
            debugPrint('[map] toggle layer pack failed: $e');
          } finally {
            if (mounted) setState(() => _layerFetchStatus = null);
          }
        }
      }
    }
    await _renderFeatures(onlyLayerId: layerId, fitCamera: false);
  }

  // ─────────────────────────────────────────────
  // Layer style loading
  // ─────────────────────────────────────────────

  /// Reads `layers.style` rows from the local SQLite via the existing
  /// providers / Drift instance. We do this via a Riverpod-friendly path
  /// that delegates to the existing layer-style fetcher you may already have.
  ///
  /// Returns map of projectLayerId → flat style {color,opacity,size,...}.
  Future<Map<String, LayerMapAppearance>> _loadLayerAppearances(
    String projectId,
  ) async {
    try {
      final raw = await ref.read(
        localLayerStylesProvider(projectId).future,
      );
      final out = <String, LayerMapAppearance>{};
      for (final entry in raw.entries) {
        Map<String, dynamic>? styleJson;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          styleJson = value;
        } else if (value is Map) {
          styleJson = Map<String, dynamic>.from(value);
        } else if (value is String) {
          try {
            final parsed = jsonDecode(value);
            if (parsed is Map<String, dynamic>) {
              styleJson = parsed;
            } else if (parsed is Map) {
              styleJson = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        }
        if (styleJson == null) continue;
        out[entry.key] = parseLayerMapAppearance(styleJson);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  String _safeColor(dynamic v, String fallback) {
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  String? _nonEmptyString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Prefer identifiable features over tippecanoe cluster proxies.
  (Map<String, dynamic>, Map<String, dynamic>)? _pickBestTapFeature(
    List<dynamic> hits,
  ) {
    (Map<String, dynamic>, Map<String, dynamic>)? fallback;
    for (final hit in hits) {
      Map<String, dynamic>? feature;
      if (hit is Map) {
        feature = Map<String, dynamic>.from(hit);
      } else if (hit is String) {
        try {
          final parsed = jsonDecode(hit);
          if (parsed is Map) feature = Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }
      if (feature == null) continue;

      Map<String, dynamic> props = const {};
      final p = feature['properties'];
      if (p is Map) {
        props = Map<String, dynamic>.from(p);
      } else if (p is String) {
        try {
          final parsed = jsonDecode(p);
          if (parsed is Map) props = Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }

      // Tippecanoe cluster bubbles — not real features.
      if (props.containsKey('clustered') ||
          props.containsKey('point_count') ||
          props['cluster'] == true) {
        continue;
      }

      final hasRef = _nonEmptyString(props['fc_ref']) != null ||
          _nonEmptyString(props['_source_ref']) != null ||
          _nonEmptyString(props['_featureId']) != null ||
          _nonEmptyString(props['_attributes']) != null ||
          _nonEmptyString(feature['id']) != null;
      if (hasRef) return (feature, props);
      fallback ??= (feature, props);
    }
    return fallback;
  }

  /// Resolve project layer UUID from MapLibre source / style layer ids.
  /// Tile sources use `pt-s-{uuid}`, `ln-s-{uuid}`, `pg-s-{uuid}`.
  String? _projectLayerIdFromMapHit(Map<String, dynamic>? feature) {
    if (feature == null) return null;

    final candidates = <String?>[
      feature['source']?.toString(),
      feature['layerId']?.toString(),
      if (feature['layer'] is Map)
        (feature['layer'] as Map)['id']?.toString(),
      feature['layer'] is String ? feature['layer'] as String : null,
    ];

    for (final raw in candidates) {
      final id = _projectLayerIdFromMapId(raw);
      if (id != null) return id;
    }

    // Reverse-lookup registered style layer / source ids.
    for (final entry in _mapSourceIdsByProjectLayer.entries) {
      for (final sid in entry.value) {
        if (candidates.contains(sid)) return entry.key;
      }
    }
    for (final entry in _mapLayerIdsByProjectLayer.entries) {
      for (final lid in entry.value) {
        if (candidates.contains(lid)) return entry.key;
      }
    }
    return null;
  }

  String? _projectLayerIdFromMapId(String? mapId) {
    if (mapId == null || mapId.isEmpty) return null;
    const prefixes = [
      'pt-s-',
      'pt-l-',
      'ln-s-',
      'ln-l-',
      'pg-s-',
      'pg-f-',
      'pg-o-',
      'colpt-s-',
      'colpt-l-',
      'colln-s-',
      'colln-l-',
      'colpg-s-',
      'colpg-f-',
      'colpg-o-',
    ];
    for (final p in prefixes) {
      if (mapId.startsWith(p)) {
        final id = mapId.substring(p.length);
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  /// Fallback when tiles lack fc_ref: nearest Point (or line start) in SQLite.
  Future<db.ReferenceFeature?> _nearestReferenceFeature({
    required db.AppDatabase database,
    required String layerId,
    required double lng,
    required double lat,
  }) async {
    // ~25 m at equator; good enough for tap enrichment.
    const maxDelta = 0.00025;
    try {
      final row = await database.customSelect(
        '''
        SELECT id FROM reference_features
        WHERE project_id = ?
          AND layer_id = ?
          AND (
            (
              LOWER(COALESCE(json_extract(geometry, '\$.type'), '')) = 'point'
              AND abs(json_extract(geometry, '\$.coordinates[0]') - ?) < ?
              AND abs(json_extract(geometry, '\$.coordinates[1]') - ?) < ?
            )
            OR (
              LOWER(COALESCE(json_extract(geometry, '\$.type'), '')) IN
                ('linestring', 'multilinestring')
              AND abs(json_extract(geometry, '\$.coordinates[0][0]') - ?) < ?
              AND abs(json_extract(geometry, '\$.coordinates[0][1]') - ?) < ?
            )
          )
        ORDER BY
          abs(
            COALESCE(
              json_extract(geometry, '\$.coordinates[0]'),
              json_extract(geometry, '\$.coordinates[0][0]')
            ) - ?
          ) + abs(
            COALESCE(
              json_extract(geometry, '\$.coordinates[1]'),
              json_extract(geometry, '\$.coordinates[0][1]')
            ) - ?
          )
        LIMIT 1
        ''',
        variables: [
          Variable.withString(widget.project.id),
          Variable.withString(layerId),
          Variable.withReal(lng),
          Variable.withReal(maxDelta),
          Variable.withReal(lat),
          Variable.withReal(maxDelta),
          Variable.withReal(lng),
          Variable.withReal(maxDelta),
          Variable.withReal(lat),
          Variable.withReal(maxDelta),
          Variable.withReal(lng),
          Variable.withReal(lat),
        ],
      ).getSingleOrNull();
      final id = row?.data['id'] as String?;
      if (id == null || id.isEmpty) return null;
      return await (database.select(database.referenceFeatures)
            ..where((r) => r.id.equals(id)))
          .getSingleOrNull();
    } catch (e) {
      debugPrint('[map] proximity lookup failed: $e');
      return null;
    }
  }

  /// Maps a line_style preset to a MapLibre dash array.
  /// Returns null for solid (no dash).
  List<double>? _dashArrayFor(String? lineStyle) {
    switch (lineStyle) {
      case 'dashed':
        return [3.0, 2.0];
      case 'dotted':
        return [0.5, 1.5];
      case 'dash_dot':
        return [3.0, 1.5, 0.5, 1.5];
      case 'solid':
      default:
        return null;
    }
  }

  /// MapLibre iconSize multiplier for a style size in pixels (SVG rasterized at 64).
  double _iconSizeFor(double sizePx) {
    final s = sizePx / 64.0;
    if (s < 0.2) return 0.2;
    if (s > 2.5) return 2.5;
    return s;
  }

  /// Unique image id so color/size changes replace the previous MapLibre image.
  String _iconImageId(String key, String color, double size) {
    final c = color.replaceAll('#', '').toLowerCase();
    return 'icon-$key-$c-${size.round()}';
  }

  /// Rasterize an SVG string to PNG bytes for a MapLibre symbol image.
  /// Returns null on failure (caller falls back to a circle).
  Future<Uint8List?> _rasterizeSvg(String svg, int size) async {
    try {
      var s = svg.trim();
      if (!s.contains('xmlns=')) {
        s = s.replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      }
      final info = await vg.loadPicture(SvgStringLoader(s), null);
      final image = await info.picture.toImage(size, size);
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      info.picture.dispose();
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[svg] rasterize failed: $e');
      return null;
    }
  }

  double _safeDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
    return fallback;
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final basemapId = settingsAsync.value?.basemap ?? BasemapId.osm;

    final layerNamesAsync =
        ref.watch(localLayerNamesProvider(widget.project.id));

    ref.listen(localLayersMetaProvider(widget.project.id), (prev, next) {
      if (next.hasValue && _styleLoaded) {
        final prevCount = prev?.value?.length ?? 0;
        final nextCount = next.value!.length;
        if (nextCount > prevCount) {
          _layerFetchAttempted.clear();
          unawaited(_ensureVisibleLayerPacks(maxLayers: 20));
        }
        final inEdit = _editState != null || _editStateLP != null;
        _renderFeatures(fitCamera: !inEdit);
      }
    });

    ref.listen(localCollectedFeaturesProvider(widget.project.id), (prev, next) {
      if (next.hasValue && _styleLoaded) {
        final inEdit = _editState != null || _editStateLP != null;
        _renderFeatures(fitCamera: !inEdit);
      }
    });

    ref.listen(settingsProvider, (prev, next) {
      final enabled = next.value?.showMyLocation ?? false;
      if (enabled != _myLocationLastEnabled) {
        _myLocationLastEnabled = enabled;
        _syncMyLocation(enabled);
      }
    });

    // Clear the temp search marker when the search Clear button is pressed
    ref.listen<SearchQueryState>(
      searchQueryProvider(widget.project.id),
      (previous, next) {
        if (previous?.results != null && next.results == null) {
          _clearSelectedResultMarker();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.project.name} Map'),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = LayoutOf(context);
                final showSidePanel = layout.useTabletMapChrome;

                final mapStack = Stack(
                  children: [
                    MapLibreMap(
                      key: ValueKey(basemapId),
                      styleString: buildBasemapStyle(basemap: basemapId),
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(5.6037, -0.1870),
                        zoom: 11,
                      ),
                      compassEnabled: true,
                      myLocationEnabled: false,
                      rotateGesturesEnabled: !_rotationLocked,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      tiltGesturesEnabled: !_rotationLocked,
                      doubleClickZoomEnabled: true,
                      dragEnabled: true,
                      trackCameraPosition: true,
                      onMapClick: _onMapClick,
                      onMapCreated: (controller) {
                        _controller = controller;
                        controller.onFeatureTapped.add(_handleFeatureTap);
                      },
                      onStyleLoadedCallback: () {
                        _styleLoaded = true;
                        unawaited(_renderFeatures(fitCamera: true));
                        unawaited(_ensureVisibleLayerPacks(maxLayers: 8));

                        final showMe =
                            ref.read(settingsProvider).value?.showMyLocation ??
                                false;
                        if (showMe) {
                          _myLocationLastEnabled = true;
                          unawaited(_syncMyLocation(true));
                        }
                      },
                    ),
                    if (_layerFetchStatus != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 72,
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _layerFetchStatus!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_guideInfo != null)
                      Positioned(
                        left: 12,
                        bottom: 88,
                        right: (showSidePanel && _tabletPanelExpanded)
                            ? _tabletPanelWidth + 88
                            : 88,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: _GuideCard(
                              info: _guideInfo!,
                              onClose: _clearSelectedResultMarker,
                            ),
                          ),
                        ),
                      ),
                    // Legend button — phone/small tablet only. Hidden on tablet
                    // landscape because the legend is always visible in the side panel.
                    if (!showSidePanel)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _LegendButton(
                          open: _legendOpen,
                          onTap: () =>
                              setState(() => _legendOpen = !_legendOpen),
                          visible: _visible,
                          layerNamesAsync: layerNamesAsync,
                          onToggle: _toggleLayer,
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      bottom: 16,
                      right: (showSidePanel && _tabletPanelExpanded)
                          ? _tabletPanelWidth + 16
                          : 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FloatingActionButton(
                            heroTag: 'addFeature',
                            tooltip: 'Add feature',
                            onPressed: _onAddFeaturePressed,
                            child: const Icon(Icons.add_location_alt_outlined),
                          ),
                          const SizedBox(height: 12),
                          PopupMenuButton<String>(
                            tooltip: 'Map controls',
                            offset: const Offset(0, -170),
                            onSelected: (v) {
                              switch (v) {
                                case 'recenter':
                                  _recenter();
                                  break;
                                case 'reset_rotation':
                                  _resetRotation();
                                  break;
                                case 'toggle_lock':
                                  _toggleRotationLock();
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'recenter',
                                child: Row(children: [
                                  Icon(Icons.center_focus_strong, size: 18),
                                  SizedBox(width: 10),
                                  Text('Recenter to data'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'reset_rotation',
                                child: Row(children: [
                                  Icon(Icons.explore, size: 18),
                                  SizedBox(width: 10),
                                  Text('Reset rotation'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'toggle_lock',
                                child: Row(children: [
                                  Icon(
                                    _rotationLocked
                                        ? Icons.screen_rotation
                                        : Icons.screen_lock_rotation,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(_rotationLocked
                                      ? 'Unlock rotation'
                                      : 'Lock rotation'),
                                ]),
                              ),
                            ],
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _rotationLocked
                                    ? Icons.screen_lock_rotation
                                    : Icons.center_focus_strong,
                                size: 20,
                                color: _rotationLocked
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CaptureBanner(),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CaptureActionBar(
                        onCancel: () async {
                          await _clearMultiTapDrawing();
                          await _onCaptureCancel();
                        },
                        onConfirm: _onCaptureConfirm,
                        onUndo: _onMultiTapUndo,
                        onFinish: _onMultiTapFinishConfirmed,
                      ),
                    ),
                  ],
                );

                if (!showSidePanel) {
                  return mapStack;
                }
                return Stack(
                  children: [
                    // The map fills the whole tablet area behind everything.
                    // On tablet the map is not squeezed by a fixed-width rail — the pills
                    // and the expanded panel float over it.
                    Positioned.fill(child: mapStack),

                    // Floating mode pills on the right side of the map (collapsed state).
                    // These are always visible so the user can quickly switch modes even
                    // when the panel is collapsed.
                    if (!_tabletPanelExpanded)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              MapModePill(
                                icon: Icons.layers_outlined,
                                label: 'Layers',
                                selected: false,
                                onTap: () {
                                  setState(() {
                                    _tabletMode = _TabletMode.layers;
                                    _tabletPanelExpanded = true;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              MapModePill(
                                icon: Icons.search,
                                label: 'Search',
                                selected: false,
                                onTap: () {
                                  _openSearchPanel();
                                },
                              ),
                              if (_panelFeature != null) ...[
                                const SizedBox(height: 8),
                                MapModePill(
                                  icon: Icons.info_outline,
                                  label: 'Feature',
                                  selected: false,
                                  onTap: () {
                                    setState(() {
                                      _tabletMode = _TabletMode.feature;
                                      _tabletPanelExpanded = true;
                                    });
                                  },
                                ),
                              ],
                              if (_panelFormArgs != null) ...[
                                const SizedBox(height: 8),
                                MapModePill(
                                  icon: Icons.edit_note_outlined,
                                  label: 'Form',
                                  selected: false,
                                  onTap: () {
                                    setState(() {
                                      _tabletMode = _TabletMode.form;
                                      _tabletPanelExpanded = true;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Expanded side panel (open state). Sits on the right, floating,
                    // with rounded left corners.
                    if (_tabletPanelExpanded)
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: _tabletPanelWidth,
                        child: MapSidePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MapSidePanelTabsHeader(
                                tabs: [
                                  MapSidePanelTab(
                                    icon: Icons.layers_outlined,
                                    label: 'Layers',
                                    selected: _tabletMode == _TabletMode.layers,
                                    onTap: () {
                                      setState(() =>
                                          _tabletMode = _TabletMode.layers);
                                    },
                                  ),
                                  MapSidePanelTab(
                                    icon: Icons.search,
                                    label: 'Search',
                                    selected: _tabletMode == _TabletMode.search,
                                    onTap: () {
                                      _openSearchPanel(expandIfNeeded: false);
                                    },
                                  ),
                                  if (_panelFeature != null)
                                    MapSidePanelTab(
                                      icon: Icons.info_outline,
                                      label: 'Feature',
                                      selected:
                                          _tabletMode == _TabletMode.feature,
                                      onTap: () {
                                        setState(() =>
                                            _tabletMode = _TabletMode.feature);
                                      },
                                    ),
                                  if (_panelFormArgs != null)
                                    MapSidePanelTab(
                                      icon: Icons.edit_note_outlined,
                                      label: 'Form',
                                      selected:
                                          _tabletMode == _TabletMode.form,
                                      onTap: () {
                                        setState(() =>
                                            _tabletMode = _TabletMode.form);
                                      },
                                    ),
                                ],
                                onCollapse: () {
                                  setState(() => _tabletPanelExpanded = false);
                                },
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: (_tabletMode == _TabletMode.form ||
                                        _tabletMode == _TabletMode.feature)
                                    ? _buildTabletPanelBody(
                                        layerNamesAsync: layerNamesAsync,
                                      )
                                    : MapSidePanelSection(
                                        child: _buildTabletPanelBody(
                                          layerNamesAsync: layerNamesAsync,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatefulWidget {
  final _GuideInfo info;
  final Future<void> Function() onClose;

  const _GuideCard({
    required this.info,
    required this.onClose,
  });

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _showAllSteps = false;

  @override
  void didUpdateWidget(covariant _GuideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.steps.length != widget.info.steps.length ||
        oldWidget.info.title != widget.info.title) {
      _showAllSteps = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.info;
    final distance = info.distanceMeters == null
        ? null
        : info.distanceMeters! >= 1000
            ? '${(info.distanceMeters! / 1000).toStringAsFixed(2)} km'
            : '${info.distanceMeters!.round()} m';
    final bearing = info.bearingDegrees == null
        ? null
        : '${_bearingArrow(info.bearingDegrees!)} ${_bearingCompass(info.bearingDegrees!)} ${info.bearingDegrees!.round()}°';

    final steps = info.steps;
    final nextStep = steps.isNotEmpty ? steps.first : null;
    final moreSteps =
        steps.length > 1 ? steps.sublist(1) : const <GuideDirectionStep>[];
    final visibleMore =
        _showAllSteps ? moreSteps : moreSteps.take(4).toList();
    final hiddenCount = moreSteps.length - visibleMore.length;
    final showDirections = info.title == 'Road guide' || steps.isNotEmpty;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.navigation_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    distance == null ? 'Guide' : info.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Dismiss guide',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (distance != null) ...[
              const SizedBox(height: 2),
              Text(
                distance,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (bearing != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  bearing,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (showDirections) ...[
              const SizedBox(height: 8),
              Text(
                'Directions',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (nextStep != null)
                        _DirectionLine(
                          index: 1,
                          step: nextStep,
                          emphasized: true,
                        ),
                      ...visibleMore.asMap().entries.map(
                            (e) => _DirectionLine(
                              index: e.key + 2,
                              step: e.value,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              if (hiddenCount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showAllSteps = !_showAllSteps),
                    child: Text(
                      _showAllSteps
                          ? 'Show fewer'
                          : 'Show $hiddenCount more step${hiddenCount == 1 ? '' : 's'}',
                    ),
                  ),
                ),
            ],
            Padding(
              padding: EdgeInsets.only(top: showDirections ? 4 : 6),
              child: Text(
                info.hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _bearingArrow(double degrees) {
    final idx = (((degrees % 360) + 22.5) ~/ 45) % 8;
    const arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];
    return arrows[idx];
  }

  static String _bearingCompass(double degrees) {
    final idx = (((degrees % 360) + 22.5) ~/ 45) % 8;
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return labels[idx];
  }
}

class _DirectionLine extends StatelessWidget {
  final int index;
  final GuideDirectionStep step;
  final bool emphasized;

  const _DirectionLine({
    required this.index,
    required this.step,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final dist = step.distanceMeters > 0
        ? GuideRouteService.formatDistancePublic(step.distanceMeters)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$index.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: (emphasized
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                    fontWeight:
                        emphasized ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (dist != null)
                  Text(
                    dist,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Floating layer legend (collapsed by default)
// ─────────────────────────────────────────────

class _LegendButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  final Map<String, bool> visible;
  final AsyncValue<Map<String, String>> layerNamesAsync;
  final Future<void> Function(String id, bool value) onToggle;

  const _LegendButton({
    required this.open,
    required this.onTap,
    required this.visible,
    required this.layerNamesAsync,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!open) {
      return Material(
        color: theme.colorScheme.surface.withOpacity(0.95),
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.layers_outlined,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.95),
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Layers', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: layerNamesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('…'),
                  ),
                  error: (e, _) => Text(
                    'Error: $e',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  data: (layers) {
                    if (layers.isEmpty) {
                      return Text(
                        'No layers',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    final ids = layers.keys.toList()..sort();
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: ids.length,
                      itemBuilder: (_, i) {
                        final id = ids[i];
                        final name = layers[id] ?? id;
                        final isOn = visible[id] ?? true;
                        return InkWell(
                          onTap: () => onToggle(id, !isOn),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOn
                                      ? Icons.visibility
                                      : Icons.visibility_off_outlined,
                                  size: 16,
                                  color: isOn
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Buckets / Bounds
// ─────────────────────────────────────────────

class _LayerBucket {
  final List<Map<String, dynamic>> points = [];
  final List<Map<String, dynamic>> lines = [];
  final List<Map<String, dynamic>> polys = [];

  bool get isEmpty => points.isEmpty && lines.isEmpty && polys.isEmpty;
}

class _BoundsAccumulator {
  double? west, east, south, north;

  bool get hasData =>
      west != null && east != null && south != null && north != null;

  void add(double lng, double lat) {
    if (west == null || lng < west!) west = lng;
    if (east == null || lng > east!) east = lng;
    if (south == null || lat < south!) south = lat;
    if (north == null || lat > north!) north = lat;
  }
}