import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/live/sun.dart';
import '../../core/api/live/weather.dart';
import '../../l10n/app_localizations.dart';

/// What the sky does in a forecast hour, from the WMO weather code (or
/// cloud cover when there is no code).
enum WeatherKind {
  clear,
  partly,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  storm;

  static WeatherKind of(WeatherHour hour) {
    final code = hour.weatherCode;
    if (code == null) {
      final cloud = hour.cloudCover ?? 0;
      return cloud < 25
          ? clear
          : cloud < 70
          ? partly
          : cloudy;
    }
    return switch (code) {
      0 || 1 => clear,
      2 => partly,
      3 => cloudy,
      45 || 48 => fog,
      >= 51 && <= 57 => drizzle,
      (>= 61 && <= 67) || (>= 80 && <= 82) => rain,
      (>= 71 && <= 77) || 85 || 86 => snow,
      >= 95 => storm,
      _ => cloudy,
    };
  }
}

/// Extra hints shown next to the sky icon.
enum WeatherTag { windy, hot, wet }

/// Wind this strong (km/h, or gusts ×1.6) counts as «wietrznie».
const windyKmh = 30.0;

/// From this temperature (°C) the hour counts as «upał».
const hotCelsius = 28.0;

/// From this chance of rain (%) the hour counts as wet.
const wetPercent = 50.0;

Set<WeatherTag> weatherTags(WeatherHour hour) => {
  if ((hour.windSpeed ?? 0) >= windyKmh ||
      (hour.windGusts ?? 0) >= windyKmh * 1.6)
    WeatherTag.windy,
  if ((hour.temperature ?? 0) >= hotCelsius) WeatherTag.hot,
  if ((hour.precipitationProbability ?? 0) >= wetPercent) WeatherTag.wet,
};

/// Whether the sun is down at [instant] in Łódź.
bool isNight(DateTime instant) =>
    sunPosition(51.77, 19.46, instant).elevation <= 0;

IconData weatherIcon(WeatherKind kind, {bool night = false}) => switch (kind) {
  WeatherKind.clear => night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
  WeatherKind.partly =>
    night ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded,
  WeatherKind.cloudy => Icons.cloud_rounded,
  WeatherKind.fog => Icons.foggy,
  WeatherKind.drizzle => Icons.grain_rounded,
  WeatherKind.rain => Icons.umbrella_rounded,
  WeatherKind.snow => Icons.ac_unit_rounded,
  WeatherKind.storm => Icons.thunderstorm_rounded,
};

Color weatherColor(WeatherKind kind, {bool night = false}) => switch (kind) {
  WeatherKind.clear ||
  WeatherKind.partly => night ? AppColors.primary : AppColors.heat2,
  WeatherKind.rain ||
  WeatherKind.drizzle ||
  WeatherKind.storm => AppColors.water,
  WeatherKind.snow => AppColors.cool,
  _ => AppColors.onSurfaceVariant,
};

String weatherLabel(
  WeatherKind kind,
  AppLocalizations l10n, {
  bool night = false,
}) => switch (kind) {
  WeatherKind.clear => night ? l10n.weatherClearNight : l10n.weatherClear,
  WeatherKind.partly => l10n.weatherPartly,
  WeatherKind.cloudy => l10n.weatherCloudy,
  WeatherKind.fog => l10n.weatherFog,
  WeatherKind.drizzle => l10n.weatherDrizzle,
  WeatherKind.rain => l10n.weatherRain,
  WeatherKind.snow => l10n.weatherSnow,
  WeatherKind.storm => l10n.weatherStorm,
};

IconData weatherTagIcon(WeatherTag tag) => switch (tag) {
  WeatherTag.windy => Icons.air_rounded,
  WeatherTag.hot => Icons.thermostat_rounded,
  WeatherTag.wet => Icons.water_drop_rounded,
};

String weatherTagLabel(
  WeatherTag tag,
  WeatherHour hour,
  AppLocalizations l10n,
) => switch (tag) {
  WeatherTag.windy => l10n.weatherWindy(
    (hour.windSpeed ?? hour.windGusts ?? 0).round(),
  ),
  WeatherTag.hot => l10n.weatherHot,
  WeatherTag.wet => l10n.weatherWet(
    (hour.precipitationProbability ?? 0).round(),
  ),
};

/// The sky icon of a forecast hour at [instant] (moon at night).
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({
    super.key,
    required this.hour,
    required this.instant,
    this.size = 24,
  });

  final WeatherHour hour;
  final DateTime instant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind = WeatherKind.of(hour);
    final night = isNight(instant);
    return Icon(
      weatherIcon(kind, night: night),
      size: size,
      color: weatherColor(kind, night: night),
      semanticLabel: weatherLabel(
        kind,
        AppLocalizations.of(context),
        night: night,
      ),
    );
  }
}

/// «☀ 23°C · Słonecznie» plus wind / heat / rain chips for one hour.
class WeatherSummary extends StatelessWidget {
  const WeatherSummary({super.key, required this.hour, required this.instant});

  final WeatherHour hour;
  final DateTime instant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = WeatherKind.of(hour);
    final night = isNight(instant);
    final tags = weatherTags(hour);
    return Row(
      key: const Key('weather-summary'),
      children: [
        WeatherIcon(hour: hour, instant: instant, size: 40),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (hour.temperature case final t?) '${t.round()}°C',
                  weatherLabel(kind, l10n, night: night),
                ].join(' · '),
                style: theme.textTheme.titleMedium,
              ),
              if (tags.isNotEmpty || hour.windSpeed != null)
                Wrap(
                  spacing: AppSizes.s12,
                  children: [
                    for (final tag in tags)
                      _Tag(
                        icon: weatherTagIcon(tag),
                        text: weatherTagLabel(tag, hour, l10n),
                        strong: true,
                      ),
                    if (!tags.contains(WeatherTag.windy) &&
                        hour.windSpeed != null)
                      _Tag(
                        icon: Icons.air_rounded,
                        text: l10n.weatherWind(hour.windSpeed!.round()),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? AppColors.onSurface : AppColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSizes.s4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
