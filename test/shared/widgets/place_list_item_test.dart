import 'package:cool_lodz/app/theme.dart';
import 'package:cool_lodz/shared/widgets/place_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('open place shows texts in green and fires onTap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      PlaceListItem(
        name: 'Biblioteka Miejska',
        subtitle: 'Biblioteka · 350 m',
        status: PlaceOpenStatus.open,
        statusText: 'Otwarte teraz · do 19:00',
        onTap: () => taps++,
      ),
    );
    expect(find.text('Biblioteka Miejska'), findsOneWidget);
    expect(find.text('Biblioteka · 350 m'), findsOneWidget);
    expect(find.textContaining('Otwarte teraz · do 19:00'), findsOneWidget);
    expect(find.text('Litera do zdobycia'), findsNothing);
    final node = tester.getSemantics(find.byType(PlaceListItem));
    expect(node.label, contains('Biblioteka Miejska'));
    expect(node.label, contains('Otwarte teraz'));
    expectTapAction(tester, find.byType(PlaceListItem));
    await tester.tap(find.byType(PlaceListItem));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('closed place uses error colour; quest place shows chip', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      Column(
        children: [
          PlaceListItem(
            name: 'Palmiarnia',
            subtitle: 'Palmiarnia · 1,2 km',
            status: PlaceOpenStatus.closed,
            statusText: 'Zamknięte, otwarcie o 10:00',
            onTap: () {},
          ),
          PlaceListItem(
            name: 'EC1',
            subtitle: 'Centrum kultury · 650 m',
            status: PlaceOpenStatus.open,
            statusText: 'Otwarte teraz',
            inQuest: true,
            onTap: () {},
          ),
        ],
      ),
    );
    final rich = tester.widget<RichText>(
      find.textContaining('Zamknięte, otwarcie o 10:00', findRichText: true),
    );
    TextSpan? span;
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text == 'Zamknięte, otwarcie o 10:00') span = s;
      return span == null;
    });
    expect(span!.style!.color, AppColors.error);
    expect(find.text('Litera do zdobycia'), findsOneWidget);
  });
}
