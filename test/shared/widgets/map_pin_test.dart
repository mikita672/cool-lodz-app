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
}
