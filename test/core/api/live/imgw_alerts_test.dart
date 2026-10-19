import 'dart:convert';
import 'dart:io';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/live/imgw_alerts.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fixtures.dart';

final now = DateTime.utc(2026, 8, 15, 12); // 14:00 in Łódź

Object? warnings() => jsonDecode(fixture('live/imgw_warningsmeteo.json'));

Map<String, Object?> heat({
  Object? id = 'X1',
  Object? level = '2',
  Object? teryt = const ['1061'],
  String from = '2026-08-15 10:00:00',
  String to = '2026-08-15 20:00:00',
}) => {
  'id': id,
  'nazwa_zdarzenia': 'Upał',
  'stopien': level,
  'obowiazuje_od': from,
  'obowiazuje_do': to,
  'teryt': teryt,
};

void main() {
  group('parseImgwWarnings', () {
    test('real feed: the heat warning for Łódź city only', () {
      // 1062 is the county around the city (powiat łódzki wschodni).
      final alerts = parseImgwWarnings(warnings(), now: now);
      expect(alerts.map((a) => a.id), ['imgw-Sk20260815100248479']);
      final alert = alerts.single;
      expect(alert.level, 1);
      expect(alert.title, 'Ostrzeżenie przed upałem 1. stopnia');
      expect(alert.area, 'Łódź');
      expect(alert.source, 'IMGW-PIB');
      expect(alert.validFrom.toUtc(), DateTime.utc(2026, 8, 15, 10, 2));
      expect(alert.validTo.toUtc(), DateTime.utc(2026, 8, 16, 16));
      expect(alert.officialUrl, imgwWarningsPage);
      expect(alert.recommendations, heatRecommendations[1]);
      expect(alert.isActiveAt(now), isTrue);
    });

    test('real "no warnings" answer is an object with a message', () {
      expect(
        parseImgwWarnings(
          jsonDecode(fixture('live/imgw_warningsmeteo_empty.json')),
          now: now,
        ),
        isEmpty,
      );
    });

    test('highest level first, then the earlier start', () {
      final alerts = parseImgwWarnings([
        heat(id: 'a', level: '2', from: '2026-08-15 13:00:00'),
        heat(id: 'b', level: '3', from: '2026-08-16 10:00:00'),
        heat(id: 'c', level: '2', from: '2026-08-15 11:00:00'),
      ], now: now);
      expect(alerts.map((a) => a.id), ['imgw-b', 'imgw-c', 'imgw-a']);
    });

    test('recommendations match the demo alerts', () {
      final alerts = parseImgwWarnings([
        heat(id: 'a', level: '3'),
        heat(id: 'b', level: '2'),
      ], now: now);
      List<String> demoTips(String file) =>
          // The bundled assets, not test/fixtures (those have short texts).
          ((jsonDecode(File('assets/demo/$file').readAsStringSync())
                      as Map<String, dynamic>)['alerts']
                  as List)
              .single['recommendations']
              .cast<String>();
      expect(alerts.first.recommendations, demoTips('alerts_level3.json'));
      expect(alerts.last.recommendations, demoTips('alerts_level2.json'));
      for (final level in [1, 2, 3]) {
        expect(heatRecommendations[level], hasLength(3));
      }
    });

    test('same JSON shape as the demo alerts', () {
      final alert = parseImgwWarnings(warnings(), now: now).single;
      final json = jsonDecode(jsonEncode(alert)) as Map<String, dynamic>;
      final demo =
          (fixtureJson('alerts_level2.json')['alerts'] as List).single
              as Map<String, dynamic>;
      expect(json.keys.toSet(), demo.keys.toSet());
      expect(Alert.fromJson(json).validTo, alert.validTo);
    });

    test('ends exactly at now → gone; later → nothing left', () {
      final atNow = parseImgwWarnings([
        heat(to: '2026-08-15 14:00:00'),
      ], now: now);
      expect(atNow, isEmpty);
      expect(
        parseImgwWarnings(warnings(), now: DateTime.utc(2026, 8, 17)),
        isEmpty,
      );
    });

    test('upcoming warnings are kept', () {
      final alerts = parseImgwWarnings(
        warnings(),
        now: DateTime.utc(2026, 8, 14, 6),
      );
      expect(alerts.map((a) => a.id), ['imgw-Sk20260815100248479']);
    });

    test('level: string or int, clamped to 1..3, missing → 1', () {
      List<int> levels(List<Object?> raw) => [
        for (final (i, l) in raw.indexed)
          ...parseImgwWarnings([
            heat(id: i, level: l),
          ], now: now).map((a) => a.level),
      ];
      expect(levels(['1', 2, ' 3 ', '4', 0, null, 'x', 2.0]), [
        1,
        2,
        3,
        3,
        1,
        1,
        1,
        2,
      ]);
    });

    test('teryt as a string, gmina codes, other counties', () {
      expect(parseImgwWarnings([heat(teryt: '1061')], now: now), hasLength(1));
      expect(
        parseImgwWarnings([heat(teryt: '1018, 1061')], now: now),
        hasLength(1),
      );
      expect(
        parseImgwWarnings([
          heat(teryt: ['1061011']),
        ], now: now),
        hasLength(1),
      );
      expect(
        parseImgwWarnings([
          heat(teryt: [1061]),
        ], now: now),
        hasLength(1),
      );
      expect(
        parseImgwWarnings([
          heat(teryt: ['1062', '1010']),
        ], now: now),
        isEmpty,
      );
      expect(parseImgwWarnings([heat(teryt: null)], now: now), isEmpty);
    });

    test('event name: case and diacritics', () {
      for (final name in ['UPAŁ', 'upal', 'Upał/Upał', 'Silny upał']) {
        expect(
          parseImgwWarnings([
            {...heat(), 'nazwa_zdarzenia': name},
          ], now: now),
          hasLength(1),
          reason: name,
        );
      }
      expect(
        parseImgwWarnings([
          {...heat(), 'nazwa_zdarzenia': 'Opady deszczu'},
        ], now: now),
        isEmpty,
      );
    });

    test('duplicate ids collapse; missing id gets a stable one', () {
      final alerts = parseImgwWarnings([
        heat(id: 'A'),
        heat(id: 'A'),
        heat(id: null),
      ], now: now);
      expect(alerts.map((a) => a.id), ['imgw-A', 'imgw-2026-08-15T08-lodz-2']);
    });

    test('a wrapper object around the list is accepted', () {
      expect(
        parseImgwWarnings({
          'warnings': [heat()],
        }, now: now),
        hasLength(1),
      );
    });

    test('not a list → server error', () {
      for (final bad in [null, 'x', 42, <String, Object?>{}]) {
        expect(
          () => parseImgwWarnings(bad, now: now),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.server,
            ),
          ),
        );
      }
    });
  });

  group('ImgwAlertsClient', () {
    test('GETs warningsmeteo and parses it', () async {
      final adapter = FakeAdapter(
        (o) => jsonBody(fixture('live/imgw_warningsmeteo.json')),
      );
      final client = ImgwAlertsClient(fakeDio(adapter));
      final alerts = await client.heatAlerts(now: now);
      expect(alerts, hasLength(1));
      expect(
        adapter.requests.single.uri.toString(),
        ImgwAlertsClient.warningsUrl,
      );
    });

    test('no warnings at all → empty list', () async {
      final client = ImgwAlertsClient(
        fakeDio(
          FakeAdapter(
            (o) => jsonBody(fixture('live/imgw_warningsmeteo_empty.json')),
          ),
        ),
      );
      expect(await client.heatAlerts(now: now), isEmpty);
    });

    Future<ApiErrorKind> failure(FakeHandler handler) async {
      final client = ImgwAlertsClient(fakeDio(FakeAdapter(handler)));
      try {
        await client.heatAlerts(now: now);
      } on ApiException catch (e) {
        return e.kind;
      }
      fail('no exception');
    }

    test('errors map like RemoteApiClient', () async {
      expect(
        await failure(
          (o) => throw DioException.receiveTimeout(
            timeout: apiTimeout,
            requestOptions: o,
          ),
        ),
        ApiErrorKind.timeout,
      );
      expect(
        await failure(
          (o) => throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          ),
        ),
        ApiErrorKind.network,
      );
      expect(await failure((o) => jsonBody('{}', 503)), ApiErrorKind.server);
      // A moved or blocked endpoint is an outage too (→ fallback).
      for (final status in [403, 404, 406, 410]) {
        expect(
          await failure((o) => jsonBody('{}', status)),
          ApiErrorKind.server,
          reason: '$status',
        );
      }
      expect(await failure((o) => jsonBody('{"a": 1}')), ApiErrorKind.server);
      expect(
        await failure(
          (o) => ResponseBody.fromString(
            '<html>',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          ),
        ),
        ApiErrorKind.server,
      );
    });
  });
}
