import 'package:cool_lodz/core/api/api_client.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/core/api/fallback_api_client.dart';
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

  Future<ProviderContainer> container({
    String baseUrl = 'https://api.test',
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    return ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiBaseUrlProvider.overrideWithValue(baseUrl),
        assetLoaderProvider.overrideWithValue(FixtureAssetLoader().call),
        remoteApiClientProvider.overrideWithValue(remote),
      ],
    );
  }

  setUp(() => remote = MockApiClient());

  test('no API_BASE_URL → demo client, no remote calls', () async {
    final c = await container(baseUrl: '');
    expect(c.read(apiClientProvider), isA<DemoApiClient>());
    expect(c.read(dataSourceProvider), DataSource.demo);
    await c.read(apiClientProvider).getAir();
    verifyZeroInteractions(remote);
  });

  test('with API_BASE_URL → remote with fallback', () async {
    final c = await container();
    expect(c.read(apiClientProvider), isA<FallbackApiClient>());
    expect(c.read(dataSourceProvider), DataSource.remote);
  });

  test('demo mode toggle is persisted and switches the client', () async {
    final c = await container();
    await c.read(demoModeProvider.notifier).set(true);
    expect(prefs.getBool(DemoMode.prefsKey), isTrue);
    expect(c.read(apiClientProvider), isA<DemoApiClient>());
    expect(c.read(dataSourceProvider), DataSource.demo);

    final restarted = await container(stored: {DemoMode.prefsKey: true});
    expect(restarted.read(demoModeProvider), isTrue);
  });

  test('a failed remote call shows the fallback state', () async {
    when(
      () => remote.getAlerts(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
      ),
    ).thenThrow(const ApiException(ApiErrorKind.network));
    final c = await container();
    final alerts = await c.read(apiClientProvider).getAlerts(lat: 1, lon: 2);
    expect(alerts.single.level, 2); // default demo scenario
    expect(c.read(usingFallbackProvider), isTrue);
    expect(c.read(dataSourceProvider), DataSource.fallback);
  });

  test('alert scenario provider drives the demo client', () async {
    final c = await container(baseUrl: '');
    expect(c.read(demoAlertScenarioProvider), DemoAlertScenario.level2);
    c.read(demoAlertScenarioProvider.notifier).set(DemoAlertScenario.none);
    expect(await c.read(apiClientProvider).getAlerts(lat: 1, lon: 2), isEmpty);
  });
}
