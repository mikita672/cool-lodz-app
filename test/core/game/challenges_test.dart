import 'package:cool_lodz/core/game/challenges.dart';
import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:flutter_test/flutter_test.dart';

RouteRecord _route(
  DateTime at, {
  double shade = 0.7,
  int meters = 1500,
  int water = 0,
}) => RouteRecord(
  departAt: at,
  shadeShare: shade,
  distanceM: meters,
  waterStops: water,
);

void main() {
  // 2026-W29: Monday 13 July – Sunday 19 July.
  const week = '2026-W29';
  final wednesday = DateTime(2026, 7, 15, 12);

  test('one challenge per week in rotation; config/game can pick one', () {
    final picked = {
      for (var w = 1; w <= 5; w++)
        Challenge.forWeek('2026-W${w.toString().padLeft(2, '0')}').kind,
    };
    expect(picked, hasLength(5));
    expect(
      Challenge.forWeek(week, override: 'coolScans').kind,
      ChallengeKind.coolScans,
    );
    expect(
      Challenge.forWeek(week, override: 'nonsense'),
      Challenge.forWeek(week),
    );
  });

  test('progress counts only this week', () {
    final history = GameHistory(
      routes: [
        _route(DateTime(2026, 7, 13, 8)), // Monday, morning, shaded
        _route(DateTime(2026, 7, 15, 13), shade: 0.3, water: 1),
        _route(DateTime(2026, 7, 19, 20), meters: 2600, water: 2), // Sunday
        _route(DateTime(2026, 7, 12, 9), meters: 9000), // last week
      ],
      log: [
        PointsEntry(
          type: PointsType.scan,
          points: 50,
          refId: 'a',
          at: DateTime(2026, 7, 14, 10),
        ),
        PointsEntry(
          type: PointsType.scan,
          points: 50,
          refId: 'a',
          at: DateTime(2026, 7, 15, 10),
        ),
        const PointsEntry(type: PointsType.scan, points: 50, refId: 'b'),
        PointsEntry(
          type: PointsType.scan,
          points: 50,
          refId: 'c',
          at: DateTime(2026, 7, 8, 10), // last week
        ),
      ],
    );
    int progress(ChallengeKind kind) =>
        Challenge.all.firstWhere((c) => c.kind == kind).progress(history, week);
    expect(progress(ChallengeKind.shadedRoutes), 2);
    expect(progress(ChallengeKind.coolScans), 2); // a and the pending b
    expect(progress(ChallengeKind.distance), 5); // 1.5 + 1.5 + 2.6 km
    expect(progress(ChallengeKind.coolHours), 2); // 8:00 and 20:00
    expect(progress(ChallengeKind.waterRoutes), 2);
  });

  test('state: target, demo target, due once, days left', () {
    final history = GameHistory(
      routes: [for (var d = 13; d <= 15; d++) _route(DateTime(2026, 7, d, 12))],
    );
    final state = ChallengeState.of(
      history,
      wednesday,
      override: 'shadedRoutes',
    );
    expect(state.week, week);
    expect(state.progress, 3);
    expect(state.target, 3);
    expect(state.due, isTrue);
    expect(state.daysLeft, 4);

    final paid = ChallengeState.of(
      GameHistory(
        routes: history.routes,
        log: const [
          PointsEntry(type: PointsType.challenge, points: 50, refId: week),
        ],
      ),
      wednesday,
      override: 'shadedRoutes',
    );
    expect(paid.awarded, isTrue);
    expect(paid.due, isFalse);

    final demo = ChallengeState.of(
      GameHistory(routes: [_route(DateTime(2026, 7, 13, 12))]),
      DateTime(2026, 7, 19, 12),
      override: 'shadedRoutes',
      demo: true,
    );
    expect(demo.target, Challenge.demoTarget);
    expect(demo.due, isTrue);
    expect(demo.daysLeft, 0);
  });
}
