import 'package:cool_lodz/core/api/api_providers.dart';
import 'package:cool_lodz/core/clock.dart';
import 'package:cool_lodz/core/game/challenges.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/models/models.dart';
import 'package:cool_lodz/features/game/data/game_config_repository.dart';
import 'package:cool_lodz/features/game/data/game_repository.dart';
import 'package:cool_lodz/features/game/game_service.dart';
import 'package:cool_lodz/features/route/data/route_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';
import '../auth/fakes.dart';

StartedRoute _route({int hour = 12, double sun = 0.3, String? end}) =>
    StartedRoute(
      from: const RoutePoint(lat: 51.77, lon: 19.44),
      to: const RoutePoint(lat: 51.76, lon: 19.45),
      departAt: DateTime(2026, 7, 15, hour),
      variant: RouteVariantType.shaded,
      sunShare: sun,
      distanceM: 2000,
      endPlaceType: end,
    );

void main() {
  late FakeGameRepository repo;

  Future<ProviderContainer> make({
    int heatOverride = 0,
    bool demo = false,
    DateTime? now,
  }) async {
    final prefs = await testPrefs();
    return ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          game: repo,
          settings: GameSettings(heatOverride: heatOverride),
        ),
        clockProvider.overrideWithValue(() => now ?? DateTime(2026, 7, 15, 12)),
        isDemoModeEffectiveProvider.overrideWithValue(demo),
      ],
    );
  }

  /// Lets the settings stream and the alert future arrive.
  Future<void> settle(ProviderContainer c) async {
    c.listen(heatLevelProvider, (_, _) {});
    await c.read(gameSettingsProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() => repo = FakeGameRepository());

  test('first shaded route: +10 and Pierwszy krok (+30)', () async {
    final c = await make();
    final award = await c.read(gameServiceProvider).routeStarted(_route());
    expect(award.pointsFor(PointsType.route), 10);
    expect(award.badges, {GameBadge.firstStep});
    expect(award.points, 40);
    expect(repo.routes, hasLength(1));
    expect(repo.state.points, 40);
    expect(repo.state.badges, {GameBadge.firstStep});
  });

  test('a sunny route gives only the badge', () async {
    final c = await make();
    final award = await c
        .read(gameServiceProvider)
        .routeStarted(_route(sun: 0.8));
    expect(award.pointsFor(PointsType.route), 0);
    expect(award.badges, {GameBadge.firstStep});
  });

  test('sixth shaded route of the day earns nothing', () async {
    final c = await make();
    final game = c.read(gameServiceProvider);
    for (var i = 0; i < 5; i++) {
      await game.routeStarted(_route());
    }
    final sixth = await game.routeStarted(_route());
    expect(sixth.points, 0);
    expect(repo.state.points, 5 * 10 + 30);
  });

  test('heat override 3: no points for 14:00, points for 8:00', () async {
    final c = await make(heatOverride: 3);
    await settle(c);
    final game = c.read(gameServiceProvider);
    final noon = await game.routeStarted(_route(hour: 14));
    expect(noon.pointsFor(PointsType.route), 0);
    final morning = await game.routeStarted(_route(hour: 8));
    expect(morning.pointsFor(PointsType.route), 10);
    // A heat day morning walk: Ranny ptaszek.
    expect(morning.badges, contains(GameBadge.earlyBird));
  });

  test('demo: the first scan gives +50 and Strażnik chłodu', () async {
    final c = await make(demo: true);
    final game = c.read(gameServiceProvider);
    final first = await game.placeScanned('cool-002');
    expect(first.pointsFor(PointsType.scan), 50);
    expect(first.badges, {GameBadge.coolGuard});
    final again = await game.placeScanned('cool-002');
    expect(again.points, 0);
  });

  test('password: 500 in writes of ≤ 200', () async {
    repo.state = const PlayerState(
      nickname: 'Ala',
      badges: {GameBadge.firstStep},
    );
    final c = await make();
    final game = c.read(gameServiceProvider);
    final solved = await game.passwordSolved('chlodne-haslo-2026');
    expect(solved.points, 500);
    expect(repo.writes, [200, 200, 100]);
    expect((await game.passwordSolved('chlodne-haslo-2026')).points, 0);
  });

  test(
    'the weekly challenge pays +50 once, with the event that ends it',
    () async {
      final prefs = await testPrefs();
      final c = ProviderContainer.test(
        overrides: [
          ...appTestOverrides(
            prefs: prefs,
            game: repo,
            settings: const GameSettings(challenge: 'shadedRoutes'),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 12)),
          isDemoModeEffectiveProvider.overrideWithValue(false),
        ],
      );
      await settle(c);
      final game = c.read(gameServiceProvider);
      expect((await game.routeStarted(_route(hour: 9))).challenge, isNull);
      expect((await game.routeStarted(_route(hour: 10))).challenge, isNull);
      final third = await game.routeStarted(_route(hour: 11));
      expect(third.challenge?.challenge.kind, ChallengeKind.shadedRoutes);
      expect(
        third.entries,
        contains(
          const PointsEntry(
            type: PointsType.challenge,
            points: 50,
            refId: '2026-W29',
          ),
        ),
      );
      final fourth = await game.routeStarted(_route(hour: 12));
      expect(fourth.challenge, isNull);
      expect(
        repo.log.where((e) => e.type == PointsType.challenge),
        hasLength(1),
      );
      // Nothing left to pay.
      expect((await game.syncChallenge()).points, 0);
    },
  );

  test('a challenge completed without its bonus is paid on sync', () async {
    final prefs = await testPrefs();
    final c = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          game: repo,
          settings: const GameSettings(challenge: 'shadedRoutes'),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 7, 15, 12)),
        // Demo: one shaded route is enough.
        isDemoModeEffectiveProvider.overrideWithValue(true),
      ],
    );
    await settle(c);
    // Stored earlier, when the bonus could not be written (offline).
    repo.routes.add(('u1', _route(hour: 8)));
    final game = c.read(gameServiceProvider);
    final award = await game.syncChallenge();
    // +50 for the challenge (and the missing Pierwszy krok badge).
    expect(award.pointsFor(PointsType.challenge), 50);
    expect(award.challenge?.target, 1);
    expect((await game.syncChallenge()).points, 0);
  });

  test('signed out: nothing happens', () async {
    final prefs = await testPrefs();
    final c = ProviderContainer.test(
      overrides: [
        ...appTestOverrides(
          prefs: prefs,
          game: repo,
          auth: FakeAuthRepository(),
        ),
      ],
    );
    final award = await c.read(gameServiceProvider).routeStarted(_route());
    expect(award.points, 0);
    expect(repo.routes, isEmpty);
  });

  test('events at the same time do not lose or double points', () async {
    repo.approvedReportIds.addAll({'r1'});
    final c = await make();
    final game = c.read(gameServiceProvider);
    final results = await Future.wait([
      game.routeStarted(_route()),
      game.syncReports(),
      game.syncReports(),
      game.placeScanned('cool-002'),
    ]);
    // 10 route + 30 Pierwszy krok + 20 report (once) + 50 scan.
    expect(results.fold(0, (a, r) => a + r.points), 110);
    expect(repo.state.points, 110);
    expect(repo.log.where((e) => e.type == PointsType.report), hasLength(1));
  });

  test('a badge is saved in the same write as its 30 points', () async {
    final c = await make(demo: true);
    await c.read(gameServiceProvider).passwordSolved('q');
    // Password (500 as 200 + 200 + 100) and, in demo, no scan badge; then a scan: 50 + 30.
    await c.read(gameServiceProvider).placeScanned('cool-002');
    expect(repo.writes, [200, 200, 100, 80]);
    expect(repo.state.badges, {GameBadge.coolGuard});
  });
}
