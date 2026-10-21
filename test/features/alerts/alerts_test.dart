import 'package:cool_lodz/app/app.dart';
import 'package:cool_lodz/app/router.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/api/demo_api_client.dart';
import 'package:cool_lodz/features/alerts/alert_screen.dart';
import 'package:cool_lodz/features/alerts/data/push_service.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:cool_lodz/features/cool_places/cool_places_screen.dart';
import 'package:cool_lodz/features/game/data/game_config_repository.dart';
import 'package:cool_lodz/features/symptoms/symptom_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

void main() {
  late SharedPreferences prefs;
  late FakePushService push;
  late FakeUserProfileRepository profiles;
  late List<Uri> launched;

  setUp(() async {
    // Demo scenarios (July alerts, demo badge thresholds): demo mode on.
    prefs = await testPrefs({DemoMode.prefsKey: true});
    push = FakePushService();
    profiles = FakeUserProfileRepository()..accepted['u1'] = true;
    launched = [];
  });

  /// The whole app (no start-flow redirects), opened on [location].
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    DemoAlertScenario alerts = DemoAlertScenario.level2,
    int heatOverride = 0,
    String? location,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer.test(
      overrides: appTestOverrides(
        prefs: prefs,
        push: push,
        profiles: profiles,
        settings: GameSettings(heatOverride: heatOverride),
        api: RecordingApiClient(
          demo: DemoApiClient(loadAsset: readAssetFile, alertScenario: alerts),
        ),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CoolLodzApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
    }
    return container;
  }

  group('S14', () {
    testWidgets('IMGW level 2: period, source, 3 tips, advice link', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        AlertScreen(
          launch: (url) async {
            launched.add(url);
            return true;
          },
        ),
        overrides: appTestOverrides(prefs: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ostrzeżenie przed upałem 2. stopnia'), findsOneWidget);
      // 10:00–20:00 in Poland, shown in the device's local time.
      String hm(String iso) {
        final t = DateTime.parse(iso).toLocal();
        return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      }

      expect(
        find.text(
          'Łódź · ${hm('2026-07-15T10:00:00+02:00')}–'
          '${hm('2026-07-15T20:00:00+02:00')}',
        ),
        findsOneWidget,
      );
      expect(find.text('Źródło: IMGW-PIB'), findsOneWidget);
      expect(find.textContaining('Pij wodę regularnie'), findsOneWidget);
      expect(find.byKey(const Key('alert-heat-mode')), findsNothing);

      await tester.tap(find.byKey(const Key('alert-official')));
      await tester.pumpAndSettle();
      expect(launched.single.host, 'www.gov.pl');
    });

    testWidgets('heatOverride 3 without IMGW: heat mode, «dziś»', (
      tester,
    ) async {
      await pumpApp(
        tester,
        alerts: DemoAlertScenario.none,
        heatOverride: 3,
        location: '/map/alert',
      );
      expect(find.text('Ostrzeżenie przed upałem 3. stopnia'), findsOneWidget);
      expect(find.text('Łódź · dziś'), findsOneWidget);
      expect(find.textContaining('Źródło:'), findsNothing);
      expect(find.byKey(const Key('alert-heat-mode')), findsOneWidget);
    });

    testWidgets('no alert: an empty state', (tester) async {
      await pumpApp(
        tester,
        alerts: DemoAlertScenario.none,
        location: '/map/alert',
      );
      expect(find.text('Brak ostrzeżeń przed upałem'), findsOneWidget);
    });

    testWidgets('«Pokaż miejsca chłodu» opens the Chłód tab', (tester) async {
      await pumpApp(tester, location: '/map/alert');
      // Above the bottom bar, not under it.
      await tester.scrollUntilVisible(
        find.byKey(const Key('alert-show-cool')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alert-show-cool')));
      await tester.pumpAndSettle();
      expect(find.byType(CoolPlacesScreen), findsOneWidget);
    });

    testWidgets('«Sprawdź objawy» opens the symptom check', (tester) async {
      await pumpApp(tester, location: '/map/alert');
      await tester.scrollUntilVisible(
        find.byKey(const Key('alert-symptoms')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alert-symptoms')));
      await tester.pumpAndSettle();
      expect(find.byType(SymptomCheckScreen), findsOneWidget);
    });

    testWidgets('heatOverride 2 shows the banner on the map (demo)', (
      tester,
    ) async {
      await pumpApp(tester, alerts: DemoAlertScenario.none, heatOverride: 2);
      expect(find.text('Ostrzeżenie przed upałem, stopień 2'), findsOneWidget);
    });
  });

  group('push', () {
    testWidgets('the token is saved when push is allowed', (tester) async {
      await pumpApp(tester);
      expect(profiles.tokens['u1'], 'fcm-token-1');

      push.refresh.add('fcm-token-2');
      await tester.pumpAndSettle();
      expect(profiles.tokens['u1'], 'fcm-token-2');
    });

    testWidgets('no token without push consent', (tester) async {
      profiles.consents['u1'] = const Consents(
        location: true,
        push: false,
        ranking: false,
      );
      await pumpApp(tester);
      expect(profiles.tokens, isEmpty);
    });

    testWidgets('a tapped notification opens S14', (tester) async {
      await pumpApp(tester);
      push.openedMessages.add(const PushMessage(title: 'Upał'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertScreen), findsOneWidget);
    });

    testWidgets('the notification that started the app opens S14', (
      tester,
    ) async {
      push.initialMessage = const PushMessage(title: 'Upał');
      await pumpApp(tester);
      expect(find.byType(AlertScreen), findsOneWidget);
    });

    testWidgets('a push while the app is open: banner with «Zobacz»', (
      tester,
    ) async {
      await pumpApp(tester);
      push.foregroundMessages.add(
        const PushMessage(
          title: 'Ostrzeżenie',
          body:
              'Ostrzeżenie przed upałem 2. stopnia w Łodzi do 20:00. '
              'Zobacz trasy w cieniu',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('w Łodzi do 20:00'), findsOneWidget);
      await tester.tap(find.text('Zobacz'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertScreen), findsOneWidget);
    });

    testWidgets('signed out: nothing is saved', (tester) async {
      final container = ProviderContainer.test(
        overrides: appTestOverrides(
          prefs: prefs,
          push: push,
          profiles: profiles,
          auth: FakeAuthRepository(),
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CoolLodzApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(profiles.tokens, isEmpty);
      expect(container.read(authRepositoryProvider).currentUser, isNull);
    });
  });
}
