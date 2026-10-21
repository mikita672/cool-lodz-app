import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/offline_cache.dart';
import '../storage/preferences.dart';
import 'api_client.dart';
import 'demo_api_client.dart';
import 'fallback_api_client.dart';
import 'live/live_api_client.dart';
import 'live/weather.dart';
import 'remote_api_client.dart';

/// `retry:` for data providers: no automatic retries. Screens show the error
/// with a «Spróbuj ponownie» button, and the API client already falls back
/// to cached/demo data after 8 s.
Duration? noRetry(int retryCount, Object error) => null;

/// `--dart-define=API_BASE_URL=https://…` (module D server); empty = the
/// live API on the phone ([LiveApiClient]).
final apiBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('API_BASE_URL'),
);

final assetLoaderProvider = Provider<AssetLoader>(
  (ref) => rootBundle.loadString,
);

/// Demo mode chosen by the user (hidden toggle, APP-19), saved on device.
class DemoMode extends Notifier<bool> {
  static const prefsKey = 'demoMode';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(prefsKey) ?? false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(prefsKey, enabled);
  }
}

final demoModeProvider = NotifierProvider<DemoMode, bool>(DemoMode.new);

/// Which alert file the demo serves. Default level 2 (demo scenario).
class DemoAlertScenarioNotifier extends Notifier<DemoAlertScenario> {
  @override
  DemoAlertScenario build() => DemoAlertScenario.level2;

  void set(DemoAlertScenario scenario) => state = scenario;
}

final demoAlertScenarioProvider =
    NotifierProvider<DemoAlertScenarioNotifier, DemoAlertScenario>(
      DemoAlertScenarioNotifier.new,
    );

/// True while the last remote call failed and cached/demo data is shown.
/// For the banner (`apiFallbackBanner`) watch [dataSourceProvider] ==
/// [DataSource.fallback]: it also accounts for demo mode.
class UsingFallback extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final usingFallbackProvider = NotifierProvider<UsingFallback, bool>(
  UsingFallback.new,
);

enum DataSource {
  /// Live data: module D, or the live API on the phone without a server.
  remote,

  /// Demo mode: demo files only, no remote calls.
  demo,

  /// Remote failed, showing cached or demo data.
  fallback,
}

/// True when the app uses only demo data: the hidden toggle (APP-19) is on.
/// Without API_BASE_URL the app is live too (on-phone API), not demo.
final isDemoModeEffectiveProvider = Provider<bool>(
  (ref) => ref.watch(demoModeProvider),
);

/// True when the map's shade layer is the bundled 14:30 file: in demo mode,
/// and after a fallback from module D. The on-phone API draws it for any
/// time even offline (another source failing does not matter).
final staticShadeLayerProvider = Provider<bool>(
  (ref) =>
      ref.watch(isDemoModeEffectiveProvider) ||
      (ref.watch(apiBaseUrlProvider).isNotEmpty &&
          ref.watch(dataSourceProvider) == DataSource.fallback),
);

final dataSourceProvider = Provider<DataSource>((ref) {
  if (ref.watch(isDemoModeEffectiveProvider)) return DataSource.demo;
  return ref.watch(usingFallbackProvider)
      ? DataSource.fallback
      : DataSource.remote;
});

final demoApiClientProvider = Provider<DemoApiClient>(
  (ref) => DemoApiClient(
    loadAsset: ref.watch(assetLoaderProvider),
    alertScenario: ref.watch(demoAlertScenarioProvider),
  ),
);

final remoteApiClientProvider = Provider<ApiClient>(
  (ref) => RemoteApiClient.create(ref.watch(apiBaseUrlProvider)),
);

/// Bundled files for places, layers and the quest; the live API reads them
/// too, so it does not depend on the demo alert scenario.
final bundledApiClientProvider = Provider<DemoApiClient>(
  (ref) => DemoApiClient(loadAsset: ref.watch(assetLoaderProvider)),
);

/// Hourly Open-Meteo forecast for Łódź, shared by the routes, the shade
/// layer and the map's shade pill.
final weatherClientProvider = Provider<OpenMeteoClient>(
  (ref) => OpenMeteoClient.create(),
);

/// The Open-Meteo forecast for the time pickers' weather; null in demo
/// mode (offline and repeatable) or when it cannot be had.
final forecastProvider = FutureProvider<WeatherForecast?>((ref) {
  if (ref.watch(isDemoModeEffectiveProvider)) return null;
  return ref.watch(weatherClientProvider).forecastOrNull();
}, retry: noRetry);

final liveApiClientProvider = Provider<ApiClient>(
  (ref) => LiveApiClient.create(
    ref.watch(bundledApiClientProvider),
    weather: ref.watch(weatherClientProvider),
  ),
);

/// The client features use: Demo when the hidden demo toggle is on; Remote
/// when API_BASE_URL is set; otherwise Live (on the phone). Remote and Live
/// fall back to cache/Demo after 8 s or on network errors.
final apiClientProvider = Provider<ApiClient>((ref) {
  final demo = ref.watch(demoApiClientProvider);
  if (ref.watch(isDemoModeEffectiveProvider)) return demo;
  final flag = ref.read(usingFallbackProvider.notifier);
  return FallbackApiClient(
    remote: ref.watch(apiBaseUrlProvider).isEmpty
        ? ref.watch(liveApiClientProvider)
        : ref.watch(remoteApiClientProvider),
    demo: demo,
    cache: ref.watch(offlineCacheProvider),
    onFallback: flag.set,
  );
});
