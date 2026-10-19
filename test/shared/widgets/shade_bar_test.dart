import 'package:cool_lodz/shared/widgets/shade_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('shows the percentage and announces it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(tester, const ShadeBar(percent: 72));
    expect(find.text('72%'), findsOneWidget);
    expect(find.bySemanticsLabel('72 procent trasy w cieniu'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('can hide the number and clamps the value', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const ShadeBar(percent: 140, showPercent: false),
    );
    expect(find.text('100%'), findsNothing);
    expect(find.bySemanticsLabel('100 procent trasy w cieniu'), findsOneWidget);
    semantics.dispose();
  });
}
