import 'package:cool_lodz/app/routes.dart';
import 'package:cool_lodz/app/senior_mode.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/core/storage/preferences.dart';
import 'package:cool_lodz/features/heat_guard/data/heat_guard_platform.dart';
import 'package:cool_lodz/features/heat_guard/data/heat_guard_settings.dart';
import 'package:cool_lodz/features/heat_guard/heat_check_screen.dart';
import 'package:cool_lodz/features/heat_guard/heat_guard_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import 'fake_heat_guard_platform.dart';

void main() {
  late SharedPreferences prefs;
  late FakeHeatGuardPlatform platform;

  setUp(() async {
    prefs = await testPrefs();
    platform = FakeHeatGuardPlatform();
  });

  List<Override> overrides({bool senior = false}) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    heatGuardPlatformProvider.overrideWithValue(platform),
    seniorModeProvider.overrideWithValue(senior),
    locationServiceProvider.overrideWithValue(
      FakeLocationService(position: const LatLng(51.75, 19.44)),
    ),
  ];

  HeatGuardSettings saved(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(HeatGuardScreen)),
  ).read(heatGuardSettingsProvider);

  Future<void> pumpSettings(WidgetTester tester, {bool senior = false}) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      const HeatGuardScreen(),
      overrides: overrides(senior: senior),
    );
    await tester.pump();
  }

  group('settings', () {
    testWidgets('turning on asks for permissions; Senior waits 5 min', (
      tester,
    ) async {
      await pumpSettings(tester, senior: true);
      expect(find.text('Alarm jest wyłączony'), findsOneWidget);
      await tester.tap(find.byKey(const Key('heat-guard-enable')));
      await tester.pumpAndSettle();
      expect(
        platform.calls,
        containsAll([
          'request:location',
          'request:backgroundLocation',
          'request:notifications',
        ]),
      );
      expect(saved(tester).enabled, isTrue);
      expect(saved(tester).waitMinutes, HeatGuardSettings.seniorWait);
      expect(find.text('Pytaj po 5 min bez ruchu'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('without «Zezwalaj zawsze» it stays off and says why', (
      tester,
    ) async {
      platform
        ..grant = false
        ..permissions_ = const HeatGuardPermissions(
          location: true,
          notifications: true,
        );
      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('heat-guard-enable')));
      await tester.pumpAndSettle();
      expect(saved(tester).enabled, isFalse);
      expect(
        find.text(
          'Alarm potrzebuje lokalizacji «Zezwalaj zawsze» i powiadomień.',
        ),
        findsOneWidget,
      );
      // The permission list shows what to fix.
      expect(find.text('Napraw'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('contacts: a bad number is refused, a good one saved', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(
        find.text('Nikt nie dostanie SMS. Dodaj bliską osobę.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('heat-guard-add-contact')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('heat-guard-contact-name')),
        'Anna',
      );
      await tester.enterText(
        find.byKey(const Key('heat-guard-contact-phone')),
        '123',
      );
      await tester.tap(find.byKey(const Key('heat-guard-contact-save')));
      await tester.pumpAndSettle();
      expect(find.text('Podaj numer, np. 601 234 567'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('heat-guard-contact-phone')),
        '601 234 567',
      );
      await tester.tap(find.byKey(const Key('heat-guard-contact-save')));
      await tester.pumpAndSettle();
      expect(saved(tester).contacts, const [
        TrustedContact(name: 'Anna', phone: '+48601234567'),
      ]);
      expect(find.text('Anna'), findsOneWidget);
      expect(platform.calls, contains('request:sms'));
      await tester.tap(find.byTooltip('Usuń Anna'));
      await tester.pumpAndSettle();
      expect(saved(tester).contacts, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('home, wait time and «tylko w upał»', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Ustaw tutaj'));
      await tester.pumpAndSettle();
      expect(saved(tester).home, const LatLng(51.75, 19.44));
      expect(find.text('Ustawiony: w domu alarm nie pyta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('heat-guard-heat-only')));
      await tester.pumpAndSettle();
      expect(saved(tester).heatOnly, isFalse);
      await tester.drag(
        find.byKey(const Key('heat-guard-wait')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();
      expect(saved(tester).waitMinutes, HeatGuardSettings.maxWait);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('«Przetestuj alarm» runs the check without SMS', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: Routes.heatGuard,
        routes: [
          GoRoute(
            path: Routes.heatGuard,
            builder: (_, _) => const HeatGuardScreen(),
          ),
          GoRoute(
            path: Routes.heatCheck,
            builder: (_, state) => HeatCheckScreen(test: state.extra == true),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(
            locale: const Locale('pl'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('heat-guard-test')));
      await tester.pumpAndSettle();
      expect(platform.calls, containsAllInOrder(['configure', 'test']));
      expect(find.text('Wszystko w porządku?'), findsOneWidget);
      expect(find.text('To jest test alarmu.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('heat-check-ok')));
      await tester.pumpAndSettle();
      expect(find.byType(HeatGuardScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
      await pumpSenior360(
        tester,
        const HeatGuardScreen(),
        overrides: overrides(),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('check screen', () {
    Future<void> pumpCheck(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HeatCheckScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          ...overrides(),
          dialEmergencyProvider.overrideWithValue(() async {
            platform.calls.add('dial112');
          }),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('«Tak, wszystko OK» answers and closes', (tester) async {
      platform.status_ = const HeatGuardStatus(phase: HeatGuardPhase.ask);
      await pumpCheck(tester);
      expect(find.text('Wszystko w porządku?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('heat-check-ok')));
      await tester.pumpAndSettle();
      expect(platform.calls, contains('ok'));
      expect(find.byType(HeatCheckScreen), findsNothing);
    });

    testWidgets('the alarm: first aid, 112, the SMS; it closes when stopped', (
      tester,
    ) async {
      platform.status_ = const HeatGuardStatus(phase: HeatGuardPhase.ask);
      await pumpCheck(tester);
      platform.status_ = const HeatGuardStatus(
        phase: HeatGuardPhase.full,
        smsSentTo: ['Anna'],
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.text('Alarm: ta osoba nie odpowiada na pytanie aplikacji'),
        findsOneWidget,
      );
      expect(find.text('Zadzwoń pod 112.'), findsOneWidget);
      expect(find.text('SMS wysłany do: Anna'), findsOneWidget);
      // Facts only: no statement about the person's health.
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect((t.data ?? '').toLowerCase(), isNot(contains('udar')));
      }
      await tester.tap(find.byKey(const Key('heat-check-call')));
      expect(platform.calls, contains('dial112'));
      // Answered from the notification: the screen closes by itself.
      platform.status_ = const HeatGuardStatus();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(HeatCheckScreen), findsNothing);
      expect(platform.calls, contains('checkClosed'));
    });

    testWidgets('«Potrzebuję pomocy» goes straight to the alarm', (
      tester,
    ) async {
      platform.status_ = const HeatGuardStatus(phase: HeatGuardPhase.ask);
      await pumpCheck(tester);
      await tester.tap(find.byKey(const Key('heat-check-help')));
      await tester.pump();
      expect(platform.calls, contains('help'));
      expect(find.byKey(const Key('heat-check-alarm')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('heat-check-stop')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('heat-check-stop')));
      await tester.pumpAndSettle();
      expect(platform.calls, contains('ok'));
      expect(find.byType(HeatCheckScreen), findsNothing);
    });
  });
}
