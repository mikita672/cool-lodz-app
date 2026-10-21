import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../api_client.dart';
import 'live_http.dart';
import 'sun.dart';

/// One forecast hour (Open-Meteo `hourly`, UTC).
class WeatherHour {
  const WeatherHour({
    required this.time,
    this.temperature,
    this.cloudCover,
    this.directRadiation,
  });

  /// UTC time stamp; radiation is the mean of the hour before it.
  final DateTime time;

  /// °C.
  final double? temperature;

  /// 0..100 %.
  final double? cloudCover;

  /// Direct solar radiation on a horizontal surface, W/m² (mean of the
  /// preceding hour).
  final double? directRadiation;
}

/// Hourly forecast for one place; [at] picks the hour of an instant.
class WeatherForecast {
  WeatherForecast(List<WeatherHour> hours)
    : hours = [...hours]..sort((a, b) => a.time.compareTo(b.time));

  final List<WeatherHour> hours;

  /// The entry covering [instant]: Open-Meteo stamps hourly radiation at
  /// the end of its hour, so 12:30 reads the 13:00 entry. Null outside the
  /// forecast.
  WeatherHour? at(DateTime instant) {
    final t = instant.toUtc();
    for (final h in hours) {
      if (!t.isBefore(h.time.subtract(_hour)) && t.isBefore(h.time)) return h;
    }
    return null;
  }

  static const _hour = Duration(hours: 1);
}

/// How strong direct sunlight is at an instant, 0..1: 0 at night or under
/// thick clouds, about 1 in a clear sky. Shade only matters as much as
/// this.
///
/// From the forecast's direct radiation compared with a clear-sky value
/// for the sun's height (900 W/m² × sin(elevation)); without radiation,
/// from cloud cover (Kasten–Czeplak: 1 − 0.75·(N/8)^3.4). Without a
/// forecast the sky counts as clear: the shade model then works on
/// geometry alone.
double sunStrength(
  WeatherForecast? forecast,
  DateTime instant, {
  double lat = 51.77,
  double lon = 19.46,
}) {
  final elevation = sunPosition(lat, lon, instant).elevation;
  if (elevation <= 0) return 0;
  final hour = forecast?.at(instant);
  if (hour == null) return 1;
  final direct = hour.directRadiation;
  final clearSky = 900 * math.sin(elevation * math.pi / 180);
  if (direct != null && clearSky > 50) {
    return (direct / clearSky).clamp(0.0, 1.0);
  }
  final cloud = hour.cloudCover;
  if (cloud == null) return 1;
  final octas = (cloud.clamp(0, 100) / 100) * 8;
  return (1 - 0.75 * math.pow(octas / 8, 3.4)).clamp(0.0, 1.0);
}

/// Hourly weather for Łódź from Open-Meteo (free, no key, CC BY 4.0).
class OpenMeteoClient {
  OpenMeteoClient(this._dio, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  factory OpenMeteoClient.create() => OpenMeteoClient(createLiveDio());

  static const lat = 51.77;
  static const lon = 19.46;
  static const url =
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,cloud_cover,direct_radiation'
      '&timezone=GMT&forecast_days=3';

  /// A forecast is reused for this long.
  static const maxAge = Duration(minutes: 30);

  final Dio _dio;
  final DateTime Function() _clock;
  Future<WeatherForecast>? _forecast;
  DateTime? _fetchedAt;

  /// The forecast, fetched at most every [maxAge]. Throws [ApiException];
  /// a failed fetch is retried on the next call.
  Future<WeatherForecast> forecast() {
    final fetched = _fetchedAt;
    final cached = _forecast;
    if (cached != null &&
        fetched != null &&
        _clock().difference(fetched) < maxAge) {
      return cached;
    }
    _fetchedAt = _clock();
    final future = getJson(_dio, url).then(parseOpenMeteo);
    _forecast = future;
    future
        .then<void>(
          (_) {},
          onError: (Object _) {
            if (identical(_forecast, future)) {
              _forecast = null;
              _fetchedAt = null;
            }
          },
        )
        .ignore();
    return future;
  }

  /// [forecast], or null when it cannot be had (offline): callers then
  /// assume a clear sky.
  Future<WeatherForecast?> forecastOrNull() async {
    try {
      return await forecast();
    } on ApiException {
      return null;
    }
  }
}

/// `{"hourly": {"time": ["2026-10-21T00:00", …], "temperature_2m": […],
/// "cloud_cover": […], "direct_radiation": […]}}` (times in GMT).
WeatherForecast parseOpenMeteo(Object? json) {
  final hourly = json is Map ? json['hourly'] : null;
  final times = hourly is Map ? hourly['time'] : null;
  if (times is! List || times.isEmpty) {
    throw const ApiException(ApiErrorKind.server, 'bad Open-Meteo response');
  }
  double? value(String key, int i) {
    final list = (hourly as Map)[key];
    if (list is! List || i >= list.length) return null;
    final v = list[i];
    return v is num ? v.toDouble() : null;
  }

  final hours = <WeatherHour>[];
  for (final (i, t) in times.indexed) {
    final time = t is String ? DateTime.tryParse('${t}Z') : null;
    if (time == null) continue;
    hours.add(
      WeatherHour(
        time: time,
        temperature: value('temperature_2m', i),
        cloudCover: value('cloud_cover', i),
        directRadiation: value('direct_radiation', i),
      ),
    );
  }
  return WeatherForecast(hours);
}
