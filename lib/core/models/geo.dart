import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'geo.g.dart';

/// A point with an optional label, used for route endpoints.
@JsonSerializable()
class RoutePoint {
  const RoutePoint({required this.lat, required this.lon, this.label});

  factory RoutePoint.fromLatLng(LatLng point, {String? label}) =>
      RoutePoint(lat: point.latitude, lon: point.longitude, label: label);

  factory RoutePoint.fromJson(Map<String, dynamic> json) =>
      _$RoutePointFromJson(json);

  final double lat;
  final double lon;
  final String? label;

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => _$RoutePointToJson(this);
}

/// Bounding box for `bbox=minLon,minLat,maxLon,maxLat` query parameters.
class GeoBounds {
  const GeoBounds({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;

  /// Value of the `bbox` query parameter.
  String toQuery() => '$minLon,$minLat,$maxLon,$maxLat';

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.minLon == minLon &&
      other.minLat == minLat &&
      other.maxLon == maxLon &&
      other.maxLat == maxLat;

  @override
  int get hashCode => Object.hash(minLon, minLat, maxLon, maxLat);
}

const _distance = Distance();

/// Great-circle distance in metres.
double distanceMeters(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

/// GeoJSON position `[lon, lat]` ↔ [LatLng].
LatLng latLngFromPosition(List<dynamic> position) =>
    LatLng((position[1] as num).toDouble(), (position[0] as num).toDouble());

List<double> positionFromLatLng(LatLng point) => [
  point.longitude,
  point.latitude,
];

/// GeoJSON `LineString` ↔ ordered list of points.
class LineStringConverter
    implements JsonConverter<List<LatLng>, Map<String, dynamic>> {
  const LineStringConverter();

  @override
  List<LatLng> fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'LineString') {
      throw FormatException('Expected LineString, got ${json['type']}');
    }
    return [
      for (final position in json['coordinates'] as List<dynamic>)
        latLngFromPosition(position as List<dynamic>),
    ];
  }

  @override
  Map<String, dynamic> toJson(List<LatLng> points) => {
    'type': 'LineString',
    'coordinates': [for (final p in points) positionFromLatLng(p)],
  };
}
