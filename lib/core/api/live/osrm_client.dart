import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../api_client.dart';
import 'live_http.dart';

/// One route from the OSRM `route` service.
class OsrmRoute {
  const OsrmRoute({
    required this.points,
    required this.distanceM,
    required this.durationS,
  });

  final List<LatLng> points;
  final double distanceM;
  final double durationS;
}

/// Walking routes from the public FOSSGIS OSRM foot router (OSM data).
class OsrmClient {
  OsrmClient(this._dio, {this.baseUrl = defaultBaseUrl});

  factory OsrmClient.create() => OsrmClient(createLiveDio());

  static const defaultBaseUrl =
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  final Dio _dio;
  final String baseUrl;

  static String url(
    String baseUrl,
    List<LatLng> points, {
    int alternatives = 0,
  }) {
    final coords = [
      for (final p in points)
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
    ].join(';');
    return '$baseUrl/$coords?overview=full&geometries=geojson'
        '&steps=false&alternatives=${alternatives > 0 ? alternatives : 'false'}';
  }

  /// Routes through [points] in order (start, optional via points, end),
  /// best first. Throws [ApiException]; `notFound` (`route_not_found`) when
  /// OSRM finds no walkable connection.
  Future<List<OsrmRoute>> route(
    List<LatLng> points, {
    int alternatives = 0,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        url(baseUrl, points, alternatives: alternatives),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && _noRoute(data['code'])) throw _routeNotFound;
      throw mapDioError(e);
    }
    return parseOsrmRoutes(response.data);
  }
}

const _routeNotFound = ApiException(ApiErrorKind.notFound, 'route_not_found');

/// OSRM codes for "these points cannot be connected on foot".
bool _noRoute(Object? code) => code == 'NoRoute' || code == 'NoSegment';

/// `{"code": "Ok", "routes": [{"geometry": {"type": "LineString", …},
/// "distance": 1873.7, "duration": 1459.3, …}], "waypoints": […]}`.
List<OsrmRoute> parseOsrmRoutes(Object? json) {
  if (json is! Map) {
    throw ApiException(ApiErrorKind.server, 'bad OSRM response: $json');
  }
  final code = json['code'];
  if (_noRoute(code)) throw _routeNotFound;
  if (code != 'Ok') {
    throw ApiException(ApiErrorKind.server, 'OSRM: $code ${json['message']}');
  }
  final routes = <OsrmRoute>[];
  for (final route in json['routes'] as List? ?? const []) {
    if (route is! Map) continue;
    final geometry = route['geometry'];
    final distance = route['distance'];
    final duration = route['duration'];
    if (geometry is! Map || distance is! num || duration is! num) continue;
    try {
      final points = const LineStringConverter().fromJson(
        geometry.cast<String, dynamic>(),
      );
      if (points.length < 2) continue;
      routes.add(
        OsrmRoute(
          points: points,
          distanceM: distance.toDouble(),
          durationS: duration.toDouble(),
        ),
      );
    } on Object {
      continue;
    }
  }
  if (routes.isEmpty) throw _routeNotFound;
  return routes;
}
