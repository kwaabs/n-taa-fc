import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../settings/settings_provider.dart';
import 'gnss_provider.dart';
import 'location_provider.dart';
import 'nmea_location_provider.dart';

/// Picks the right LocationProvider based on user settings.
///
/// When settings switch from phone to external (or vice versa), Riverpod
/// tears down the old provider and builds a new one. Old streams are cancelled
/// via the ref.onDispose hook.
final activeLocationProvider = Provider<LocationProvider>((ref) {
  // Only rebuild when location source itself changes, not on every
  // unrelated setting change (basemap, snap, accuracy filter, etc.).
  final source = ref.watch(settingsProvider.select(
    (async) => async.value?.locationSource ?? 'phone',
  ));
  final deviceAddress = ref.watch(settingsProvider.select(
    (async) => async.value?.externalDeviceAddress,
  ));
  final deviceName = ref.watch(settingsProvider.select(
    (async) => async.value?.externalDeviceName,
  ));

  LocationProvider provider;

  if (source == 'external' && deviceAddress != null) {
    final transport = ref.watch(bluetoothTransportProvider);
    provider = NmeaLocationProvider(
      transport: transport,
      deviceName: deviceName ?? 'GNSS receiver',
    );
  } else {
    provider = PhoneLocationProvider();
  }

  ref.onDispose(() {
    provider.stop();
  });

  return provider;
});
