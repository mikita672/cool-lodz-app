import 'package:cool_lodz/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('primary button shows label and icon and fires onPressed', (
    tester,
  ) async {
    var taps = 0;
    await pumpComponent(
      tester,
      AppButton(
        label: 'Prowadź tam',
        icon: Icons.navigation_rounded,
        onPressed: () => taps++,
      ),
    );
    expect(find.text('Prowadź tam'), findsOneWidget);
    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expectTapAction(tester, find.byType(AppButton));
    semantics.dispose();
    await tester.tap(find.text('Prowadź tam'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(FilledButton)).height, 52);
  });

  testWidgets('Senior theme makes buttons 60 dp high', (tester) async {
    await pumpComponent(
      tester,
      Column(
        children: [
          AppButton(label: 'A', onPressed: () {}),
          AppButton(
            label: 'B',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
          AppButton(
            label: 'C',
            variant: AppButtonVariant.text,
            onPressed: () {},
          ),
        ],
      ),
      senior: true,
    );
    expect(tester.getSize(find.byType(FilledButton)).height, 60);
    expect(tester.getSize(find.byType(OutlinedButton)).height, 60);
    expect(tester.getSize(find.byType(TextButton)).height, 60);
  });

  testWidgets('loading shows a spinner, ignores taps and is announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      AppButton(label: 'Zapisz', loading: true, onPressed: () => taps++),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Zapisz'));
    expect(taps, 0);
    final node = tester.getSemantics(find.byType(AppButton)).getSemanticsData();
    expect(node.value, 'Ładowanie');
    expect(node.label, contains('Zapisz'));
    semantics.dispose();
  });

  testWidgets('expand stretches to full width', (tester) async {
    await pumpComponent(
      tester,
      AppButton(
        label: 'Zgłoś problem',
        variant: AppButtonVariant.secondary,
        expand: true,
        onPressed: () {},
      ),
    );
    expect(tester.getSize(find.byType(OutlinedButton)).width, 328);
  });
}
