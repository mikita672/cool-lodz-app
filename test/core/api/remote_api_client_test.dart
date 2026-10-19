import 'dart:convert';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/reference_routes.dart';
import 'package:cool_lodz/core/api/remote_api_client.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio.dart';
import '../../helpers/fixtures.dart';

Object? encoded(Object? models) => jsonDecode(jsonEncode(models));

RouteRequest manufakturaAt(DateTime time) => RouteRequest(
  from: ReferenceRoutes.manufakturaPiotrkowska.from,
  to: ReferenceRoutes.manufakturaPiotrkowska.to,
  datetime: time,
  profile: const RouteProfile(
    id: ProfileId.senior,
    weights: ProfileWeights(shade: 90, time: 20, quiet: 60, air: 50),
  ),
);

void main() {
  group('Remote and Demo give the same models from the same JSON', () {
    late FakeAdapter adapter;
    late RemoteApiClient remote;
    late DemoApiClient demo;

    setUp(() {
      adapter = FakeAdapter((options) {
        final path = options.uri.path;
        if (path == '/v1/routes') {
          final departures =
              fixtureJson('routes_manufaktura_piotrkowska.json')['departures']
                  as Map<String, dynamic>;
          return jsonBody(jsonEncode(departures['14:30']));
        }
        if (path == '/v1/places') {
          return jsonBody(
            fixture('places_${options.uri.queryParameters['type']}.json'),
          );
        }
        if (path == '/v1/alerts') {
          return jsonBody(fixture('alerts_level2.json'));
        }
        if (path == '/v1/air') return jsonBody(fixture('air.json'));
        if (path == '/v1/layers/shade') {
          return jsonBody(fixture('layer_shade_1430.geojson'));
        }
        if (path == '/v1/layers/green') {
          return jsonBody(fixture('layer_green.geojson'));
        }
        return jsonBody('{"error": "not_found"}', 404);
      });
      remote = RemoteApiClient(fakeDio(adapter));
      demo = DemoApiClient(loadAsset: FixtureAssetLoader().call);
    });

    test('routes', () async {
      final request = manufakturaAt(DateTime(2026, 7, 15, 14, 30));
      expect(
        encoded(await remote.getRoutes(request)),
        encoded(await demo.getRoutes(request)),
      );
      final sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(encoded(sent.data), encoded(request.toJson()));
    });

    test('places', () async {
      for (final type in PlaceType.values) {
        expect(
          encoded(await remote.getPlaces(types: {type})),
          encoded(await demo.getPlaces(types: {type})),
        );
      }
    });

    test('alerts, air, layers', () async {
      expect(
        encoded(await remote.getAlerts(lat: 51.77, lon: 19.45)),
        encoded(await demo.getAlerts(lat: 51.77, lon: 19.45)),
      );
      expect(encoded(await remote.getAir()), encoded(await demo.getAir()));
      final time = DateTime(2026, 7, 15, 14, 30);
      for (final kind in [LayerKind.shade, LayerKind.green]) {
        expect(
          encoded(await remote.getLayer(kind, datetime: time)),
          encoded(await demo.getLayer(kind, datetime: time)),
        );
      }
    });
  });

  group('RemoteApiClient requests', () {
    test('query parameters follow the contract', () async {
      final adapter = FakeAdapter((options) {
        final path = options.uri.path;
        if (path == '/v1/places') return jsonBody('{"places": []}');
        if (path == '/v1/alerts') return jsonBody('{"alerts": []}');
        return jsonBody('{"type": "FeatureCollection", "features": []}');
      });
      final remote = RemoteApiClient(fakeDio(adapter));
      const bbox = GeoBounds(
        minLon: 19.4,
        minLat: 51.74,
        maxLon: 19.5,
        maxLat: 51.8,
      );
      await remote.getPlaces(
        types: {PlaceType.bench, PlaceType.cool},
        bbox: bbox,
      );
      await remote.getAlerts(lat: 51.77, lon: 19.45);
      await remote.getLayer(
        LayerKind.noise,
        datetime: DateTime.utc(2026, 7, 15, 12, 30),
      );
      final [places, alerts, layer] = [for (final r in adapter.requests) r.uri];
      expect(places.queryParameters, {
        'type': 'cool,bench',
        'bbox': '19.4,51.74,19.5,51.8',
      });
      expect(alerts.queryParameters, {'lat': '51.77', 'lon': '19.45'});
      expect(layer.path, '/v1/layers/noise');
      expect(layer.queryParameters, {'datetime': '2026-07-15T12:30:00Z'});
    });

    test('create() uses the base URL and 8 s timeouts', () {
      final client = RemoteApiClient.create('https://api.example');
      expect(client, isA<RemoteApiClient>());
      expect(apiTimeout, const Duration(seconds: 8));
    });
  });

  group('RemoteApiClient errors', () {
    Future<ApiException> errorFrom(FakeHandler handler) async {
      final remote = RemoteApiClient(fakeDio(FakeAdapter(handler)));
      try {
        await remote.getAir();
      } on ApiException catch (e) {
        return e;
      }
      fail('no ApiException');
    }

    test('404 → notFound with the error code', () async {
      final e = await errorFrom(
        (_) => jsonBody('{"error": "route_not_found"}', 404),
      );
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, 'route_not_found');
      expect(e.statusCode, 404);
      expect(e.isOffline, isFalse);
    });

    test('500 → server', () async {
      final e = await errorFrom((_) => jsonBody('{}', 503));
      expect(e.kind, ApiErrorKind.server);
      expect(e.isOffline, isTrue);
    });

    test('receive timeout → timeout', () async {
      final e = await errorFrom(
        (o) => throw DioException.receiveTimeout(
          timeout: apiTimeout,
          requestOptions: o,
        ),
      );
      expect(e.kind, ApiErrorKind.timeout);
    });

    test('connection error → network', () async {
      final e = await errorFrom(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
      );
      expect(e.kind, ApiErrorKind.network);
    });

    test('response off the contract → server', () async {
      final e = await errorFrom((_) => jsonBody('{"stations": "nope"}'));
      expect(e.kind, ApiErrorKind.server);
    });

    test('quest places are not a module D endpoint', () async {
      final remote = RemoteApiClient(
        fakeDio(FakeAdapter((_) => jsonBody('{}'))),
      );
      expect(
        remote.getQuestPlaces(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.notFound,
          ),
        ),
      );
    });
  });
}
