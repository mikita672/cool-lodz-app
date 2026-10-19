import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import 'shade_model.dart';
import 'sun.dart';

/// A street centreline of the tenement grid with its width (metres), from
/// `assets/demo/streets_core.geojson`.
class StreetLine {
  const StreetLine(this.points, this.width);

  final List<LatLng> points;
  final double width;
}

/// `{"type": "FeatureCollection", "features": [{"geometry": LineString,
/// "properties": {"w": 18}}]}` → streets. Broken features are skipped.
List<StreetLine> parseStreets(Object? json) {
  final features = json is Map ? json['features'] : null;
  if (features is! List) return const [];
  final streets = <StreetLine>[];
  for (final f in features) {
    if (f is! Map) continue;
    final geometry = f['geometry'];
    final props = f['properties'];
    if (geometry is! Map || geometry['type'] != 'LineString') continue;
    try {
      final points = const LineStringConverter().fromJson(
        geometry.cast<String, dynamic>(),
      );
      final width = props is Map ? (props['w'] as num?)?.toDouble() : null;
      if (points.length >= 2) {
        streets.add(
          StreetLine(points, width ?? ShadeModel.tenementStreetWidth),
        );
      }
    } on Object {
      continue;
    }
  }
  return streets;
}

/// The map's shade layer for any time (`/v1/layers/shade` on the phone):
/// the time-independent tree polygons plus building-shadow strips on the
/// sun side of every street, as wide as the shadow that 16 m tenements cast
/// across it at that moment (the same rule as the 14:30 file and the route
/// model, see docs/data-sources.md).
class ShadeLayerBuilder {
  ShadeLayerBuilder({
    required GeoLayer bundledShade,
    required this.streets,
    required this.model,
  }) : trees = [
         for (final f in bundledShade.features)
           if (f.properties['source'] != 'buildings') f,
       ];

  final List<GeoFeature> trees;
  final List<StreetLine> streets;

  /// For parks: no street canyon there.
  final ShadeModel model;

  /// Building shadow strips are this shady.
  static const buildingShade = 0.85;

  /// Strips narrower than this are not drawn.
  static const minStripWidth = 3.0;

  /// Streets are cut into pieces of about this length to follow bends.
  static const pieceLength = 40.0;

  static const _centre = LatLng(51.77, 19.46);

  GeoLayer at(DateTime time) {
    final sun = sunPosition(_centre.latitude, _centre.longitude, time);
    return GeoLayer(
      features: [
        ...trees,
        for (final street in streets) ..._strips(street, sun),
      ],
    );
  }

  Iterable<GeoFeature> _strips(StreetLine street, SunPosition sun) sync* {
    // Runs of consecutive pieces with the shadow on the same side.
    final runs = <({List<LatLng> points, List<double> widths, int side})>[];
    for (final piece in _pieces(street.points)) {
      final mid = piece[piece.length ~/ 2];
      if (model.inPark(mid)) {
        runs.add((points: [], widths: [], side: 0)); // breaks a run
        continue;
      }
      final bearing = bearingDegrees(piece.first, piece.last);
      final across = sun.elevation <= 2
          ? street.width
          : ShadeModel.tenementHeight /
                math.tan(sun.elevation * math.pi / 180) *
                math.sin((sun.azimuth - bearing) * math.pi / 180).abs();
      final w = math.min(street.width, across);
      if (w < minStripWidth) {
        runs.add((points: [], widths: [], side: 0));
        continue;
      }
      // The left normal of travel points to bearing − 90°.
      final side = math.cos((sun.azimuth - (bearing - 90)) * math.pi / 180) > 0
          ? 1
          : -1;
      final last = runs.isEmpty ? null : runs.last;
      if (last != null && last.side == side) {
        last.points.addAll(piece.skip(1));
        last.widths.add(w);
      } else {
        runs.add((points: [...piece], widths: [w], side: side));
      }
    }
    for (final run in runs) {
      if (run.side == 0 || run.points.length < 2) continue;
      final w = run.widths.reduce((a, b) => a + b) / run.widths.length;
      final outer = _offset(run.points, run.side * street.width / 2);
      final inner = _offset(run.points, run.side * (street.width / 2 - w));
      yield GeoFeature(
        geometry: GeoPolygons([
          GeoPolygon([...outer, ...inner.reversed, outer.first]),
        ]),
        properties: const {'shade': buildingShade, 'source': 'buildings'},
      );
    }
  }

  /// Consecutive pieces of about [pieceLength] metres (shared end points).
  static List<List<LatLng>> _pieces(List<LatLng> line) {
    final pieces = <List<LatLng>>[];
    var current = [line.first];
    var length = 0.0;
    for (var i = 1; i < line.length; i++) {
      current.add(line[i]);
      length += distanceMeters(line[i - 1], line[i]);
      if (length >= pieceLength) {
        pieces.add(current);
        current = [line[i]];
        length = 0;
      }
    }
    if (current.length > 1) {
      if (pieces.isNotEmpty && length < pieceLength / 2) {
        pieces.last.addAll(current.skip(1));
      } else {
        pieces.add(current);
      }
    }
    return pieces;
  }

  /// [line] shifted sideways by [d] metres (positive = left of travel).
  static List<LatLng> _offset(List<LatLng> line, double d) {
    const mPerDegLat = 111195.0;
    final mPerDegLon = mPerDegLat * math.cos(_centre.latitude * math.pi / 180);
    return [
      for (var i = 0; i < line.length; i++)
        () {
          final a = line[math.max(i - 1, 0)];
          final b = line[math.min(i + 1, line.length - 1)];
          final dx = (b.longitude - a.longitude) * mPerDegLon;
          final dy = (b.latitude - a.latitude) * mPerDegLat;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len == 0) return line[i];
          return LatLng(
            line[i].latitude + dx / len * d / mPerDegLat,
            line[i].longitude - dy / len * d / mPerDegLon,
          );
        }(),
    ];
  }
}
