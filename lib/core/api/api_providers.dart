import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/offline_cache.dart';
import '../storage/preferences.dart';
import 'api_client.dart';
import 'demo_api_client.dart';
import 'fallback_api_client.dart';
import 'remote_api_client.dart';

/// `--dart-define=API_BASE_URL=https://…`; empty = demo mode only.
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
  /// Live module D.
  remote,

  /// Demo mode: demo files only, no remote calls.
  demo,

  /// Remote failed, showing cached or demo data.
  fallback,
}

/// True when the app uses only demo data (toggle on or no API_BASE_URL).
final isDemoModeEffectiveProvider = Provider<bool>(
  (ref) => ref.watch(demoModeProvider) || ref.watch(apiBaseUrlProvider).isEmpty,
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

/// The client features use: Demo in demo mode, otherwise Remote with
/// fallback to cache/Demo after 8 s.
final apiClientProvider = Provider<ApiClient>((ref) {
  final demo = ref.watch(demoApiClientProvider);
  if (ref.watch(isDemoModeEffectiveProvider)) return demo;
  final flag = ref.read(usingFallbackProvider.notifier);
  return FallbackApiClient(
    remote: ref.watch(remoteApiClientProvider),
    demo: demo,
    cache: ref.watch(offlineCacheProvider),
    onFallback: flag.set,
  );
});
