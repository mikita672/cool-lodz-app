import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/live/gios_air.dart';
import 'package:cool_lodz/core/api/live/imgw_alerts.dart';
import 'package:cool_lodz/core/api/live/live_api_client.dart';
import 'package:cool_lodz/core/api/live/osrm_client.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late List<String> assetReads;
  late bool assetsBroken;

  LiveApiClient client({DateTime? now}) {
    assetReads = [];
    assetsBroken = false;
    final bundled = DemoApiClient(
      loadAsset: (path) {
        assetReads.add(path);
        if (assetsBroken) throw StateError('no $path');
        return readAssetFile(path);
      },
    );
    return LiveApiClient(
      bundled: bundled,
      imgw: ImgwAlertsClient(
        fakeDio(
          FakeAdapter((o) => jsonBody(fixture('live/imgw_warningsmeteo.json'))),
        ),
      ),
      gios: GiosAirClient(
        fakeDio(
          FakeAdapter((RequestOptions o) {
            if (o.uri.path.endsWith('/findAll')) {
              return jsonBody(fixture('live/gios_v1_stations.json'));
            }
            return jsonBody(fixture('live/gios_v1_index.json'));
          }),
        ),
      ),
      osrm: OsrmClient(
        fakeDio(
          FakeAdapter(
            (o) => jsonBody(fixture('live/osrm_route_alternatives.json')),
          ),
        ),
      ),
      clock: () => now ?? DateTime.utc(2026, 8, 15, 12),
    );
  }

  test('alerts come from IMGW, for the clock time', () async {
    final alerts = await client().getAlerts(lat: 0, lon: 0);
    expect(alerts.single.id, 'imgw-Sk20260815100248479');
    expect(
      await client(now: DateTime.utc(2026, 9)).getAlerts(lat: 0, lon: 0),
      isEmpty,
    );
  });

  test('air comes from GIOŚ, filtered by bbox', () async {
    final all = await client().getAir();
    expect(all.map((s) => s.id), [
      'gios-295',
      'gios-296',
      'gios-302',
      'gios-10058',
    ]);
    expect(all.every((s) => s.indexLevel == 0), isTrue);
    final centre = await client().getAir(
      bbox: const GeoBounds(
        minLon: 19.44,
        minLat: 51.77,
        maxLon: 19.46,
        maxLat: 51.78,
      ),
    );
    expect(centre.map((s) => s.id), ['gios-296', 'gios-302']);
  });

  test('places, layers and the quest are the bundled files', () async {
    final c = client();
    expect(await c.getPlaces(types: {PlaceType.cool}), isNotEmpty);
    expect(
      (await c.getLayer(LayerKind.green, datetime: DateTime(2026))).features,
      isNotEmpty,
    );
    expect(await c.getQuestPlaces(), hasLength(7));
    expect(assetReads, everyElement(startsWith('assets/demo/')));
  });

  test('routes from the engine; the shade model loads once', () async {
    final c = client();
    RouteRequest req() => RouteRequest(
      from: const RoutePoint(lat: 51.7794, lon: 19.4466),
      to: const RoutePoint(lat: 51.7676, lon: 19.4568),
      datetime: DateTime.parse('2026-07-15T14:30:00+02:00'),
      profile: const RouteProfile(
        id: ProfileId.standard,
        weights: ProfileWeights(shade: 60, time: 60, quiet: 30, air: 30),
      ),
    );
    expect((await c.getRoutes(req())).variants, hasLength(2));
    await c.getRoutes(req());
    expect(assetReads.where((p) => p.contains('layer_shade')), hasLength(1));
  });

  test('a failed shade model load is retried', () async {
    final c = client();
    assetsBroken = true;
    final req = RouteRequest(
      from: const RoutePoint(lat: 51.7794, lon: 19.4466),
      to: const RoutePoint(lat: 51.7676, lon: 19.4568),
      datetime: DateTime.parse('2026-07-15T14:30:00+02:00'),
      profile: const RouteProfile(
        id: ProfileId.standard,
        weights: ProfileWeights(shade: 60, time: 60, quiet: 30, air: 30),
      ),
    );
    await expectLater(c.getRoutes(req), throwsA(anything));
    assetsBroken = false;
    expect((await c.getRoutes(req)).variants, hasLength(2));
  });
}
