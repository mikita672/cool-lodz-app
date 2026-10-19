import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/layer_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('shows label and icon, toggles and reports selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    bool? changed;
    await pumpComponent(
      tester,
      LayerFilterChip(
        label: 'Cień',
        icon: Icons.beach_access_rounded,
        selected: false,
        onSelected: (v) => changed = v,
      ),
    );
    expect(find.text('Cień'), findsOneWidget);
    expect(find.byIcon(Icons.beach_access_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(FilterChip)),
      matchesSemantics(
        label: 'Cień',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('Cień'));
    expect(changed, isTrue);
    expect(
      tester.getSize(find.byType(FilterChip)).height,
      greaterThanOrEqualTo(AppSizes.minTouchTarget),
    );
    semantics.dispose();
  });

  testWidgets('selected chip uses white icon', (tester) async {
    await pumpComponent(
      tester,
      LayerFilterChip(
        label: 'Cień',
        icon: Icons.beach_access_rounded,
        selected: true,
        onSelected: (_) {},
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.beach_access_rounded));
    expect(icon.color, AppColors.onPrimary);
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, true);
  });
}
