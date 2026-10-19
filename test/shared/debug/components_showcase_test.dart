import 'package:cool_lodz/app/app_shell.dart';
import 'package:cool_lodz/shared/debug/components_showcase.dart';
import 'package:cool_lodz/shared/widgets/badge_unlocked_dialog.dart';
import 'package:cool_lodz/shared/widgets/route_variant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/harness.dart';

/// Scrolls through the whole page and runs [check] on every screenful.
Future<void> forEachScreen(
  WidgetTester tester,
  Future<void> Function() check,
) async {
  final scrollable = find.byType(Scrollable).first;
  while (true) {
    await check();
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final senior in [false, true]) {
    testWidgets('showcase has no overflow and meets tap target guidelines '
        'at 360×800 (senior: $senior)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        ComponentsShowcase(initialSenior: senior),
        scroll: false,
      );
      expect(find.byType(RouteVariantCard), findsNWidgets(3));
      expect(find.byType(AppNavigationBar), findsWidgets);
      final scaler = MediaQuery.textScalerOf(
        tester.element(find.byType(RouteVariantCard).first),
      );
      expect(scaler.scale(16), closeTo(senior ? 20 : 16, 0.01));

      await forEachScreen(tester, () async {
        expect(tester.takeException(), isNull);
      });
      expect(find.text('MapPin'), findsOneWidget);

      // Guidelines on a tall 360 dp view, so no target is half-scrolled
      // under the app bar (clipped nodes would be false positives).
      final extent = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent;
      tester.view.physicalSize = Size(360, extent + 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('Senior switch toggles the preview', (tester) async {
    await pumpComponent(tester, const ComponentsShowcase(), scroll: false);
    final before = tester.getSize(find.text('Najkrótsza')).height;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('Najkrótsza')).height, greaterThan(before));
  });

  testWidgets('badge dialog opened from the showcase uses Senior preview', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const ComponentsShowcase(initialSenior: true),
      scroll: false,
    );
    await tester.scrollUntilVisible(
      find.text('Nowa odznaka!'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nowa odznaka!'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(BadgeUnlockedDialog));
    expect(MediaQuery.textScalerOf(context).scale(16), closeTo(20, 0.01));
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Super!')).height,
      60,
    );
  });
}
