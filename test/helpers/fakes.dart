import 'dart:io';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/route/data/address_search.dart';
import 'package:latlong2/latlong.dart';

/// Reads `assets/demo/…` from disk synchronously. `rootBundle` decodes big
/// files in an isolate that widget tests do not wait for.
Future<String> readAssetFile(String path) async =>
    File(path).readAsStringSync();

/// Location with a fixed answer; [problem] makes it unavailable.
class FakeLocationService implements LocationService {
  FakeLocationService({this.position = const LatLng(51.7700, 19.4570)});

  LatLng position;
  LocationProblem? problem;
  var enableCalls = 0;
  var currentCalls = 0;

  @override
  Future<LocationProblem?> check() async => problem;

  @override
  Future<LatLng> current() async {
    currentCalls++;
    final p = problem;
    if (p != null) throw LocationUnavailable(p);
    return position;
  }

  @override
  Future<void> enable() async {
    enableCalls++;
    problem = null;
  }
}

/// The demo client (real `assets/demo/` files) that records route requests.
/// [routeError] makes `getRoutes` throw.
class RecordingApiClient implements ApiClient {
  RecordingApiClient({DemoApiClient? demo})
    : _demo = demo ?? DemoApiClient(loadAsset: readAssetFile);

  final DemoApiClient _demo;
  final routeRequests = <RouteRequest>[];
  final placeRequests = <Set<PlaceType>>[];
  Object? routeError;

  @override
  Future<RouteResponse> getRoutes(RouteRequest request) async {
    routeRequests.add(request);
    final e = routeError;
    if (e != null) throw e;
    return _demo.getRoutes(request);
  }

  @override
  Future<List<Place>> getPlaces({
    required Set<PlaceType> types,
    GeoBounds? bbox,
  }) {
    placeRequests.add(types);
    return _demo.getPlaces(types: types, bbox: bbox);
  }

  @override
  Future<List<Alert>> getAlerts({required double lat, required double lon}) =>
      _demo.getAlerts(lat: lat, lon: lon);

  @override
  Future<List<AirStation>> getAir({GeoBounds? bbox}) =>
      _demo.getAir(bbox: bbox);

  @override
  Future<GeoLayer> getLayer(
    LayerKind kind, {
    GeoBounds? bbox,
    required DateTime datetime,
  }) => _demo.getLayer(kind, bbox: bbox, datetime: datetime);

  @override
  Future<List<QuestPlace>> getQuestPlaces() => _demo.getQuestPlaces();
}

class FakeAddressSearch implements AddressSearch {
  final queries = <String>[];
  List<RoutePoint> results = const [];
  Object? error;

  @override
  Future<List<RoutePoint>> search(String query) async {
    queries.add(query);
    final e = error;
    if (e != null) throw e;
    return results;
  }
}
