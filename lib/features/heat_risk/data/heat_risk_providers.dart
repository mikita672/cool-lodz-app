import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/live/air_quality.dart';
import '../../../core/api/live/weather.dart';
import '../../../core/clock.dart';
import '../../../core/heat/heat_risk.dart';
import '../../../core/models/models.dart';
import '../../../core/storage/preferences.dart';
import '../../game/data/game_config_repository.dart';
import '../../profile/data/comfort_profile_provider.dart';

/// «Chodzę z psem» (Profil): hot pavement warnings for paws.
class WalksWithDog extends Notifier<bool> {
  static const prefsKey = 'walksWithDog';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(prefsKey) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(prefsKey, value);
  }
}

final walksWithDogProvider = NotifierProvider<WalksWithDog, bool>(
  WalksWithDog.new,
);

/// The forecast, or null when it cannot be had (the card then follows the
/// heat warning only).
Future<WeatherForecast?> forecastOrNull(Ref ref) async {
  try {
    return await ref.watch(forecastProvider.future);
  } catch (_) {
    return null;
  }
}

/// «Ryzyko upałowe dziś» for the user's profile (seniors: lower
/// thresholds). The map refreshes it when the app comes back to the front
/// and when the details open, as the day goes on.
final heatRiskProvider = FutureProvider<HeatRisk?>((ref) async {
  final profile = ref.watch(comfortProfileProvider);
  final alert = ref.watch(currentAlertProvider);
  final forecast = await forecastOrNull(ref);
  return assessHeatRisk(
    forecast: forecast,
    now: ref.read(clockProvider)(),
    senior: profile.id == ProfileId.senior || profile.seniorMode,
    alertLevel: alert?.level ?? 0,
  );
}, retry: noRetry);

/// Asphalt in the sun at [departure] (°C), for the paw warning on S07; null
/// without a forecast for that hour.
final asphaltAtProvider = FutureProvider.family<double?, DateTime>((
  ref,
  departure,
) async {
  final forecast = await forecastOrNull(ref);
  final air = forecast?.at(departure)?.temperature;
  if (air == null) return null;
  return asphaltTemperature(air, departure, forecast: forecast);
}, retry: noRetry);

final airQualityClientProvider = Provider<AirQualityClient>(
  (ref) => AirQualityClient.create(),
);

/// Pollen and the European AQI for the rest of today (Open-Meteo); null
/// offline. The demo has a fixed hot-day reading.
final airTodayProvider = FutureProvider<AirToday?>((ref) async {
  final now = ref.read(clockProvider)();
  if (ref.watch(isDemoModeEffectiveProvider)) return demoAirToday;
  try {
    return await ref.watch(airQualityClientProvider).today(now);
  } catch (_) {
    return null;
  }
}, retry: noRetry);
