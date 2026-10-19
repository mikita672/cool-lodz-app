import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/heat_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

Color _titleColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

void main() {
  testWidgets('renders all levels with their colours and text contrast', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      const Column(
        children: [
          HeatBanner(level: 1, subtitle: 'IMGW · do 20:00'),
          HeatBanner(level: 2),
          HeatBanner(level: 3),
        ],
      ),
    );
    for (final level in [1, 2, 3]) {
      expect(
        find.text('Ostrzeżenie przed upałem, stopień $level'),
        findsOneWidget,
      );
    }
    expect(find.text('IMGW · do 20:00'), findsOneWidget);
    expect(
      _titleColor(tester, 'Ostrzeżenie przed upałem, stopień 1'),
      AppColors.onSurface,
    );
    expect(
      _titleColor(tester, 'Ostrzeżenie przed upałem, stopień 3'),
      AppColors.onPrimary,
    );
    final colors = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(HeatBanner),
            matching: find.byType(Material),
          ),
        )
        .map((m) => m.color)
        .toList();
    expect(colors, [AppColors.heat1, AppColors.heat2, AppColors.heat3]);
  });

  testWidgets('fires onTap and has a Semantics label', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      HeatBanner(level: 2, subtitle: 'IMGW · do 20:00', onTap: () => taps++),
    );
    expect(
      find.bySemanticsLabel(
        'Ostrzeżenie przed upałem, stopień 2. IMGW · do 20:00',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(HeatBanner));
    expect(taps, 1);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    semantics.dispose();
  });
}
