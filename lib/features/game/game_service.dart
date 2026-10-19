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

  /// Events run one after another: each reads the history only after the
  /// previous award was written, so points are never lost or paid twice
  /// (e.g. «Prowadź» while S12 syncs reports, or a double tap).
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() event) {
    final result = _queue.then((_) => event());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  GameRepository get _repo => _ref.read(gameRepositoryProvider);
  DateTime get _now => _ref.read(clockProvider)();
  String? get _uid => _ref.read(authRepositoryProvider).currentUser?.uid;
  int get _heat => _ref.read(heatLevelProvider);

  int get _coolGuardPlaces => _ref.read(isDemoModeEffectiveProvider)
      ? GameConfig.demoBadgeCoolGuardPlaces
      : GameConfig.badgeCoolGuardPlaces;

  /// «Prowadź» on S07: stores the route, then 10 points for ≥ 60 % shade
  /// (5 a day, none in heat mode 11–17) and route badges.
  Future<GameAward> routeStarted(StartedRoute route) =>
      _serial(() => _routeStarted(route));

  Future<GameAward> _routeStarted(StartedRoute route) async {
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
      approvedReportIds: history.approvedReportIds,
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
  Future<GameAward> placeScanned(String placeId) =>
      _serial(() => _placeScanned(placeId));

  Future<GameAward> _placeScanned(String placeId) async {
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
      approvedReportIds: history.approvedReportIds,
    );
    return _award(uid, withScan, [if (points > 0) entry]);
  }

  /// The quest password was solved: 200 points once.
  Future<GameAward> passwordSolved(String questId) =>
      _serial(() => _passwordSolved(questId));

  Future<GameAward> _passwordSolved(String questId) async {
    final uid = _uid;
    if (uid == null) return GameAward.none;
    final history = await _repo.history(uid);
    final points = GameRules.passwordPoints(questId: questId, history: history);
    return _award(uid, history, [
      if (points > 0)
        PointsEntry(type: PointsType.password, points: points, refId: questId),
    ]);
  }

  /// Reports approved in the console since the last check: 20 points each
  /// and Pomocnik miasta after 3. Called when S12 opens.
  Future<GameAward> syncReports() => _serial(_syncReports);

  Future<GameAward> _syncReports() async {
    final uid = _uid;
    if (uid == null) return GameAward.none;
    final history = await _repo.history(uid);
    final unpaid = GameRules.unpaidReports(history);
    if (unpaid.isEmpty) return GameAward.none;
    return _award(uid, history, [
      for (final id in unpaid)
        PointsEntry(
          type: PointsType.report,
          points: GameConfig.pointsReportApproved,
          refId: id,
        ),
    ]);
  }

  /// Visits saved today whose scan points are missing (the award failed or
  /// the visit was sent later from offline): 50 each. Called when S10 opens.
  Future<GameAward> syncScans(Iterable<String> placeIdsVisitedToday) =>
      _serial(() async {
        final uid = _uid;
        if (uid == null) return GameAward.none;
        final history = await _repo.history(uid);
        final now = _now;
        final unpaid = [
          for (final id in {...placeIdsVisitedToday})
            if (history.countOn(PointsType.scan, now, refId: id) == 0) id,
        ]..sort();
        if (unpaid.isEmpty) return GameAward.none;
        final entries = [
          for (final id in unpaid)
            PointsEntry(
              type: PointsType.scan,
              points: GameConfig.pointsQrScan,
              refId: id,
            ),
        ];
        final withScans = GameHistory(
          routes: history.routes,
          log: [...history.log, ...entries],
          badges: history.badges,
          approvedReports: history.approvedReports,
          approvedReportIds: history.approvedReportIds,
        );
        return _award(uid, withScans, entries);
      });

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
      shadedTenRoutes: _ref.read(isDemoModeEffectiveProvider)
          ? GameConfig.demoBadgeShadedTenCount
          : GameConfig.badgeShadedTenCount,
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
    await _repo.award(uid, all, now: _now);
    return GameAward(entries: all, badges: badges);
  }
}

final gameServiceProvider = Provider<GameService>(GameService.new);

/// Runs [GameService.syncReports] while S12 is open; its result is the
/// award to show (if any).
final reportSyncProvider = FutureProvider.autoDispose<GameAward>(
  (ref) => ref.read(gameServiceProvider).syncReports(),
  retry: (_, _) => null,
);

/// S12: the signed-in player's totals and badges.
final playerProvider = StreamProvider<PlayerState>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const PlayerState());
  return ref.watch(gameRepositoryProvider).watchPlayer(uid);
});

/// S12: the last 10 points.
final recentPointsProvider = StreamProvider<List<PointsEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(gameRepositoryProvider).watchLog(uid);
});
