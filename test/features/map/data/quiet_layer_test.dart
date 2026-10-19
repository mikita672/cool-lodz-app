import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/map/data/quiet_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fakes.dart';

GeoFeature box(
  double s,
  double w,
  double n,
  double e,
  Map<String, dynamic> props,
) => GeoFeature(
  geometry: GeoPolygons([
    GeoPolygon([
      LatLng(s, w),
      LatLng(s, e),
      LatLng(n, e),
      LatLng(n, w),
      LatLng(s, w),
    ]),
  ]),
  properties: props,
);

int? levelAt(GeoLayer layer, LatLng p) {
  for (final f in layer.features) {
    final r = f.geometry.polygons.single.outer;
    if (p.latitude >= r[0].latitude &&
        p.latitude <= r[2].latitude &&
        p.longitude >= r[0].longitude &&
        p.longitude <= r[2].longitude) {
      return f.properties['quiet'] as int;
    }
  }
  return null;
}

void main() {
  test('quiet = away from the noise bands; parks and far cells quietest', () {
    // A loud E–W road band through the middle of a 1 km square.
    final noise = GeoLayer(
      features: [
        box(51.760, 19.450, 51.769, 19.465, {'db': 30}), // sets the bounds
        box(51.7643, 19.450, 51.7647, 19.465, {'db': 70}),
      ],
    );
    // The first box covers everything: nothing is quiet.
    expect(quietAreas(noise).features, isEmpty);

    final road = GeoLayer(features: [noise.features[1]]);
    final bounds = GeoLayer(
      features: [
        noise.features[1],
        box(51.760, 19.450, 51.7601, 19.4501, {'db': 70}),
        box(51.7689, 19.4649, 51.769, 19.465, {'db': 70}),
      ],
    );
    final green = GeoLayer(
      features: [
        box(51.7660, 19.452, 51.7680, 19.456, {'kind': 'park'}),
      ],
    );
    final layer = quietAreas(bounds, green: green);
    expect(road.features, hasLength(1));
    expect(layer.features, isNotEmpty);
    expect(levelAt(layer, const LatLng(51.7645, 19.457)), isNull); // road
    // ~55 m from the road: quiet; ~250 m away: very quiet.
    expect(levelAt(layer, const LatLng(51.7638, 19.460)), 1);
    expect(levelAt(layer, const LatLng(51.7620, 19.460)), 2);
    expect(levelAt(layer, const LatLng(51.7670, 19.454)), 2); // park
    // Merged into rectangles, far fewer than grid cells (~25 × 25).
    expect(layer.features.length, lessThan(60));
  });

  test('the bundled noise layer gives a usable quiet map', () async {
    final bundled = DemoApiClient(loadAsset: readAssetFile);
    final at = DateTime(2026, 7, 15);
    final layer = quietAreas(
      await bundled.getLayer(LayerKind.noise, datetime: at),
      green: await bundled.getLayer(LayerKind.green, datetime: at),
    );
    expect(layer.features.length, inInclusiveRange(50, 5000));
    expect(layer.features.map((f) => f.properties['quiet']).toSet(), {1, 2});
  });
}
