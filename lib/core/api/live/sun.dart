import 'dart:math' as math;

/// Sun position seen from a point on the ground.
class SunPosition {
  const SunPosition({required this.elevation, required this.azimuth});

  /// Degrees above the horizon (negative at night).
  final double elevation;

  /// Degrees from north, clockwise (90 = east, 180 = south).
  final double azimuth;
}

const _rad = math.pi / 180;
final _j2000 = DateTime.utc(2000, 1, 1, 12);

/// Low-precision almanac formula (same as `tools/demo-data/build.py`),
/// accurate to a fraction of a degree, which is plenty for street shadows.
SunPosition sunPosition(double lat, double lon, DateTime instant) {
  final n =
      instant.toUtc().difference(_j2000).inMilliseconds /
      Duration.millisecondsPerDay;
  final l = (280.460 + 0.9856474 * n) % 360;
  final g = ((357.528 + 0.9856003 * n) % 360) * _rad;
  final lambda = (l + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * _rad;
  final eps = (23.439 - 0.0000004 * n) * _rad;
  final ra = math.atan2(math.cos(eps) * math.sin(lambda), math.cos(lambda));
  final dec = math.asin(math.sin(eps) * math.sin(lambda));
  final gmst = (18.697374558 + 24.06570982441908 * n) % 24;
  final ha = (gmst * 15 + lon) * _rad - ra;
  final phi = lat * _rad;
  final el = math.asin(
    math.sin(phi) * math.sin(dec) +
        math.cos(phi) * math.cos(dec) * math.cos(ha),
  );
  final az = math.atan2(
    -math.sin(ha),
    math.cos(phi) * math.tan(dec) - math.sin(phi) * math.cos(ha),
  );
  return SunPosition(elevation: el / _rad, azimuth: (az / _rad) % 360);
}
