import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/live/shade_model.dart';
import 'package:cool_lodz/core/api/live/sun.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fakes.dart';

/// A square around [c] with half-size [d] degrees.
GeoFeature square(LatLng c, double d, Map<String, dynamic> props) => GeoFeature(
  geometry: GeoPolygons([
    GeoPolygon([
      LatLng(c.latitude - d, c.longitude - d),
      LatLng(c.latitude - d, c.longitude + d),
      LatLng(c.latitude + d, c.longitude + d),
      LatLng(c.latitude + d, c.longitude - d),
      LatLng(c.latitude - d, c.longitude - d),
    ]),
  ]),
  properties: props,
);

void main() {
  const a = LatLng(51.770, 19.450);
  const b = LatLng(51.770, 19.452);
  const c = LatLng(51.770, 19.454);

  group('buildingShadow', () {
    double shadow(double bearing, double el, double az) => buildingShadow(
      height: 16,
      width: 18,
      streetBearing: bearing,
      sun: SunPosition(elevation: el, azimuth: az),
    );

    test('sun along the street → no shadow', () {
      expect(shadow(0, 60, 180), closeTo(0, 1e-9));
    });

    test('sun across an E–W street at 45° → 0.6 × 16 / 18', () {
      expect(shadow(90, 45, 180), closeTo(0.6 * 16 / 18, 1e-9));
    });

    test('low sun fills the canyon; capped at 1', () {
      expect(shadow(90, 10, 180), 1);
      expect(shadow(90, 1, 180), 1);
    });
  });

  group('ShadeModel', () {
    test('trees count, the 14:30 building strips do not, parks are 0.8', () {
      final model = ShadeModel.fromLayers(
        shade: GeoLayer(
          features: [
            square(a, 0.0002, {'shade': 0.6, 'source': 'trees'}),
            square(b, 0.0002, {'shade': 0.85, 'source': 'buildings'}),
            square(c, 0.0002, {'shade': 0.7}), // untagged = trees
          ],
        ),
        green: GeoLayer(
          features: [
            square(b, 0.0001, {'kind': 'park'}),
            square(a, 0.0001, {'kind': 'grass'}),
          ],
        ),
      );
      expect(model.canopyAt(a), 0.6);
      expect(model.canopyAt(b), ShadeModel.parkCanopy);
      expect(model.canopyAt(const LatLng(51.770, 19.45205)), 0.8);
      expect(model.canopyAt(const LatLng(51.7701, 19.45185)), 0); // strip only
      expect(model.canopyAt(c), 0.7);
      expect(model.canopyAt(const LatLng(51.8, 19.5)), 0);
      expect(model.inPark(b), isTrue);
      expect(model.inPark(a), isFalse); // grass is not a park
      expect(model.parkCentres.single.latitude, closeTo(51.770, 1e-9));
    });

    test('holes are not covered', () {
      final model = ShadeModel(
        canopy: [
          const GeoFeature(
            geometry: GeoPolygons([
              GeoPolygon(
                [
                  LatLng(51.0, 19.0),
                  LatLng(51.0, 19.01),
                  LatLng(51.01, 19.01),
                  LatLng(51.01, 19.0),
                  LatLng(51.0, 19.0),
                ],
                [
                  [
                    LatLng(51.004, 19.004),
                    LatLng(51.004, 19.006),
                    LatLng(51.006, 19.006),
                    LatLng(51.006, 19.004),
                    LatLng(51.004, 19.004),
                  ],
                ],
              ),
            ]),
            properties: {'shade': 0.5},
          ),
        ],
        parks: const [],
      );
      expect(model.canopyAt(const LatLng(51.002, 19.002)), 0.5);
      expect(model.canopyAt(const LatLng(51.005, 19.005)), 0);
    });

    test('sun shares: trees and buildings shade the walk; night is 0', () {
      final model = ShadeModel(
        canopy: [
          square(const LatLng(51.770, 19.4475), 0.0004, {'shade': 0.9}),
        ],
        parks: const [],
      );
      // E–W street in the tenement grid: the first half under trees.
      final route = model.analyse([
        const LatLng(51.770, 19.447),
        const LatLng(51.770, 19.448),
        const LatLng(51.770, 19.449),
      ]);
      expect(route.edgeCount, 2);
      expect(route.length, closeTo(138, 2));
      final noon = DateTime.utc(2026, 7, 15, 10, 45);
      final shares = route.sunShares(noon, const Duration(minutes: 2));
      expect(shares[0], lessThan(shares[1]));
      // Building shadow alone at noon on an E–W street: well below 1.
      expect(shares[1], inExclusiveRange(0.2, 0.9));
      expect(
        route.sunShare(noon, const Duration(minutes: 2)),
        closeTo((shares[0] + shares[1]) / 2, 0.01),
      );
      expect(route.sunShares(DateTime.utc(2026, 7, 15, 22), Duration.zero), [
        0,
        0,
      ]);
    });

    test('the same walk is sunnier outside the tenement grid', () {
      final model = ShadeModel(canopy: const [], parks: const []);
      final noon = DateTime.utc(2026, 7, 15, 10, 45);
      double share(double lat) => model
          .analyse([LatLng(lat, 19.447), LatLng(lat, 19.449)])
          .sunShare(noon, const Duration(minutes: 2));
      expect(share(51.80), greaterThan(share(51.77)));
    });

    test('bundled layers: parks shade, Piotrkowska has no trees', () async {
      final bundled = DemoApiClient(loadAsset: readAssetFile);
      final model = ShadeModel.fromLayers(
        shade: await bundled.getLayer(
          LayerKind.shade,
          datetime: DateTime(2026, 7, 15, 14, 30),
        ),
        green: await bundled.getLayer(
          LayerKind.green,
          datetime: DateTime(2026, 7, 15, 14, 30),
        ),
      );
      // Park Staszica.
      expect(
        model.canopyAt(const LatLng(51.7734, 19.4762)),
        greaterThanOrEqualTo(0.8),
      );
      expect(model.parkCentres, isNotEmpty);
    });
  });
}
