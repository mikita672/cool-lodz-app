import 'live/weather.dart';

/// A hot, sunny July day in Łódź, hour by hour (local time 0–23): the demo
/// mode's weather, so the time pickers, «Kiedy najlepiej iść?» and the heat
/// risk card show the demo story's heat on any day, offline.
abstract final class DemoWeather {
  static const temperature = [
    21, 20, 20, 19, 19, 20, 22, 24, 26, 28, 30, 31, //
    32, 33, 34, 34, 33, 32, 30, 28, 26, 24, 23, 22,
  ];
  static const apparentTemperature = [
    21, 20, 20, 19, 19, 20, 23, 25, 28, 30, 32, 34, //
    35, 36, 37, 37, 36, 34, 32, 29, 27, 25, 24, 23,
  ];
  static const uvIndex = [
    0, 0, 0, 0, 0, 0, 0, 1, 2, 4, 5, 7, //
    8, 8, 7, 6, 4, 2, 1, 0, 0, 0, 0, 0,
  ];
  static const cloudCover = [
    10, 10, 5, 5, 5, 5, 5, 5, 5, 10, 10, 15, //
    20, 20, 25, 20, 15, 10, 10, 5, 5, 5, 10, 10,
  ];

  /// W/m², the mean of the hour before (as Open-Meteo stamps it).
  static const directRadiation = [
    0, 0, 0, 0, 0, 0, 30, 150, 300, 450, 560, 640, //
    680, 690, 650, 570, 460, 330, 190, 60, 5, 0, 0, 0,
  ];
  static const weatherCode = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, //
    1, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0,
  ];
  static const windSpeed = [
    6, 6, 5, 5, 5, 6, 7, 8, 9, 10, 11, 12, //
    13, 13, 14, 14, 13, 12, 10, 9, 8, 7, 7, 6,
  ];

  /// The demo day repeated for [days] days from midnight of [now]'s day
  /// (local time). Each entry is stamped at the end of its hour, like
  /// Open-Meteo's, so [WeatherForecast.at] reads hour h for h:00–h:59.
  static WeatherForecast forecast(DateTime now, {int days = 7}) {
    final midnight = DateTime(now.year, now.month, now.day);
    return WeatherForecast([
      for (var d = 0; d < days; d++)
        for (var h = 0; h < 24; h++)
          WeatherHour(
            time: DateTime(
              midnight.year,
              midnight.month,
              midnight.day + d,
              h + 1,
            ).toUtc(),
            temperature: temperature[h].toDouble(),
            apparentTemperature: apparentTemperature[h].toDouble(),
            uvIndex: uvIndex[h].toDouble(),
            cloudCover: cloudCover[h].toDouble(),
            directRadiation: directRadiation[(h + 1) % 24].toDouble(),
            weatherCode: weatherCode[h],
            windSpeed: windSpeed[h].toDouble(),
            windGusts: windSpeed[h] * 1.8,
            precipitationProbability: 0,
          ),
    ]);
  }
}
