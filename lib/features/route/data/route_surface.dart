import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/models/models.dart';
import '../../map/data/street_modes.dart';

/// What a route crosses that is hard with a pram, a wheelchair or a
/// walking frame.
@immutable
class RouteSurface {
  const RouteSurface({
    this.cobblesM = 0,
    this.pavingM = 0,
    this.steps = 0,
    this.stepsWithRamp = 0,
  });

  /// Metres on sett or cobbles («kocie łby») or unpaved.
  final double cobblesM;

  /// Metres on paving stones (bumpy, but fine for most).
  final double pavingM;

  /// Flights of steps with no ramp known, and with one.
  final int steps;
  final int stepsWithRamp;

  /// Worth telling: from 30 m of cobbles or any steps without a ramp.
  bool get notable => cobblesM >= minCobblesM || steps > 0;

  static const minCobblesM = 30.0;
}

const _mLat = 111195.0;
const _mLon = _mLat * 0.6189;

/// Local metres around Łódź (good enough for a few kilometres).
math.Point<double> _m(LatLng p) =>
    math.Point(p.longitude * _mLon, p.latitude * _mLat);

double _segDist(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
) {
  final vx = b.x - a.x;
  final vy = b.y - a.y;
  final l2 = vx * vx + vy * vy;
  final t = l2 == 0
      ? 0.0
      : (((p.x - a.x) * vx + (p.y - a.y) * vy) / l2).clamp(0.0, 1.0);
  final cx = a.x + t * vx;
  final cy = a.y + t * vy;
  return math.sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
}

/// Walks [route] in 10 m steps; a step counts on a surface when a mapped
/// rough way is within [nearM]. Steps count when within [stepsM] of the
/// route.
RouteSurface routeSurface(
  List<LatLng> route,
  StreetModes modes, {
  double nearM = 8,
  double stepsM = 12,
}) {
  if (route.length < 2) return const RouteSurface();
  // A 50 m grid of rough segments.
  const cell = 50.0;
  final grid =
      <(int, int), List<(math.Point<double>, math.Point<double>, int)>>{};
  for (final line in modes.surfaces) {
    for (var i = 0; i + 1 < line.points.length; i++) {
      final a = _m(line.points[i]);
      final b = _m(line.points[i + 1]);
      final x0 = (math.min(a.x, b.x) / cell).floor();
      final x1 = (math.max(a.x, b.x) / cell).floor();
      final y0 = (math.min(a.y, b.y) / cell).floor();
      final y1 = (math.max(a.y, b.y) / cell).floor();
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          (grid[(x, y)] ??= []).add((a, b, line.surface));
        }
      }
    }
  }

  var cobbles = 0.0;
  var paving = 0.0;
  const step = 10.0;
  final pts = [for (final p in route) _m(p)];
  for (var i = 0; i + 1 < pts.length; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    final len = a.distanceTo(b);
    final n = math.max(1, (len / step).ceil());
    for (var k = 0; k < n; k++) {
      final t = (k + 0.5) / n;
      final p = math.Point(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y));
      var worst = 0;
      final cx = (p.x / cell).floor();
      final cy = (p.y / cell).floor();
      for (var x = cx - 1; x <= cx + 1; x++) {
        for (var y = cy - 1; y <= cy + 1; y++) {
          for (final (sa, sb, s)
              in grid[(x, y)] ??
                  const <(math.Point<double>, math.Point<double>, int)>[]) {
            if (s > worst && _segDist(p, sa, sb) <= nearM) worst = s;
          }
        }
      }
      if (worst >= 2) {
        cobbles += len / n;
      } else if (worst == 1) {
        paving += len / n;
      }
    }
  }

  var steps = 0;
  var ramps = 0;
  for (final s in modes.steps) {
    final p = _m(s.point);
    var near = false;
    for (var i = 0; i + 1 < pts.length && !near; i++) {
      if (_segDist(p, pts[i], pts[i + 1]) <= stepsM) near = true;
    }
    if (!near) continue;
    if (s.ramp) {
      ramps++;
    } else {
      steps++;
    }
  }
  return RouteSurface(
    cobblesM: cobbles,
    pavingM: paving,
    steps: steps,
    stepsWithRamp: ramps,
  );
}

/// [routeSurface] of a variant (by identity); null while the data loads.
final routeSurfaceProvider = FutureProvider.family<RouteSurface?, RouteVariant>(
  (ref, variant) async {
    final modes = await ref.watch(streetModesProvider.future);
    return routeSurface(variant.geometry, modes);
  },
  retry: noRetry,
);
