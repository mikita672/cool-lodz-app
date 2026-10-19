import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/clock.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_rules.dart';
import '../auth/data/auth_repository.dart';
import '../route/data/route_history_repository.dart';
import 'data/game_config_repository.dart';
import 'data/game_repository.dart';

/// What one game event gave the user.
@immutable
class GameAward {
  const GameAward({this.entries = const [], this.badges = const {}});

  static const none = GameAward();

  final List<PointsEntry> entries;
  final Set<GameBadge> badges;

  int get points => entries.fold(0, (a, e) => a + e.points);

  /// Points without the badge bonuses («+50 pkt» for the scan itself).
  int pointsFor(PointsType type) =>
      entries.where((e) => e.type == type).fold(0, (a, e) => a + e.points);
}

/// Applies the game rules to events and saves the result: routes started
/// with «Prowadź» (Q-08), QR scans and the quest password.
class GameService {
  GameService(this._ref);

  final Ref _ref;

  GameRepository get _repo => _ref.read(gameRepositoryProvider);
  DateTime get _now => _ref.read(clockProvider)();
  String? get _uid => _ref.read(authRepositoryProvider).currentUser?.uid;
  int get _heat => _ref.read(heatLevelProvider);

  int get _coolGuardPlaces => _ref.read(isDemoModeEffectiveProvider)
      ? GameConfig.demoBadgeCoolGuardPlaces
      : GameConfig.badgeCoolGuardPlaces;

  /// «Prowadź» on S07: stores the route, then 10 points for ≥ 60 % shade
  /// (5 a day, none in heat mode 11–17) and route badges.
  Future<GameAward> routeStarted(StartedRoute route) async {
    final uid = _uid;
    if (uid == null) return GameAward.none;
    final history = await _repo.history(uid);
    await _repo.addRoute(uid, route);
    final record = RouteRecord(
      departAt: route.departAt,
      shadeShare: route.shadeShare,
      endPlaceType: route.endPlaceType,
    );
    final withRoute = GameHistory(
      routes: [...history.routes, record],
      log: history.log,
      badges: history.badges,
      approvedReports: history.approvedReports,
    );
    final points = GameRules.routePoints(
      route: record,
      history: withRoute,
      now: _now,
      heatLevel: _heat,
    );
    return _award(uid, withRoute, [
      if (points > 0) PointsEntry(type: PointsType.route, points: points),
    ], route: record);
  }

  /// A valid QR scan of [placeId] (the visit is already saved).
  Future<GameAward> placeScanned(String placeId) async {
    final uid = _uid;
    if (uid == null) return GameAward.none;
    final history = await _repo.history(uid);
    final points = GameRules.scanPoints(
      placeId: placeId,
      history: history,
      now: _now,
    );
    final entry = PointsEntry(
      type: PointsType.scan,
      points: points,
      refId: placeId,
    );
    final withScan = GameHistory(
      routes: history.routes,
      log: [...history.log, entry],
      badges: history.badges,
      approvedReports: history.approvedReports,
    );
    return _award(uid, withScan, [if (points > 0) entry]);
  }

  /// The quest password was solved: 200 points once.
  Future<GameAward> passwordSolved(String questId) async {
    final uid = _uid;
    if (uid == null) return GameAward.none;
    final history = await _repo.history(uid);
    final points = GameRules.passwordPoints(questId: questId, history: history);
    return _award(uid, history, [
      if (points > 0)
        PointsEntry(type: PointsType.password, points: points, refId: questId),
    ]);
  }

  Future<GameAward> _award(
    String uid,
    GameHistory history,
    List<PointsEntry> entries, {
    RouteRecord? route,
  }) async {
    final badges = GameRules.newBadges(
      history: history,
      route: route,
      heatAlertToday: _heat >= 1,
      coolGuardPlaces: _coolGuardPlaces,
    );
    final all = [
      ...entries,
      for (final b in GameBadge.values)
        if (badges.contains(b))
          PointsEntry(
            type: PointsType.badge,
            points: GameConfig.pointsBadge,
            refId: b.id,
          ),
    ];
    if (all.isEmpty) return GameAward.none;
    await _repo.award(uid, all, badges: badges, now: _now);
    return GameAward(entries: all, badges: badges);
  }
}

final gameServiceProvider = Provider<GameService>(GameService.new);

/// S12: the signed-in player's totals and badges.
final playerProvider = StreamProvider<PlayerState>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) return Stream.value(const PlayerState());
  return ref.watch(gameRepositoryProvider).watchPlayer(uid);
});

/// S12: the last 10 points.
final recentPointsProvider = StreamProvider<List<PointsEntry>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(gameRepositoryProvider).watchLog(uid);
});
