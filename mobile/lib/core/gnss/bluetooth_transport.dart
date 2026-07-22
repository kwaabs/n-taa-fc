import 'dart:async';

/// Represents a discovered Bluetooth device.
class BtDevice {
  final String address;   // MAC address (Android) or accessory ID (iOS)
  final String name;
  final int? rssi;        // Signal strength (Android has it, iOS may not)
  final bool paired;      // Already known to the OS pairing list

  const BtDevice({
    required this.address,
    required this.name,
    this.rssi,
    this.paired = false,
  });
}

/// Connection lifecycle.
enum BtConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Cross-platform Bluetooth transport abstraction.
///
/// Two concrete implementations:
///  - AndroidSppTransport uses flutter_bluetooth_serial (Classic SPP)
///  - IosMfiTransport uses ExternalAccessory framework via MethodChannel
///
/// Both expose the same interface so upstream code doesn't care.
abstract class BluetoothTransport {
  /// Whether Bluetooth is available and enabled on this device.
  Future<bool> get isAvailable;
  Future<bool> get isEnabled;

  /// Request the OS-level Bluetooth permissions. Returns true if all granted.
  Future<bool> requestPermissions();

  /// Prompt the user to enable Bluetooth if it's off. Best-effort.
  Future<bool> requestEnable();

  /// Start discovering nearby devices. Emits BtDevice each time a new device
  /// is found. Discovery stops on stopScan() or after [timeout].
  Stream<BtDevice> scan({Duration timeout = const Duration(seconds: 10)});

  /// Cancel an in-progress scan.
  Future<void> stopScan();

  /// List devices already paired with the OS (independent of scan).
  Future<List<BtDevice>> pairedDevices();

  /// Connect to a device. Throws BluetoothException on failure.
  /// After success, [dataStream] emits raw bytes.
  Future<void> connect(BtDevice device);

  /// Disconnect the current connection (no-op if none).
  Future<void> disconnect();

  /// Raw bytes coming from the connected device (e.g. NMEA sentences).
  Stream<List<int>> get dataStream;

  /// Live connection state — for UI.
  Stream<BtConnectionState> get connectionState;

  /// True while a connection is active.
  bool get isConnected;
}

class BluetoothException implements Exception {
  final String message;
  final Object? cause;
  BluetoothException(this.message, [this.cause]);
  @override
  String toString() => 'BluetoothException: $message${cause == null ? '' : ' ($cause)'}';
}
