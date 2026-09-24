/// Parses a single coordinate number from user input.
///
/// Accepts `.` or `,` as the decimal separator (e.g. `5.6037` or `5,6037`).
/// Returns `null` if empty or not a number.
double? parseCoordinate(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Parses a latitude/longitude pair from free-form user input.
///
/// Accepted forms (whitespace optional):
/// - `5.6037, -0.1870`
/// - `5.6037 -0.1870`
/// - `5.6037,-0.1870`
///
/// Returns `(lat, lng)` or `null` if invalid / out of range.
(double, double)? parseLatLng(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // Split on comma or whitespace; keep signed decimals.
  // Prefer comma-as-separator when both values use `.` decimals, e.g.
  // "5.60, -0.18". If a single token uses `,` as decimal, whitespace split.
  final parts = text
      .split(RegExp(r'[,\s]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length != 2) return null;

  return parseLatLngPair(parts[0], parts[1]);
}

/// Validates a lat/lng pair from separate fields.
(double, double)? parseLatLngPair(String latRaw, String lngRaw) {
  final lat = parseCoordinate(latRaw);
  final lng = parseCoordinate(lngRaw);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90) return null;
  if (lng < -180 || lng > 180) return null;
  return (lat, lng);
}
