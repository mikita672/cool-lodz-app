import 'dart:convert';
import 'dart:io';

import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/live/live_api_client.dart';
import 'package:cool_lodz/core/api/live/shade_model.dart';
import 'package:cool_lodz/core/api/live/shadows.dart';
import 'package:cool_lodz/core/api/live/sun.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fakes.dart';

/// One 20 × 20 m building, 20 m high, south-west corner at the origin.
ShadowCasters block({List<List<num>> trees = const []}) =>
    ShadowCasters.fromJson({
      'origin': [19.46, 51.77],
      'metresPerDegree': [68900.0, 111195.0],
      'unit': 'dm',
      'buildings': [
        [20, 0, 0, 200, 0, 0, 200, -200, 0],
      ],
      'trees': trees,
    });

LatLng at(ShadowCasters c, double x, double y) => c.toLatLng(x, y);

void main() {
  const noon = SunPosition(elevation: 45, azimuth: 180); // sun due south
  const evening = SunPosition(elevation: 45, azimuth: 270); // due west

  group('ray test', () {
    test('north of the block at noon is in its shadow, south is not', () {
      final c = block();
      expect(c.inShadow(at(c, 10, 30), noon), isTrue); // 10 m north
      expect(c.inShadow(at(c, 10, 45), noon), isFalse); // beyond 20 m
      expect(c.inShadow(at(c, 10, -5), noon), isFalse); // south side
    });

    test('the shadow turns with the sun', () {
      final c = block();
      expect(c.inShadow(at(c, 30, 10), evening), isTrue); // east side
      expect(c.inShadow(at(c, 10, 30), evening), isFalse);
      expect(
        c.inShadow(at(c, 10, 30), const SunPosition(elevation: -3, azimuth: 0)),
        isTrue,
      );
    });

    test('a tree crown shades the ground away from the sun', () {
      // Tree 9 m, crown radius 3 m at (100, 0): crown centre 5.85 m up.
      final c = block(
        trees: [
          [1000, 0],
        ],
      );
      expect(
        c.inShadow(
          at(c, 100, -5.85),
          const SunPosition(elevation: 45, azimuth: 0),
        ),
        isTrue,
      );
      expect(
        c.inShadow(
          at(c, 100, 5.85),
          const SunPosition(elevation: 45, azimuth: 0),
        ),
        isFalse,
      );
    });
  });

  group('shadow polygons', () {
    test('swept away from the sun, roof cut out, none at night', () {
      final c = block();
      final s = c.shadows(noon);
      expect(s, hasLength(1));
      final polygon = s.single.geometry.polygons.single;
      final lats = polygon.outer.map((p) => p.latitude);
      // 20 m high at 45°: 20 m long towards the north.
      expect(
        lats.reduce((a, b) => a > b ? a : b),
        closeTo(51.77 + 40 / 111195, 1e-7),
      );
      expect(polygon.holes, hasLength(1));
      expect(c.shadows(const SunPosition(elevation: -1, azimuth: 0)), isEmpty);
      // Outside the asked area: nothing.
      expect(
        c.shadows(
          noon,
          bounds: const GeoBounds(
            minLon: 19.5,
            minLat: 51.8,
            maxLon: 19.6,
            maxLat: 51.9,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('bundled data', () {
    late ShadowCasters casters;
    late ShadeModel model;

    setUpAll(() async {
      casters = ShadowCasters.fromJson(
        jsonDecode(File('assets/demo/shadow_casters.json').readAsStringSync()),
      );
      final bundled = DemoApiClient(loadAsset: readAssetFile);
      final t = DateTime(2026, 7, 15);
      model = ShadeModel.fromLayers(
        shade: await bundled.getLayer(LayerKind.shade, datetime: t),
        green: await bundled.getLayer(LayerKind.green, datetime: t),
        casters: casters,
      );
    });

    test('thousands of buildings and trees in Śródmieście', () {
      expect(casters.buildingCount, greaterThan(10000));
      expect(casters.treeCount, greaterThan(10000));
      expect(casters.covers(const LatLng(51.7676, 19.4568)), isTrue);
      expect(casters.covers(const LatLng(51.70, 19.40)), isFalse);
    });

    test('ul. Piotrkowska: shade moves through the day', () {
      final walk = model.analyse(const [
        LatLng(51.7700, 19.4570),
        LatLng(51.7650, 19.4590),
      ]);
      double share(String iso) =>
          walk.sunShare(DateTime.parse(iso), const Duration(minutes: 8));
      final morning = share('2026-07-15T09:00:00+02:00');
      final noonShare = share('2026-07-15T13:00:00+02:00');
      final evening = share('2026-07-15T19:00:00+02:00');
      expect([
        morning,
        noonShare,
        evening,
      ], everyElement(inInclusiveRange(0, 1)));
      // A N–S street: sunny around noon, shaded with the low sun.
      expect(noonShare, greaterThan(evening));
      expect(share('2026-07-15T23:00:00+02:00'), 0);
    });

    test('the map layer: parks always, shadows only in daylight', () {
      const box = GeoBounds(
        minLon: 19.452,
        minLat: 51.765,
        maxLon: 19.462,
        maxLat: 51.771,
      );
      final day = shadeLayerAt(
        model,
        DateTime.parse('2026-07-15T13:00:00+02:00'),
        bbox: box,
      );
      final shadows = day.features.where(
        (f) => f.properties['source'] == 'shadow',
      );
      expect(shadows.length, greaterThan(200));
      final night = shadeLayerAt(
        model,
        DateTime.parse('2026-07-15T23:00:00+02:00'),
        bbox: box,
      );
      expect(
        night.features.where((f) => f.properties['source'] == 'shadow'),
        isEmpty,
      );
      expect(
        night.features.where((f) => f.properties['source'] == 'park'),
        isNotEmpty,
      );
      final cloudy = shadeLayerAt(
        model,
        DateTime.parse('2026-07-15T13:00:00+02:00'),
        bbox: box,
        strength: 0.3,
      );
      expect(
        cloudy.features
            .firstWhere((f) => f.properties['source'] == 'shadow')
            .shade,
        closeTo(0.27, 1e-9),
      );
    });
  });
}
