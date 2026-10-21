import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api/live/sun.dart';
import '../api/live/weather.dart';

/// Heat stress for a person outdoors, from the feels-like temperature.
/// Steps follow the UTCI heat-stress scale: moderate from 26 °C, strong
/// from 32 °C, very strong from 38 °C.
enum HeatRiskLevel { low, moderate, high, extreme }

/// «Ryzyko upałowe dziś»: how hot it feels now and at the peak of the rest
/// of today, the hottest hours, UV and an estimate of the pavement heat.
@immutable
class HeatRisk {
  const HeatRisk({
    required this.level,
    this.feelsLikeNow,
    this.peakFeelsLike,
    this.peakAt,
    this.riskFrom,
    this.riskTo,
    this.uvMax,
    this.asphaltNow,
    this.asphaltPeak,
    this.alertLevel = 0,
  });

  /// The rest of today's highest level (at least the IMGW warning's).
  final HeatRiskLevel level;
  final double? feelsLikeNow;
  final double? peakFeelsLike;

  /// Local time of [peakFeelsLike].
  final DateTime? peakAt;

  /// The hours (local) when the level is at its highest, [riskTo]
  /// exclusive; null when the level is low or comes only from the warning.
  final DateTime? riskFrom;
  final DateTime? riskTo;

  /// The rest of today's highest UV index.
  final double? uvMax;

  /// Asphalt in the sun now and at its hottest today, °C (estimate).
  final double? asphaltNow;
  final double? asphaltPeak;

  /// The IMGW (or demo) heat warning level behind [level], 0 without one.
  final int alertLevel;
}

/// The feels-like thresholds for moderate, high and extreme. Seniors feel
/// heat sooner, so theirs are [seniorShift] lower.
const heatRiskThresholds = [26.0, 32.0, 38.0];
const seniorShift = 2.0;

HeatRiskLevel heatRiskLevelFor(double feelsLike, {bool senior = false}) {
  final shift = senior ? seniorShift : 0.0;
  var level = HeatRiskLevel.low;
  for (final (i, t) in heatRiskThresholds.indexed) {
    if (feelsLike >= t - shift) level = HeatRiskLevel.values[i + 1];
  }
  return level;
}

/// An IMGW heat warning sets the minimum: 1 → moderate, 2 → high,
/// 3 → extreme.
HeatRiskLevel heatRiskLevelForAlert(int alertLevel) =>
    HeatRiskLevel.values[alertLevel.clamp(0, 3)];

/// Asphalt in the sun (°C), estimated from the air temperature, the sun's
/// height and how much direct sun gets through the clouds: about air
/// + 27 °C in the midday summer sun (25 °C air → ~52 °C asphalt, the
/// figure vets quote), a few degrees above the air at night.
double asphaltTemperature(
  double air,
  DateTime instant, {
  WeatherForecast? forecast,
}) {
  final elevation = sunPosition(51.77, 19.46, instant).elevation;
  if (elevation <= 0) return air + 2;
  final strength = sunStrength(forecast, instant);
  final sinEl = math.sin(elevation * math.pi / 180);
  return air + 30 * strength * math.sqrt(sinEl);
}

/// Paw safety on asphalt: from 45 °C test it with the back of your hand
/// for 7 seconds; from 52 °C skin burns within a minute.
const asphaltCaution = 45.0;
const asphaltDanger = 52.0;

/// Today's heat risk from [forecast] (from the hour of [now] to midnight)
/// and the heat warning [alertLevel]. Null when there is neither.
HeatRisk? assessHeatRisk({
  required WeatherForecast? forecast,
  required DateTime now,
  bool senior = false,
  int alertLevel = 0,
}) {
  final floor = heatRiskLevelForAlert(alertLevel);
  final hours = <(DateTime, WeatherHour)>[];
  if (forecast != null) {
    final start = DateTime(now.year, now.month, now.day, now.hour);
    for (var t = start; t.day == now.day; t = t.add(const Duration(hours: 1))) {
      // The middle of each hour reads that hour's entry.
      final w = forecast.at(t.add(const Duration(minutes: 30)));
      if (w != null) hours.add((t, w));
      if (hours.length > 24) break;
    }
  }
  if (hours.isEmpty) {
    if (alertLevel <= 0) return null;
    return HeatRisk(level: floor, alertLevel: alertLevel);
  }

  double? feels(WeatherHour w) => w.apparentTemperature ?? w.temperature;
  HeatRiskLevel levelOf(WeatherHour w) {
    final f = feels(w);
    return f == null ? HeatRiskLevel.low : heatRiskLevelFor(f, senior: senior);
  }

  // The peak of the rest of today.
  DateTime? peakAt;
  double? peak;
  double? uvMax;
  double? asphaltPeak;
  var level = HeatRiskLevel.low;
  for (final (t, w) in hours) {
    final f = feels(w);
    if (f != null && (peak == null || f > peak)) {
      peak = f;
      peakAt = t;
    }
    final l = levelOf(w);
    if (l.index > level.index) level = l;
    final uv = w.uvIndex;
    if (uv != null && (uvMax == null || uv > uvMax)) uvMax = uv;
    final air = w.temperature;
    if (air != null) {
      final a = asphaltTemperature(
        air,
        t.add(const Duration(minutes: 30)),
        forecast: forecast,
      );
      if (asphaltPeak == null || a > asphaltPeak) asphaltPeak = a;
    }
  }

  // The hours at that level (first to last).
  DateTime? from;
  DateTime? to;
  if (level != HeatRiskLevel.low) {
    for (final (t, w) in hours) {
      if (levelOf(w) == level) {
        from ??= t;
        to = t.add(const Duration(hours: 1));
      }
    }
  }

  final current = hours.first.$2;
  final air = current.temperature;
  return HeatRisk(
    level: floor.index > level.index ? floor : level,
    feelsLikeNow: feels(current),
    peakFeelsLike: peak,
    peakAt: peakAt,
    riskFrom: from,
    riskTo: to,
    uvMax: uvMax,
    asphaltNow: air == null
        ? null
        : asphaltTemperature(air, now, forecast: forecast),
    asphaltPeak: asphaltPeak,
    alertLevel: alertLevel,
  );
}
