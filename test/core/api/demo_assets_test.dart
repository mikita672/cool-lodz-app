import 'dart:io';

import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses the real `assets/demo/` files through `DemoApiClient`. Files that
/// are not in the repo yet are skipped.
void main() {
  final demo = DemoApiClient(
    loadAsset: (path) async => File(path).readAsStringSync(),
  );
  bool exists(String name) => File('assets/demo/$name').existsSync();
  String? skip(String name) => exists(name) ? null : 'no assets/demo/$name';

  test(
    'places_cool.json parses; every place has hours',
    () async {
      final places = await demo.getPlaces(types: {PlaceType.cool});
      expect(places.length, inInclusiveRange(15, 20));
      for (final p in places) {
        expect(p.type, PlaceType.cool);
        expect(p.name, isNotNull, reason: p.id);
        // Either always open or opens at some point in the week.
        final monday = DateTime(2026, 7, 13, 3);
        expect(
          p.isAlwaysOpen || p.isOpenAt(monday) || p.nextOpening(monday) != null,
          isTrue,
          reason: p.id,
        );
      }
    },
    skip: skip('places_cool.json'),
  );

  test(
    'quest.json: 7 ordered letters at quest places',
    () async {
      final quest = await demo.getQuestPlaces();
      expect(quest.map((q) => q.order), [1, 2, 3, 4, 5, 6, 7]);
      final places = {
        for (final p in await demo.getPlaces(types: {PlaceType.cool})) p.id: p,
      };
      for (final q in quest) {
        expect(places[q.placeId]?.questPlace, isTrue, reason: q.placeId);
      }
    },
    skip: skip('quest.json') ?? skip('places_cool.json'),
  );

  for (final route in ReferenceRoutes.all) {
    final name = route.asset.split('/').last;
    test(
      '$name: every departure has 3 variants ending at the endpoints',
      () async {
        for (final time in [
          DateTime(2026, 7, 15, 10),
          DateTime(2026, 7, 15, 14, 30),
          DateTime(2026, 7, 15, 18),
        ]) {
          final response = await demo.getRoutes(
            RouteRequest(
              from: route.from,
              to: route.to,
              datetime: time,
              profile: const RouteProfile(
                id: ProfileId.standard,
                weights: ProfileWeights(
                  shade: 50,
                  time: 50,
                  quiet: 50,
                  air: 50,
                ),
              ),
            ),
          );
          expect(response.variants, hasLength(3));
          for (final v in response.variants) {
            expect(
              distanceMeters(v.geometry.first, route.from.latLng),
              lessThan(matchRadiusMeters),
            );
            expect(
              distanceMeters(v.geometry.last, route.to.latLng),
              lessThan(matchRadiusMeters),
            );
          }
        }
      },
      skip: skip(name),
    );
  }

  for (final name in [
    'places_water.json',
    'places_bench.json',
    'alerts_none.json',
    'alerts_level2.json',
    'alerts_level3.json',
    'air.json',
    'layer_shade_1430.geojson',
    'layer_green.geojson',
    'layer_noise.geojson',
  ]) {
    test('$name parses', () async {
      final time = DateTime(2026, 7, 15, 14, 30);
      switch (name) {
        case 'places_water.json':
          await demo.getPlaces(types: {PlaceType.water});
        case 'places_bench.json':
          await demo.getPlaces(types: {PlaceType.bench});
        case 'air.json':
          await demo.getAir();
        case final n when n.startsWith('alerts_'):
          final scenario = DemoAlertScenario.values.byName(
            n.substring(7, n.length - 5),
          );
          await DemoApiClient(
            loadAsset: (path) async => File(path).readAsStringSync(),
            alertScenario: scenario,
          ).getAlerts(lat: 51.77, lon: 19.45);
        case 'layer_shade_1430.geojson':
          await demo.getLayer(LayerKind.shade, datetime: time);
        case 'layer_green.geojson':
          await demo.getLayer(LayerKind.green, datetime: time);
        case 'layer_noise.geojson':
          await demo.getLayer(LayerKind.noise, datetime: time);
      }
    }, skip: skip(name));
  }
}
