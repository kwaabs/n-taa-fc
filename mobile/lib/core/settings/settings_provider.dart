import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import 'app_settings.dart';
import 'basemap_options.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => AppSettings.load();

  Future<void> setThemeMode(AppThemeMode mode) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(themeMode: mode);
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setBasemap(BasemapId id) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(basemap: id);
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setLocationSource({
    required String source,
    String? deviceAddress,
    String? deviceName,
  }) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(
      locationSource: source,
      externalDeviceAddress: deviceAddress,
      externalDeviceName: deviceName,
    );
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setSnapEnabled(bool value) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(snapEnabled: value);
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setTrackPreset(String presetId) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(trackPreset: presetId);
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setTrackAccuracyFilter(int meters) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(trackAccuracyFilterMeters: meters);
    state = AsyncData(next);
    await next.save();
  }

  Future<void> setShowMyLocation(bool value) async {
    final cur = state.value ?? const AppSettings();
    final next = cur.copyWith(showMyLocation: value);
    state = AsyncData(next);
    await next.save();
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
