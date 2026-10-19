import 'dart:convert';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/api/synthetic_routes.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/core/warsaw_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fixtures.dart';

const _profile = RouteProfile(
  id: ProfileId.standard,
  weights: ProfileWeights(shade: 50, time: 50, quiet: 50, air: 50),
);

RouteRequest request(RoutePoint from, RoutePoint to, [DateTime? time]) =>
    RouteRequest(
      from: from,
      to: to,
      datetime: time ?? warsawWallClockToUtc(2026, 7, 15, 14, 30),
      profile: _profile,
    );

/// [p] moved [meters] to the north.
RoutePoint north(RoutePoint p, double meters) {
  final moved = const Distance().offset(p.latLng, meters, 0);
  return RoutePoint(lat: moved.latitude, lon: moved.longitude);
}

String fixtureDeparture(String file, String time) =>
    jsonEncode((fixtureJson(file)['departures'] as Map<String, dynamic>)[time]);

void main() {
  late FixtureAssetLoader loader;
  late DemoApiClient demo;

  setUp(() {
    loader = FixtureAssetLoader();
    demo = DemoApiClient(loadAsset: loader.call);
  });

  group('reference routes', () {
    const manufaktura = ReferenceRoutes.manufakturaPiotrkowska;
    const placWolnosci = ReferenceRoutes.placWolnosciPiotrkowska;

    test('match when both endpoints are within 300 m', () {
      expect(
        ReferenceRoutes.match(
          request(north(manufaktura.from, 250), north(manufaktura.to, -250)),
        ),
        manufaktura,
      );
      expect(
        ReferenceRoutes.match(request(placWolnosci.from, placWolnosci.to)),
        placWolnosci,
      );
      expect(
        ReferenceRoutes.match(
          request(north(manufaktura.from, 350), manufaktura.to),
        ),
        isNull,
      );
      // Reverse direction is not the reference route.
      expect(
        ReferenceRoutes.match(request(manufaktura.to, manufaktura.from)),
        isNull,
      );
    });

    test('contract example request matches Manufaktura → Piotrkowska', () {
      expect(
        ReferenceRoutes.match(
          request(
            const RoutePoint(lat: 51.7801, lon: 19.4475),
            const RoutePoint(lat: 51.7676, lon: 19.4568),
          ),
        ),
        manufaktura,
      );
    });

    test('nearest departure is returned', () async {
      const file = 'routes_manufaktura_piotrkowska.json';
      Future<String> at(int h, int m) async => jsonEncode(
        await demo.getRoutes(
          request(
            manufaktura.from,
            manufaktura.to,
            warsawWallClockToUtc(2026, 7, 15, h, m),
          ),
        ),
      );
      String expected(String key) => jsonEncode(
        RouteResponse.fromJson(
          jsonDecode(fixtureDeparture(file, key)) as Map<String, dynamic>,
        ),
      );
      expect(await at(7, 0), expected('10:00'));
      expect(await at(12, 14), expected('10:00')); // 134 min vs 136 min
      expect(await at(12, 16), expected('14:30'));
      expect(await at(14, 30), expected('14:30'));
      expect(await at(16, 15), expected('14:30')); // tie → earlier
      expect(await at(21, 0), expected('18:00'));
      expect(loader.requested.toSet(), {manufaktura.asset});
      expect(loader.requested, hasLength(1), reason: 'file read once');
    });

    test('second reference route reads its own file', () async {
      final response = await demo.getRoutes(
        request(placWolnosci.from, placWolnosci.to),
      );
      expect(response.variants, hasLength(3));
      expect(loader.requested, [placWolnosci.asset]);
    });
  });

  group('synthetic routes', () {
    const a = RoutePoint(lat: 51.7500, lon: 19.4000, label: 'A');
    const b = RoutePoint(lat: 51.7650, lon: 19.4300, label: 'B');

    test('three variants with consistent numbers', () async {
      final response = await demo.getRoutes(request(a, b));
      expect(loader.requested, isEmpty);
      expect(response.coverage, RouteCoverage.approximate);
      expect(response.variants.map((v) => v.variant), [
        RouteVariantType.shortest,
        RouteVariantType.shaded,
        RouteVariantType.compromise,
      ]);
      final shortest = response.shortest!;
      final straight = distanceMeters(a.latLng, b.latLng);
      expect(shortest.distanceM, closeTo(straight * 1.3, 1));
      expect(
        shortest.durationS,
        closeTo(shortest.distanceM / SyntheticRoutes.walkingSpeed, 1),
      );
      for (final v in response.variants) {
        expect(v.extraTimeVsShortestS, v.durationS - shortest.durationS);
        expect(v.distanceM, greaterThanOrEqualTo(shortest.distanceM));
        expect(v.geometry.first, a.latLng);
        expect(v.geometry.last, b.latLng);
        expect(v.sunShare, inInclusiveRange(0, 1));
        expect(v.sunShareByHour.keys.first, '08:00');
        expect(v.sunShareByHour.keys.last, '20:00');
        expect(v.sunShareByHour, hasLength(25));
        expect(
          v.sunShareAt(warsawWallClockToUtc(2026, 7, 15, 14, 30)),
          v.sunShare,
        );
        expect(v.segments.first.from, 0);
        expect(v.segments.last.to, v.geometry.length - 1);
        final mean =
            v.segments.map((s) => s.sunShare).reduce((x, y) => x + y) /
            v.segments.length;
        expect(mean, closeTo(v.sunShare, 0.011));
      }
      final shaded = response.variant(RouteVariantType.shaded)!;
      final compromise = response.variant(RouteVariantType.compromise)!;
      expect(shaded.extraTimeVsShortestS, greaterThan(0));
      expect(compromise.extraTimeVsShortestS, greaterThan(0));
      expect(
        shaded.extraTimeVsShortestS,
        greaterThan(compromise.extraTimeVsShortestS),
      );
      expect(shaded.sunShare, lessThan(compromise.sunShare));
      expect(compromise.sunShare, lessThan(shortest.sunShare));
    });

    test('deterministic and round-trips through JSON', () async {
      final first = jsonEncode(await demo.getRoutes(request(a, b)));
      final second = jsonEncode(await demo.getRoutes(request(a, b)));
      expect(first, second);
      expect(
        jsonEncode(
          RouteResponse.fromJson(jsonDecode(first) as Map<String, dynamic>),
        ),
        first,
      );
    });

    test('more shade in the evening than at 14:30', () async {
      final noon = await demo.getRoutes(request(a, b));
      final evening = await demo.getRoutes(
        request(a, b, warsawWallClockToUtc(2026, 7, 15, 19)),
      );
      expect(evening.shortest!.sunShare, lessThan(noon.shortest!.sunShare));
    });

    test('same start and end does not break', () async {
      final response = await demo.getRoutes(request(a, a));
      expect(response.variants, hasLength(3));
      expect(response.shortest!.distanceM, 0);
    });
  });

  group('other endpoints', () {
    test('places by type, bbox filter', () async {
      final all = await demo.getPlaces(
        types: {PlaceType.water, PlaceType.cool},
      );
      expect(all.map((p) => p.type).toSet(), {PlaceType.cool, PlaceType.water});
      const bbox = GeoBounds(
        minLon: 19.44,
        minLat: 51.77,
        maxLon: 19.46,
        maxLat: 51.78,
      );
      final inBox = await demo.getPlaces(types: {PlaceType.cool}, bbox: bbox);
      expect(inBox.map((p) => p.id), ['cool-002']);
    });

    test('alert scenario selects the file', () async {
      Future<List<Alert>> alerts(DemoAlertScenario s) => DemoApiClient(
        loadAsset: loader.call,
        alertScenario: s,
      ).getAlerts(lat: 51.77, lon: 19.45);
      expect(await alerts(DemoAlertScenario.none), isEmpty);
      expect((await alerts(DemoAlertScenario.level2)).single.level, 2);
      expect((await alerts(DemoAlertScenario.level3)).single.level, 3);
      expect(DemoApiClient().alertScenario, DemoAlertScenario.level2);
    });

    test('shade layer is the 14:30 file for any time', () async {
      await demo.getLayer(LayerKind.shade, datetime: DateTime(2026, 7, 15, 9));
      await demo.getLayer(LayerKind.noise, datetime: DateTime(2026, 7, 15, 9));
      expect(loader.requested, [
        'assets/demo/layer_shade_1430.geojson',
        'assets/demo/layer_noise.geojson',
      ]);
    });

    test('air and quest', () async {
      expect(await demo.getAir(), hasLength(2));
      final quest = await demo.getQuestPlaces();
      expect(quest.map((q) => q.order), [1, 2]);
    });

    test('missing file → notFound, broken file → server', () async {
      final broken = DemoApiClient(
        loadAsset: (path) async => path.endsWith('air.json')
            ? '{"stations": 1}'
            : throw StateError('no'),
      );
      await expectLater(
        broken.getAlerts(lat: 0, lon: 0),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.notFound,
          ),
        ),
      );
      await expectLater(
        broken.getAir(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.server,
          ),
        ),
      );
    });
  });
}
