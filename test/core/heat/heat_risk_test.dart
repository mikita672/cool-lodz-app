import 'package:cool_lodz/core/api/demo_weather.dart';
import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:cool_lodz/core/heat/heat_risk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels follow the UTCI steps; seniors 2 °C sooner', () {
    expect(heatRiskLevelFor(25.9), HeatRiskLevel.low);
    expect(heatRiskLevelFor(26), HeatRiskLevel.moderate);
    expect(heatRiskLevelFor(32), HeatRiskLevel.high);
    expect(heatRiskLevelFor(38), HeatRiskLevel.extreme);
    expect(heatRiskLevelFor(24.5, senior: true), HeatRiskLevel.moderate);
    expect(heatRiskLevelFor(36, senior: true), HeatRiskLevel.extreme);
    expect(heatRiskLevelForAlert(0), HeatRiskLevel.low);
    expect(heatRiskLevelForAlert(2), HeatRiskLevel.high);
    expect(heatRiskLevelForAlert(5), HeatRiskLevel.extreme);
  });

  group('the demo hot day', () {
    final now = DateTime(2026, 7, 15, 10, 20);
    final forecast = DemoWeather.forecast(now);

    test('peak, hottest hours, UV and asphalt for the rest of today', () {
      final risk = assessHeatRisk(forecast: forecast, now: now)!;
      expect(risk.level, HeatRiskLevel.high); // 37 °C feels like
      expect(risk.feelsLikeNow, 32);
      expect(risk.peakFeelsLike, 37);
      expect(risk.peakAt, DateTime(2026, 7, 15, 14));
      // Feels like ≥ 32 °C from 10:00 to 18:59.
      expect(risk.riskFrom, DateTime(2026, 7, 15, 10));
      expect(risk.riskTo, DateTime(2026, 7, 15, 19));
      expect(risk.uvMax, 8);
      expect(risk.asphaltPeak, greaterThan(asphaltDanger));
    });

    test('a senior: very high from 36 °C', () {
      final risk = assessHeatRisk(forecast: forecast, now: now, senior: true)!;
      expect(risk.level, HeatRiskLevel.extreme);
      expect(risk.riskFrom, DateTime(2026, 7, 15, 13));
      expect(risk.riskTo, DateTime(2026, 7, 15, 17));
    });

    test('late evening: only the hours left count', () {
      final evening = DateTime(2026, 7, 15, 21, 10);
      final risk = assessHeatRisk(forecast: forecast, now: evening)!;
      expect(risk.level, HeatRiskLevel.low);
      expect(risk.peakFeelsLike, 25);
      expect(risk.riskFrom, isNull);
      // An IMGW warning keeps the level up.
      final warned = assessHeatRisk(
        forecast: forecast,
        now: evening,
        alertLevel: 2,
      )!;
      expect(warned.level, HeatRiskLevel.high);
      expect(warned.alertLevel, 2);
    });
  });

  test('without a forecast: the warning alone, or nothing', () {
    final now = DateTime(2026, 7, 15, 12);
    expect(assessHeatRisk(forecast: null, now: now), isNull);
    final risk = assessHeatRisk(forecast: null, now: now, alertLevel: 3)!;
    expect(risk.level, HeatRiskLevel.extreme);
    expect(risk.peakFeelsLike, isNull);
  });

  test('a cool autumn day is low', () {
    final now = DateTime(2026, 10, 21, 9);
    final forecast = WeatherForecast([
      for (var h = 0; h < 24; h++)
        WeatherHour(
          time: DateTime(2026, 10, 21, h + 1).toUtc(),
          temperature: 14,
          apparentTemperature: 12,
          uvIndex: 2,
        ),
    ]);
    final risk = assessHeatRisk(forecast: forecast, now: now)!;
    expect(risk.level, HeatRiskLevel.low);
    expect(risk.uvMax, 2);
  });

  test('asphalt: ~+27 °C in the midday summer sun, little at night', () {
    final noon = DateTime.utc(2026, 7, 15, 11);
    final hot = asphaltTemperature(25, noon);
    expect(hot, inInclusiveRange(50, 56)); // vets: 25 °C air → ~52 °C
    expect(asphaltTemperature(25, DateTime.utc(2026, 7, 15, 23)), 27);
    // Thick clouds: hardly warmer than the air.
    final cloudy = WeatherForecast([
      WeatherHour(
        time: DateTime.utc(2026, 7, 15, 12),
        temperature: 25,
        directRadiation: 0,
      ),
    ]);
    expect(
      asphaltTemperature(
        25,
        noon.add(const Duration(minutes: 30)),
        forecast: cloudy,
      ),
      25,
    );
  });
}
