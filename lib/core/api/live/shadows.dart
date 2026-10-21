import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import 'sun.dart';

/// Buildings (footprint + height) and trees (crown) of Śródmieście from
/// OpenStreetMap (`assets/demo/shadow_casters.json`), and the shadows they
/// cast for a sun position: polygons for the map ([shadows]) and a ray
/// test for the route model ([inShadow]).
///
/// Works in metres east/north of the file's origin.
class ShadowCasters {
  ShadowCasters._(this._origin, this._mLon, this._mLat, this._b, this._t) {
    for (final (i, b) in _b.indexed) {
      for (var cx = _cell(b.minX); cx <= _cell(b.maxX); cx++) {
        for (var cy = _cell(b.minY); cy <= _cell(b.maxY); cy++) {
          (_bCells[_key(cx, cy)] ??= []).add(i);
        }
      }
      if (b.h > _maxHeight) _maxHeight = b.h;
      _grow(b.minX, b.minY);
      _grow(b.maxX, b.maxY);
    }
    for (final (i, t) in _t.indexed) {
      (_tCells[_key(_cell(t.x), _cell(t.y))] ??= []).add(i);
      _grow(t.x, t.y);
    }
  }

  /// `{"origin": [lon, lat], "metresPerDegree": [x, y], "unit": "dm",
  /// "buildings": [[h, x0, y0, dx1, dy1, …]], "trees": [[x, y(, h, r)]]}`.
  factory ShadowCasters.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('shadow casters');
    final origin = (json['origin'] as List).cast<num>();
    final scale = (json['metresPerDegree'] as List).cast<num>();
    const dm = 0.1;
    final buildings = <_Building>[];
    for (final raw in json['buildings'] as List? ?? const []) {
      final v = (raw as List).cast<num>();
      if (v.length < 7) continue;
      final xs = <double>[];
      final ys = <double>[];
      var x = v[1].toDouble();
      var y = v[2].toDouble();
      xs.add(x * dm);
      ys.add(y * dm);
      for (var i = 3; i + 1 < v.length; i += 2) {
        x += v[i];
        y += v[i + 1];
        xs.add(x * dm);
        ys.add(y * dm);
      }
      buildings.add(_Building(xs, ys, v[0].toDouble()));
    }
    final trees = <_Tree>[
      for (final raw in json['trees'] as List? ?? const [])
        if ((raw as List).cast<num>() case final v when v.length >= 2)
          _Tree(
            v[0] * dm,
            v[1] * dm,
            v.length > 2 ? v[2].toDouble() : defaultTreeHeight,
            v.length > 3 ? v[3].toDouble() : defaultCrownRadius,
          ),
    ];
    return ShadowCasters._(
      LatLng(origin[1].toDouble(), origin[0].toDouble()),
      scale[0].toDouble(),
      scale[1].toDouble(),
      buildings,
      trees,
    );
  }

  static const defaultTreeHeight = 9.0;
  static const defaultCrownRadius = 3.0;

  /// The crown's centre is at this share of the tree's height.
  static const crownHeight = 0.65;

  /// Shadows are cut at this length (very low sun).
  static const maxShadow = 250.0;

  /// The ray test steps this far along the ray towards the sun.
  static const rayStep = 2.5;

  static const _cellSize = 20.0;

  final LatLng _origin;
  final double _mLon;
  final double _mLat;
  final List<_Building> _b;
  final List<_Tree> _t;
  final _bCells = <int, List<int>>{};
  final _tCells = <int, List<int>>{};
  double _maxHeight = 0;
  double? _minX, _minY, _maxX, _maxY;

  int get buildingCount => _b.length;
  int get treeCount => _t.length;

  /// Where there is data (with a margin).
  bool covers(LatLng p) {
    final (x, y) = toXY(p);
    return _minX != null &&
        x >= _minX! &&
        x <= _maxX! &&
        y >= _minY! &&
        y <= _maxY!;
  }

  (double, double) toXY(LatLng p) => (
    (p.longitude - _origin.longitude) * _mLon,
    (p.latitude - _origin.latitude) * _mLat,
  );

  LatLng toLatLng(double x, double y) =>
      LatLng(_origin.latitude + y / _mLat, _origin.longitude + x / _mLon);

  /// Unit vector (east, north) towards the sun.
  static (double, double) _towardsSun(SunPosition sun) {
    final a = sun.azimuth * math.pi / 180;
    return (math.sin(a), math.cos(a));
  }

  /// True when a building or a tree crown stands between [p] and the sun
  /// (or the sun is down).
  bool inShadow(LatLng p, SunPosition sun) {
    if (sun.elevation <= 0) return true;
    final (x, y) = toXY(p);
    final tanEl = math.tan(sun.elevation * math.pi / 180);
    final (dx, dy) = _towardsSun(sun);
    final reach = math.min(maxShadow, _maxHeight / tanEl);
    final seenTrees = <int>{};
    for (var s = rayStep; s <= reach + rayStep; s += rayStep) {
      final px = x + dx * s;
      final py = y + dy * s;
      final rayHeight = s * tanEl;
      final cx = _cell(px);
      final cy = _cell(py);
      for (final i in _bCells[_key(cx, cy)] ?? const <int>[]) {
        final b = _b[i];
        if (b.h > rayHeight && b.contains(px, py)) return true;
      }
      // Crowns reach a few metres sideways: the cells around the ray too.
      for (var nx = cx - 1; nx <= cx + 1; nx++) {
        for (var ny = cy - 1; ny <= cy + 1; ny++) {
          final key = _key(nx, ny);
          if (!seenTrees.add(key)) continue;
          for (final i in _tCells[key] ?? const <int>[]) {
            final t = _t[i];
            // The crown's shadow is a disc around the trunk moved away from
            // the sun: is [p] inside it?
            final d = t.h * crownHeight / tanEl;
            final sx = t.x - dx * d;
            final sy = t.y - dy * d;
            if ((sx - x) * (sx - x) + (sy - y) * (sy - y) < t.r * t.r) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Shadow polygons at [sun] inside [bounds] (all when null): each
  /// building's footprint swept away from the sun by height / tan(elevation),
  /// and each crown's disc moved the same way. Properties
  /// `{"shade": shade, "source": "shadow"}`.
  List<GeoFeature> shadows(
    SunPosition sun, {
    GeoBounds? bounds,
    double shade = 0.85,
  }) {
    if (sun.elevation <= 0) return const [];
    final tanEl = math.tan(sun.elevation * math.pi / 180);
    final (dx, dy) = _towardsSun(sun);
    final props = {'shade': shade, 'source': 'shadow'};
    bool inside(double minX, double minY, double maxX, double maxY) {
      if (bounds == null) return true;
      final (x0, y0) = toXY(LatLng(bounds.minLat, bounds.minLon));
      final (x1, y1) = toXY(LatLng(bounds.maxLat, bounds.maxLon));
      return maxX >= x0 && minX <= x1 && maxY >= y0 && minY <= y1;
    }

    final out = <GeoFeature>[];
    for (final b in _b) {
      final len = math.min(maxShadow, b.h / tanEl);
      final ox = -dx * len;
      final oy = -dy * len;
      if (!inside(
        math.min(b.minX, b.minX + ox),
        math.min(b.minY, b.minY + oy),
        math.max(b.maxX, b.maxX + ox),
        math.max(b.maxY, b.maxY + oy),
      )) {
        continue;
      }
      final hull = _hull([
        for (var i = 0; i < b.xs.length; i++) (b.xs[i], b.ys[i]),
        for (var i = 0; i < b.xs.length; i++) (b.xs[i] + ox, b.ys[i] + oy),
      ]);
      // The roof itself is not "in shadow": cut the footprint out.
      out.add(
        _feature(
          hull,
          props,
          hole: [for (var i = 0; i < b.xs.length; i++) (b.xs[i], b.ys[i])],
        ),
      );
    }
    for (final t in _t) {
      final d = t.h * crownHeight / tanEl;
      final cx = t.x - dx * d;
      final cy = t.y - dy * d;
      if (!inside(cx - t.r, cy - t.r, cx + t.r, cy + t.r)) continue;
      // The crown's shadow stretches along the sun's direction.
      final stretch = math.min(
        3.0,
        1 / math.sin(sun.elevation * math.pi / 180),
      );
      out.add(
        _feature([
          for (var k = 0; k < 10; k++)
            () {
              final a = k * math.pi / 5;
              final u = math.cos(a) * t.r * stretch; // along the shadow
              final v = math.sin(a) * t.r;
              return (cx - dx * u + dy * v, cy - dy * u - dx * v);
            }(),
        ], props),
      );
    }
    return out;
  }

  GeoFeature _feature(
    List<(double, double)> ring,
    Map<String, Object> props, {
    List<(double, double)>? hole,
  }) {
    List<LatLng> closed(List<(double, double)> r) => [
      for (final (x, y) in r) toLatLng(x, y),
      toLatLng(r.first.$1, r.first.$2),
    ];
    return GeoFeature(
      geometry: GeoPolygons([
        GeoPolygon(closed(ring), [
          if (hole != null && hole.length >= 3) closed(hole),
        ]),
      ]),
      properties: props,
    );
  }

  /// Convex hull (monotone chain), counter-clockwise.
  static List<(double, double)> _hull(List<(double, double)> points) {
    final p = [...points]
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    if (p.length < 3) return p;
    double cross((double, double) o, (double, double) a, (double, double) b) =>
        (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
    final lower = <(double, double)>[];
    for (final q in p) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    final upper = <(double, double)>[];
    for (final q in p.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }

  void _grow(double x, double y) {
    _minX = math.min(_minX ?? x, x);
    _minY = math.min(_minY ?? y, y);
    _maxX = math.max(_maxX ?? x, x);
    _maxY = math.max(_maxY ?? y, y);
  }

  static int _cell(double v) => (v / _cellSize).floor();

  static int _key(int cx, int cy) => cx * 100003 + cy;
}

class _Building {
  _Building(this.xs, this.ys, this.h)
    : minX = xs.reduce(math.min),
      maxX = xs.reduce(math.max),
      minY = ys.reduce(math.min),
      maxY = ys.reduce(math.max);

  final List<double> xs;
  final List<double> ys;
  final double h;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  bool contains(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return false;
    var inside = false;
    for (var i = 0, j = xs.length - 1; i < xs.length; j = i++) {
      if ((ys[i] > y) != (ys[j] > y) &&
          x < (xs[j] - xs[i]) * (y - ys[i]) / (ys[j] - ys[i]) + xs[i]) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class _Tree {
  const _Tree(this.x, this.y, this.h, this.r);

  final double x;
  final double y;
  final double h;
  final double r;
}
