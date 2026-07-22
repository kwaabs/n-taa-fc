import 'dart:async';

import 'bluetooth_transport.dart';

/// Stub implementation of AndroidSppTransport.
///
/// The original implementation used flutter_bluetooth_serial (Classic SPP).
/// That plugin is unmaintained and incompatible with modern Android Gradle
/// Plugin. This stub keeps the app building and preserves the transport
/// interface. External GNSS via classic Bluetooth is parked until an SPP
/// plugin decision is made.
///
/// When restoring:
///  - Reinstate flutter_bluetooth_serial (or replacement) in pubspec.yaml
///  - Restore the original implementation from
///    `android_spp_transport.dart.parked` in this same directory
///  - Test on a real GNSS device (Emlid, SXBlue, Bad Elf, Trimble, etc.)
class AndroidSppTransport implements BluetoothTransport {
  static const _kParkedMessage =
      'External Bluetooth GNSS is temporarily disabled. '
      'Reason: SPP plugin path pending decision. '
      'Device GPS still works.';

  final _connectionStateController =
      StreamController<BtConnectionState>.broadcast();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<bool> get isEnabled async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool> requestEnable() async => false;

  @override
  Stream<BtDevice> scan({Duration timeout = const Duration(seconds: 10)}) {
    return const Stream<BtDevice>.empty();
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<List<BtDevice>> pairedDevices() async => const [];

  @override
  Future<void> connect(BtDevice device) async {
    throw BluetoothException(_kParkedMessage);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<int>> get dataStream => const Stream<List<int>>.empty();

  @override
  Stream<BtConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  bool get isConnected => false;
}