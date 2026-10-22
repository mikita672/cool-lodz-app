import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'live_http.dart';

/// Pollen counted by the Open-Meteo air-quality API (CAMS Europe).
enum PollenKind { alder, birch, grass, ragweed }

enum PollenLevel { none, low, moderate, high }

/// Grains/m³ from which a pollen is moderate and high (rough allergy
/// thresholds: tree pollen is counted in larger numbers).
const pollenThresholds = <PollenKind, (double, double)>{
  PollenKind.alder: (10, 100),
  PollenKind.birch: (10, 100),
  PollenKind.grass: (20, 50),
  PollenKind.ragweed: (10, 50),
};

PollenLevel pollenLevel(PollenKind kind, double grains) {
  if (grains < 1) return PollenLevel.none;
  final (moderate, high) = pollenThresholds[kind]!;
  if (grains >= high) return PollenLevel.high;
  if (grains >= moderate) return PollenLevel.moderate;
  return PollenLevel.low;
}

/// European Air Quality Index bands: 0 very good … 5 extremely poor.
int aqiBand(double aqi) => switch (aqi) {
  < 20 => 0,
  < 40 => 1,
  < 60 => 2,
  < 80 => 3,
  < 100 => 4,
  _ => 5,
};

/// The rest of today's air: the European AQI now and at its worst, and the
/// highest count of each pollen.
@immutable
class AirToday {
  const AirToday({this.aqiNow, this.aqiMax, this.pollen = const {}});

  final double? aqiNow;
  final double? aqiMax;
  final Map<PollenKind, double> pollen;

  /// Pollen at least low, highest first.
  List<(PollenKind, PollenLevel)> get pollenLevels {
    final list = [
      for (final e in pollen.entries)
        if (pollenLevel(e.key, e.value) case final l when l != PollenLevel.none)
          (e.key, l),
    ];
    list.sort((a, b) => b.$2.index.compareTo(a.$2.index));
    return list;
  }

  bool get allergyWarning =>
      pollenLevels.any((p) => p.$2 == PollenLevel.high) || (aqiMax ?? 0) >= 60;
}

/// Open-Meteo hourly air quality JSON → today from [now]'s hour.
AirToday parseAirQuality(Object? json, DateTime now) {
  if (json is! Map) return const AirToday();
  final hourly = json['hourly'];
  if (hourly is! Map) return const AirToday();
  final times = [for (final t in hourly['time'] as List? ?? const []) '$t'];
  final from = DateTime(now.year, now.month, now.day, now.hour);
  final today = <int>[];
  for (final (i, t) in times.indexed) {
    final at = DateTime.tryParse(t);
    if (at == null || at.isBefore(from) || at.day != now.day) continue;
    today.add(i);
  }
  double? value(String key, int i) {
    final list = hourly[key];
    if (list is! List || i >= list.length) return null;
    return (list[i] as num?)?.toDouble();
  }

  double? maxOf(String key) {
    double? m;
    for (final i in today) {
      final v = value(key, i);
      if (v != null && (m == null || v > m)) m = v;
    }
    return m;
  }

  return AirToday(
    aqiNow: today.isEmpty ? null : value('european_aqi', today.first),
    aqiMax: maxOf('european_aqi'),
    pollen: {for (final k in PollenKind.values) k: ?maxOf('${k.name}_pollen')},
  );
}

class AirQualityClient {
  AirQualityClient(this._dio);

  factory AirQualityClient.create() => AirQualityClient(createLiveDio());

  static const url =
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=51.77&longitude=19.46&forecast_days=1'
      '&timezone=Europe%2FWarsaw'
      '&hourly=european_aqi,birch_pollen,grass_pollen,alder_pollen,'
      'ragweed_pollen';

  final Dio _dio;

  Future<AirToday> today(DateTime now) async =>
      parseAirQuality(await getJson(_dio, url), now);
}

/// The demo's hot July day: grass in bloom, ozone pushing the AQI up.
const demoAirToday = AirToday(
  aqiNow: 34,
  aqiMax: 58,
  pollen: {
    PollenKind.grass: 64,
    PollenKind.birch: 0,
    PollenKind.alder: 0,
    PollenKind.ragweed: 3,
  },
);
