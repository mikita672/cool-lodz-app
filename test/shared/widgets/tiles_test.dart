import 'dart:ui' show Tristate;

import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/badge_tile.dart';
import 'package:cool_lodz/shared/widgets/leaderboard_row.dart';
import 'package:cool_lodz/shared/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('LetterTile', () {
    testWidgets('found and empty states have labels; tap fires', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpComponent(
        tester,
        Row(
          children: [
            LetterTile(letter: 'C', onTap: () => taps++),
            const LetterTile(),
          ],
        ),
      );
      expect(find.text('C'), findsOneWidget);
      expect(find.bySemanticsLabel('Litera C, znaleziona'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Litera jeszcze nieodkryta'),
        findsOneWidget,
      );
      expectTapAction(tester, find.byType(LetterTile).first);
      expect(tester.getSize(find.byType(LetterTile).first), const Size(48, 48));
      await tester.tap(find.text('C'));
      expect(taps, 1);
      semantics.dispose();
    });
  });

  group('BadgeTile', () {
    testWidgets('earned badge is colourful, locked one shows a lock', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpComponent(
        tester,
        Row(
          children: [
            Expanded(
              child: BadgeTile(
                icon: Icons.park_rounded,
                name: 'Łowca parków',
                earned: true,
                color: AppColors.green,
                caption: 'Zdobyta 12.10',
                onTap: () => taps++,
              ),
            ),
            const Expanded(
              child: BadgeTile(
                icon: Icons.beach_access_rounded,
                name: 'Cienista dziesiątka',
                earned: false,
                caption: '10 tras z cieniem ≥ 60%',
              ),
            ),
          ],
        ),
      );
      expect(find.text('Łowca parków'), findsOneWidget);
      expect(find.text('10 tras z cieniem ≥ 60%'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.park_rounded)).color,
        AppColors.green,
      );
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.beach_access_rounded), findsNothing);
      expect(
        find.bySemanticsLabel('Odznaka Łowca parków, zdobyta. Zdobyta 12.10'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Odznaka Cienista dziesiątka, zablokowana. 10 tras z cieniem ≥ 60%',
        ),
        findsOneWidget,
      );
      expectTapAction(tester, find.byType(BadgeTile).first);
      await tester.tap(find.text('Łowca parków'));
      expect(taps, 1);
      semantics.dispose();
    });
  });

  group('LeaderboardRow', () {
    testWidgets('normal and own rows', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const Column(
          children: [
            LeaderboardRow(rank: 1, name: 'Śródmieście', points: 12480),
            LeaderboardRow(
              rank: 14,
              name: 'cienista_ania',
              points: 420,
              own: true,
            ),
          ],
        ),
      );
      expect(find.text('Śródmieście'), findsOneWidget);
      // Polish grouping uses a non-breaking space.
      expect(find.text('12 480 pkt'), findsOneWidget);
      expect(find.text('Ty · cienista_ania'), findsOneWidget);
      expect(find.text('420 pkt'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Miejsce 14, Ty · cienista_ania, 420 punktów'),
        findsOneWidget,
      );
      final own = tester.getSemantics(find.byType(LeaderboardRow).last);
      expect(own.flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    });
  });

  group('LeaderboardRow plural and layout', () {
    testWidgets('semantics uses Polish plural forms of punkt', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const Column(
          children: [
            LeaderboardRow(rank: 1, name: 'a', points: 1),
            LeaderboardRow(rank: 2, name: 'b', points: 3),
            LeaderboardRow(rank: 3, name: 'c', points: 12),
            LeaderboardRow(rank: 4, name: 'd', points: 22),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Miejsce 1, a, 1 punkt'), findsOneWidget);
      expect(find.bySemanticsLabel('Miejsce 2, b, 3 punkty'), findsOneWidget);
      expect(find.bySemanticsLabel('Miejsce 3, c, 12 punktów'), findsOneWidget);
      expect(find.bySemanticsLabel('Miejsce 4, d, 22 punkty'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('4-digit rank and big score fit at 360 dp in Senior', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const LeaderboardRow(
          rank: 1234,
          name: 'bardzo_dlugi_pseudonim_gracza',
          points: 1234567,
          own: true,
        ),
        senior: true,
      );
      expect(tester.takeException(), isNull);
      final rank = tester.getSize(find.text('1234'));
      // One line: height equals the scaled line height (14 × 20/14 × 1.25).
      expect(rank.height, closeTo(25, 0.5));
    });
  });
}
