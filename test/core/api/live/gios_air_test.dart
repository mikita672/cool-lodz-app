import 'dart:async';
import 'dart:convert';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/live/gios_air.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fixtures.dart';

const v1Index = '/pjp-api/v1/rest/aqindex/getIndex/';

String v1IndexJson(Map<String, Object?> fields) =>
    jsonEncode({'AqIndex': fields});

Matcher apiError(ApiErrorKind kind) =>
    isA<ApiException>().having((e) => e.kind, 'kind', kind);

void main() {
  group('parseGiosStations', () {
    test('real v1 list: Polish keys, numbers as strings', () {
      final stations = parseGiosStations(
        jsonDecode(fixture('live/gios_v1_stations.json')),
      );
      expect(stations, hasLength(6));
      final gdanska = stations[2];
      expect(gdanska.id, '296');
      expect(gdanska.name, 'Łódź, ul. Gdańska');
      expect(gdanska.lat, 51.775378);
      expect(gdanska.lon, 19.450992);
      expect(gdanska.city, 'Łódź');
      expect(stations.where((s) => isLodz(s.city)), hasLength(4));
    });

    test('v1 with other spellings of the keys', () {
      final stations = parseGiosStations({
        'lista_stacji': [
          {
            'IDENTYFIKATOR STACJI': '7',
            'nazwa stacji': 'Łódź, Test',
            'wgs84 φ n': '51.7',
            'wgs84 λ e': '19.4',
            'nazwa miasta': 'ŁÓDŹ',
          },
          {
            'Identyfikator stacji': 8,
            'Nazwa stacji': 'Łódź, Bez greckich liter',
            'WGS84 N': 51.8,
            'WGS84 E': 19.5,
            'Nazwa miasta': 'Lodz',
          },
        ],
      });
      expect(stations.map((s) => s.id), ['7', '8']);
      expect(stations.every((s) => isLodz(s.city)), isTrue);
      expect(stations.last.lat, 51.8);
      expect(stations.last.lon, 19.5);
    });

    test('nothing usable → server error', () {
      for (final bad in [
        null,
        'x',
        <Object?>[],
        {'Lista stacji pomiarowych': <Object?>[]},
        [
          {'foo': 1},
        ],
      ]) {
        expect(
          () => parseGiosStations(bad),
          throwsA(apiError(ApiErrorKind.server)),
        );
      }
    });
  });

  group('parseGiosIndex', () {
    test('real v1 index: overall value, not the per-pollutant ones', () {
      final index = parseGiosIndex(
        jsonDecode(fixture('live/gios_v1_index.json')),
      );
      expect(index.level, 0);
      expect(index.updatedAt!.toUtc(), DateTime.utc(2026, 10, 19, 14, 20, 29));
      // Per-pollutant values must not leak into the overall one.
      expect(
        parseGiosIndex({
          'AqIndex': {
            'Wartość indeksu dla wskaźnika O3': 3,
            'Nazwa kategorii indeksu dla wskażnika O3': 'Dostateczny',
          },
        }).level,
        isNull,
      );
    });

    test('real v1 index of a station without one: all fields null', () {
      final index = parseGiosIndex(
        jsonDecode(fixture('live/gios_v1_index_empty.json')),
      );
      expect(index.level, isNull);
      expect(index.updatedAt, isNull);
    });

    test('v1: value as string, or only the category name', () {
      expect(
        parseGiosIndex({
          'AqIndex': {'Wartość indeksu': '4'},
        }).level,
        4,
      );
      expect(
        parseGiosIndex({
          'AqIndex': {'Nazwa kategorii indeksu': 'Bardzo zły'},
        }).level,
        5,
      );
      expect(
        parseGiosIndex({
          'AqIndex': {
            'Wartość indeksu': null,
            'Nazwa kategorii indeksu': 'Umiarkowany',
          },
        }).level,
        2,
      );
    });

    test('v1: no index', () {
      for (final fields in <Map<String, Object?>>[
        {},
        {'Wartość indeksu': -1, 'Nazwa kategorii indeksu': 'Brak indeksu'},
        {'Wartość indeksu': 7},
        {
          'Wartość indeksu': 1,
          'Status indeksu ogólnego dla stacji pomiarowej': false,
        },
      ]) {
        expect(parseGiosIndex({'AqIndex': fields}).level, isNull);
      }
      expect(parseGiosIndex({'AqIndex': null}).level, isNull);
    });

    test('not an object → server error', () {
      expect(() => parseGiosIndex([1]), throwsA(apiError(ApiErrorKind.server)));
    });
  });

  group('GiosAirClient', () {
    late FakeAdapter adapter;

    FutureOr<ResponseBody> v1(RequestOptions o) {
      final path = o.uri.path;
      if (path == '/pjp-api/v1/rest/station/findAll') {
        return jsonBody(fixture('live/gios_v1_stations.json'));
      }
      if (path.startsWith(v1Index)) {
        return switch (path.substring(v1Index.length)) {
          '295' => jsonBody(fixture('live/gios_v1_index.json')),
          '296' => jsonBody(fixture('live/gios_v1_index_empty.json')),
          '302' => jsonBody('{}', 500),
          '10058' => jsonBody(
            v1IndexJson({
              'Wartość indeksu': '2',
              'Data wykonania obliczeń indeksu': '2026-07-15 14:20',
            }),
          ),
          _ => jsonBody('{}', 404),
        };
      }
      return jsonBody('{}', 404);
    }

    test('Łódź stations with their index', () async {
      adapter = FakeAdapter(v1);
      final client = GiosAirClient(fakeDio(adapter));
      final stations = await client.lodzStations();

      expect(stations.map((s) => s.id), [
        'gios-295',
        'gios-296',
        'gios-302',
        'gios-10058',
      ]);
      expect(stations.map((s) => s.indexLevel), [0, null, null, 2]);
      expect(stations.first.name, 'Łódź, ul. Czernika');
      expect(stations.first.lat, 51.75805);
      expect(stations.first.lon, 19.529786);
      expect(
        stations.first.updatedAt!.toUtc(),
        DateTime.utc(2026, 10, 19, 14, 20, 29),
      );
      expect(stations[1].updatedAt, isNull);
      expect(
        stations.last.updatedAt!.toUtc(),
        DateTime.utc(2026, 7, 15, 12, 20),
      );
      expect(adapter.requests.first.uri.toString(), GiosAirClient.stationsUrl);
      expect(
        adapter.requests
            .map((r) => r.uri.path)
            .where((p) => p.startsWith(v1Index)),
        hasLength(4),
      );
    });

    test('the station list is fetched once', () async {
      adapter = FakeAdapter(v1);
      final client = GiosAirClient(fakeDio(adapter));
      await client.lodzStations();
      await client.lodzStations();
      expect(
        adapter.requests.where((r) => r.uri.path.endsWith('/findAll')),
        hasLength(1),
      );
    });

    test('at most maxIndexCalls index requests, concurrency-limited', () async {
      final many = {
        'Lista stacji pomiarowych': [
          for (var i = 0; i < 12; i++)
            {
              'Identyfikator stacji': 100 + i,
              'Nazwa stacji': 'Łódź, stacja $i',
              'WGS84 φ N': '51.7$i',
              'WGS84 λ E': '19.4$i',
              'Nazwa miasta': 'Łódź',
            },
        ],
      };
      var inFlight = 0;
      var maxInFlight = 0;
      adapter = FakeAdapter((o) async {
        if (o.uri.path.endsWith('/findAll')) return jsonBody(jsonEncode(many));
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return jsonBody(v1IndexJson({'Wartość indeksu': 3}));
      });
      final client = GiosAirClient(fakeDio(adapter));
      final stations = await client.lodzStations();

      expect(stations, hasLength(12));
      expect(stations.where((s) => s.indexLevel == 3), hasLength(8));
      expect(stations.skip(8).every((s) => s.indexLevel == null), isTrue);
      expect(adapter.requests, hasLength(1 + 8));
      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1));
    });

    test('unusable or gone station list → error, retried next time', () async {
      var gone = true;
      adapter = FakeAdapter(
        (o) => gone ? jsonBody('{"Lista stacji": []}', 410) : v1(o),
      );
      final client = GiosAirClient(fakeDio(adapter));
      await expectLater(
        client.lodzStations(),
        throwsA(apiError(ApiErrorKind.badRequest)),
      );
      adapter = FakeAdapter((o) => jsonBody('{"Lista stacji": []}'));
      await expectLater(
        GiosAirClient(fakeDio(adapter)).lodzStations(),
        throwsA(apiError(ApiErrorKind.server)),
      );
      gone = false;
      expect(await client.lodzStations(), hasLength(4));
    });

    test('offline → network error, not cached', () async {
      var offline = true;
      adapter = FakeAdapter((o) {
        if (offline) {
          throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          );
        }
        return v1(o);
      });
      final client = GiosAirClient(fakeDio(adapter));
      await expectLater(
        client.lodzStations(),
        throwsA(apiError(ApiErrorKind.network)),
      );
      expect(adapter.requests, hasLength(1));
      offline = false;
      expect(await client.lodzStations(), hasLength(4));
    });

    test('timeout → timeout error', () async {
      adapter = FakeAdapter(
        (o) => throw DioException.connectionTimeout(
          timeout: apiTimeout,
          requestOptions: o,
        ),
      );
      await expectLater(
        GiosAirClient(fakeDio(adapter)).lodzStations(),
        throwsA(apiError(ApiErrorKind.timeout)),
      );
    });

    test('no Łódź stations → empty list', () async {
      adapter = FakeAdapter(
        (o) => jsonBody(
          fixture('live/gios_v1_stations.json').replaceAll('Łódź', 'Kutno'),
        ),
      );
      expect(await GiosAirClient(fakeDio(adapter)).lodzStations(), isEmpty);
    });
  });
}
