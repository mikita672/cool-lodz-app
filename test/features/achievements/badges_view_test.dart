import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/achievements/badge_info.dart';
import 'package:cool_lodz/features/achievements/badges_view.dart';
import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/game/game_service.dart';
import 'package:cool_lodz/features/route/data/route_history_repository.dart';
import 'package:cool_lodz/shared/widgets/badge_tile.dart';
import 'package:cool_lodz/shared/widgets/badge_unlocked_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late SharedPreferences prefs;
  late FakeGameRepository repo;

  setUp(() async {
    prefs = await testPrefs();
    repo = FakeGameRepository(
      player: const PlayerState(
        nickname: 'Ala',
        points: 12480,
        badges: {GameBadge.firstStep, GameBadge.coolGuard},
      ),
    );
    repo.log.addAll([
      PointsEntry(
        type: PointsType.scan,
        points: 50,
        refId: 'cool-002',
        at: DateTime(2026, 7, 15, 14, 32),
      ),
      PointsEntry(
        type: PointsType.badge,
        points: 30,
        refId: 'coolGuard',
        at: DateTime(2026, 7, 15, 14, 32),
      ),
    ]);
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 1400)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpScreen(
      tester,
      const Scaffold(body: BadgesView()),
      overrides: [...appTestOverrides(prefs: prefs, game: repo)],
    );
  }

  testWidgets('total points, 7 badges, earned in colour', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('12\u00a0480 pkt'), findsOneWidget);
    expect(find.text('Do wydania: 12\u00a0480 pkt'), findsOneWidget);
    expect(find.byKey(const Key('badges-shop')), findsOneWidget);
    expect(find.byType(BadgeTile), findsNWidgets(7));
    BadgeTile tile(GameBadge b) =>
        tester.widget<BadgeTile>(find.byKey(Key('badge-${b.id}')));
    expect(tile(GameBadge.firstStep).earned, isTrue);
    expect(tile(GameBadge.firstStep).caption, 'Zdobyta');
    expect(tile(GameBadge.shadedTen).earned, isFalse);
    expect(
      tile(GameBadge.shadedTen).caption,
      '10 tras z co najmniej 60% cienia',
    );
  });

  testWidgets('the last points, newest first', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Odznaka: Strażnik chłodu'), findsOneWidget);
    expect(find.text('Kod QR w miejscu chłodu'), findsOneWidget);
    expect(find.text('+50 pkt'), findsOneWidget);
    expect(find.text('15.07, 14:32'), findsNWidgets(2));
  });

  testWidgets('«Twój wpływ»: walks, shade, sun avoided, water, CO₂', (
    tester,
  ) async {
    repo.routes.add((
      'u1',
      StartedRoute(
        from: const RoutePoint(lat: 51.78, lon: 19.45),
        to: const RoutePoint(lat: 51.76, lon: 19.46),
        departAt: DateTime(2026, 7, 15, 14, 30),
        variant: RouteVariantType.shaded,
        sunShare: 0.25,
        distanceM: 2000,
        durationS: 1800,
        shortestSunShare: 0.65,
        waterStops: 2,
      ),
    ));
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('impact-card')), findsOneWidget);
    expect(find.text('Twój wpływ'), findsOneWidget);
    expect(find.text('2,0 km'), findsOneWidget);
    expect(find.text('23 min'), findsOneWidget); // 30 min × 75 % shade
    expect(find.text('12 min'), findsOneWidget); // 30 min × (65 − 25) %
    expect(find.text('0,3 kg'), findsOneWidget); // 2 km × 0.17
    expect(find.text('Mniej słońca'), findsOneWidget);
  });

  testWidgets('«Twój wpływ» before any walk: a hint', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Rozpocznij spacer przyciskiem'),
      findsOneWidget,
    );
  });

  testWidgets('no points yet: a hint', (tester) async {
    repo = FakeGameRepository();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nie masz jeszcze punktów'), findsOneWidget);
    expect(find.text('0 pkt'), findsOneWidget);
  });

  testWidgets('award feedback: toast and one dialog per badge', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAwardFeedback(
              context,
              const GameAward(
                entries: [
                  PointsEntry(type: PointsType.scan, points: 50),
                  PointsEntry(type: PointsType.badge, points: 30),
                ],
                badges: {GameBadge.coolGuard},
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('+50 pkt'), findsOneWidget);
    expect(find.byType(BadgeUnlockedDialog), findsOneWidget);
    expect(find.text('Strażnik chłodu'), findsOneWidget);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pumpSenior360(
      tester,
      const Scaffold(body: BadgesView()),
      overrides: [...appTestOverrides(prefs: prefs, game: repo)],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
