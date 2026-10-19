import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../core/models/models.dart';

/// Quiet areas for the «Cisza» map layer, derived from the noise layer
/// (`/v1/layers/noise`, bands along loud roads): every cell of a ~40 m grid
/// outside all noise bands is quiet (1); inside a park or wood, or at least
/// [veryQuietMeters] from every band, it is very quiet (2). Cells are merged
/// into rectangles. Properties: `{"quiet": 1|2}`.
GeoLayer quietAreas(
  GeoLayer noise, {
  GeoLayer? green,
  double cellMeters = 40,
  double veryQuietMeters = 120,
}) {
  final bands = _Index([
    for (final f in noise.features)
      for (final p in f.geometry.polygons) p,
  ]);
  final parks = _Index([
    for (final f in green?.features ?? const <GeoFeature>[])
      if (const {'park', 'forest', 'wood', 'garden'}.contains(f.kind))
        for (final p in f.geometry.polygons) p,
  ]);
  final box = bands.bounds;
  if (box == null) return const GeoLayer(features: []);

  // Whole cells that fit the bounds exactly (no sliver outside the data).
  final cellLat = cellMeters / 111195;
  final cellLon =
      cellMeters /
      (111195 * math.cos((box.minLat + box.maxLat) / 2 * math.pi / 180));
  final rows = math.max(1, ((box.maxLat - box.minLat) / cellLat).round());
  final cols = math.max(1, ((box.maxLon - box.minLon) / cellLon).round());
  final dLat = (box.maxLat - box.minLat) / rows;
  final dLon = (box.maxLon - box.minLon) / cols;

  LatLng centre(int r, int c) =>
      LatLng(box.minLat + (r + 0.5) * dLat, box.minLon + (c + 0.5) * dLon);
  final loud = [
    for (var r = 0; r < rows; r++)
      [for (var c = 0; c < cols; c++) bands.contains(centre(r, c))],
  ];
  // Cells this many cells away from every loud cell are very quiet.
  final reach = (veryQuietMeters / cellMeters).ceil();
  bool farFromRoads(int r, int c) {
    for (
      var y = math.max<int>(0, r - reach);
      y <= math.min<int>(rows - 1, r + reach);
      y++
    ) {
      for (
        var x = math.max<int>(0, c - reach);
        x <= math.min<int>(cols - 1, c + reach);
        x++
      ) {
        if (loud[y][x]) return false;
      }
    }
    return true;
  }

  // Per row: runs of equal level as [startCol, endCol (exclusive), level].
  final runs = <List<List<int>>>[];
  for (var r = 0; r < rows; r++) {
    final row = <List<int>>[];
    for (var c = 0; c < cols; c++) {
      final level = loud[r][c]
          ? 0
          : parks.contains(centre(r, c)) || farFromRoads(r, c)
          ? 2
          : 1;
      if (row.isNotEmpty && row.last[2] == level && row.last[1] == c) {
        row.last[1] = c + 1;
      } else {
        row.add([c, c + 1, level]);
      }
    }
    runs.add([
      for (final run in row)
        if (run[2] > 0) run,
    ]);
  }

  // Stack equal runs of consecutive rows into one rectangle.
  final features = <GeoFeature>[];
  final open = <String, List<int>>{}; // "start:end:level" -> [firstRow]
  void close(String key, int lastRow) {
    final parts = key.split(':').map(int.parse).toList();
    final first = open.remove(key)!.single;
    final south = box.minLat + first * dLat;
    final north = box.minLat + (lastRow + 1) * dLat;
    final west = box.minLon + parts[0] * dLon;
    final east = box.minLon + parts[1] * dLon;
    features.add(
      GeoFeature(
        geometry: GeoPolygons([
          GeoPolygon([
            LatLng(south, west),
            LatLng(south, east),
            LatLng(north, east),
            LatLng(north, west),
            LatLng(south, west),
          ]),
        ]),
        properties: {'quiet': parts[2]},
      ),
    );
  }

  for (var r = 0; r < rows; r++) {
    final keys = {for (final run in runs[r]) '${run[0]}:${run[1]}:${run[2]}'};
    for (final key in open.keys.toList()) {
      if (!keys.contains(key)) close(key, r - 1);
    }
    for (final key in keys) {
      open.putIfAbsent(key, () => [r]);
    }
  }
  for (final key in open.keys.toList()) {
    close(key, rows - 1);
  }
  return GeoLayer(features: features);
}

class _Box {
  _Box(this.minLat, this.maxLat, this.minLon, this.maxLon);

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
}

class _Index {
  _Index(List<GeoPolygon> polygons) {
    for (final p in polygons) {
      if (p.outer.length < 3) continue;
      final lats = p.outer.map((q) => q.latitude);
      final lons = p.outer.map((q) => q.longitude);
      final box = _Box(
        lats.reduce(math.min),
        lats.reduce(math.max),
        lons.reduce(math.min),
        lons.reduce(math.max),
      );
      final b = bounds;
      bounds = b == null
          ? box
          : _Box(
              math.min(b.minLat, box.minLat),
              math.max(b.maxLat, box.maxLat),
              math.min(b.minLon, box.minLon),
              math.max(b.maxLon, box.maxLon),
            );
      for (var x = _cell(box.minLon); x <= _cell(box.maxLon); x++) {
        for (var y = _cell(box.minLat); y <= _cell(box.maxLat); y++) {
          (_cells[(x, y)] ??= []).add((p, box));
        }
      }
    }
  }

  static const _cellDeg = 0.002;
  final _cells = <(int, int), List<(GeoPolygon, _Box)>>{};
  _Box? bounds;

  static int _cell(double v) => (v / _cellDeg).floor();

  bool contains(LatLng p) {
    for (final (polygon, box)
        in _cells[(_cell(p.longitude), _cell(p.latitude))] ??
            const <(GeoPolygon, _Box)>[]) {
      if (p.latitude < box.minLat ||
          p.latitude > box.maxLat ||
          p.longitude < box.minLon ||
          p.longitude > box.maxLon) {
        continue;
      }
      if (_inRing(p, polygon.outer) &&
          !polygon.holes.any((h) => _inRing(p, h))) {
        return true;
      }
    }
    return false;
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
