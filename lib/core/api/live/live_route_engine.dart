import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../warsaw_time.dart';
import '../api_client.dart';
import 'osrm_client.dart';
import 'shade_model.dart';
import 'weather.dart';

/// `POST /v1/routes` computed on the phone: OSRM foot routes (with
/// alternatives and via-point detours) scored by [ShadeModel] into the
/// variants shortest / shaded / compromise (only the distinct ones) plus
/// further distinct walks as alternatives. Sun shares follow the time, the
/// day and, with a [weather] forecast, the clouds; heat makes shade weigh
/// more in the compromise.
class LiveRouteEngine {
  LiveRouteEngine({
    required this.osrm,
    required this.shadeModel,
    required this.places,
    this.weather,
  });

  final OsrmClient osrm;

  /// Loaded once and kept by the caller (bundled layers).
  final Future<ShadeModel> Function() shadeModel;

  /// Cool places and drinking water for `stops`.
  final Future<List<Place>> Function() places;

  /// Hourly forecast; null or failing = clear sky.
  final Future<WeatherForecast?> Function()? weather;

  /// Routes do not wait longer than this for the forecast.
  static const weatherTimeout = Duration(seconds: 3);

  /// The shaded variant must save at least this much sun share; otherwise
  /// (night, overcast, no shady detour) it is the shortest walk.
  static const minShadeGain = 0.03;

  /// Longer straight lines are not a walk (Łódź is ~20 km across).
  static const maxStraightDistance = 25000.0;

  /// Detours longer than this × the shortest walk are dropped.
  static const maxDetourFactor = 1.6;

  /// At most this many variants (named ones first, then alternatives).
  static const maxVariants = 5;

  /// The shaded variant may take at most this × the shortest walk.
  static const maxShadedFactor = 1.5;

  static const coolStopRadius = 80.0;
  static const waterStopRadius = 25.0;

  /// Stops this close to the start are not worth a mention.
  static const stopSkipNearStart = 150.0;
  static const maxStopsPerType = 4;

  /// A park is a via point when going through it is at most this × the
  /// straight line.
  static const maxParkDetour = 1.3;
  static const maxParkVias = 2;

  Future<RouteResponse> route(RouteRequest request) async {
    final from = request.from.latLng;
    final to = request.to.latLng;
    if (distanceMeters(from, to) > maxStraightDistance) {
      // OSRM would happily route across Europe by ferry.
      throw const ApiException(ApiErrorKind.notFound, 'route_not_found');
    }

    final direct = osrm.route([from, to], alternatives: 2);
    final forecastFuture = _forecast();
    final ShadeModel model;
    try {
      model = await shadeModel();
    } catch (_) {
      direct.ignore(); // its error must not go unhandled
      rethrow;
    }
    final detours = [
      for (final via in viaPoints(from, to, parks: model.parkCentres))
        osrm
            .route([from, via, to])
            .then<List<OsrmRoute>>(
              (r) => r,
              // A detour that fails is just not a candidate.
              onError: (Object _) => const <OsrmRoute>[],
            ),
    ];
    final routes = [
      ...await direct, // its errors (no route, offline) are the answer
      for (final list in await Future.wait(detours)) ...list.take(1),
    ];

    final forecast = await forecastFuture;
    double strength(DateTime t) => sunStrength(forecast, t);
    final departureWeather = forecast?.at(request.datetime);

    final shortestDistance = routes.map((r) => r.distanceM).reduce(math.min);
    final candidates = <_Candidate>[];
    for (final r in routes) {
      final points = removeSpurs(r.points);
      if (points.length < 2) continue;
      final shade = model.analyse(points);
      final scale = r.distanceM > 0 ? shade.length / r.distanceM : 1.0;
      final distance = shade.length;
      if (distance > shortestDistance * maxDetourFactor) continue;
      final duration = Duration(seconds: (r.durationS * scale).round());
      final c = _Candidate(points, shade, distance, duration);
      if (candidates.any((o) => o.sameAs(c))) continue;
      c.sun = shade.sunShare(request.datetime, duration, strength: strength);
      candidates.add(c);
    }
    if (candidates.isEmpty) {
      throw const ApiException(ApiErrorKind.notFound, 'route_not_found');
    }

    final shortest = candidates.reduce(
      (a, b) => b.duration < a.duration ? b : a,
    );
    var shaded = candidates
        .where(
          (c) =>
              c.duration.inSeconds <=
              shortest.duration.inSeconds * maxShadedFactor,
        )
        .reduce((a, b) => b.sun < a.sun - 0.005 ? b : a);
    if (shortest.sun - shaded.sun < minShadeGain) shaded = shortest;
    final compromise = _compromise(
      candidates,
      shortest,
      shaded,
      request.profile.weights,
      heat: heatWeight(departureWeather?.temperature),
    );

    final stopPlaces = await places();
    final coverage =
        candidates.every(
          (c) => c.points.every(
            (p) => ShadeModel.dataBounds.contains(p.latitude, p.longitude),
          ),
        )
        ? RouteCoverage.full
        : RouteCoverage.approximate;
    // Each distinct walk once: the named variants that differ, then the
    // other shadier candidates (least sun first) as alternatives, at most
    // [maxVariants]. A single possible walk gives a single variant.
    // When two names share a walk, the profile's default name (S07 opens
    // on it: shaded for Senior, compromise otherwise) keeps it.
    final senior = request.profile.id == ProfileId.senior;
    final picked = <(RouteVariantType, _Candidate)>[];
    for (final (type, c) in [
      (RouteVariantType.shortest, shortest),
      if (senior) (RouteVariantType.shaded, shaded),
      (RouteVariantType.compromise, compromise),
      if (!senior) (RouteVariantType.shaded, shaded),
    ]) {
      if (!picked.any((p) => identical(p.$2, c))) picked.add((type, c));
    }
    picked.sort((a, b) => a.$1.index.compareTo(b.$1.index));
    // Alternatives only when they spare some sun: at night or under thick
    // clouds a longer walk has nothing to offer.
    final rest = [
      for (final c in candidates)
        if (!picked.any((p) => identical(p.$2, c)) &&
            c.sun <= shortest.sun - minShadeGain)
          c,
    ]..sort((a, b) => a.sun.compareTo(b.sun));
    for (final c in rest.take(maxVariants - picked.length)) {
      picked.add((RouteVariantType.alternative, c));
    }
    return RouteResponse(
      coverage: coverage,
      variants: [
        for (final (type, c) in picked)
          _variant(type, c, shortest, request.datetime, stopPlaces, strength),
      ],
      weather: forecast == null
          ? null
          : RouteWeather(
              sunStrength: _round2(strength(request.datetime)),
              temperature: departureWeather?.temperature,
              cloudCover: departureWeather?.cloudCover,
            ),
    );
  }

  /// «Chłodny spacer»: walking speed for the length of a loop (4.5 km/h).
  static const loopSpeed = 1.25;
  static const maxLoops = 3;

  /// Loops of about [minutes] from [from] and back, through parks where
  /// they lie on the way, least sun at [departure] first (the first is
  /// `shaded`, the rest `alternative`).
  Future<RouteResponse> loop(
    LatLng from, {
    required int minutes,
    required DateTime departure,
  }) async {
    final target = minutes * 60 * loopSpeed;
    final forecastFuture = _forecast();
    final model = await shadeModel();
    final results = await Future.wait([
      for (final vias in loopVias(from, target, parks: model.parkCentres))
        osrm
            .route([from, ...vias, from])
            .then<List<OsrmRoute>>(
              (r) => r.take(1).toList(),
              onError: (Object _) => const <OsrmRoute>[],
            ),
    ]);
    final forecast = await forecastFuture;
    double strength(DateTime t) => sunStrength(forecast, t);
    final candidates = <_Candidate>[];
    for (final r in results.expand((l) => l)) {
      if (r.points.length < 2) continue;
      final shade = model.analyse(r.points);
      final distance = shade.length;
      if (distance < target * 0.6 || distance > target * 1.6) continue;
      final scale = r.distanceM > 0 ? distance / r.distanceM : 1.0;
      final c = _Candidate(
        r.points,
        shade,
        distance,
        Duration(seconds: (r.durationS * scale).round()),
      );
      if (candidates.any((o) => o.sameAs(c))) continue;
      c.sun = shade.sunShare(departure, c.duration, strength: strength);
      candidates.add(c);
    }
    if (candidates.isEmpty) {
      throw const ApiException(ApiErrorKind.notFound, 'route_not_found');
    }
    double score(_Candidate c) => c.sun + 0.6 * (c.distance / target - 1).abs();
    candidates.sort((a, b) => score(a).compareTo(score(b)));
    final best = candidates.first;
    final stopPlaces = await places();
    return RouteResponse(
      coverage:
          candidates.every(
            (c) => c.points.every(
              (p) => ShadeModel.dataBounds.contains(p.latitude, p.longitude),
            ),
          )
          ? RouteCoverage.full
          : RouteCoverage.approximate,
      variants: [
        for (final (i, c) in candidates.take(maxLoops).indexed)
          _variant(
            i == 0 ? RouteVariantType.shaded : RouteVariantType.alternative,
            c,
            best,
            departure,
            stopPlaces,
            strength,
          ),
      ],
    );
  }

  /// Via points for loops of about [length] metres: two corners of a
  /// triangle in six directions; a corner moves to a park centre within
  /// a third of the side.
  static List<List<LatLng>> loopVias(
    LatLng from,
    double length, {
    List<LatLng> parks = const [],
  }) {
    // Streets add ~10 % to the straight sides.
    final side = length / 3.3;
    final k = math.cos(from.latitude * math.pi / 180);
    LatLng at(double bearingDeg) {
      final b = bearingDeg * math.pi / 180;
      final p = LatLng(
        from.latitude + side * math.cos(b) / 111195,
        from.longitude + side * math.sin(b) / (111195 * k),
      );
      LatLng? park;
      var best = side / 3;
      for (final c in parks) {
        final d = distanceMeters(p, c);
        if (d < best) {
          best = d;
          park = c;
        }
      }
      return park ?? p;
    }

    return [
      for (var b = 0.0; b < 360; b += 60) [at(b), at(b + 60)],
    ];
  }

  Future<WeatherForecast?> _forecast() async {
    final source = weather;
    if (source == null) return null;
    try {
      return await source().timeout(weatherTimeout);
    } catch (_) {
      return null; // offline or slow: clear sky
    }
  }

  /// How much more shade counts in the compromise at [temperature] °C:
  /// more in heat, less when it is cool (the sun is then welcome).
  static double heatWeight(double? temperature) => switch (temperature) {
    null => 1,
    >= 30 => 1.5,
    >= 25 => 1.25,
    < 15 => 0.6,
    _ => 1,
  };

  /// The candidate with the best balance of sun and extra time for the
  /// profile; a third route when there is one that is worth it.
  static _Candidate _compromise(
    List<_Candidate> all,
    _Candidate shortest,
    _Candidate shaded,
    ProfileWeights weights, {
    double heat = 1,
  }) {
    final shadeW = math.min(1.0, weights.shade.clamp(0, 100) / 100 * heat);
    final timeW = weights.time.clamp(0, 100) / 100;
    final sum = shadeW + timeW;
    final ws = sum == 0 ? 0.5 : shadeW / sum;
    final wt = sum == 0 ? 0.5 : timeW / sum;
    double cost(_Candidate c) =>
        ws * c.sun +
        wt *
            2 *
            (c.duration.inSeconds / math.max(1, shortest.duration.inSeconds) -
                1);
    final others = [
      for (final c in all)
        if (!identical(c, shortest) &&
            !identical(c, shaded) &&
            c.sun < shortest.sun &&
            c.duration <= shaded.duration)
          c,
    ];
    final pool = others.isNotEmpty ? others : [shortest, shaded];
    return pool.reduce((a, b) => cost(b) < cost(a) ? b : a);
  }

  RouteVariant _variant(
    RouteVariantType type,
    _Candidate c,
    _Candidate shortest,
    DateTime departure,
    List<Place> places,
    double Function(DateTime) strength,
  ) {
    final perEdge = c.shade.sunShares(
      departure,
      c.duration,
      strength: strength,
    );
    return RouteVariant(
      variant: type,
      geometry: [
        for (final p in c.points)
          LatLng(_round6(p.latitude), _round6(p.longitude)),
      ],
      segments: makeSegments(c.shade.edgeLengths, perEdge),
      distanceM: c.distance.round(),
      durationS: c.duration.inSeconds,
      sunShare: _round2(c.shade.mean(perEdge)),
      extraTimeVsShortestS: math.max(
        0,
        c.duration.inSeconds - shortest.duration.inSeconds,
      ),
      stops: findStops(c.points, places),
      sunShareByHour: {
        for (final (key, start) in daySlots(departure))
          key: _round2(c.shade.sunShare(start, c.duration, strength: strength)),
      },
    );
  }

  /// Via points for detours: sideways from the middle of the straight line
  /// (both sides), plus up to [maxParkVias] [parks] that lie along the way.
  static List<LatLng> viaPoints(
    LatLng from,
    LatLng to, {
    List<LatLng> parks = const [],
  }) {
    final d = distanceMeters(from, to);
    if (d < 300) return const [];
    final k = math.cos(from.latitude * math.pi / 180);
    final mid = LatLng(
      (from.latitude + to.latitude) / 2,
      (from.longitude + to.longitude) / 2,
    );
    // Unit normal in metres, then back to degrees.
    final dx = (to.longitude - from.longitude) * k * _mPerDegLat;
    final dy = (to.latitude - from.latitude) * _mPerDegLat;
    final len = math.sqrt(dx * dx + dy * dy);
    final offset = (d * 0.2).clamp(120.0, 500.0);
    final along = <(double, LatLng)>[];
    for (final c in parks) {
      final a = distanceMeters(from, c);
      final b = distanceMeters(c, to);
      if (a < 150 || b < 150) continue;
      final factor = (a + b) / d;
      if (factor <= maxParkDetour) along.add((factor, c));
    }
    along.sort((x, y) => x.$1.compareTo(y.$1));
    return [
      for (final side in const [1, -1])
        LatLng(
          mid.latitude + side * dx / len * offset / _mPerDegLat,
          mid.longitude - side * dy / len * offset / (_mPerDegLat * k),
        ),
      for (final (_, c) in along.take(maxParkVias)) c,
    ];
  }

  /// Departures 08:00–20:00 every 30 min on the day of [departure]
  /// (Warsaw wall clock), as `"HH:mm"` → instant.
  static List<(String, DateTime)> daySlots(DateTime departure) {
    final local = departure.toUtc().add(warsawUtcOffset(departure));
    return [
      for (var m = 8 * 60; m <= 20 * 60; m += 30)
        (
          formatHhMm(m),
          warsawWallClockToUtc(
            local.year,
            local.month,
            local.day,
            m ~/ 60,
            m % 60,
          ),
        ),
    ];
  }

  /// Cool places within 80 m and drinking water within 25 m of the line,
  /// in walking order; none right next to the start.
  static List<RouteStop> findStops(List<LatLng> line, List<Place> places) {
    final found = <(double, Place)>[];
    for (final p in places) {
      final radius = switch (p.type) {
        PlaceType.cool => coolStopRadius,
        PlaceType.water => waterStopRadius,
        PlaceType.bench => null,
      };
      if (radius == null) continue;
      final point = LatLng(p.lat, p.lon);
      if (distanceMeters(line.first, point) < stopSkipNearStart) continue;
      final (dist, along) = _project(point, line);
      if (dist <= radius) found.add((along, p));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    final counts = <PlaceType, int>{};
    return [
      for (final (_, p) in found)
        if ((counts[p.type] = (counts[p.type] ?? 0) + 1) <= maxStopsPerType)
          RouteStop(
            placeId: p.id,
            type: p.type == PlaceType.water ? StopType.water : StopType.cool,
          ),
    ];
  }

  /// Distance from [p] to [line] and how far along the line it is (m).
  static (double, double) _project(LatLng p, List<LatLng> line) {
    final k = math.cos(p.latitude * math.pi / 180);
    (double, double) xy(LatLng q) => (
      (q.longitude - p.longitude) * k * _mPerDegLat,
      (q.latitude - p.latitude) * _mPerDegLat,
    );
    var best = double.infinity;
    var bestAlong = 0.0;
    var walked = 0.0;
    for (var i = 0; i + 1 < line.length; i++) {
      final (ax, ay) = xy(line[i]);
      final (bx, by) = xy(line[i + 1]);
      final vx = bx - ax;
      final vy = by - ay;
      final len2 = vx * vx + vy * vy;
      final t = len2 == 0 ? 0.0 : ((-ax * vx - ay * vy) / len2).clamp(0.0, 1.0);
      final cx = ax + t * vx;
      final cy = ay + t * vy;
      final d = math.sqrt(cx * cx + cy * cy);
      final segment = math.sqrt(len2);
      if (d < best) {
        best = d;
        bestAlong = walked + t * segment;
      }
      walked += segment;
    }
    return (best, bestAlong);
  }
}

const _mPerDegLat = 111195.0;

double _round2(double v) => (v * 100).round() / 100;

double _round6(double v) => (v * 1e6).round() / 1e6;

class _Candidate {
  _Candidate(this.points, this.shade, this.distance, this.duration);

  final List<LatLng> points;
  final RouteShade shade;
  final double distance;
  final Duration duration;
  double sun = 1;

  /// Nearly the same walk: length within 2 % and the middle point within
  /// 40 m.
  bool sameAs(_Candidate o) =>
      (distance - o.distance).abs() <= 0.02 * math.max(distance, o.distance) &&
      distanceMeters(_middle, o._middle) <= 40;

  LatLng get _middle => points[points.length ~/ 2];
}

/// Drops repeated points and the loops between them, e.g. the out-and-back
/// spur OSRM adds to reach a via point (A, B, A → A).
List<LatLng> removeSpurs(List<LatLng> points) {
  final out = <LatLng>[];
  final seen = <(double, double), int>{};
  for (final p in points) {
    final key = (p.latitude, p.longitude);
    final at = seen[key];
    if (at != null) {
      for (final q in out.sublist(at + 1)) {
        seen.remove((q.latitude, q.longitude));
      }
      out.removeRange(at + 1, out.length);
      continue;
    }
    seen[key] = out.length;
    out.add(p);
  }
  return out;
}

/// Groups edges into runs of similar sun share (smoothed over ~40 m,
/// quantised to quarters, runs under 80 m merged into a neighbour, then
/// neighbours closer than [minStep] joined, at most [maxRuns]). Returns
/// vertex ranges `[from, to]`, inclusive.
List<RouteSegment> makeSegments(
  List<double> lengths,
  List<double> sun, {
  int maxRuns = 12,
  double minRunLength = 80,
  double minStep = 0.1,
}) {
  final n = sun.length;
  if (n == 0) return const [];
  final smooth = <double>[];
  for (var i = 0; i < n; i++) {
    var acc = 0.0;
    var w = 0.0;
    var d = 0.0;
    for (var j = i; j >= 0 && d < 20; j--) {
      acc += sun[j] * lengths[j];
      w += lengths[j];
      d += lengths[j];
    }
    d = 0;
    for (var j = i + 1; j < n && d < 20; j++) {
      acc += sun[j] * lengths[j];
      w += lengths[j];
      d += lengths[j];
    }
    smooth.add(w > 0 ? acc / w : sun[i]);
  }
  // Runs as [startEdge, endEdgeExclusive].
  final runs = <List<int>>[];
  int? lastLevel;
  for (var i = 0; i < n; i++) {
    final level = (smooth[i] * 4).round();
    if (runs.isNotEmpty && level == lastLevel) {
      runs.last[1] = i + 1;
    } else {
      runs.add([i, i + 1]);
    }
    lastLevel = level;
  }
  double runLength(List<int> r) {
    var s = 0.0;
    for (var k = r[0]; k < r[1]; k++) {
      s += lengths[k];
    }
    return s;
  }

  double value(List<int> r) {
    var s = 0.0;
    for (var k = r[0]; k < r[1]; k++) {
      s += sun[k] * lengths[k];
    }
    final len = runLength(r);
    return len > 0 ? s / len : sun[r[0]];
  }

  void merge(int i) {
    runs[i][1] = runs[i + 1][1];
    runs.removeAt(i + 1);
  }

  // Short runs go into the more similar neighbour.
  var changed = true;
  while (changed && runs.length > 1) {
    changed = false;
    for (var i = 0; i < runs.length; i++) {
      if (runLength(runs[i]) >= minRunLength) continue;
      if (i == 0) {
        merge(0);
      } else if (i == runs.length - 1) {
        merge(i - 1);
      } else {
        final left = (value(runs[i - 1]) - value(runs[i])).abs();
        final right = (value(runs[i + 1]) - value(runs[i])).abs();
        merge(left <= right ? i - 1 : i);
      }
      changed = true;
      break;
    }
  }
  // Neighbours less than [minStep] apart are one segment.
  while (runs.length > 1) {
    var best = -1;
    var bestDiff = minStep;
    for (var k = 0; k + 1 < runs.length; k++) {
      final diff = (value(runs[k]) - value(runs[k + 1])).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = k;
      }
    }
    if (best < 0) break;
    merge(best);
  }
  while (runs.length > maxRuns) {
    var best = 0;
    var bestCost = double.infinity;
    for (var k = 0; k + 1 < runs.length; k++) {
      final c =
          (value(runs[k]) - value(runs[k + 1])).abs() *
          math.min(runLength(runs[k]), runLength(runs[k + 1]));
      if (c < bestCost) {
        bestCost = c;
        best = k;
      }
    }
    merge(best);
  }
  return [
    for (final r in runs)
      RouteSegment(from: r[0], to: r[1], sunShare: _round2(value(r))),
  ];
}
