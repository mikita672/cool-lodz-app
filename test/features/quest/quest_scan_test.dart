import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/location/location_service.dart';
import 'package:cool_lodz/features/quest/data/quest_repository.dart';
import 'package:cool_lodz/features/quest/data/quest_scan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Manufaktura (cool-002), the first quest place, letter C.
const _manufaktura = LatLng(51.7791, 19.4439);
const _okCode = 'coollodz://quest/cool-002?c=K7M2QX';

void main() {
  late FakeLocationService location;
  late FakeQuestRepository quest;
  late FakeGameRepository game;
  late DateTime now;

  setUp(() {
    location = FakeLocationService(position: _manufaktura);
    quest = FakeQuestRepository();
    game = FakeGameRepository();
    now = DateTime(2026, 7, 15, 12);
  });

  Future<QuestScanService> service({bool demo = false}) async {
    final c = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: await testPrefs(),
          location: location,
          quest: quest,
          game: game,
        ),
        clockProvider.overrideWithValue(() => now),
        isDemoModeEffectiveProvider.overrideWithValue(demo),
      ],
    );
    return c.read(questScanServiceProvider);
  }

  test('a valid scan at the door: letter C and +50', () async {
    final result = await (await service()).scan(_okCode);
    expect(result, isA<ScanSuccess>());
    final success = result as ScanSuccess;
    expect(success.stop.letter, 'C');
    expect(success.award.pointsFor(PointsType.scan), 50);
    expect(quest.visits, {'u1_cool-002_20260715'});
    expect(game.state.points, 50);
  });

  test('a second scan of the same place today is rejected', () async {
    final s = await service();
    await s.scan(_okCode);
    final again = await s.scan(_okCode);
    expect((again as ScanFailure).problem, ScanProblem.alreadyToday);
    expect(game.state.points, 50);
  });

  test('the same place tomorrow counts again', () async {
    final s = await service();
    await s.scan(_okCode);
    now = now.add(const Duration(days: 1));
    expect(await s.scan(_okCode), isA<ScanSuccess>());
  });

  test('more than 150 m away is rejected', () async {
    // ~200 m north of Manufaktura.
    location.position = const LatLng(51.7809, 19.4439);
    final result = await (await service()).scan(_okCode);
    final failure = result as ScanFailure;
    expect(failure.problem, ScanProblem.tooFar);
    expect(failure.distanceMeters, greaterThan(150));
    expect(quest.visits, isEmpty);
  });

  test('140 m away is fine', () async {
    location.position = const LatLng(51.77784, 19.4439);
    expect(await (await service()).scan(_okCode), isA<ScanSuccess>());
  });

  test('wrong code: «Kod nieważny» (rejected by the rules)', () async {
    final result = await (await service()).scan(
      'coollodz://quest/cool-002?c=WRONG1',
    );
    expect((result as ScanFailure).problem, ScanProblem.invalidCode);
  });

  test('not a quest QR or not a quest place: «Kod nieważny»', () async {
    final s = await service();
    for (final raw in [
      'https://example.com',
      'coollodz://quest/cool-004?c=AAAAAA', // Port Łódź: not in the quest
      'coollodz://quest/cool-002',
      'coollodz://other/cool-002?c=K7M2QX',
    ]) {
      final result = await s.scan(raw);
      expect(
        (result as ScanFailure).problem,
        ScanProblem.invalidCode,
        reason: raw,
      );
    }
  });

  test('no location: asks to turn it on', () async {
    location.problem = LocationProblem.deniedForever;
    final result = await (await service()).scan(_okCode);
    expect((result as ScanFailure).problem, ScanProblem.noLocation);
  });

  test('demo: the first scan also gives Strażnik chłodu', () async {
    final result = await (await service(demo: true)).scan(_okCode);
    expect((result as ScanSuccess).award.badges, {GameBadge.coolGuard});
  });

  group('QuestCode', () {
    test('parses coollodz://quest/{placeId}?c={kod}', () {
      final code = QuestCode.parse(' coollodz://quest/cool-017?c=AB12CD ')!;
      expect(code.placeId, 'cool-017');
      expect(code.code, 'AB12CD');
    });

    test('visit ids back to place ids', () {
      expect(placeIdOfVisit('u1_cool-002_20260715', 'u1'), 'cool-002');
      expect(placeIdOfVisit('u2_cool-002_20260715', 'u1'), isNull);
    });
  });
}
