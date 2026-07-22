import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_spp_transport.dart';
import 'bluetooth_transport.dart';

/// Chooses the platform-appropriate BluetoothTransport implementation.
/// iOS gets a stub for now — deferred until MFi Swift bridge lands.
final bluetoothTransportProvider = Provider<BluetoothTransport>((ref) {
  if (Platform.isAndroid) {
    return AndroidSppTransport();
  }
  // iOS + others: return a stub that says "unsupported"
  return _StubTransport();
});

/// Placeholder transport for platforms we haven't wired yet (iOS in v1).
class _StubTransport implements BluetoothTransport {
  @override
  Future<bool> get isAvailable async => false;
  @override
  Future<bool> get isEnabled async => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<bool> requestEnable() async => false;
  @override
  Stream<BtDevice> scan({Duration timeout = const Duration(seconds: 10)}) =>
      const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Future<List<BtDevice>> pairedDevices() async => const [];
  @override
  Future<void> connect(BtDevice device) async {
    throw BluetoothException('External GNSS not supported on this platform yet');
  }
  @override
  Future<void> disconnect() async {}
  @override
  Stream<List<int>> get dataStream => const Stream.empty();
  @override
  Stream<BtConnectionState> get connectionState => const Stream.empty();
  @override
  bool get isConnected => false;
}