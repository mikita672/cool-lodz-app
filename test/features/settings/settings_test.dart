import 'dart:io';

import 'package:cool_lodz/app/app_info.dart';
import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/features/auth/data/auth_repository.dart';
import 'package:cool_lodz/features/auth/data/system_permissions.dart';
import 'package:cool_lodz/features/auth/data/user_profile_repository.dart';
import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/profile/data/comfort_profile_provider.dart';
import 'package:cool_lodz/features/settings/about_screen.dart';
import 'package:cool_lodz/features/settings/consents_settings_screen.dart';
import 'package:cool_lodz/features/settings/profile_tab_screen.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

void main() {
  late SharedPreferences prefs;
  late FakeAccountRepository account;
  late FakeAuthRepository auth;
  late FakeUserProfileRepository profiles;
  late FakeGameRepository game;
  late FakeSystemPermissions permissions;

  setUp(() async {
    prefs = await testPrefs();
    account = FakeAccountRepository();
    auth = FakeAuthRepository(
      user: const AppUser(uid: 'u1', email: 'a@b.pl'),
    );
    profiles = FakeUserProfileRepository()
      ..consents['u1'] = const Consents(
        location: true,
        push: true,
        ranking: true,
      );
    game = FakeGameRepository(
      player: const PlayerState(
        nickname: 'cienista_ania',
        district: 'polesie',
        rankingConsent: true,
        points: 1230,
      ),
    );
    permissions = FakeSystemPermissions();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    String initial = '/profile',
    Size size = const Size(400, 1200),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const ProfileTabScreen(),
          routes: [
            GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
            GoRoute(
              path: 'consents',
              builder: (_, _) => const ConsentsSettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/profile-select',
          builder: (_, _) => const Scaffold(body: Text('S04')),
        ),
        GoRoute(
          path: '/privacy',
          builder: (_, _) => const Scaffold(body: Text('Polityka')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          auth: auth,
          profiles: profiles,
          game: game,
          account: account,
        ),
        systemPermissionsProvider.overrideWithValue(permissions),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('pl'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('S16', () {
    testWidgets('header: nickname, points, district', (tester) async {
      await pump(tester);
      expect(find.text('cienista_ania'), findsOneWidget);
      expect(find.text('1\u00a0230 pkt'), findsOneWidget);
      expect(find.text('Polesie'), findsOneWidget);
      expect(find.text('Domyślny'), findsOneWidget); // comfort profile
    });

    testWidgets('choosing a district saves it', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('settings-district')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('district-srodmiescie')));
      await tester.pumpAndSettle();
      expect(account.districts.single, ('u1', 'srodmiescie'));
    });

    testWidgets('Senior switch saves the comfort profile', (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const Key('settings-senior')));
      await tester.pumpAndSettle();
      expect(c.read(comfortProfileProvider).seniorMode, isTrue);
      expect(profiles.comfortProfiles['u1']!.seniorMode, isTrue);
    });

    testWidgets('heat notifications off saves the consent', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('settings-push')));
      await tester.pumpAndSettle();
      final (uid, consents) = account.consents.single;
      expect(uid, 'u1');
      expect(consents.push, isFalse);
      expect(consents.ranking, isTrue);
    });

    testWidgets('a failed save shows an error', (tester) async {
      account.error = Exception('offline');
      await pump(tester);
      await tester.tap(find.byKey(const Key('settings-push')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nie udało się zapisać zmian'),
        findsOneWidget,
      );
    });

    testWidgets('«Mój profil komfortu» opens S04', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('settings-comfort')));
      await tester.pumpAndSettle();
      expect(find.text('S04'), findsOneWidget);
    });

    testWidgets('sign out', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('settings-sign-out')));
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
    });

    testWidgets('delete account: wrong password, then all data removed', (
      tester,
    ) async {
      await pump(tester);
      await tester.ensureVisible(find.byKey(const Key('settings-delete')));
      await tester.tap(find.byKey(const Key('settings-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Usunąć konto?'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete-password')), 'nope');
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Nieprawidłowe hasło'), findsOneWidget);
      expect(account.deletedData, isEmpty);

      await tester.enterText(
        find.byKey(const Key('delete-password')),
        'secret123',
      );
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(account.deletedData, ['u1']);
      expect(auth.deleted, ['u1']);
      expect(auth.currentUser, isNull);
      expect(find.text('Konto zostało usunięte'), findsOneWidget);
    });

    testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
      await pump(tester, size: const Size(360, 1400), textScale: 1.25);
      expect(tester.takeException(), isNull);
    });
  });

  group('Zgody i prywatność', () {
    testWidgets('withdrawing the ranking consent saves it', (tester) async {
      await pump(tester, initial: '/profile/consents');
      await tester.tap(find.byKey(const Key('settings-consent-ranking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-consents-save')));
      await tester.pumpAndSettle();
      final (_, consents) = account.consents.single;
      expect(consents.ranking, isFalse);
      expect(consents.push, isTrue);
      expect(permissions.calls, isEmpty);
    });

    testWidgets('turning location on asks for the permission', (tester) async {
      profiles.consents['u1'] = const Consents(
        location: false,
        push: false,
        ranking: false,
      );
      await pump(tester, initial: '/profile/consents');
      await tester.tap(find.byKey(const Key('settings-consent-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-consents-save')));
      await tester.pumpAndSettle();
      expect(permissions.calls, ['location']);
      expect(account.consents.single.$2.location, isTrue);
    });
  });

  group('O aplikacji', () {
    testWidgets('medical note, sources, OSM attribution', (tester) async {
      await pump(tester, initial: '/profile/about');
      expect(
        find.text(
          'Aplikacja nie jest wyrobem medycznym. '
          'W razie złego samopoczucia dzwoń 112.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('© OpenStreetMap contributors'),
        findsOneWidget,
      );
      expect(find.text('Wersja $appVersion'), findsOneWidget);
      expect(find.byKey(const Key('about-demo')), findsNothing);
    });

    testWidgets('5 taps on the version reveal the demo switch', (tester) async {
      // Tall enough that the switch is not under the navigation bar.
      final c = await pump(
        tester,
        initial: '/profile/about',
        size: const Size(400, 1600),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('about-version')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('about-demo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('about-demo')));
      await tester.pumpAndSettle();
      expect(c.read(demoModeProvider), isTrue);
      expect(prefs.getBool('demoMode'), isTrue);

      final level3 = find.byKey(const Key('about-demo-alert-level3'));
      await tester.scrollUntilVisible(
        level3,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(level3);
      await tester.pumpAndSettle();
      expect(c.read(demoAlertScenarioProvider).name, 'level3');
    });
  });

  test('app version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}
