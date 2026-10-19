import 'package:cool_lodz/shared/widgets/badge_unlocked_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('opens with badge texts and closes with Super!', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showBadgeUnlockedDialog(
            context,
            icon: Icons.home_rounded,
            name: 'Strażnik chłodu',
            description: 'Odwiedziłeś 5 miejsc chłodu.',
            points: 30,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nowa odznaka!'), findsOneWidget);
    expect(find.text('Strażnik chłodu'), findsOneWidget);
    expect(find.text('Odwiedziłeś 5 miejsc chłodu.'), findsOneWidget);
    expect(find.text('+30 pkt'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(find.bySemanticsLabel('Strażnik chłodu'), findsOneWidget);
    await tester.tap(find.text('Super!'));
    await tester.pumpAndSettle();
    expect(find.byType(BadgeUnlockedDialog), findsNothing);
    semantics.dispose();
  });

  testWidgets('confetti animation runs once and finishes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 200, height: 100, child: ConfettiBurst()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
