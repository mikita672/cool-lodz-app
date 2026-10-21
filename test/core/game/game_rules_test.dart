import 'package:cool_lodz/core/game/game_config.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 15, 12);

RouteRecord _route({
  int hour = 12,
  double shade = 0.7,
  String? end,
  DateTime? day,
}) {
  final d = day ?? _now;
  return RouteRecord(
    departAt: DateTime(d.year, d.month, d.day, hour),
    shadeShare: shade,
    endPlaceType: end,
  );
}

PointsEntry _log(PointsType type, {String? ref, DateTime? at, int pts = 10}) =>
    PointsEntry(type: type, points: pts, refId: ref, at: at ?? _now);

void main() {
  group('route points', () {
    test('10 for shade ≥ 60 %, 0 below', () {
      const h = GameHistory();
      expect(
        GameRules.routePoints(
          route: _route(shade: 0.6),
          history: h,
          now: _now,
          heatLevel: 0,
        ),
        10,
      );
      expect(
        GameRules.routePoints(
          route: _route(shade: 0.59),
          history: h,
          now: _now,
          heatLevel: 0,
        ),
        0,
      );
    });

    test('at most 5 a day; yesterday does not count', () {
      final five = GameHistory(
        log: [for (var i = 0; i < 5; i++) _log(PointsType.route)],
      );
      expect(
        GameRules.routePoints(
          route: _route(),
          history: five,
          now: _now,
          heatLevel: 0,
        ),
        0,
      );
      final yesterday = GameHistory(
        log: [
          for (var i = 0; i < 5; i++)
            _log(PointsType.route, at: DateTime(2026, 7, 14, 12)),
        ],
      );
      expect(
        GameRules.routePoints(
          route: _route(),
          history: yesterday,
          now: _now,
          heatLevel: 0,
        ),
        10,
      );
    });

    test('heat mode (level 3): 0 for departures 11:00–17:00', () {
      const h = GameHistory();
      int at(int hour, int heat) => GameRules.routePoints(
        route: _route(hour: hour),
        history: h,
        now: _now,
        heatLevel: heat,
      );
      expect(at(11, 3), 0);
      expect(at(16, 3), 0);
      expect(at(10, 3), 10);
      expect(at(17, 3), 10);
      expect(at(14, 2), 10); // level 2 is not heat mode
    });
  });

  group('scan and password', () {
    test('50 for the first scan of a place today', () {
      expect(
        GameRules.scanPoints(
          placeId: 'cool-002',
          history: const GameHistory(),
          now: _now,
        ),
        GameConfig.pointsQrScan,
      );
      final scanned = GameHistory(
        log: [_log(PointsType.scan, ref: 'cool-002', pts: 50)],
      );
      expect(
        GameRules.scanPoints(placeId: 'cool-002', history: scanned, now: _now),
        0,
      );
      // Another place, or the same place tomorrow, counts.
      expect(
        GameRules.scanPoints(placeId: 'cool-003', history: scanned, now: _now),
        50,
      );
      expect(
        GameRules.scanPoints(
          placeId: 'cool-002',
          history: scanned,
          now: _now.add(const Duration(days: 1)),
        ),
        50,
      );
    });

    test('password: 500 once', () {
      expect(
        GameRules.passwordPoints(questId: 'q', history: const GameHistory()),
        500,
      );
      final solved = GameHistory(
        log: [_log(PointsType.password, ref: 'q', pts: 200)],
      );
      expect(GameRules.passwordPoints(questId: 'q', history: solved), 0);
    });
  });

  group('badges', () {
    test('Pierwszy krok after the first route', () {
      expect(GameRules.newBadges(history: const GameHistory()), isEmpty);
      expect(GameRules.newBadges(history: GameHistory(routes: [_route()])), {
        GameBadge.firstStep,
      });
    });

    test('Cienista dziesiątka after 10 shaded routes', () {
      final nine = GameHistory(
        routes: [for (var i = 0; i < 9; i++) _route()],
        badges: {GameBadge.firstStep},
      );
      expect(GameRules.newBadges(history: nine), isEmpty);
      final ten = GameHistory(
        routes: [for (var i = 0; i < 10; i++) _route(), _route(shade: 0.2)],
        badges: {GameBadge.firstStep},
      );
      expect(GameRules.newBadges(history: ten), {GameBadge.shadedTen});
    });

    test('Strażnik chłodu after 5 different places (1 in demo)', () {
      final four = GameHistory(
        log: [
          for (final p in ['a', 'b', 'c', 'd', 'd'])
            _log(PointsType.scan, ref: p),
        ],
      );
      expect(GameRules.newBadges(history: four), isEmpty);
      expect(
        GameRules.newBadges(
          history: four,
          coolGuardPlaces: GameConfig.demoBadgeCoolGuardPlaces,
        ),
        {GameBadge.coolGuard},
      );
      final five = GameHistory(
        log: [
          ...four.log,
          _log(PointsType.scan, ref: 'e'),
        ],
      );
      expect(GameRules.newBadges(history: five), {GameBadge.coolGuard});
    });

    test('Ranny ptaszek / Wieczorny spacerowicz need a heat alert day', () {
      final morning = _route(hour: 7);
      final h = GameHistory(routes: [morning], badges: {GameBadge.firstStep});
      expect(GameRules.newBadges(history: h, route: morning), isEmpty);
      expect(
        GameRules.newBadges(history: h, route: morning, heatAlertToday: true),
        {GameBadge.earlyBird},
      );
      final evening = _route(hour: 20);
      expect(
        GameRules.newBadges(
          history: GameHistory(
            routes: [evening],
            badges: {GameBadge.firstStep},
          ),
          route: evening,
          heatAlertToday: true,
        ),
        {GameBadge.eveningWalker},
      );
      final noon = _route(hour: 10);
      expect(
        GameRules.newBadges(
          history: GameHistory(routes: [noon], badges: {GameBadge.firstStep}),
          route: noon,
          heatAlertToday: true,
        ),
        isEmpty,
      );
    });

    test('Łowca parków after 5 routes to a park', () {
      final h = GameHistory(
        routes: [for (var i = 0; i < 5; i++) _route(end: 'park', shade: 0.1)],
        badges: {GameBadge.firstStep},
      );
      expect(GameRules.newBadges(history: h), {GameBadge.parkHunter});
    });

    test('Pomocnik miasta after 3 approved reports', () {
      expect(
        GameRules.newBadges(history: const GameHistory(approvedReports: 3)),
        {GameBadge.cityHelper},
      );
    });

    test('badges are given once', () {
      final h = GameHistory(routes: [_route()], badges: {GameBadge.firstStep});
      expect(GameRules.newBadges(history: h), isEmpty);
    });
  });

  test('chunks stay within 200 points per write', () {
    final chunks = GameRules.chunk([
      const PointsEntry(type: PointsType.password, points: 200),
      const PointsEntry(type: PointsType.badge, points: 30),
      const PointsEntry(type: PointsType.badge, points: 30),
      const PointsEntry(type: PointsType.scan, points: 50),
    ]);
    expect(
      [for (final c in chunks) c.fold(0, (a, e) => a + e.points)],
      [200, 110],
    );
  });

  test('ids round-trip', () {
    for (final b in GameBadge.values) {
      expect(GameBadge.fromId(b.id), b);
    }
    for (final t in PointsType.values) {
      expect(PointsType.fromId(t.id), t);
    }
  });
}
