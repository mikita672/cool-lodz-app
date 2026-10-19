import 'dart:convert';
import 'dart:io';

import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/live/imgw_alerts.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fixtures.dart';

final now = DateTime.utc(2026, 7, 15, 10); // 12:00 in Łódź

Object? warnings() => jsonDecode(fixture('live/imgw_warningsmeteo.json'));

Map<String, Object?> heat({
  Object? id = 'X1',
  Object? level = '2',
  Object? teryt = const ['1061'],
  String from = '2026-07-15 10:00:00',
  String to = '2026-07-15 20:00:00',
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
    test('keeps current heat warnings for Łódź, highest level first', () {
      final alerts = parseImgwWarnings(warnings(), now: now);
      expect(alerts.map((a) => a.id), ['imgw-SU20261231', 'imgw-SU20261214']);

      final level3 = alerts.first;
      expect(level3.level, 3);
      expect(level3.title, 'Ostrzeżenie przed upałem 3. stopnia');
      expect(level3.validFrom.toUtc(), DateTime.utc(2026, 7, 16, 8));
      expect(level3.validTo.toUtc(), DateTime.utc(2026, 7, 17, 19));

      final level2 = alerts.last;
      expect(level2.level, 2);
      expect(level2.title, 'Ostrzeżenie przed upałem 2. stopnia');
      expect(level2.area, 'Łódź');
      expect(level2.source, 'IMGW-PIB');
      expect(level2.validFrom.toUtc(), DateTime.utc(2026, 7, 15, 8));
      expect(level2.validTo.toUtc(), DateTime.utc(2026, 7, 15, 18));
      expect(level2.officialUrl, imgwWarningsPage);
      expect(level2.isActiveAt(now), isTrue);
    });

    test('recommendations match the demo alerts', () {
      final alerts = parseImgwWarnings(warnings(), now: now);
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
      final alert = parseImgwWarnings(warnings(), now: now).last;
      final json = jsonDecode(jsonEncode(alert)) as Map<String, dynamic>;
      final demo =
          (fixtureJson('alerts_level2.json')['alerts'] as List).single
              as Map<String, dynamic>;
      expect(json.keys.toSet(), demo.keys.toSet());
      expect(Alert.fromJson(json).validTo, alert.validTo);
    });

    test('ends exactly at now → gone; later → nothing left', () {
      final atNoon = parseImgwWarnings([
        heat(to: '2026-07-15 12:00:00'),
      ], now: now);
      expect(atNoon, isEmpty);
      expect(
        parseImgwWarnings(warnings(), now: DateTime.utc(2026, 7, 18)),
        isEmpty,
      );
    });

    test('upcoming warnings are kept', () {
      final alerts = parseImgwWarnings(
        warnings(),
        now: DateTime.utc(2026, 7, 14, 6),
      );
      expect(alerts.map((a) => a.id), [
        'imgw-SU20261231',
        'imgw-SU20261214',
        'imgw-SU20261199',
        'imgw-SU20261216',
      ]);
      expect(alerts[2].recommendations, heatRecommendations[1]);
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
      expect(alerts.map((a) => a.id), ['imgw-A', 'imgw-2026-07-15T08-lodz-2']);
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
      expect(alerts, hasLength(2));
      expect(
        adapter.requests.single.uri.toString(),
        ImgwAlertsClient.warningsUrl,
      );
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
