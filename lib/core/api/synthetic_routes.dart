import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../warsaw_time.dart';

/// Plausible offline routes for pairs that are not reference routes, so every
/// screen works in demo mode. Deterministic: the same request gives the same
/// response. Coverage is always `approximate`.
abstract final class SyntheticRoutes {
  /// Street network detour over the straight line.
  static const detourFactor = 1.3;

  /// Walking speed, m/s.
  static const walkingSpeed = 1.3;

  static const _points = 24;
  static const _segments = 4;

  static RouteResponse generate(RouteRequest request) {
    final from = request.from.latLng;
    final to = request.to.latLng;
    final straight = distanceMeters(from, to);
    final seed = _seed(from, to);
    // Sun share of the shortest variant at midday: 0.55..0.80.
    final baseSun = 0.55 + 0.25 * seed;
    final time = request.datetime;

    final shortest = _variant(
      RouteVariantType.shortest,
      from,
      to,
      straight,
      bend: 0.06,
      lengthFactor: 1.0,
      middaySun: baseSun,
      time: time,
      seed: seed,
    );
    return RouteResponse(
      coverage: RouteCoverage.approximate,
      variants: [
        shortest,
        _variant(
          RouteVariantType.shaded,
          from,
          to,
          straight,
          bend: -0.16,
          lengthFactor: 1.12,
          middaySun: baseSun - 0.40,
          time: time,
          seed: seed,
          shortestDuration: shortest.durationS,
        ),
        _variant(
          RouteVariantType.compromise,
          from,
          to,
          straight,
          bend: 0.12,
          lengthFactor: 1.05,
          middaySun: baseSun - 0.22,
          time: time,
          seed: seed,
          shortestDuration: shortest.durationS,
        ),
      ],
    );
  }

  static RouteVariant _variant(
    RouteVariantType type,
    LatLng from,
    LatLng to,
    double straight, {
    required double bend,
    required double lengthFactor,
    required double middaySun,
    required DateTime time,
    required double seed,
    int? shortestDuration,
  }) {
    final distance = (straight * detourFactor * lengthFactor).round();
    final duration = (distance / walkingSpeed).round();
    final byHour = <String, double>{
      for (var m = 8 * 60; m <= 20 * 60; m += 30)
        formatHhMm(m): _round(_sunAt(middaySun, m)),
    };
    final minute = warsawMinuteOfDay(time).clamp(8 * 60, 20 * 60);
    final sun = _round(_sunAt(middaySun, minute));
    final geometry = _bentLine(from, to, bend);
    return RouteVariant(
      variant: type,
      geometry: geometry,
      segments: _segmentsAround(sun, seed, geometry.length),
      distanceM: distance,
      durationS: duration,
      sunShare: sun,
      extraTimeVsShortestS: duration - (shortestDuration ?? duration),
      sunShareByHour: byHour,
    );
  }

  /// Sun share over the day: lowest in the morning and evening, highest
  /// around 14:00.
  static double _sunAt(double midday, int minute) {
    final hours = minute / 60;
    final curve = math.sin(math.pi * (hours - 6) / 16).clamp(0.0, 1.0);
    return (midday * (0.35 + 0.65 * curve)).clamp(0.02, 0.98);
  }

  /// Equal-length segments alternating ±0.1 around [mean], so their average
  /// stays [mean].
  static List<RouteSegment> _segmentsAround(
    double mean,
    double seed,
    int points,
  ) {
    final spread = math.min(0.1, math.min(mean, 1 - mean));
    final first = seed < 0.5 ? 1 : -1;
    final last = points - 1;
    return [
      for (var i = 0; i < _segments; i++)
        RouteSegment(
          from: last * i ~/ _segments,
          to: last * (i + 1) ~/ _segments,
          sunShare: _round(mean + (i.isEven ? first : -first) * spread),
        ),
    ];
  }

  /// Quadratic Bézier from [a] to [b]; the control point is pushed sideways
  /// by [bend] × the straight distance.
  static List<LatLng> _bentLine(LatLng a, LatLng b, double bend) {
    // Work in a local metric-ish plane (lon scaled by cos(lat)).
    final k = math.cos(a.latitude * math.pi / 180);
    final dx = (b.longitude - a.longitude) * k;
    final dy = b.latitude - a.latitude;
    final cx = (a.longitude * k + b.longitude * k) / 2 - dy * bend;
    final cy = (a.latitude + b.latitude) / 2 + dx * bend;
    return [
      for (var i = 0; i < _points; i++)
        () {
          final t = i / (_points - 1);
          final u = 1 - t;
          final x =
              u * u * a.longitude * k +
              2 * u * t * cx +
              t * t * b.longitude * k;
          final y = u * u * a.latitude + 2 * u * t * cy + t * t * b.latitude;
          return LatLng(_round6(y), _round6(x / k));
        }(),
    ];
  }

  /// 0..1 from the rounded coordinates.
  static double _seed(LatLng a, LatLng b) {
    var h = 17;
    for (final v in [a.latitude, a.longitude, b.latitude, b.longitude]) {
      h = (h * 31 + (v * 1e4).round()) & 0x7fffffff;
    }
    return (h % 1000) / 999;
  }

  static double _round(double v) => (v * 100).round() / 100;

  static double _round6(double v) => (v * 1e6).round() / 1e6;
}
