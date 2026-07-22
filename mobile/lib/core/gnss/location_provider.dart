import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Abstract source of Position updates. Both PhoneLocationProvider and
/// NmeaLocationProvider implement this. Capture code holds this interface,
/// not the concrete impl.
abstract class LocationProvider {
  /// Human-readable name for UI ("Phone GPS", "External: Bad Elf", etc.).
  String get name;

  /// True while actively producing positions.
  bool get isActive;

  /// Last position emitted (or null if none yet).
  Position? get lastKnownPosition;

  /// Live stream of positions.
  Stream<Position> get positionStream;

  /// Start producing positions. Idempotent.
  Future<void> start();

  /// Stop producing positions. Idempotent.
  Future<void> stop();
}

/// Wraps the built-in geolocator plugin.
class PhoneLocationProvider implements LocationProvider {
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<Position>.broadcast();
  Position? _last;
  bool _active = false;

  @override
  String get name => 'Phone GPS';

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

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _last = pos;
        _controller.add(pos);
      },
      onError: (e) {
        _controller.addError(e);
      },
    );
  }

  @override
  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    _sub = null;
  }
}
