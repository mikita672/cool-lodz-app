import 'dart:convert';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/live/live_http.dart';
import 'package:cool_lodz/core/api/live/osrm_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fixtures.dart';

Matcher apiError(ApiErrorKind kind) =>
    isA<ApiException>().having((e) => e.kind, 'kind', kind);

const from = LatLng(51.7794, 19.4466);
const to = LatLng(51.7676, 19.4568);

void main() {
  group('parseOsrmRoutes', () {
    test('real response with an alternative', () {
      final routes = parseOsrmRoutes(
        jsonDecode(fixture('live/osrm_route_alternatives.json')),
      );
      expect(routes, hasLength(2));
      expect(routes.first.distanceM, 1873.7);
      expect(routes.first.durationS, 1459.3);
      expect(routes.first.points, hasLength(180));
      expect(routes.first.points.first, const LatLng(51.779419, 19.446817));
      expect(routes.last.distanceM, 1934.3);
    });

    test('real response through a via point', () {
      final routes = parseOsrmRoutes(
        jsonDecode(fixture('live/osrm_route_via.json')),
      );
      expect(routes.single.distanceM, closeTo(1937, 1));
    });

    test('no route → route_not_found', () {
      for (final code in ['NoRoute', 'NoSegment']) {
        expect(
          () => parseOsrmRoutes({'code': code, 'message': 'x'}),
          throwsA(apiError(ApiErrorKind.notFound)),
        );
      }
      expect(
        () => parseOsrmRoutes({'code': 'Ok', 'routes': <Object?>[]}),
        throwsA(apiError(ApiErrorKind.notFound)),
      );
    });

    test('broken routes are skipped; garbage → server error', () {
      final routes = parseOsrmRoutes({
        'code': 'Ok',
        'routes': [
          {'distance': 1, 'duration': 1},
          {
            'geometry': {'type': 'Point', 'coordinates': <Object?>[]},
            'distance': 1,
            'duration': 1,
          },
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [19.4, 51.7],
                [19.5, 51.8],
              ],
            },
            'distance': 10,
            'duration': 8,
          },
        ],
      });
      expect(routes.single.distanceM, 10);
      expect(
        () => parseOsrmRoutes('x'),
        throwsA(apiError(ApiErrorKind.server)),
      );
      expect(
        () => parseOsrmRoutes({'code': 'TooBig'}),
        throwsA(apiError(ApiErrorKind.server)),
      );
    });
  });

  group('OsrmClient', () {
    test('URL: lon,lat pairs, GeoJSON, alternatives', () {
      expect(
        OsrmClient.url('https://r.test/foot', [from, to], alternatives: 2),
        'https://r.test/foot/19.446600,51.779400;19.456800,51.767600'
        '?overview=full&geometries=geojson&steps=false&alternatives=2',
      );
      expect(
        OsrmClient.url('https://r.test/foot', [from, to]),
        endsWith('alternatives=false'),
      );
    });

    test('GETs the public foot router', () async {
      final adapter = FakeAdapter(
        (o) => jsonBody(fixture('live/osrm_route_alternatives.json')),
      );
      final routes = await OsrmClient(
        fakeDio(adapter),
      ).route([from, to], alternatives: 2);
      expect(routes, hasLength(2));
      expect(
        adapter.requests.single.uri.toString(),
        startsWith(
          'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
          '19.446600,51.779400;19.456800,51.767600?',
        ),
      );
    });

    Future<ApiErrorKind> failure(FakeHandler handler) async {
      try {
        await OsrmClient(fakeDio(FakeAdapter(handler))).route([from, to]);
      } on ApiException catch (e) {
        return e.kind;
      }
      fail('no exception');
    }

    test('errors', () async {
      expect(
        await failure((o) => jsonBody('{"code":"NoRoute","message":"x"}', 400)),
        ApiErrorKind.notFound,
      );
      // Real 400 answer for 0,0.
      expect(
        await failure(
          (o) => jsonBody(fixture('live/osrm_error_null_island.json'), 400),
        ),
        ApiErrorKind.badRequest,
      );
      expect(await failure((o) => jsonBody('{}', 503)), ApiErrorKind.server);
      expect(
        await failure(
          (o) => throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          ),
        ),
        ApiErrorKind.network,
      );
    });
  });

  test('live Dio accepts JSON-LD (GIOŚ answers 406 otherwise)', () {
    final accept = createLiveDio().options.headers['Accept'] as String;
    expect(accept, contains('application/json'));
    expect(accept, contains('application/ld+json'));
  });
}
