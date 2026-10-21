import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/heat_guard/heat_check_screen.dart';
import 'package:cool_lodz/features/symptoms/symptom_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

void main() {
  group('symptomResult', () {
    test('red flags first, then exhaustion, then ok; null until answered', () {
      expect(symptomResult([false, false, false, false, null]), isNull);
      expect(
        symptomResult([false, true, false, true, false]),
        SymptomResult.urgent,
      );
      expect(
        symptomResult([false, false, true, false, false]),
        SymptomResult.urgent,
      );
      expect(
        symptomResult([false, false, false, false, true]),
        SymptomResult.exhaustion,
      );
      expect(
        symptomResult([false, false, false, false, false]),
        SymptomResult.ok,
      );
    });
  });

  test('nearestOpenPlace skips closed places', () {
    final open = const Place(
      id: 'a',
      type: PlaceType.cool,
      lat: 51.770,
      lon: 19.46,
    );
    final closer = Place(
      id: 'b',
      type: PlaceType.cool,
      lat: 51.7701,
      lon: 19.4571,
      hours: OpeningHours(const {}), // never open
    );
    final (place, _) = nearestOpenPlace(
      [open, closer],
      const LatLng(51.7700, 19.4570),
      DateTime(2026, 7, 15, 12),
    )!;
    expect(place.id, 'a');
    expect(
      nearestOpenPlace(
        [closer],
        const LatLng(51.77, 19.457),
        DateTime(2026, 7, 15, 12),
      ),
      isNull,
    );
  });

  group('screen', () {
    late SharedPreferences prefs;
    late List<String> dialled;

    setUp(() async {
      prefs = await testPrefs();
      dialled = [];
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        const SymptomCheckScreen(),
        overrides: [
          ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 12)),
          dialEmergencyProvider.overrideWithValue(() async {
            dialled.add('112');
          }),
        ],
      );
      await tester.pumpAndSettle();
    }

    Future<void> answer(WidgetTester tester, List<bool> answers) async {
      for (final (i, yes) in answers.indexed) {
        await tester.tap(find.byKey(Key('symptom-$i-${yes ? 'yes' : 'no'}')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('confusion → 112 now, with first aid', (tester) async {
      await pump(tester);
      expect(
        find.text('Odpowiedz na wszystkie pytania, aby zobaczyć, co robić.'),
        findsOneWidget,
      );
      await answer(tester, [true, false, false, false, false]);
      expect(find.byKey(const Key('symptoms-result-urgent')), findsOneWidget);
      expect(
        find.text('Możliwy udar cieplny. Zadzwoń pod 112 teraz.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('symptoms-call')));
      expect(dialled, ['112']);
      expect(find.byKey(const Key('symptoms-nearest')), findsNothing);
    });

    testWidgets('a headache → go somewhere cool, the nearest open place', (
      tester,
    ) async {
      await pump(tester);
      await answer(tester, [false, false, false, true, false]);
      expect(
        find.byKey(const Key('symptoms-result-exhaustion')),
        findsOneWidget,
      );
      expect(find.textContaining('po 30 minutach'), findsOneWidget);
      expect(find.byKey(const Key('symptoms-nearest')), findsOneWidget);
      expect(find.text('Prowadź tam'), findsOneWidget);
    });

    testWidgets('no symptoms → advice', (tester) async {
      await pump(tester);
      await answer(tester, [false, false, false, false, false]);
      expect(find.byKey(const Key('symptoms-result-ok')), findsOneWidget);
      expect(find.text('Brak typowych objawów przegrzania.'), findsOneWidget);
    });

    testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
      await pumpSenior360(
        tester,
        const SymptomCheckScreen(),
        overrides: [
          ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
