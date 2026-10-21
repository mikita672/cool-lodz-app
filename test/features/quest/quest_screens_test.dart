import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/features/game/data/game_config_repository.dart';
import 'package:cool_lodz/features/quest/quest_scan_screen.dart';
import 'package:cool_lodz/features/quest/quest_view.dart';
import 'package:cool_lodz/l10n/app_localizations.dart';
import 'package:cool_lodz/shared/widgets/badge_unlocked_dialog.dart';
import 'package:cool_lodz/shared/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

final _now = DateTime(2026, 7, 15, 12);

/// All 7 quest places visited (any day).
Set<String> _allVisits() => {
  for (final p in [
    'cool-002',
    'cool-007',
    'cool-006',
    'cool-017',
    'cool-005',
    'cool-001',
    'cool-003',
  ])
    'u1_${p}_20260710',
};

void main() {
  late SharedPreferences prefs;
  late FakeQuestRepository quest;
  late FakeGameRepository game;
  late FakeQrScanner scanner;
  late FakeLocationService location;

  setUp(() async {
    // Demo scenarios (July alerts, demo badge thresholds): demo mode on.
    prefs = await testPrefs({DemoMode.prefsKey: true});
    quest = FakeQuestRepository();
    game = FakeGameRepository();
    scanner = FakeQrScanner();
    location = FakeLocationService(position: const LatLng(51.7791, 19.4439));
  });

  Future<void> pump(
    WidgetTester tester, {
    String initial = '/quest',
    int heatOverride = 0,
    Size size = const Size(400, 2000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/quest',
          builder: (_, _) => const Scaffold(body: QuestView()),
          routes: [
            GoRoute(path: 'scan', builder: (_, _) => const QuestScanScreen()),
          ],
        ),
        GoRoute(
          path: '/route/result',
          builder: (_, _) => const Scaffold(body: Text('S07')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appTestOverrides(
            prefs: prefs,
            quest: quest,
            game: game,
            scanner: scanner,
            location: location,
            settings: GameSettings(heatOverride: heatOverride),
          ),
          clockProvider.overrideWithValue(() => _now),
        ],
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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String?> letters(WidgetTester tester) => [
    for (final t in tester.widgetList<LetterTile>(
      find.descendant(
        of: find.byKey(const Key('quest-letters')),
        matching: find.byType(LetterTile),
      ),
    ))
      t.letter,
  ];

  group('S10', () {
    testWidgets('a visit today without points is paid when S10 opens', (
      tester,
    ) async {
      quest.visits.add('u1_cool-007_20260715');
      await pump(tester);
      expect(game.state.points, greaterThanOrEqualTo(50));
      expect(
        game.log.where((e) => e.type == PointsType.scan).single.refId,
        'cool-007',
      );
    });

    testWidgets('board with empty tiles, 0 z 7, places to visit', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Chłodne hasło'), findsOneWidget);
      expect(letters(tester), List.filled(7, null));
      expect(find.text('0 z 7 liter'), findsOneWidget);
      expect(find.text('Do odwiedzenia'), findsNWidgets(7));
      // «Wyzwanie tygodnia» above the board.
      expect(find.byKey(const Key('challenge-card')), findsOneWidget);
      expect(find.text('Wyzwanie tygodnia'), findsOneWidget);
      expect(find.text('+50 pkt'), findsOneWidget);
      expect(find.byKey(const Key('quest-scan')), findsOneWidget);
    });

    testWidgets('a visited place opens its letter', (tester) async {
      quest.visits.add('u1_cool-007_20260714');
      await pump(tester);
      expect(letters(tester), [null, 'H', null, null, null, null, null]);
      expect(find.text('1 z 7 liter'), findsOneWidget);
      expect(find.text('Odwiedzone'), findsOneWidget);
    });

    testWidgets('«Prowadź tam» on a place opens S07', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Prowadź tam').first);
      await tester.pumpAndSettle();
      expect(find.text('S07'), findsOneWidget);
    });

    testWidgets('all letters: wrong password, then CHŁODNO gives 200', (
      tester,
    ) async {
      quest.visits.addAll(_allVisits());
      await pump(tester);
      expect(find.text('7 z 7 liter'), findsOneWidget);
      expect(find.byKey(const Key('quest-scan')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('quest-password')),
        'CHLODNO',
      );
      await tester.tap(find.byKey(const Key('quest-password-check')));
      await tester.pumpAndSettle();
      expect(find.textContaining('To nie to hasło'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('quest-password')),
        'chłodno',
      );
      await tester.tap(find.byKey(const Key('quest-password-check')));
      await tester.pumpAndSettle();
      expect(game.state.points, 200);
      expect(find.byKey(const Key('quest-reward')), findsOneWidget);
      expect(find.textContaining('CHLODNO-'), findsOneWidget);
    });

    testWidgets('heat mode: hint on top, parks hidden', (tester) async {
      await pump(tester, heatOverride: 3);
      expect(find.byKey(const Key('quest-heat-hint')), findsOneWidget);
      expect(
        find.text('Dziś odwiedzaj miejsca rano lub wieczorem'),
        findsOneWidget,
      );
      // Park Staszica (cool-017) is outdoors.
      expect(find.byKey(const Key('quest-place-cool-017')), findsNothing);
      expect(
        find.textContaining('ukrywamy miejsca na słońcu: 1'),
        findsOneWidget,
      );
    });

    testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
      await pump(tester, size: const Size(360, 1600), textScale: 1.25);
      expect(tester.takeException(), isNull);
    });
  });

  group('S11', () {
    testWidgets('«Skanuj kod QR» opens the scanner with the hint', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('quest-scan')));
      await tester.pumpAndSettle();
      expect(find.byType(QuestScanScreen), findsOneWidget);
      expect(find.text('Zeskanuj kod przy wejściu'), findsOneWidget);
    });

    testWidgets('success: letter C, +50 pkt, then the badge in demo', (
      tester,
    ) async {
      await pump(tester, initial: '/quest/scan');
      scanner.scan('coollodz://quest/cool-002?c=K7M2QX');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-success')), findsOneWidget);
      // The badge dialog follows the letter after a short pause.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Nowa litera: C'), findsOneWidget);
      expect(find.text('+50 pkt'), findsOneWidget);
      // Demo mode: Strażnik chłodu after 1 place.
      expect(find.byType(BadgeUnlockedDialog), findsOneWidget);
      await tester.tap(find.text('Super!'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scan-done')));
      await tester.pumpAndSettle();
      expect(find.text('1 z 7 liter'), findsOneWidget);
    });

    testWidgets('too far: message with the distance, scan again', (
      tester,
    ) async {
      location.position = const LatLng(51.7830, 19.4439); // ~430 m
      await pump(tester, initial: '/quest/scan');
      scanner.scan('coollodz://quest/cool-002?c=K7M2QX');
      await tester.pumpAndSettle();
      expect(find.text('Jesteś za daleko od miejsca'), findsOneWidget);
      expect(find.textContaining('potrzeba do 150 m'), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan-again')));
      await tester.pumpAndSettle();
      expect(find.text('Zeskanuj kod przy wejściu'), findsOneWidget);
    });

    testWidgets('repeat today and invalid code messages', (tester) async {
      quest.visits.add('u1_cool-002_20260715');
      // That earlier scan was paid already.
      game.log.add(
        PointsEntry(
          type: PointsType.scan,
          points: 50,
          refId: 'cool-002',
          at: _now,
        ),
      );
      await pump(tester, initial: '/quest/scan');
      scanner.scan('coollodz://quest/cool-002?c=K7M2QX');
      await tester.pumpAndSettle();
      expect(find.text('Ten kod już dziś zeskanowałeś'), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan-again')));
      await tester.pumpAndSettle();
      scanner.scan('https://example.com');
      await tester.pumpAndSettle();
      expect(find.text('Kod nieważny'), findsOneWidget);
    });

    testWidgets('no camera permission: explanation and settings', (
      tester,
    ) async {
      scanner.permissionDenied = true;
      await pump(tester, initial: '/quest/scan');
      expect(find.byKey(const Key('scan-no-camera')), findsOneWidget);
      expect(find.text('Otwórz ustawienia'), findsOneWidget);
    });
  });
}
