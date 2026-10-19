import 'package:cool_lodz/shared/debug/components_showcase.dart';
import 'package:cool_lodz/shared/widgets/route_variant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/harness.dart';

void main() {
  for (final senior in [false, true]) {
    testWidgets(
      'showcase renders without overflow at 360×800 (senior: $senior)',
      (tester) async {
        await pumpComponent(
          tester,
          ComponentsShowcase(initialSenior: senior),
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(RouteVariantCard), findsNWidgets(3));
        // Scroll to the end: every section lays out without errors.
        await tester.dragUntilVisible(
          find.text('MapPin'),
          find.byType(SingleChildScrollView).first,
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scaler = MediaQuery.textScalerOf(
          tester.element(find.text('MapPin')),
        );
        expect(scaler.scale(16), closeTo(senior ? 20 : 16, 0.01));
      },
    );
  }

  testWidgets('Senior switch toggles the preview', (tester) async {
    await pumpComponent(tester, const ComponentsShowcase(), scroll: false);
    final before = tester.getSize(find.text('Najkrótsza')).height;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('Najkrótsza')).height, greaterThan(before));
  });
}
