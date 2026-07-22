import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import 'basemap_options.dart';

/// Global app settings — versioned for future migrations.
class AppSettings {
  static const _key = 'app_settings_v1';
  static const int currentVersion = 1;

  final int version;

  // ── Appearance ──
  final AppThemeMode themeMode;

  // ── Map ──
  final BasemapId basemap;

  /// When true, the map shows a pulsing marker at the user's current GPS
  /// position with an accuracy ring around it. Off by default.
  final bool showMyLocation;

  // ── Location source (A6 will implement 'external') ──
  final String locationSource; // 'phone' | 'external'
  final String? externalDeviceAddress;
  final String? externalDeviceName;

  // ── Data capture ──
  /// Snap taps to nearby vertices during multi-tap capture.
  final bool snapEnabled;

  // ── GPS tracking ──
  /// Preset id: 'fast' | 'balanced' | 'battery_saving'.
  final String trackPreset;

  /// Reject sampled points with accuracy worse than this many metres.
  /// Special value: 0 means "off" (accept everything).
  final int trackAccuracyFilterMeters;

  const AppSettings({
    this.version = currentVersion,
    this.themeMode = AppThemeMode.system,
    this.basemap = BasemapId.osm,
    this.showMyLocation = false,
    this.locationSource = 'phone',
    this.externalDeviceAddress,
    this.externalDeviceName,
    this.snapEnabled = true,
    this.trackPreset = 'balanced',
    this.trackAccuracyFilterMeters = 20,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    BasemapId? basemap,
    bool? showMyLocation,
    String? locationSource,
    String? externalDeviceAddress,
    String? externalDeviceName,
    bool? snapEnabled,
    String? trackPreset,
    int? trackAccuracyFilterMeters,
  }) {
    return AppSettings(
      version: version,
      themeMode: themeMode ?? this.themeMode,
      basemap: basemap ?? this.basemap,
      showMyLocation: showMyLocation ?? this.showMyLocation,
      locationSource: locationSource ?? this.locationSource,
      externalDeviceAddress:
          externalDeviceAddress ?? this.externalDeviceAddress,
      externalDeviceName: externalDeviceName ?? this.externalDeviceName,
      snapEnabled: snapEnabled ?? this.snapEnabled,
      trackPreset: trackPreset ?? this.trackPreset,
      trackAccuracyFilterMeters:
          trackAccuracyFilterMeters ?? this.trackAccuracyFilterMeters,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'theme_mode': themeMode.storageValue,
        'basemap': basemap.name,
        'show_my_location': showMyLocation,
        'location_source': locationSource,
        if (externalDeviceAddress != null)
          'external_device_address': externalDeviceAddress,
        if (externalDeviceName != null)
          'external_device_name': externalDeviceName,
        'snap_enabled': snapEnabled,
        'track_preset': trackPreset,
        'track_accuracy_filter_meters': trackAccuracyFilterMeters,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      version: (json['version'] as int?) ?? currentVersion,
      themeMode: AppThemeMode.fromString(json['theme_mode'] as String?),
      basemap: basemapIdFromString(json['basemap'] as String?),
      showMyLocation: (json['show_my_location'] as bool?) ?? false,
      locationSource: (json['location_source'] as String?) ?? 'phone',
      externalDeviceAddress: json['external_device_address'] as String?,
      externalDeviceName: json['external_device_name'] as String?,
      snapEnabled: (json['snap_enabled'] as bool?) ?? true,
      trackPreset: (json['track_preset'] as String?) ?? 'balanced',
      trackAccuracyFilterMeters:
          (json['track_accuracy_filter_meters'] as int?) ?? 20,
    );
  }

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const AppSettings();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return fromJson(decoded);
      }
    } catch (_) {
      // Corrupted prefs — fall through to defaults
    }
    return const AppSettings();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}

// ── Track preset helpers ──

class TrackPreset {
  final String id;
  final String label;
  final String description;
  final int minIntervalSeconds;
  final double minDistanceMeters;

  const TrackPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.minIntervalSeconds,
    required this.minDistanceMeters,
  });
}

const trackPresets = <TrackPreset>[
  TrackPreset(
    id: 'fast',
    label: 'Fast',
    description: '1 s / 1 m — walking, dense capture',
    minIntervalSeconds: 1,
    minDistanceMeters: 1.0,
  ),
  TrackPreset(
    id: 'balanced',
    label: 'Balanced',
    description: '2 s / 3 m — default',
    minIntervalSeconds: 2,
    minDistanceMeters: 3.0,
  ),
  TrackPreset(
    id: 'battery_saving',
    label: 'Battery-saving',
    description: '5 s / 10 m — long routes',
    minIntervalSeconds: 5,
    minDistanceMeters: 10.0,
  ),
];

TrackPreset trackPresetById(String id) {
  for (final p in trackPresets) {
    if (p.id == id) return p;
  }
  return trackPresets[1]; // default: balanced
}

// ── Accuracy filter options ──
// 0 = off. Values in metres.
const trackAccuracyOptions = <int>[5, 10, 20, 50, 0];

String trackAccuracyLabel(int meters) {
  if (meters == 0) return 'Off (accept everything)';
  return '≤ $meters m';
}
