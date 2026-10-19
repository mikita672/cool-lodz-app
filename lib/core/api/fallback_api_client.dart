import 'dart:async';

import '../models/models.dart';
import '../storage/offline_cache.dart';
import 'api_client.dart';
import 'reference_routes.dart';

/// Tries [remote]; if it does not answer within [timeout] or fails with a
/// network/server error, answers from the offline cache or [demo] and
/// reports `true` through [onFallback] (the banner «Brak połączenia z
/// serwerem, pokazujemy ostatnie dane»). It reports `false` again once every
/// kind of call (routes, places, alerts, air, layers) that fell back answers
/// again; a successful call also refreshes the cache. `notFound` (e.g. `route_not_found`) is a
/// real answer and is rethrown.
class FallbackApiClient implements ApiClient {
  FallbackApiClient({
    required this.remote,
    required this.demo,
    this.cache,
    required this.onFallback,
    this.timeout = apiTimeout,
  });

  final ApiClient remote;
  final ApiClient demo;
  final OfflineCache? cache;
  final void Function(bool usingFallback) onFallback;
  final Duration timeout;

  /// The cached route is reused when its departure differs by at most this.
  static const cachedRouteMaxTimeDiff = Duration(minutes: 30);

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) => _guard(
    'routes',
    () => remote.getRoutes(request),
    onSuccess: (response) => cache?.saveLastRoute(request, response),
    fallback: () {
      final cached = cache?.lastRoute();
      if (cached != null && _sameRoute(cached.request, request)) {
        return Future.value(cached.response);
      }
      return demo.getRoutes(request);
    },
  );

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) => _guard(
    'places',
    () => remote.getPlaces(types: types, bbox: bbox),
    onSuccess: (places) => cache?.saveCoolPlaces(places),
    fallback: () async {
      final cached = types.contains(PlaceType.cool)
          ? cache?.coolPlaces()
          : null;
      if (cached == null || cached.isEmpty) {
        return demo.getPlaces(types: types, bbox: bbox);
      }
      final rest = types.difference({PlaceType.cool});
      return [
        for (final p in cached)
          if (bbox == null || bbox.contains(p.lat, p.lon)) p,
        if (rest.isNotEmpty) ...await demo.getPlaces(types: rest, bbox: bbox),
      ];
    },
  );

  @override
  Future<List<Alert>> getAlerts({required double lat, required double lon}) =>
      _guard(
        'alerts',
        () => remote.getAlerts(lat: lat, lon: lon),
        // No made-up warning when the server is down: «no alert» is the
        // safe answer (the demo ones exist only in demo mode).
        fallback: () async => const <Alert>[],
      );

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) => _guard(
    'air',
    () => remote.getAir(bbox: bbox),
    fallback: () => demo.getAir(bbox: bbox),
  );

  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) => _guard(
    'layers',
    () => remote.getLayer(kind, bbox: bbox, datetime: datetime),
    fallback: () => demo.getLayer(kind, bbox: bbox, datetime: datetime),
  );

  /// Always the bundled seed: module D has no quest endpoint.
  @override
  Future<List<QuestPlace>> getQuestPlaces() => demo.getQuestPlaces();

  /// Calls whose last attempt fell back. The banner stays while any does:
  /// one source failing (e.g. GIOŚ) must not be hidden by another one
  /// answering (e.g. bundled places).
  final _failing = <String>{};

  void _report(String source, {required bool failed}) {
    failed ? _failing.add(source) : _failing.remove(source);
    onFallback(_failing.isNotEmpty);
  }

  Future<T> _guard<T>(
    String source,
    Future<T> Function() call, {
    required Future<T> Function() fallback,
    FutureOr<void> Function(T value)? onSuccess,
  }) async {
    final T value;
    try {
      value = await call().timeout(timeout);
    } on TimeoutException {
      return _fallBack(source, fallback);
    } on ApiException catch (e) {
      if (!e.isOffline) rethrow;
      return _fallBack(source, fallback);
    }
    _report(source, failed: false);
    try {
      await onSuccess?.call(value);
    } catch (_) {
      // A full or broken cache must not break a good answer.
    }
    return value;
  }

  Future<T> _fallBack<T>(String source, Future<T> Function() fallback) async {
    final value = await fallback();
    _report(source, failed: true);
    return value;
  }

  static bool _sameRoute(RouteRequest a, RouteRequest b) =>
      a.profile.id == b.profile.id &&
      distanceMeters(a.from.latLng, b.from.latLng) <= matchRadiusMeters &&
      distanceMeters(a.to.latLng, b.to.latLng) <= matchRadiusMeters &&
      (minuteOfDay(a.datetime) - minuteOfDay(b.datetime)).abs() <=
          cachedRouteMaxTimeDiff.inMinutes;
}
