import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/leaderboard/data/ranking_repository.dart';
import 'package:cool_lodz/features/leaderboard/ranking_view.dart';
import 'package:cool_lodz/shared/widgets/leaderboard_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  late SharedPreferences prefs;
  late FakeRankingRepository ranking;
  late FakeGameRepository game;

  setUp(() async {
    prefs = await testPrefs();
    ranking = FakeRankingRepository()
      ..weekDistricts = {'srodmiescie': 420, 'polesie': 300, 'baluty': 50}
      ..summerDistricts = {'polesie': 5000, 'srodmiescie': 4000}
      ..weekUsers = [
        for (var i = 0; i < 40; i++)
          RankingEntry(id: 'x$i', name: 'Gracz $i', points: 1000 - i * 10),
      ]
      ..summerUsers = const [
        RankingEntry(id: 'u1', name: 'Ala', points: 900),
        RankingEntry(id: 'b', name: 'Bartek', points: 500),
      ];
    game = FakeGameRepository(
      player: const PlayerState(
        nickname: 'Ala',
        district: 'polesie',
        rankingConsent: true,
        points: 900,
        weekId: '2026-W29',
        weekPoints: 5,
      ),
    );
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpScreen(
      tester,
      const Scaffold(body: RankingView()),
      overrides: [
        ...appTestOverrides(prefs: prefs, game: game, ranking: ranking),
        // 2026-07-15 is in ISO week 2026-W29.
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 12)),
      ],
    );
  }

  List<LeaderboardRow> rows(WidgetTester tester) => tester
      .widgetList<LeaderboardRow>(
        find.descendant(
          of: find.byKey(const Key('ranking-list')),
          matching: find.byType(LeaderboardRow),
        ),
      )
      .toList();

  testWidgets('districts this week, own district highlighted', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    final r = rows(tester);
    expect(r.map((e) => e.name).take(3), ['Śródmieście', 'Polesie', 'Bałuty']);
    expect(r.length, 5);
    expect(r[1].own, isTrue);
    expect(find.byKey(const Key('ranking-own-pinned')), findsNothing);
  });

  testWidgets('districts all summer', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ranking-period-summer')));
    await tester.pumpAndSettle();
    expect(rows(tester).first.name, 'Polesie');
    expect(rows(tester).first.points, 5000);
  });

  testWidgets('users all summer: own row highlighted in the list', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Użytkownicy'));
    await tester.tap(find.byKey(const Key('ranking-period-summer')));
    await tester.pumpAndSettle();
    final r = rows(tester);
    expect(r.first.name, 'Ala');
    expect(r.first.own, isTrue);
    expect(find.byKey(const Key('ranking-own-pinned')), findsNothing);
  });

  testWidgets('users this week: not in the top list → pinned at the bottom', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Użytkownicy'));
    await tester.pumpAndSettle();
    final pinned = tester.widget<LeaderboardRow>(
      find.byKey(const Key('ranking-own-pinned')),
    );
    expect(pinned.own, isTrue);
    expect(pinned.rank, 41);
    expect(pinned.points, 5);
  });

  testWidgets('without ranking consent the user is not listed', (tester) async {
    game.state = const PlayerState(
      nickname: 'Ala',
      district: 'polesie',
      points: 900,
    );
    ranking.summerUsers = const [
      RankingEntry(id: 'b', name: 'Bartek', points: 500),
    ];
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Użytkownicy'));
    await tester.tap(find.byKey(const Key('ranking-period-summer')));
    await tester.pumpAndSettle();
    expect(rows(tester).map((r) => r.name), ['Bartek']);
    expect(rows(tester).any((r) => r.own), isFalse);
    expect(find.byKey(const Key('ranking-own-pinned')), findsNothing);
    expect(find.textContaining('Nie bierzesz udziału'), findsOneWidget);
  });

  testWidgets('no district chosen: a hint', (tester) async {
    game.state = const PlayerState(nickname: 'Ala');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Wybierz dzielnicę w Profilu'), findsOneWidget);
  });

  testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
    await pumpSenior360(
      tester,
      const Scaffold(body: RankingView()),
      overrides: [
        ...appTestOverrides(prefs: prefs, game: game, ranking: ranking),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Użytkownicy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('district names follow GameConfig', () {
    expect(districtName('srodmiescie'), 'Śródmieście');
    expect(districtName('unknown'), 'unknown');
  });
}
