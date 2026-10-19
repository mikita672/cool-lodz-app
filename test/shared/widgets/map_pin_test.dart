import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/app_icons.dart';
import 'package:cool_lodz/shared/widgets/map_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('each pin type has a label and a 48 dp tap area', (tester) async {
    final semantics = tester.ensureSemantics();
    final tapped = <MapPinType>[];
    await pumpComponent(
      tester,
      Wrap(
        children: [
          for (final type in MapPinType.values)
            MapPin(type: type, letter: 'Ł', onTap: () => tapped.add(type)),
        ],
      ),
    );
    for (final label in [
      'Miejsce chłodu',
      'Poidełko',
      'Ławka',
      'Litera questu Ł',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.event_seat_rounded), findsOneWidget);
    expect(find.text('Ł'), findsOneWidget);
    for (final pin in tester.widgetList(find.byType(MapPin))) {
      expect(
        tester.getSize(find.byWidget(pin)).shortestSide,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
    }
    for (final pin in MapPinType.values) {
      expectTapAction(tester, find.byType(MapPin).at(pin.index));
    }
    await tester.tap(find.bySemanticsLabel('Poidełko'));
    expect(tapped, [MapPinType.water]);
    semantics.dispose();
  });

  testWidgets('custom icons render and expose labels only when given', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const Row(
        children: [
          CoolPlaceIcon(semanticLabel: 'Miejsce chłodu'),
          WaterTapIcon(semanticLabel: 'Poidełko'),
          QuestLetterIcon(letter: 'C'),
        ],
      ),
    );
    expect(find.bySemanticsLabel('Miejsce chłodu'), findsOneWidget);
    expect(find.bySemanticsLabel('Poidełko'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.bySemanticsLabel('C'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Senior mode shows labels; cool pin glyph is dark', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Wrap(
        children: [
          for (final type in MapPinType.values) MapPin(type: type, letter: 'Ł'),
        ],
      ),
      senior: true,
    );
    for (final label in ['Chłód', 'Woda', 'Ławka', 'Litera Ł']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.widget<Icon>(find.byIcon(Icons.ac_unit_rounded)).color,
      AppColors.onSurface,
    );
  });

  testWidgets('labels are hidden by default in normal mode', (tester) async {
    await pumpComponent(tester, const MapPin(type: MapPinType.water));
    expect(find.text('Woda'), findsNothing);
  });
}
