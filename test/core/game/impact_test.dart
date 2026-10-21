import 'package:cool_lodz/core/game/game_rules.dart';
import 'package:cool_lodz/core/game/impact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds up the walks; old routes estimate the time', () {
    final impact = Impact.from(
      GameHistory(
        routes: [
          RouteRecord(
            departAt: DateTime(2026, 7, 15, 9),
            shadeShare: 0.8,
            distanceM: 1500,
            durationS: 1200, // 20 min
            shortestSunShare: 0.5,
            waterStops: 1,
          ),
          // Saved before the impact fields: 1300 m at 1.3 m/s = 1000 s.
          RouteRecord(
            departAt: DateTime(2026, 7, 14, 18),
            shadeShare: 0.6,
            distanceM: 1300,
          ),
        ],
        log: const [
          PointsEntry(type: PointsType.scan, points: 50, refId: 'cool-1'),
          PointsEntry(type: PointsType.scan, points: 50, refId: 'cool-1'),
          PointsEntry(type: PointsType.scan, points: 50, refId: 'cool-2'),
        ],
      ),
    );
    expect(impact.walks, 2);
    expect(impact.distanceKm, closeTo(2.8, 1e-9));
    // 20 × 0.8 + 16.7 × 0.6 = 26
    expect(impact.minutesInShade, 26);
    // Only the first knows the shortest walk: 20 × (0.5 − 0.2) = 6.
    expect(impact.sunAvoidedMinutes, 6);
    expect(impact.waterPoints, 1);
    expect(impact.coolPlaces, 2);
    expect(impact.co2SavedKg, closeTo(2.8 * 0.17, 1e-9));
  });

  test('no walks, no comparison', () {
    final impact = Impact.from(const GameHistory());
    expect(impact.walks, 0);
    expect(impact.sunAvoidedMinutes, isNull);
    expect(impact.co2SavedKg, 0);
  });

  test('a sunnier choice than the shortest does not count negative', () {
    final impact = Impact.from(
      GameHistory(
        routes: [
          RouteRecord(
            departAt: DateTime(2026, 7, 15, 9),
            shadeShare: 0.2,
            distanceM: 1000,
            durationS: 600,
            shortestSunShare: 0.5,
          ),
        ],
      ),
    );
    expect(impact.sunAvoidedMinutes, 0);
  });
}
