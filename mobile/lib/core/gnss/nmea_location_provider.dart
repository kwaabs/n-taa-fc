import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'bluetooth_transport.dart';
import 'location_provider.dart';
import 'nmea_parser.dart';

/// LocationProvider backed by an external Bluetooth GNSS receiver.
/// Reads bytes from [BluetoothTransport.dataStream], parses NMEA, and
/// emits Position updates.
class NmeaLocationProvider implements LocationProvider {
  final BluetoothTransport transport;
  final String deviceName;

  StreamSubscription<List<int>>? _btSub;
  StreamSubscription<BtConnectionState>? _stateSub;
  final NmeaParser _parser = NmeaParser();
  final _controller = StreamController<Position>.broadcast();
  Position? _last;
  bool _active = false;

  NmeaLocationProvider({
    required this.transport,
    required this.deviceName,
  });

  @override
  String get name => 'External: $deviceName';

  @override
  bool get isActive => _active;

  @override
  Position? get lastKnownPosition => _last;

  @override
  Stream<Position> get positionStream => _controller.stream;

  @override
  Future<void> start() async {
    if (_active) return;
    _active = true;

    _parser.onPosition((p) {
      _last = p;
      _controller.add(p);
    });

    _btSub = transport.dataStream.listen(
      (bytes) => _parser.addBytes(bytes),
      onError: (e) => _controller.addError(e),
    );

    _stateSub = transport.connectionState.listen((state) {
      if (state == BtConnectionState.idle ||
          state == BtConnectionState.error) {
        _active = false;
        _controller.addError(BluetoothException(
          'External GNSS disconnected — reconnect to resume submeter accuracy',
        ));
      }
    });
  }

  @override
  Future<void> stop() async {
    _active = false;
    await _btSub?.cancel();
    _btSub = null;
    await _stateSub?.cancel();
    _stateSub = null;
  }
}