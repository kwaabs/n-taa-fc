import 'package:geolocator/geolocator.dart';

/// Streaming NMEA parser.
///
/// Feed raw bytes via [addBytes]; listen to [positions] for parsed positions
/// derived from $GPGGA / $GPRMC (and multi-constellation prefixes $GN/$GL/$GA).
class NmeaParser {
  /// Optional: adjust the HDOP → metres multiplier if you know your receiver.
  /// Consumer GNSS: ~3.0. Sub-meter receivers: 1.0. RTK: 0.5.
  final double hdopToMetres;

  final _buffer = StringBuffer();
  DateTime? _lastRmcDate; // GGA has no date; we borrow it from RMC

  NmeaParser({this.hdopToMetres = 3.0});

  final _controller = <Function(Position)>[];

  /// Call this repeatedly as bytes arrive from the transport.
  void addBytes(List<int> bytes) {
    // Byte-safe: NMEA is ASCII, one char = one byte
    for (final b in bytes) {
      if (b == 10 || b == 13) {
        // \n or \r — line terminator
        if (_buffer.isNotEmpty) {
          _handleLine(_buffer.toString());
          _buffer.clear();
        }
      } else {
        _buffer.writeCharCode(b);
      }
    }
  }

  /// Register a listener for parsed positions.
  void onPosition(void Function(Position) fn) => _controller.add(fn);

  void _emit(Position pos) {
    for (final fn in List.of(_controller)) {
      try {
        fn(pos);
      } catch (_) {}
    }
  }

  void _handleLine(String line) {
    // Basic validity check — NMEA sentences start with $ and (optionally) end with *XX checksum
    if (!line.startsWith(r'$')) return;

    // Strip checksum for parsing (not verifying it — receivers vary)
    final starIdx = line.indexOf('*');
    final body = starIdx >= 0 ? line.substring(1, starIdx) : line.substring(1);
    final parts = body.split(',');

    if (parts.isEmpty) return;

    final id = parts[0];
    // Accept GPS ($GP), Glonass ($GL), Galileo ($GA), multi ($GN)
    if (id.length < 5) return;
    final talker = id.substring(0, 2);
    final sentence = id.substring(2);
    const allowedTalkers = {'GP', 'GN', 'GL', 'GA', 'GB'};
    if (!allowedTalkers.contains(talker)) return;

    switch (sentence) {
      case 'GGA':
        _handleGga(parts);
        break;
      case 'RMC':
        _handleRmc(parts);
        break;
    }
  }

  /// $GNGGA,120044.00,5106.94086,N,01732.02754,E,1,08,0.98,102.5,M,45.2,M,,*76
  ///
  /// Fields:
  ///   1 UTC time
  ///   2 lat
  ///   3 N/S
  ///   4 lng
  ///   5 E/W
  ///   6 fix quality (0 = invalid, 1 = GPS, 2 = DGPS, 4 = RTK, 5 = float RTK)
  ///   7 num satellites
  ///   8 HDOP
  ///   9 altitude
  void _handleGga(List<String> p) {
    if (p.length < 10) return;

    final fixQuality = int.tryParse(p[6]) ?? 0;
    if (fixQuality == 0) return; // invalid fix

    final lat = _parseLatLng(p[2], p[3]);
    final lng = _parseLatLng(p[4], p[5]);
    if (lat == null || lng == null) return;

    final numSats = int.tryParse(p[7]) ?? 0;
    final hdop = double.tryParse(p[8]) ?? 5.0;
    final alt = double.tryParse(p[9]) ?? 0.0;

    final accuracy = hdop * hdopToMetres;

    _emit(Position(
      latitude: lat,
      longitude: lng,
      timestamp: _timestampFromUtc(p[1]) ?? DateTime.now().toUtc(),
      accuracy: accuracy,
      altitude: alt,
      altitudeAccuracy: accuracy,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      floor: null,
      isMocked: false,
      // Custom cheat: use the platform Position but stash sat count in provider
    ));
  }

  /// $GNRMC,120044.00,A,5106.94086,N,01732.02754,E,0.05,,050825,,,A,V*15
  ///
  /// Fields:
  ///   1 UTC time
  ///   2 status (A = active, V = void)
  ///   3-6 lat/N/S, lng/E/W
  ///   7 speed knots
  ///   8 course
  ///   9 date DDMMYY
  void _handleRmc(List<String> p) {
    if (p.length < 10) return;
    if (p[2] != 'A') return; // void — ignore

    final lat = _parseLatLng(p[3], p[4]);
    final lng = _parseLatLng(p[5], p[6]);
    if (lat == null || lng == null) return;

    // Record the date part so subsequent GGA can borrow it
    if (p[9].length >= 6) {
      final d = p[9];
      final day = int.tryParse(d.substring(0, 2)) ?? 1;
      final mon = int.tryParse(d.substring(2, 4)) ?? 1;
      final yr = int.tryParse(d.substring(4, 6)) ?? 0;
      _lastRmcDate = DateTime.utc(2000 + yr, mon, day);
    }

    final knots = double.tryParse(p[7]) ?? 0.0;
    final speedMps = knots * 0.514444;
    final course = double.tryParse(p[8]) ?? 0.0;

    _emit(Position(
      latitude: lat,
      longitude: lng,
      timestamp: _timestampFromUtc(p[1]) ?? DateTime.now().toUtc(),
      accuracy: 3.0, // RMC has no HDOP — placeholder; GGA overrides
      altitude: 0,
      altitudeAccuracy: 0,
      heading: course,
      headingAccuracy: 0,
      speed: speedMps,
      speedAccuracy: 0,
      floor: null,
      isMocked: false,
    ));
  }

  /// NMEA lat/lng format is DDMM.mmmm (or DDDMM.mmmm for lng).
  /// Converts to decimal degrees. Returns null if invalid.
  double? _parseLatLng(String raw, String hemi) {
    if (raw.isEmpty) return null;
    final dotIdx = raw.indexOf('.');
    if (dotIdx < 3) return null;
    final degLen = dotIdx - 2;
    final deg = int.tryParse(raw.substring(0, degLen));
    final min = double.tryParse(raw.substring(degLen));
    if (deg == null || min == null) return null;

    var d = deg + (min / 60.0);
    if (hemi == 'S' || hemi == 'W') d = -d;
    return d;
  }

  DateTime? _timestampFromUtc(String utc) {
    // UTC field is HHMMSS.ss
    if (utc.length < 6) return _lastRmcDate;
    final h = int.tryParse(utc.substring(0, 2));
    final m = int.tryParse(utc.substring(2, 4));
    final s = int.tryParse(utc.substring(4, 6));
    if (h == null || m == null || s == null) return _lastRmcDate;
    final date = _lastRmcDate ?? DateTime.now().toUtc();
    return DateTime.utc(date.year, date.month, date.day, h, m, s);
  }
}