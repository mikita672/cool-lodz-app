import 'dart:ui' show Tristate;

import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/route_variant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('shaded card shows all numbers, stops and fires onTap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      RouteVariantCard(
        variant: RouteVariant.shaded,
        minutes: 26,
        distanceKm: 2.1,
        shadePercent: 72,
        extraMinutes: 4,
        coolStops: 2,
        waterStops: 1,
        selected: true,
        onTap: () => taps++,
      ),
    );
    expect(find.text('Zacieniona'), findsOneWidget);
    expect(find.text('26 min · 2,1 km'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('w cieniu'), findsOneWidget);
    expect(find.text('+4 min względem najkrótszej'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    final node = tester.getSemantics(find.byType(RouteVariantCard));
    expect(node.label, contains('72 procent trasy w cieniu'));
    expect(node.label, contains('Miejsca chłodu na trasie: 2'));
    expect(node.label, contains('Poidełka na trasie: 1'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    expect(node.flagsCollection.isButton, isTrue);

    await tester.tap(find.byType(RouteVariantCard));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('shortest unselected card says Najszybsza trasa', (tester) async {
    await pumpComponent(
      tester,
      RouteVariantCard(
        variant: RouteVariant.shortest,
        minutes: 22,
        distanceKm: 1.8,
        shadePercent: 31,
        selected: false,
        onTap: () {},
      ),
    );
    expect(find.text('Najkrótsza'), findsOneWidget);
    expect(find.text('Najszybsza trasa'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(RouteVariantCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.surface);
  });

  testWidgets('compromise card is highlighted when selected', (tester) async {
    await pumpComponent(
      tester,
      RouteVariantCard(
        variant: RouteVariant.compromise,
        minutes: 24,
        distanceKm: 1.9,
        shadePercent: 54,
        extraMinutes: 2,
        selected: true,
        onTap: () {},
      ),
    );
    expect(find.text('Kompromis'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(RouteVariantCard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppColors.primaryContainer);
  });
}
