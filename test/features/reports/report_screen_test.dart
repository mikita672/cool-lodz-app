import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/game/game_service.dart';
import 'package:cool_lodz/features/reports/data/report_repository.dart';
import 'package:cool_lodz/features/reports/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

const _manufaktura = Place(
  id: 'cool-002',
  type: PlaceType.cool,
  name: 'Manufaktura',
  lat: 51.7791,
  lon: 19.4439,
);

void main() {
  late SharedPreferences prefs;
  late FakeReportRepository reports;
  late FakeLocationService location;

  setUp(() async {
    prefs = await testPrefs();
    reports = FakeReportRepository();
    location = FakeLocationService(position: const LatLng(51.765, 19.457));
  });

  Future<void> pump(WidgetTester tester, {Place? place}) {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpScreen(
      tester,
      ReportScreen(place: place),
      overrides: appTestOverrides(
        prefs: prefs,
        reports: reports,
        location: location,
      ),
    );
  }

  testWidgets('a type is required', (tester) async {
    await pump(tester, place: _manufaktura);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    expect(find.text('Wybierz rodzaj problemu'), findsOneWidget);
    expect(reports.created, isEmpty);
  });

  testWidgets('from S08: the place position, type and comment are sent', (
    tester,
  ) async {
    await pump(tester, place: _manufaktura);
    await tester.pumpAndSettle();
    expect(find.text('Manufaktura'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-type-noShade')));
    await tester.enterText(
      find.byKey(const Key('report-comment')),
      '  Brak drzew przy wejściu  ',
    );
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();

    final r = reports.created.single;
    expect(r.type, ReportType.noShade);
    expect(r.lat, 51.7791);
    expect(r.lon, 19.4439);
    expect(r.comment, contains('Brak drzew przy wejściu'));
    expect(find.text('Dziękujemy!'), findsOneWidget);
    expect(find.text('+20 pkt po zatwierdzeniu'), findsOneWidget);
  });

  testWidgets('without a place the GPS position is used', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-type-noBench')));
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    expect(reports.created.single.lat, 51.765);
  });

  testWidgets('a failed send keeps the form', (tester) async {
    reports.error = Exception('offline');
    await pump(tester, place: _manufaktura);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-type-other')));
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nie udało się wysłać zgłoszenia'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-send')), findsOneWidget);
  });

  testWidgets('the comment is limited to 200 characters', (tester) async {
    await pump(tester, place: _manufaktura);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('report-comment')), 'x' * 250);
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('report-comment')),
    );
    expect(field.controller!.text.length, 200);
  });

  group('points after approval', () {
    test('20 per approved report once; Pomocnik miasta after 3', () async {
      final game = FakeGameRepository();
      final c = ProviderContainer.test(
        overrides: appTestOverrides(prefs: prefs, game: game),
      );
      final service = c.read(gameServiceProvider);

      game.approvedReportIds.addAll({'r1', 'r2'});
      final first = await service.syncReports();
      expect(first.pointsFor(PointsType.report), 40);
      expect(first.badges, isEmpty);

      expect((await service.syncReports()).points, 0);

      game.approvedReportIds.add('r3');
      final third = await service.syncReports();
      expect(third.pointsFor(PointsType.report), 20);
      expect(third.badges, {GameBadge.cityHelper});
    });
  });
}
