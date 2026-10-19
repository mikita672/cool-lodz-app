import 'dart:convert';

import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fixtures.dart';

/// JSON → model → JSON → model → JSON must be stable.
void expectRoundTrip<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) fromJson,
  Map<String, dynamic> Function(T) toJson,
) {
  final once = jsonDecode(jsonEncode(toJson(fromJson(json))));
  final twice = jsonDecode(
    jsonEncode(toJson(fromJson(once as Map<String, dynamic>))),
  );
  expect(twice, equals(once));
}

RouteResponse departure(String file, String time) => RouteResponse.fromJson(
  (fixtureJson(file)['departures'] as Map<String, dynamic>)[time]
      as Map<String, dynamic>,
);

void main() {
  group('round-trips on fixtures', () {
    test('routes (all departures of both reference files)', () {
      for (final file in [
        'routes_manufaktura_piotrkowska.json',
        'routes_plac_wolnosci_piotrkowska.json',
      ]) {
        final departures =
            fixtureJson(file)['departures'] as Map<String, dynamic>;
        for (final response in departures.values) {
          expectRoundTrip(
            response as Map<String, dynamic>,
            RouteResponse.fromJson,
            (r) => r.toJson(),
          );
        }
      }
    });

    test('places, alerts, air, layers, quest', () {
      for (final f in ['places_cool', 'places_water', 'places_bench']) {
        expectRoundTrip(
          fixtureJson('$f.json'),
          PlacesResponse.fromJson,
          (r) => r.toJson(),
        );
      }
      for (final f in ['alerts_none', 'alerts_level2', 'alerts_level3']) {
        expectRoundTrip(
          fixtureJson('$f.json'),
          AlertsResponse.fromJson,
          (r) => r.toJson(),
        );
      }
      expectRoundTrip(
        fixtureJson('air.json'),
        AirResponse.fromJson,
        (r) => r.toJson(),
      );
      for (final f in ['layer_shade_1430', 'layer_green', 'layer_noise']) {
        expectRoundTrip(
          fixtureJson('$f.geojson'),
          GeoLayer.fromJson,
          (r) => r.toJson(),
        );
      }
      expectRoundTrip(
        fixtureJson('quest.json'),
        QuestData.fromJson,
        (r) => r.toJson(),
      );
    });

    test('layer geometry keeps Polygon vs MultiPolygon and holes', () {
      final layer = GeoLayer.fromJson(fixtureJson('layer_shade_1430.geojson'));
      final json = layer.toJson();
      final features = json['features'] as List;
      expect((features[0] as Map)['geometry']['type'], 'Polygon');
      expect((features[1] as Map)['geometry']['type'], 'MultiPolygon');
      expect(layer.features[1].geometry.polygons, hasLength(2));
      expect(layer.features[1].geometry.polygons[1].holes, hasLength(1));
      expect(layer.features[0].shade, 0.8);
      final green = GeoLayer.fromJson(fixtureJson('layer_green.geojson'));
      expect(green.features.single.kind, 'park');
      expect(green.features.single.id, 'park-zrodliska');
      final noise = GeoLayer.fromJson(fixtureJson('layer_noise.geojson'));
      expect(noise.features.single.db, 65);
    });
  });

  group('RouteVariant', () {
    final response = departure('routes_manufaktura_piotrkowska.json', '14:30');

    test('geometry is [lon, lat] → LatLng', () {
      final shaded = response.variant(RouteVariantType.shaded)!;
      expect(shaded.geometry.first, const LatLng(51.7794, 19.4466));
      expect(shaded.geometry.last, const LatLng(51.7676, 19.4568));
      final json = shaded.toJson()['geometry'] as Map<String, dynamic>;
      expect(json['type'], 'LineString');
      expect((json['coordinates'] as List).first, [19.4466, 51.7794]);
    });

    test('fields, helpers and snake_case keys', () {
      final shaded = response.variant(RouteVariantType.shaded)!;
      expect(response.coverage, RouteCoverage.full);
      expect(response.shortest!.extraTimeVsShortestS, 0);
      expect(shaded.distanceM, 1720);
      expect(shaded.duration, const Duration(seconds: 1360));
      expect(shaded.extraTimeVsShortest, const Duration(minutes: 4));
      expect(shaded.sunShare, 0.28);
      expect(shaded.shadeShare, closeTo(0.72, 1e-9));
      expect(shaded.segments.first.shadeShare, closeTo(0.62, 1e-9));
      expect(shaded.stops.map((s) => s.type), [StopType.cool, StopType.water]);
      final json = shaded.toJson();
      expect(json.keys, containsAll(['distance_m', 'duration_s']));
      expect(json.keys, contains('extraTimeVsShortest_s'));
    });

    test('sunShareByHour is ordered by time and queryable', () {
      final shaded = response.variant(RouteVariantType.shaded)!;
      final keys = shaded.sunShareByHour.keys.toList();
      expect(keys.first, '08:00');
      expect(keys.last, '20:00');
      expect(keys, hasLength(25));
      expect(keys, orderedEquals([...keys]..sort()));
      expect(
        shaded.sunShareAt(DateTime(2026, 7, 15, 14, 40)),
        shaded.sunShareByHour['14:30'],
      );
      expect(shaded.bestDepartureSlot, isNotNull);

      final unsorted = RouteVariant(
        variant: RouteVariantType.shortest,
        geometry: const [],
        distanceM: 1,
        durationS: 1,
        sunShare: 0.5,
        extraTimeVsShortestS: 0,
        sunShareByHour: const {'18:00': 0.2, '08:00': 0.1, '12:30': 0.9},
      );
      expect(unsorted.sunShareByHour.keys, ['08:00', '12:30', '18:00']);
      expect(unsorted.bestDepartureSlot, '08:00');
    });

    test('segments, stops and sunShareByHour are optional', () {
      final r = departure('routes_plac_wolnosci_piotrkowska.json', '14:30');
      final v = r.variants.first;
      expect(r.isApproximate, isTrue);
      expect(v.segments, isEmpty);
      expect(v.stops, isEmpty);
      expect(v.sunShareByHour, isEmpty);
      expect(v.sunShareAt(DateTime(2026, 7, 15, 9)), v.sunShare);
      expect(v.bestDepartureSlot, isNull);
    });
  });

  group('Place', () {
    final places = PlacesResponse.fromJson(
      fixtureJson('places_cool.json'),
    ).places;

    test('cool place fields', () {
      final ec1 = places.first;
      expect(ec1.type, PlaceType.cool);
      expect(ec1.category, PlaceCategory.culture);
      expect(ec1.latLng, const LatLng(51.7684, 19.4694));
      expect(ec1.amenities, [
        Amenity.airConditioning,
        Amenity.water,
        Amenity.toilet,
        Amenity.wheelchair,
      ]);
      expect(ec1.accessible, isTrue);
      expect(ec1.questPlace, isTrue);
      expect(ec1.source, 'https://ec1lodz.pl/');
      expect(ec1.hours!.on(DateTime.monday), isEmpty);
    });

    test('unknown amenities are skipped', () {
      expect(places[1].amenities, [
        Amenity.airConditioning,
        Amenity.toilet,
        Amenity.wheelchair,
      ]);
    });

    test('null hours = always open', () {
      final park = places[2];
      expect(park.isAlwaysOpen, isTrue);
      expect(park.isOpenAt(DateTime(2026, 7, 13, 3)), isTrue);
      expect(park.nextOpening(DateTime(2026, 7, 13, 3)), isNull);
    });

    test('water points need only id, type, lat, lon', () {
      final water = PlacesResponse.fromJson(
        fixtureJson('places_water.json'),
      ).places.first;
      expect(water.type, PlaceType.water);
      expect(water.name, isNull);
      expect(water.amenities, isEmpty);
      expect(water.questPlace, isFalse);
      expect(water.toJson(), {
        'id': 'water-003',
        'type': 'water',
        'lat': 51.7731,
        'lon': 19.4558,
        'amenities': <String>[],
        'questPlace': false,
      });
    });
  });

  group('RouteRequest', () {
    test('serialises as in the contract, datetime with offset', () {
      final departure = DateTime(2026, 7, 15, 14, 30);
      final request = RouteRequest(
        from: const RoutePoint(
          lat: 51.7794,
          lon: 19.4466,
          label: 'Manufaktura',
        ),
        to: const RoutePoint(lat: 51.7676, lon: 19.4568),
        datetime: departure,
        profile: const RouteProfile(
          id: ProfileId.senior,
          weights: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 50),
        ),
      );
      final json = jsonDecode(jsonEncode(request.toJson()));
      expect(json['from'], {
        'lat': 51.7794,
        'lon': 19.4466,
        'label': 'Manufaktura',
      });
      expect(json['to'], {'lat': 51.7676, 'lon': 19.4568});
      expect(json['profile'], {
        'id': 'senior',
        'weights': {'shade': 90, 'time': 20, 'quiet': 60, 'air': 50},
      });
      expect(json['filters'], <String, dynamic>{});
      expect(
        json['datetime'] as String,
        matches(RegExp(r'^2026-07-15T14:30:00[+-]\d\d:\d\d$')),
      );
      final back = RouteRequest.fromJson(json as Map<String, dynamic>);
      expect(back.datetime.isAtSameMomentAs(departure), isTrue);
      expect(back.datetime.hour, 14);
    });

    test('profile "default" maps to ProfileId.standard', () {
      final profile = RouteProfile.fromJson({
        'id': 'default',
        'weights': {'shade': 50, 'time': 50, 'quiet': 50, 'air': 50},
      });
      expect(profile.id, ProfileId.standard);
      expect(profile.toJson()['id'], 'default');
    });

    test('offset parsing keeps the instant', () {
      final parsed = const OffsetDateTimeConverter().fromJson(
        '2026-07-15T14:30:00+02:00',
      );
      expect(parsed.toUtc(), DateTime.utc(2026, 7, 15, 12, 30));
      expect(
        formatOffsetDateTime(DateTime.utc(2026, 7, 15, 12, 30)),
        '2026-07-15T12:30:00Z',
      );
    });
  });

  group('Alert, AirStation, QuestPlace', () {
    test('alert fields and isActiveAt', () {
      final alert = AlertsResponse.fromJson(
        fixtureJson('alerts_level2.json'),
      ).alerts.single;
      expect(alert.level, 2);
      expect(alert.recommendations, hasLength(3));
      expect(alert.validFrom.toUtc(), DateTime.utc(2026, 7, 15, 8));
      expect(alert.isActiveAt(DateTime.utc(2026, 7, 15, 12)), isTrue);
      expect(alert.isActiveAt(DateTime.utc(2026, 7, 15, 18)), isFalse);
      expect(
        AlertsResponse.fromJson(fixtureJson('alerts_none.json')).alerts,
        isEmpty,
      );
    });

    test('air index 0..5, null = no data', () {
      final stations = AirResponse.fromJson(fixtureJson('air.json')).stations;
      expect(stations.first.indexLevel, 1);
      expect(stations.first.updatedAt!.toUtc(), DateTime.utc(2026, 7, 15, 12));
      expect(stations.last.indexLevel, isNull);
      expect(stations.last.updatedAt, isNull);
    });

    test('quest places are ordered; bare list accepted', () {
      final quest = QuestData.fromJson(fixtureJson('quest.json'));
      expect(quest.title, 'Chłodne hasło');
      expect(quest.ordered.map((p) => p.letter), ['C', 'H']);
      final bare = QuestData.fromJson([
        {'placeId': 'cool-001', 'letter': 'C', 'order': 1},
      ]);
      expect(bare.places.single.placeId, 'cool-001');
      expect(bare.places.single.lat, isNull);
    });
  });

  test('GeoBounds query and contains', () {
    const bbox = GeoBounds(
      minLon: 19.40,
      minLat: 51.74,
      maxLon: 19.50,
      maxLat: 51.80,
    );
    expect(bbox.toQuery(), '19.4,51.74,19.5,51.8');
    expect(bbox.contains(51.77, 19.45), isTrue);
    expect(bbox.contains(51.70, 19.45), isFalse);
  });
}
