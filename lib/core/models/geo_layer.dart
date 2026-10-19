import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

import 'geo.dart';

part 'geo_layer.g.dart';

/// `/v1/layers/{kind}`.
enum LayerKind { shade, green, noise }

/// GeoJSON `FeatureCollection` of polygons.
@JsonSerializable()
class GeoLayer {
  const GeoLayer({this.type = 'FeatureCollection', required this.features});

  factory GeoLayer.fromJson(Map<String, dynamic> json) =>
      _$GeoLayerFromJson(json);

  final String type;
  final List<GeoFeature> features;

  Map<String, dynamic> toJson() => _$GeoLayerToJson(this);
}

@JsonSerializable()
class GeoFeature {
  const GeoFeature({
    this.type = 'Feature',
    this.id,
    required this.geometry,
    this.properties = const {},
  });

  factory GeoFeature.fromJson(Map<String, dynamic> json) =>
      _$GeoFeatureFromJson(json);

  final String type;
  final Object? id;
  final GeoPolygons geometry;

  final Map<String, dynamic> properties;

  /// `shade` layer: share of shade 0..1.
  double? get shade => (properties['shade'] as num?)?.toDouble();

  /// `green` layer: e.g. `park`.
  String? get kind => properties['kind'] as String?;

  /// `noise` layer: level in dB.
  double? get db => (properties['db'] as num?)?.toDouble();

  Map<String, dynamic> toJson() => _$GeoFeatureToJson(this);
}

/// One polygon: outer ring plus holes (GeoJSON rings, closed).
class GeoPolygon {
  const GeoPolygon(this.outer, [this.holes = const []]);

  final List<LatLng> outer;
  final List<List<LatLng>> holes;

  List<List<LatLng>> get rings => [outer, ...holes];
}

/// GeoJSON `Polygon` or `MultiPolygon` geometry.
class GeoPolygons {
  const GeoPolygons(this.polygons, {this.multi = false});

  factory GeoPolygons.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as List<dynamic>;
    switch (json['type']) {
      case 'Polygon':
        return GeoPolygons([_polygon(coordinates)]);
      case 'MultiPolygon':
        return GeoPolygons([
          for (final p in coordinates) _polygon(p as List<dynamic>),
        ], multi: true);
      default:
        throw FormatException('Unsupported geometry ${json['type']}');
    }
  }

  final List<GeoPolygon> polygons;

  /// Keeps the original GeoJSON type for round-trips.
  final bool multi;

  Map<String, dynamic> toJson() => multi
      ? {
          'type': 'MultiPolygon',
          'coordinates': [for (final p in polygons) _rings(p)],
        }
      : {'type': 'Polygon', 'coordinates': _rings(polygons.single)};

  static GeoPolygon _polygon(List<dynamic> rings) {
    final parsed = [
      for (final ring in rings)
        [
          for (final position in ring as List<dynamic>)
            latLngFromPosition(position as List<dynamic>),
        ],
    ];
    return GeoPolygon(parsed.first, parsed.sublist(1));
  }

  static List<List<List<double>>> _rings(GeoPolygon polygon) => [
    for (final ring in polygon.rings)
      [for (final p in ring) positionFromLatLng(p)],
  ];
}
