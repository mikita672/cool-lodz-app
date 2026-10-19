import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/fallback_api_client.dart';
import 'package:cool_lodz/core/api/live/live_api_client.dart';
import 'package:cool_lodz/core/storage/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late SharedPreferences prefs;
  late MockApiClient remote;
  late MockApiClient live;

  Future<ProviderContainer> container({
    String baseUrl = 'https://api.test',
    Map<String, Object> stored = const {},
    bool realLive = false,
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    return ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiBaseUrlProvider.overrideWithValue(baseUrl),
        assetLoaderProvider.overrideWithValue(FixtureAssetLoader().call),
        remoteApiClientProvider.overrideWithValue(remote),
        if (!realLive) liveApiClientProvider.overrideWithValue(live),
      ],
    );
  }

  setUp(() {
    remote = MockApiClient();
    live = MockApiClient();
  });

  test('no API_BASE_URL → live API on the phone with fallback', () async {
    when(() => live.getAir()).thenAnswer((_) async => const []);
    final c = await container(baseUrl: '');
    expect(c.read(apiClientProvider), isA<FallbackApiClient>());
    expect(c.read(isDemoModeEffectiveProvider), isFalse);
    expect(c.read(dataSourceProvider), DataSource.remote);
    // The map shade layer is still the bundled 14:30 file.
    expect(c.read(staticShadeLayerProvider), isTrue);
    await c.read(apiClientProvider).getAir();
    verify(() => live.getAir()).called(1);
    verifyZeroInteractions(remote);
  });

  test('the real live client is built when nothing overrides it', () async {
    final c = await container(baseUrl: '', realLive: true);
    expect(c.read(liveApiClientProvider), isA<LiveApiClient>());
  });

  test('with API_BASE_URL → remote with fallback', () async {
    when(() => remote.getAir()).thenAnswer((_) async => const []);
    final c = await container();
    expect(c.read(apiClientProvider), isA<FallbackApiClient>());
    expect(c.read(dataSourceProvider), DataSource.remote);
    expect(c.read(staticShadeLayerProvider), isFalse);
    await c.read(apiClientProvider).getAir();
    verify(() => remote.getAir()).called(1);
    verifyZeroInteractions(live);
  });

  test('demo mode toggle is persisted and switches the client', () async {
    for (final baseUrl in ['', 'https://api.test']) {
      final c = await container(baseUrl: baseUrl);
      await c.read(demoModeProvider.notifier).set(true);
      expect(prefs.getBool(DemoMode.prefsKey), isTrue);
      expect(c.read(apiClientProvider), isA<DemoApiClient>());
      expect(c.read(isDemoModeEffectiveProvider), isTrue);
      expect(c.read(dataSourceProvider), DataSource.demo);
      expect(c.read(staticShadeLayerProvider), isTrue);
    }

    final restarted = await container(stored: {DemoMode.prefsKey: true});
    expect(restarted.read(demoModeProvider), isTrue);
  });

  for (final baseUrl in ['', 'https://api.test']) {
    test(
      'a failed call shows the fallback state (base url "$baseUrl")',
      () async {
        for (final client in [remote, live]) {
          when(
            () => client.getAlerts(
              lat: any(named: 'lat'),
              lon: any(named: 'lon'),
            ),
          ).thenThrow(const ApiException(ApiErrorKind.network));
        }
        final c = await container(baseUrl: baseUrl);
        final alerts = await c
            .read(apiClientProvider)
            .getAlerts(lat: 1, lon: 2);
        expect(alerts, isEmpty); // no made-up warning offline
        expect(c.read(usingFallbackProvider), isTrue);
        expect(c.read(dataSourceProvider), DataSource.fallback);
        expect(c.read(staticShadeLayerProvider), isTrue);
      },
    );
  }

  test('alert scenario provider drives the demo client', () async {
    final c = await container(stored: {DemoMode.prefsKey: true});
    expect(c.read(demoAlertScenarioProvider), DemoAlertScenario.level2);
    c.read(demoAlertScenarioProvider.notifier).set(DemoAlertScenario.none);
    expect(await c.read(apiClientProvider).getAlerts(lat: 1, lon: 2), isEmpty);
  });
}
