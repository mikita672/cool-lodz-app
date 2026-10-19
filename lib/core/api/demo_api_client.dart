import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';
import '../warsaw_time.dart';
import 'api_client.dart';
import 'reference_routes.dart';
import 'synthetic_routes.dart';

/// Reads an asset as text; `rootBundle.loadString` in the app.
typedef AssetLoader = Future<String> Function(String path);

/// Which `alerts_*.json` the demo serves.
enum DemoAlertScenario { none, level2, level3 }

/// Module D answers from `assets/demo/` (same contract as the server).
class DemoApiClient implements ApiClient {
  DemoApiClient({
    AssetLoader? loadAsset,
    this.alertScenario = DemoAlertScenario.level2,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  static const dir = 'assets/demo';

  final AssetLoader _loadAsset;
  final DemoAlertScenario alertScenario;
  final _cache = <String, Future<Object?>>{};

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) async {
    final reference = ReferenceRoutes.match(request);
    if (reference == null) return SyntheticRoutes.generate(request);
    final file = await _json(reference.asset) as Map<String, dynamic>;
    final departures = file['departures'] as Map<String, dynamic>;
    final key = nearestTimeKey(
      departures.keys,
      warsawMinuteOfDay(request.datetime),
    );
    if (key == null) {
      throw ApiException(ApiErrorKind.server, '${reference.asset} is empty');
    }
    return _parse(
      () => RouteResponse.fromJson(departures[key] as Map<String, dynamic>),
    );
  }

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) async {
    final places = <Place>[];
    for (final type in PlaceType.values.where(types.contains)) {
      final json = await _json('$dir/places_${type.name}.json');
      places.addAll(
        _parse(
          () => PlacesResponse.fromJson(json as Map<String, dynamic>),
        ).places,
      );
    }
    return [
      for (final p in places)
        if (bbox == null || bbox.contains(p.lat, p.lon)) p,
    ];
  }

  /// [lat]/[lon] are ignored: the demo covers Łódź only.
  @override
  Future<List<Alert>> getAlerts({
    required double lat,
    required double lon,
  }) async {
    final json = await _json('$dir/alerts_${alertScenario.name}.json');
    return _parse(
      () => AlertsResponse.fromJson(json as Map<String, dynamic>),
    ).alerts;
  }

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) async {
    final json = await _json('$dir/air.json');
    final stations = _parse(
      () => AirResponse.fromJson(json as Map<String, dynamic>),
    ).stations;
    return [
      for (final s in stations)
        if (bbox == null || bbox.contains(s.lat, s.lon)) s,
    ];
  }

  /// The demo has one shade layer (14:30), returned for any [datetime].
  /// [bbox] is ignored: the files cover Śródmieście only.
  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) async {
    final name = kind == LayerKind.shade ? 'shade_1430' : kind.name;
    final json = await _json('$dir/layer_$name.geojson');
    return _parse(() => GeoLayer.fromJson(json as Map<String, dynamic>));
  }

  @override
  Future<List<QuestPlace>> getQuestPlaces() async {
    final json = await _json('$dir/quest.json');
    return _parse(() => QuestData.fromJson(json!)).ordered;
  }

  /// Any other bundled file of [dir], decoded (e.g. `streets_core.geojson`).
  Future<Object?> readJson(String file) => _json('$dir/$file');

  /// Decoded file, read once; a failed read is retried next time.
  Future<Object?> _json(String path) {
    final cached = _cache[path];
    if (cached != null) return cached;
    final future = _read(path);
    _cache[path] = future;
    future
        .then<void>(
          (_) {},
          onError: (Object _) {
            _cache.remove(path);
          },
        )
        .ignore();
    return future;
  }

  Future<Object?> _read(String path) async {
    final String text;
    try {
      text = await _loadAsset(path);
    } catch (_) {
      throw ApiException(ApiErrorKind.notFound, 'missing $path');
    }
    try {
      return jsonDecode(text);
    } on FormatException catch (e) {
      throw ApiException(ApiErrorKind.server, '$path: ${e.message}');
    }
  }

  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } catch (e) {
      throw ApiException(ApiErrorKind.server, 'bad demo data: $e');
    }
  }
}
