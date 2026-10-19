import 'dart:convert';
import 'dart:io';

import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/live/shade_layer.dart';
import 'package:cool_lodz/core/api/live/shade_model.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fakes.dart';

void main() {
  late ShadeLayerBuilder builder;
  late int trees;

  setUpAll(() async {
    final bundled = DemoApiClient(loadAsset: readAssetFile);
    final at = DateTime(2026, 7, 15, 14, 30);
    final shade = await bundled.getLayer(LayerKind.shade, datetime: at);
    final green = await bundled.getLayer(LayerKind.green, datetime: at);
    trees = shade.features
        .where((f) => f.properties['source'] != 'buildings')
        .length;
    builder = ShadeLayerBuilder(
      bundledShade: shade,
      streets: parseStreets(
        jsonDecode(File('assets/demo/streets_core.geojson').readAsStringSync()),
      ),
      model: ShadeModel.fromLayers(shade: shade, green: green),
    );
  });

  List<GeoFeature> strips(String iso) => builder
      .at(DateTime.parse(iso))
      .features
      .where((f) => f.properties['source'] == 'buildings')
      .toList();

  test('the bundled street file parses', () {
    expect(builder.streets.length, greaterThan(100));
    expect(builder.streets.every((s) => s.width >= 14), isTrue);
  });

  test('trees stay, the fixed 14:30 strips are replaced', () {
    final layer = builder.at(DateTime.parse('2026-07-15T14:30:00+02:00'));
    expect(
      layer.features.where((f) => f.properties['source'] != 'buildings'),
      hasLength(trees),
    );
    // About as many strips as the 14:30 file had (260).
    expect(
      strips('2026-07-15T14:30:00+02:00').length,
      inInclusiveRange(150, 600),
    );
  });

  test('the shadow follows the sun', () {
    double area(List<GeoFeature> fs) => fs.fold(0.0, (sum, f) {
      final ring = f.geometry.polygons.single.outer;
      var a = 0.0;
      for (var i = 0; i + 1 < ring.length; i++) {
        a +=
            ring[i].longitude * ring[i + 1].latitude -
            ring[i + 1].longitude * ring[i].latitude;
      }
      return sum + a.abs() / 2;
    });
    final noon = area(strips('2026-07-15T13:00:00+02:00'));
    final evening = area(strips('2026-07-15T19:30:00+02:00'));
    // Low evening sun: far more of the streets is in building shadow.
    expect(evening, greaterThan(noon * 1.5));
    for (final f in strips('2026-07-15T19:30:00+02:00')) {
      expect(f.shade, ShadeLayerBuilder.buildingShade);
      final ring = f.geometry.polygons.single.outer;
      expect(ring.first, ring.last);
    }
  });

  test('a N–S street at solar noon gets (almost) no strip', () {
    final single = ShadeLayerBuilder(
      bundledShade: const GeoLayer(features: []),
      streets: const [
        StreetLine([LatLng(51.760, 19.457), LatLng(51.770, 19.457)], 18),
        StreetLine([LatLng(51.765, 19.450), LatLng(51.765, 19.465)], 18),
      ],
      model: ShadeModel(canopy: const [], parks: const []),
    );
    // Solar noon in Łódź ≈ 12:43 CEST; the E–W street is shaded.
    final layer = single.at(DateTime.parse('2026-07-15T12:43:00+02:00'));
    expect(layer.features, hasLength(1));
    final lats = layer.features.single.geometry.polygons.single.outer.map(
      (p) => p.latitude,
    );
    // From the south kerb (9 m south) to about the centre line: the shadow
    // of the south row of houses (the sun is in the south).
    expect(
      lats.reduce((a, b) => a < b ? a : b),
      closeTo(51.765 - 9 / 111195, 1e-6),
    );
    expect(lats.every((l) => l <= 51.765 + 1 / 111195), isTrue);
  });

  test('broken street features are skipped', () {
    expect(parseStreets(null), isEmpty);
    expect(
      parseStreets({
        'features': [
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [1, 2],
            },
          },
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [19.4, 51.7],
                [19.5, 51.8],
              ],
            },
          },
        ],
      }).single.width,
      ShadeModel.tenementStreetWidth,
    );
  });
}
