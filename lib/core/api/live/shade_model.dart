import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import 'sun.dart';

/// Where the walker is in the sun, from bundled OpenStreetMap layers and the
/// sun position (the model of `docs/data-sources.md`, run on the phone):
///
/// - tree crowns: the `trees` polygons of `layer_shade_1430.geojson` (their
///   `shade` value) and parks/woods of `layer_green.geojson` (0.8); crowns
///   count more when the sun is low;
/// - building shadow: a street canyon (tenements in the Śródmieście grid,
///   lower buildings elsewhere) whose shadow across the street follows the
///   sun's height and direction. The 14:30 building strips of the shade
///   layer are skipped: they are valid for one time only.
class ShadeModel {
  ShadeModel({
    required List<GeoFeature> canopy,
    required List<GeoFeature> parks,
  }) : _canopy = _PolygonIndex([
         for (final f in canopy)
           for (final p in f.geometry.polygons)
             if (p.outer.length >= 3)
               _Indexed(p, (f.shade ?? 0).clamp(0.0, 1.0)),
       ]),
       _parks = _PolygonIndex([
         for (final f in parks)
           for (final p in f.geometry.polygons)
             if (p.outer.length >= 3) _Indexed(p, parkCanopy),
       ]),
       parkCentres = [
         for (final f in parks)
           for (final p in f.geometry.polygons)
             if (p.outer.isNotEmpty) _centre(p.outer),
       ];

  /// From `/v1/layers/shade` (bundled 14:30 file) and `/v1/layers/green`.
  factory ShadeModel.fromLayers({
    required GeoLayer shade,
    required GeoLayer green,
  }) => ShadeModel(
    canopy: [
      for (final f in shade.features)
        if (f.properties['source'] != 'buildings') f,
    ],
    parks: [
      for (final f in green.features)
        if (const {'park', 'forest', 'wood', 'garden'}.contains(f.kind)) f,
    ],
  );

  /// Area the bundled layers cover (Śródmieście); outside it the shade is
  /// only estimated and the route gets `coverage: approximate`.
  static const dataBounds = GeoBounds(
    minLon: 19.425,
    minLat: 51.745,
    maxLon: 19.495,
    maxLat: 51.790,
  );

  /// The 19th-century tenement grid.
  static const tenementCore = GeoBounds(
    minLon: 19.435,
    minLat: 51.755,
    maxLon: 19.480,
    maxLat: 51.785,
  );

  static const parkCanopy = 0.8;
  static const tenementHeight = 16.0;
  static const tenementStreetWidth = 18.0;

  /// Outside the grid: lower blocks and wider streets (an estimate).
  static const otherHeight = 10.0;
  static const otherStreetWidth = 24.0;

  /// A pedestrian uses one sidewalk, not the whole canyon.
  static const buildingWeight = 0.6;

  /// Canopy is sampled along an edge at least every this many metres.
  static const sampleStep = 15.0;

  final _PolygonIndex _canopy;
  final _PolygonIndex _parks;

  /// Rough centre of every park and wood (via points for shaded detours).
  final List<LatLng> parkCentres;

  /// Mean of the vertices; a closed ring's repeated last point is skipped.
  static LatLng _centre(List<LatLng> ring) {
    final closed = ring.length > 1 && ring.first == ring.last;
    final points = closed ? ring.sublist(0, ring.length - 1) : ring;
    var lat = 0.0;
    var lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Tree-crown cover at [p], 0..1.
  double canopyAt(LatLng p) =>
      math.max(_canopy.maxValueAt(p), _parks.maxValueAt(p));

  bool inPark(LatLng p) => _parks.maxValueAt(p) > 0;

  /// Static context of every edge of [points]; sun shares for any time come
  /// from [RouteShade.sunShares].
  RouteShade analyse(List<LatLng> points) {
    final edges = <_Edge>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      final length = distanceMeters(a, b);
      final samples = math.max(1, (length / sampleStep).ceil());
      var canopy = 0.0;
      var parkSamples = 0;
      for (var k = 0; k < samples; k++) {
        final t = (k + 0.5) / samples;
        final p = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        canopy += canopyAt(p);
        if (inPark(p)) parkSamples++;
      }
      final mid = LatLng(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );
      final inGrid = tenementCore.contains(mid.latitude, mid.longitude);
      edges.add(
        _Edge(
          length: length,
          mid: mid,
          bearing: bearingDegrees(a, b),
          canopy: canopy / samples,
          // Mostly inside a park: no street canyon.
          canyon: parkSamples * 2 > samples
              ? null
              : inGrid
              ? const _Canyon(tenementHeight, tenementStreetWidth)
              : const _Canyon(otherHeight, otherStreetWidth),
        ),
      );
    }
    return RouteShade._(edges);
  }
}

/// Share of the walk along a street canyon in building shadow.
double buildingShadow({
  required double height,
  required double width,
  required double streetBearing,
  required SunPosition sun,
}) {
  if (sun.elevation <= 2) return 1;
  final across =
      height /
      math.tan(sun.elevation * math.pi / 180) *
      math.sin((sun.azimuth - streetBearing) * math.pi / 180).abs();
  return math.min(1, ShadeModel.buildingWeight * across / width);
}

/// Initial bearing from [a] to [b], degrees clockwise from north.
double bearingDegrees(LatLng a, LatLng b) {
  final k = math.cos(a.latitude * math.pi / 180);
  final dx = (b.longitude - a.longitude) * k;
  final dy = b.latitude - a.latitude;
  return (math.atan2(dx, dy) * 180 / math.pi) % 360;
}

/// A route analysed by [ShadeModel.analyse].
class RouteShade {
  RouteShade._(this._edges);

  final List<_Edge> _edges;

  int get edgeCount => _edges.length;

  List<double> get edgeLengths => [for (final e in _edges) e.length];

  double get length => _edges.fold(0, (sum, e) => sum + e.length);

  /// Sun share of every edge for a walk that starts at [start] and takes
  /// [duration]: each edge is evaluated when the walker gets there.
  List<double> sunShares(DateTime start, Duration duration) {
    final total = length;
    var walked = 0.0;
    return [
      for (final e in _edges)
        () {
          final at = total <= 0
              ? 0.0
              : (walked + e.length / 2) / total * duration.inSeconds;
          walked += e.length;
          final sun = sunPosition(
            e.mid.latitude,
            e.mid.longitude,
            start.add(Duration(seconds: at.round())),
          );
          if (sun.elevation <= 2) return 0.0;
          final canyon = e.canyon;
          final building = canyon == null
              ? 0.0
              : buildingShadow(
                  height: canyon.height,
                  width: canyon.width,
                  streetBearing: e.bearing,
                  sun: sun,
                );
          // Crowns cast longer shadows when the sun is low.
          final crowns = math.min(
            0.95,
            e.canopy * (2 - math.sin(sun.elevation * math.pi / 180)),
          );
          return ((1 - building) * (1 - crowns)).clamp(0.0, 1.0);
        }(),
    ];
  }

  /// Length-weighted mean of per-edge [values].
  double mean(List<double> values) {
    var sum = 0.0;
    var total = 0.0;
    for (var i = 0; i < _edges.length; i++) {
      sum += values[i] * _edges[i].length;
      total += _edges[i].length;
    }
    return total <= 0 ? 0 : sum / total;
  }

  /// Mean sun share of the whole walk.
  double sunShare(DateTime start, Duration duration) =>
      mean(sunShares(start, duration));
}

class _Canyon {
  const _Canyon(this.height, this.width);

  final double height;
  final double width;
}

class _Edge {
  const _Edge({
    required this.length,
    required this.mid,
    required this.bearing,
    required this.canopy,
    required this.canyon,
  });

  final double length;
  final LatLng mid;
  final double bearing;
  final double canopy;
  final _Canyon? canyon;
}

class _Indexed {
  _Indexed(this.polygon, this.value)
    : minLat = polygon.outer.map((p) => p.latitude).reduce(math.min),
      maxLat = polygon.outer.map((p) => p.latitude).reduce(math.max),
      minLon = polygon.outer.map((p) => p.longitude).reduce(math.min),
      maxLon = polygon.outer.map((p) => p.longitude).reduce(math.max);

  final GeoPolygon polygon;
  final double value;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  bool contains(LatLng p) {
    if (p.latitude < minLat ||
        p.latitude > maxLat ||
        p.longitude < minLon ||
        p.longitude > maxLon) {
      return false;
    }
    if (!_inRing(p, polygon.outer)) return false;
    return !polygon.holes.any((h) => _inRing(p, h));
  }

  static bool _inRing(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) *
                      (p.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Polygons bucketed in a grid of ~150 m cells.
class _PolygonIndex {
  _PolygonIndex(List<_Indexed> items) {
    for (final item in items) {
      for (var x = _cell(item.minLon); x <= _cell(item.maxLon); x++) {
        for (var y = _cell(item.minLat); y <= _cell(item.maxLat); y++) {
          (_cells[(x, y)] ??= []).add(item);
        }
      }
    }
  }

  static const _cellDeg = 0.002;

  final _cells = <(int, int), List<_Indexed>>{};

  static int _cell(double v) => (v / _cellDeg).floor();

  double maxValueAt(LatLng p) {
    var best = 0.0;
    for (final item
        in _cells[(_cell(p.longitude), _cell(p.latitude))] ??
            const <_Indexed>[]) {
      if (item.value > best && item.contains(p)) best = item.value;
    }
    return best;
  }
}
