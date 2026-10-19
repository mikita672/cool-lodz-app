import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Module D over HTTP. Base URL comes from `--dart-define=API_BASE_URL=…`.
class RemoteApiClient implements ApiClient {
  RemoteApiClient(this._dio);

  factory RemoteApiClient.create(String baseUrl) => RemoteApiClient(
    Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: apiTimeout,
        sendTimeout: apiTimeout,
        receiveTimeout: apiTimeout,
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
      ),
    ),
  );

  final Dio _dio;

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) => _call(
    () => _dio.post<Object?>('/v1/routes', data: request.toJson()),
    RouteResponse.fromJson,
  );

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) => _call(
    () => _dio.get<Object?>(
      '/v1/places',
      queryParameters: {
        'type': [
          for (final t in PlaceType.values)
            if (types.contains(t)) t.name,
        ].join(','),
        'bbox': ?bbox?.toQuery(),
      },
    ),
    (json) => PlacesResponse.fromJson(json).places,
  );

  @override
  Future<List<Alert>> getAlerts({required double lat, required double lon}) =>
      _call(
        () => _dio.get<Object?>(
          '/v1/alerts',
          queryParameters: {'lat': lat, 'lon': lon},
        ),
        (json) => AlertsResponse.fromJson(json).alerts,
      );

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) => _call(
    () => _dio.get<Object?>(
      '/v1/air',
      queryParameters: {'bbox': ?bbox?.toQuery()},
    ),
    (json) => AirResponse.fromJson(json).stations,
  );

  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) => _call(
    () => _dio.get<Object?>(
      '/v1/layers/${kind.name}',
      queryParameters: {
        'bbox': ?bbox?.toQuery(),
        'datetime': formatOffsetDateTime(datetime),
      },
    ),
    GeoLayer.fromJson,
  );

  /// Module D has no quest endpoint; `FallbackApiClient` serves the bundled
  /// seed instead.
  @override
  Future<List<QuestPlace>> getQuestPlaces() async =>
      throw const ApiException(ApiErrorKind.notFound, 'no quest endpoint');

  Future<T> _call<T>(
    Future<Response<Object?>> Function() send,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final Response<Object?> response;
    try {
      response = await send();
    } on DioException catch (e) {
      throw _map(e);
    }
    try {
      var data = response.data;
      if (data is String) data = jsonDecode(data);
      return parse(data as Map<String, dynamic>);
    } catch (e) {
      throw ApiException(ApiErrorKind.server, 'bad response: $e');
    }
  }

  static ApiException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(ApiErrorKind.timeout, e.message);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return ApiException(
          switch (status) {
            404 => ApiErrorKind.notFound,
            408 || 429 => ApiErrorKind.server,
            final s? when s >= 400 && s < 500 => ApiErrorKind.badRequest,
            _ => ApiErrorKind.server,
          },
          _errorCode(e.response?.data) ?? e.message,
          status,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ApiException(ApiErrorKind.network, e.message);
    }
  }

  /// `{"error": "route_not_found"}` → `route_not_found`.
  static String? _errorCode(Object? data) {
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
