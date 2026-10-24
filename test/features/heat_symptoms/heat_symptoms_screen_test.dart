import 'dart:convert';
import 'dart:io';

import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/heat_guard/heat_check_screen.dart';
import 'package:cool_lodz/features/heat_symptoms/heat_symptoms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Wording that states or suggests a user's health. The app shows only
/// facts from public sources (see docs/spec.md, «Objawy upału»).
const forbidden = [
  'możliwy udar',
  'możliwe wyczerpanie',
  'masz udar',
  'podejrzenie udaru',
  'brak typowych objawów',
  'test objawów',
  'wygląda na to, że',
  'może potrzebować pomocy',
];

void main() {
  test('nearestOpenPlace skips closed places', () {
    const open = Place(id: 'a', type: PlaceType.cool, lat: 51.770, lon: 19.46);
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
  });

  test('no UI text states or suggests the user\'s health', () {
    final arb =
        jsonDecode(File('lib/l10n/app_pl.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final MapEntry(:key, :value) in arb.entries) {
      if (key.startsWith('@') || value is! String) continue;
      for (final phrase in forbidden) {
        expect(
          value.toLowerCase(),
          isNot(contains(phrase)),
          reason: '$key: «$value»',
        );
      }
    }
  });

  group('screen', () {
    late SharedPreferences prefs;
    late List<String> dialled;
    late List<Uri> opened;

    setUp(() async {
      prefs = await testPrefs();
      dialled = [];
      opened = [];
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(
        tester,
        HeatSymptomsScreen(
          launch: (url) async {
            opened.add(url);
            return true;
          },
        ),
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

    testWidgets('information only: no questions, no yes/no, no assessment', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Objawy upału'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(Radio<bool>), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tak'), findsNothing);
      expect(find.text('Nie'), findsNothing);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final text = (t.data ?? '').toLowerCase();
        expect(text, isNot(contains('?')), reason: 'a question: $text');
        for (final phrase in forbidden) {
          expect(text, isNot(contains(phrase)));
        }
      }
    });

    testWidgets('the 112 list, first aid, the sources and the footer', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.text('Dzwoń pod 112, jeśli występuje którykolwiek z tych objawów'),
        findsOneWidget,
      );
      expect(find.text('utrata przytomności'), findsOneWidget);
      expect(find.text('pij wodę małymi łykami;'), findsOneWidget);
      expect(find.textContaining('w ciągu pół godziny'), findsOneWidget);
      expect(
        find.text(
          'Cool Łódź nie jest wyrobem medycznym, nie zastępuje porady '
          'lekarza i podaje wyłącznie informacje z publicznych źródeł.',
        ),
        findsOneWidget,
      );
      expect(find.text(HeatSymptomsSources.mz.toString()), findsOneWidget);
      expect(find.text(HeatSymptomsSources.nhs.toString()), findsOneWidget);
      await tester.tap(find.byKey(const Key('heat-symptoms-source-nhs')));
      expect(opened, [HeatSymptomsSources.nhs]);
      // The button only opens the dialer (tel:112); nothing calls by itself.
      await tester.tap(find.byKey(const Key('heat-symptoms-call')));
      expect(dialled, ['112']);
      expect(find.byKey(const Key('heat-symptoms-nearest')), findsOneWidget);
      expect(find.byKey(const Key('read-aloud')), findsOneWidget);
    });

    testWidgets('Senior ×1.25 at 360 dp has no overflow', (tester) async {
      await pumpSenior360(
        tester,
        const HeatSymptomsScreen(),
        overrides: [
          ...appTestOverrides(prefs: prefs, location: FakeLocationService()),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
