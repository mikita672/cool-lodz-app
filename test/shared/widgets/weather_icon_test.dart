import 'package:cool_lodz/core/api/live/weather.dart';
import 'package:cool_lodz/shared/widgets/weather_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WeatherHour _h({
  int? code,
  double? cloud,
  double? temp,
  double? wind,
  double? gusts,
  double? rain,
}) => WeatherHour(
  time: DateTime.utc(2026, 7, 15, 12),
  weatherCode: code,
  cloudCover: cloud,
  temperature: temp,
  windSpeed: wind,
  windGusts: gusts,
  precipitationProbability: rain,
);

void main() {
  test('WMO codes → sky', () {
    expect(WeatherKind.of(_h(code: 0)), WeatherKind.clear);
    expect(WeatherKind.of(_h(code: 2)), WeatherKind.partly);
    expect(WeatherKind.of(_h(code: 3)), WeatherKind.cloudy);
    expect(WeatherKind.of(_h(code: 45)), WeatherKind.fog);
    expect(WeatherKind.of(_h(code: 53)), WeatherKind.drizzle);
    expect(WeatherKind.of(_h(code: 63)), WeatherKind.rain);
    expect(WeatherKind.of(_h(code: 81)), WeatherKind.rain);
    expect(WeatherKind.of(_h(code: 73)), WeatherKind.snow);
    expect(WeatherKind.of(_h(code: 96)), WeatherKind.storm);
    // Without a code: cloud cover.
    expect(WeatherKind.of(_h(cloud: 10)), WeatherKind.clear);
    expect(WeatherKind.of(_h(cloud: 50)), WeatherKind.partly);
    expect(WeatherKind.of(_h(cloud: 90)), WeatherKind.cloudy);
  });

  test('tags: windy, hot, wet', () {
    expect(weatherTags(_h(wind: 10, temp: 20, rain: 10)), isEmpty);
    expect(weatherTags(_h(wind: 32)), {WeatherTag.windy});
    expect(weatherTags(_h(gusts: 55)), {WeatherTag.windy});
    expect(weatherTags(_h(temp: 31, rain: 70)), {
      WeatherTag.hot,
      WeatherTag.wet,
    });
  });

  test('moon at night, sun by day', () {
    expect(weatherIcon(WeatherKind.clear), Icons.wb_sunny_rounded);
    expect(weatherIcon(WeatherKind.clear, night: true), Icons.nightlight_round);
    expect(isNight(DateTime.utc(2026, 7, 15, 10)), isFalse);
    expect(isNight(DateTime.utc(2026, 7, 15, 22)), isTrue);
  });
}
