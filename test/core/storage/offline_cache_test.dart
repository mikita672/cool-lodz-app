import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/storage/offline_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fixtures.dart';

void main() {
  late SharedPreferences prefs;
  late OfflineCache cache;
  final now = DateTime(2026, 7, 15, 14, 31);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = OfflineCache(prefs, clock: () => now);
  });

  test('empty cache reads as null', () {
    expect(cache.lastRoute(), isNull);
    expect(cache.coolPlaces(), isNull);
  });

  test('last route survives a restart', () async {
    final response = RouteResponse.fromJson(
      (fixtureJson('routes_manufaktura_piotrkowska.json')['departures']
              as Map<String, dynamic>)['14:30']
          as Map<String, dynamic>,
    );
    final request = RouteRequest(
      from: const RoutePoint(lat: 51.7794, lon: 19.4466, label: 'Manufaktura'),
      to: const RoutePoint(lat: 51.7720, lon: 19.4570),
      datetime: DateTime(2026, 7, 15, 14, 30),
      profile: const RouteProfile(
        id: ProfileId.tourist,
        weights: ProfileWeights(shade: 60, time: 60, quiet: 40, air: 40),
      ),
    );
    await cache.saveLastRoute(request, response);

    final reopened = OfflineCache(await SharedPreferences.getInstance());
    final cached = reopened.lastRoute()!;
    expect(cached.request.toJson(), request.toJson());
    expect(cached.response.toJson(), response.toJson());
    expect(cached.savedAt.isAtSameMomentAs(now), isTrue);
  });

  test('cool places: only cool ones, merged by id', () async {
    final places = PlacesResponse.fromJson(
      fixtureJson('places_cool.json'),
    ).places;
    await cache.saveCoolPlaces([
      places[0],
      const Place(id: 'w', type: PlaceType.water, lat: 1, lon: 1),
    ]);
    await cache.saveCoolPlaces(places);
    final cached = cache.coolPlaces()!;
    expect(cached.map((p) => p.id), ['cool-001', 'cool-002', 'cool-017']);
    expect(cached[0].hours!.toJson(), places[0].hours!.toJson());
    expect(cached[2].hours, isNull);
  });

  test('broken data reads as null', () async {
    await prefs.setString(OfflineCache.lastRouteKey, '{"nope": 1}');
    await prefs.setString(OfflineCache.coolPlacesKey, 'not json');
    expect(cache.lastRoute(), isNull);
    expect(cache.coolPlaces(), isNull);
  });
}
