import 'package:cool_lodz/shared/widgets/place_sheet_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('shows details, amenities and fires both actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var navigate = 0, report = 0;
    await pumpComponent(
      tester,
      PlaceSheetContent(
        name: 'EC1 Łódź',
        subtitle: 'Centrum kultury · ul. Targowa 1/3',
        status: PlaceOpenStatus.open,
        statusText: 'Otwarte teraz',
        statusDetail: 'Dziś 10:00–19:00',
        amenities: PlaceAmenity.values,
        inQuest: true,
        onNavigate: () => navigate++,
        onReport: () => report++,
      ),
    );
    expect(find.text('EC1 Łódź'), findsOneWidget);
    expect(find.text('Centrum kultury · ul. Targowa 1/3'), findsOneWidget);
    expect(find.textContaining('Otwarte teraz'), findsOneWidget);
    expect(find.textContaining('Dziś 10:00–19:00'), findsOneWidget);
    expect(find.text('Litera do zdobycia'), findsOneWidget);
    for (final label in ['Klimatyzacja', 'Woda', 'Toaleta', 'Dostępne']) {
      expect(find.text(label), findsOneWidget);
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    await tester.tap(find.text('Prowadź tam'));
    await tester.tap(find.text('Zgłoś problem'));
    expect(navigate, 1);
    expect(report, 1);
    semantics.dispose();
  });

  testWidgets('closed place without quest has no chip', (tester) async {
    await pumpComponent(
      tester,
      PlaceSheetContent(
        name: 'Palmiarnia',
        subtitle: 'Ogród zimowy',
        status: PlaceOpenStatus.closed,
        statusText: 'Zamknięte, otwarcie o 10:00',
        onNavigate: () {},
        onReport: () {},
      ),
    );
    expect(find.textContaining('Zamknięte, otwarcie o 10:00'), findsOneWidget);
    expect(find.text('Litera do zdobycia'), findsNothing);
    expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
  });
}
