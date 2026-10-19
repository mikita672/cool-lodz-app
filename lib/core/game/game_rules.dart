import 'package:flutter/foundation.dart';

import 'game_config.dart';

/// The seven badges from the spec. [id] is stored in `users.badges`.
enum GameBadge {
  firstStep('firstStep'), // Pierwszy krok
  shadedTen('shadedTen'), // Cienista dziesiątka
  coolGuard('coolGuard'), // Strażnik chłodu
  earlyBird('earlyBird'), // Ranny ptaszek
  eveningWalker('eveningWalker'), // Wieczorny spacerowicz
  parkHunter('parkHunter'), // Łowca parków
  cityHelper('cityHelper'); // Pomocnik miasta (S)

  const GameBadge(this.id);

  final String id;

  static GameBadge? fromId(String id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// What a `pointsLog` entry was for.
enum PointsType {
  route('route'),
  scan('scan'),
  password('password'),
  badge('badge'),
  report('report');

  const PointsType(this.id);

  final String id;

  static PointsType? fromId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// One entry of `users/{uid}/pointsLog`.
@immutable
class PointsEntry {
  const PointsEntry({
    required this.type,
    required this.points,
    this.refId,
    this.at,
  });

  final PointsType type;
  final int points;

  /// Route id, place id, quest id, badge id or report id.
  final String? refId;

  /// Server time; null while the write is pending.
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      other is PointsEntry &&
      other.type == type &&
      other.points == points &&
      other.refId == refId;

  @override
  int get hashCode => Object.hash(type, points, refId);

  @override
  String toString() => 'PointsEntry(${type.id}, $points, $refId)';
}

/// A route started with «Prowadź», as the badges need it.
@immutable
class RouteRecord {
  const RouteRecord({
    required this.departAt,
    required this.shadeShare,
    this.endPlaceType,
  });

  /// Local time.
  final DateTime departAt;
  final double shadeShare;

  /// `park` for Łowca parków.
  final String? endPlaceType;

  bool get isShaded => shadeShare >= GameConfig.shadedRouteMinShade;
}

/// Everything the rules look at, loaded from Firestore.
@immutable
class GameHistory {
  const GameHistory({
    this.routes = const [],
    this.log = const [],
    this.badges = const {},
    this.approvedReports = 0,
    this.approvedReportIds = const {},
  });

  /// All routes, including the one being awarded.
  final List<RouteRecord> routes;
  final List<PointsEntry> log;
  final Set<GameBadge> badges;
  final int approvedReports;

  /// Ids of the user's reports approved in the console (S15).
  final Set<String> approvedReportIds;

  /// Distinct places with a scan entry.
  Set<String> get scannedPlaces => {
    for (final e in log)
      if (e.type == PointsType.scan && e.refId != null) e.refId!,
  };

  /// Entries of [type] whose time falls on [day]'s calendar day (local).
  /// Pending entries (no time yet) count as today.
  int countOn(PointsType type, DateTime day, {String? refId}) => log
      .where(
        (e) =>
            e.type == type &&
            (refId == null || e.refId == refId) &&
            (e.at == null || _sameDay(e.at!.toLocal(), day)),
      )
      .length;

  bool has(PointsType type, {String? refId}) =>
      log.any((e) => e.type == type && (refId == null || e.refId == refId));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Pure game rules from the spec («Геймификация»). Numbers live in
/// [GameConfig].
abstract final class GameRules {
  /// Heat mode (alert level 3): routes leaving 11:00–17:00 earn nothing.
  static bool isHeatBlocked(DateTime departAt, int heatLevel) =>
      heatLevel >= GameConfig.heatModeLevel &&
      departAt.hour >= GameConfig.heatNoPointsFromHour &&
      departAt.hour < GameConfig.heatNoPointsToHour;

  /// Points for a route started with «Prowadź» (Q-08): 10 for shade
  /// ≥ 60 %, at most 5 a day, 0 in heat mode 11–17.
  static int routePoints({
    required RouteRecord route,
    required GameHistory history,
    required DateTime now,
    required int heatLevel,
  }) {
    if (!route.isShaded) return 0;
    if (isHeatBlocked(route.departAt, heatLevel)) return 0;
    final today = history.countOn(PointsType.route, now);
    if (today >= GameConfig.shadedRoutesPerDay) return 0;
    return GameConfig.pointsShadedRoute;
  }

  /// 50 for the first scan of [placeId] today.
  static int scanPoints({
    required String placeId,
    required GameHistory history,
    required DateTime now,
  }) =>
      history.countOn(PointsType.scan, now, refId: placeId) >=
          GameConfig.qrScansPerPlacePerDay
      ? 0
      : GameConfig.pointsQrScan;

  /// 200 once per quest.
  static int passwordPoints({
    required String questId,
    required GameHistory history,
  }) => history.has(PointsType.password, refId: questId)
      ? 0
      : GameConfig.pointsPasswordSolved;

  /// Approved reports that have not earned their 20 points yet.
  static List<String> unpaidReports(GameHistory history) => [
    for (final id in history.approvedReportIds)
      if (!history.has(PointsType.report, refId: id)) id,
  ]..sort();

  /// Badges [history] earns that it does not have yet. [route] is a route
  /// started just now; [heatAlertToday] says whether a heat warning is on
  /// today (Ranny ptaszek, Wieczorny spacerowicz need it at that moment,
  /// it is not stored with the route).
  static Set<GameBadge> newBadges({
    required GameHistory history,
    RouteRecord? route,
    bool heatAlertToday = false,
    int coolGuardPlaces = GameConfig.badgeCoolGuardPlaces,
  }) {
    final earned = <GameBadge>{};
    final routes = history.routes;
    if (routes.isNotEmpty) earned.add(GameBadge.firstStep);
    final shaded = routes
        .where((r) => r.shadeShare >= GameConfig.badgeShadedTenMinShade)
        .length;
    if (shaded >= GameConfig.badgeShadedTenCount) {
      earned.add(GameBadge.shadedTen);
    }
    if (history.scannedPlaces.length >= coolGuardPlaces) {
      earned.add(GameBadge.coolGuard);
    }
    if (route != null && heatAlertToday) {
      final h = route.departAt.hour;
      if (h >= GameConfig.badgeEarlyBirdFromHour &&
          h < GameConfig.badgeEarlyBirdToHour) {
        earned.add(GameBadge.earlyBird);
      }
      if (h >= GameConfig.badgeEveningFromHour &&
          h < GameConfig.badgeEveningToHour) {
        earned.add(GameBadge.eveningWalker);
      }
    }
    final parks = routes.where((r) => r.endPlaceType == 'park').length;
    if (parks >= GameConfig.badgeParkHunterRoutes) {
      earned.add(GameBadge.parkHunter);
    }
    if (history.approvedReports >= GameConfig.badgeCityHelperReports) {
      earned.add(GameBadge.cityHelper);
    }
    return earned.difference(history.badges);
  }

  /// Splits [entries] into groups of at most [GameConfig.maxPointsPerWrite]
  /// points: the Firestore rules cap every write at +200.
  static List<List<PointsEntry>> chunk(List<PointsEntry> entries) {
    final chunks = <List<PointsEntry>>[];
    var current = <PointsEntry>[];
    var sum = 0;
    for (final e in entries) {
      if (current.isNotEmpty && sum + e.points > GameConfig.maxPointsPerWrite) {
        chunks.add(current);
        current = [];
        sum = 0;
      }
      current.add(e);
      sum += e.points;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }
}
