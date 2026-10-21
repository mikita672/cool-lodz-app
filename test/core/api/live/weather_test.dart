import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/fixtures.dart';

void main() {
  group('parseOpenMeteo', () {
    test('real hourly answer (GMT)', () {
      final f = parseOpenMeteo(fixtureJson('live/open_meteo_hourly.json'));
      expect(f.hours, hasLength(48));
      expect(f.hours.first.time, DateTime.utc(2026, 10, 21));
      final noon = f.at(DateTime.utc(2026, 10, 21, 11, 30))!;
      // 11:30 UTC reads the 12:00 entry (radiation of 11–12 UTC).
      expect(noon.time, DateTime.utc(2026, 10, 21, 12));
      expect(noon.temperature, isNotNull);
      expect(noon.cloudCover, inInclusiveRange(0, 100));
      expect(noon.directRadiation, greaterThanOrEqualTo(0));
      expect(f.at(DateTime.utc(2030)), isNull);
    });

    test('garbage → server error', () {
      for (final bad in [
        null,
        'x',
        <String, Object?>{},
        {'hourly': {}},
      ]) {
        expect(
          () => parseOpenMeteo(bad),
          throwsA(isA<ApiException>()),
          reason: '$bad',
        );
      }
    });
  });

  group('sunStrength', () {
    WeatherForecast one({double? direct, double? cloud}) => WeatherForecast([
      WeatherHour(
        time: DateTime.utc(2026, 7, 15, 11),
        directRadiation: direct,
        cloudCover: cloud,
        temperature: 25,
      ),
    ]);
    final noon = DateTime.utc(2026, 7, 15, 10, 45);

    test('night is 0; no forecast is a clear sky', () {
      expect(sunStrength(null, DateTime.utc(2026, 7, 15, 22)), 0);
      expect(sunStrength(null, noon), 1);
    });

    test('from direct radiation vs. the clear-sky value', () {
      expect(sunStrength(one(direct: 800), noon), greaterThan(0.95));
      expect(sunStrength(one(direct: 200), noon), inExclusiveRange(0.2, 0.35));
      expect(sunStrength(one(direct: 0), noon), 0);
    });

    test('from cloud cover when radiation is missing', () {
      expect(sunStrength(one(cloud: 0), noon), 1);
      expect(sunStrength(one(cloud: 100), noon), closeTo(0.25, 1e-9));
      expect(sunStrength(one(cloud: 50), noon), greaterThan(0.9));
    });
  });

  group('OpenMeteoClient', () {
    test('fetches once per 30 min; a failure is retried', () async {
      var now = DateTime.utc(2026, 10, 21, 12);
      var fail = true;
      final adapter = FakeAdapter((o) {
        if (fail) {
          throw DioException.connectionError(requestOptions: o, reason: 'x');
        }
        return jsonBody(fixture('live/open_meteo_hourly.json'));
      });
      final client = OpenMeteoClient(fakeDio(adapter), clock: () => now);
      expect(await client.forecastOrNull(), isNull);
      fail = false;
      expect((await client.forecast()).hours, hasLength(48));
      await client.forecast();
      expect(adapter.requests, hasLength(2));
      now = now.add(const Duration(minutes: 31));
      await client.forecast();
      expect(adapter.requests, hasLength(3));
      expect(adapter.requests.last.uri.toString(), OpenMeteoClient.url);
    });
  });
}
