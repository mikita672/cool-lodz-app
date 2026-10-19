import '../models/models.dart';

/// Access to the module D API (routes, places, alerts, air, map layers).
///
/// Implementations: `RemoteApiClient` (HTTP), `DemoApiClient`
/// (`assets/demo/`), and `FallbackApiClient` (remote, then demo after 8 s).
/// All methods throw [ApiException].
abstract interface class ApiClient {
  /// `POST /v1/routes`: three variants.
  Future<RouteResponse> getRoutes(RouteRequest request);

  /// `GET /v1/places?type=…&bbox=…`.
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  });

  /// `GET /v1/alerts?lat&lon`; empty = no alert.
  Future<List<Alert>> getAlerts({required double lat, required double lon});

  /// `GET /v1/air?bbox`.
  Future<List<AirStation>> getAir({GeoBounds? bbox});

  /// `GET /v1/layers/{kind}?bbox&datetime`.
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  });

  /// Quest places in order. Module D has no endpoint for them: they come from
  /// the bundled `quest.json` (the seed for Firestore `questPlaces`).
  Future<List<QuestPlace>> getQuestPlaces();
}

enum ApiErrorKind {
  /// No answer within the timeout.
  timeout,

  /// No connection, DNS, TLS and similar.
  network,

  /// 404, e.g. `route_not_found`, or a missing demo file.
  notFound,

  /// A 4xx other than 404, 408 and 429: the request itself is wrong (e.g.
  /// `invalid_point`). Demo data would only hide it.
  badRequest,

  /// 5xx, 408, 429 or a response that does not match the contract.
  server,
}

class ApiException implements Exception {
  const ApiException(this.kind, [this.message, this.statusCode]);

  final ApiErrorKind kind;
  final String? message;
  final int? statusCode;

  /// Errors after which the app switches to demo data.
  bool get isOffline =>
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.server;

  @override
  String toString() =>
      'ApiException(${kind.name}${statusCode == null ? '' : ' $statusCode'}'
      '${message == null ? '' : ': $message'})';
}

/// Remote timeout from the spec (non-functional requirements: "Performance").
const apiTimeout = Duration(seconds: 8);
