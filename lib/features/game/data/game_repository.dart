import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/game/game_rules.dart';
import '../../route/data/route_history_repository.dart';

/// The game fields of `users/{uid}`.
@immutable
class PlayerState {
  const PlayerState({
    this.nickname = '',
    this.district,
    this.rankingConsent = false,
    this.points = 0,
    this.weekId,
    this.weekPoints = 0,
    this.badges = const {},
  });

  factory PlayerState.fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const PlayerState();
    final consents = d[UserFields.consents];
    return PlayerState(
      nickname: (d[UserFields.nickname] as String?) ?? '',
      district: d[UserFields.district] as String?,
      rankingConsent:
          consents is Map && consents[UserFields.consentRanking] == true,
      points: (d[UserFields.points] as num?)?.toInt() ?? 0,
      weekId: d[UserFields.weekId] as String?,
      weekPoints: (d[UserFields.weekPoints] as num?)?.toInt() ?? 0,
      badges: {
        for (final id in (d[UserFields.badges] as List?) ?? const [])
          ?GameBadge.fromId('$id'),
      },
    );
  }

  final String nickname;

  /// A `FirestoreDistricts` id, or null until chosen in S16.
  final String? district;
  final bool rankingConsent;
  final int points;
  final String? weekId;
  final int weekPoints;
  final Set<GameBadge> badges;

  /// Points of [currentWeek] (0 when the stored week is an older one).
  int weekPointsIn(String currentWeek) =>
      weekId == currentWeek ? weekPoints : 0;
}

/// Firestore access for the game (S07 routes, S11 scans, S12, quest
/// password). The rules only cap each write; the client adds the points
/// (known limitation, spec «Геймификация»).
abstract interface class GameRepository {
  Future<PlayerState> player(String uid);

  /// Routes, points log and approved reports.
  Future<GameHistory> history(String uid);

  Future<void> addRoute(String uid, StartedRoute route);

  /// Writes [entries] (+ [badges]) in batches of at most 200 points: log
  /// entries, `users/{uid}` totals and week, the `rankings/{uid}` mirror
  /// (with consent) and the district totals (when a district is set).
  Future<void> award(
    String uid,
    List<PointsEntry> entries, {
    Set<GameBadge> badges = const {},
    required DateTime now,
  });

  Stream<PlayerState> watchPlayer(String uid);

  /// The latest [limit] log entries, newest first.
  Stream<List<PointsEntry>> watchLog(String uid, {int limit = 10});
}

class FirestoreGameRepository implements GameRepository {
  FirestoreGameRepository(this._db, this._routes);

  final FirebaseFirestore _db;
  final RouteHistoryRepository _routes;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(FirestoreCollections.users).doc(uid);

  CollectionReference<Map<String, dynamic>> _log(String uid) =>
      _user(uid).collection(FirestoreCollections.pointsLog);

  @override
  Future<PlayerState> player(String uid) async =>
      PlayerState.fromDoc((await _user(uid).get()).data());

  @override
  Future<GameHistory> history(String uid) async {
    final results = await Future.wait([
      _user(uid).collection(FirestoreCollections.routes).get(),
      _log(uid).get(),
      _db
          .collection(FirestoreCollections.reports)
          .where(ReportFields.uid, isEqualTo: uid)
          .where(
            ReportFields.status,
            isEqualTo: FirestoreReports.statusApproved,
          )
          .get(),
      _user(uid).get(),
    ]);
    final routes = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final log = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final reports = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final user = results[3] as DocumentSnapshot<Map<String, dynamic>>;
    return GameHistory(
      routes: [for (final d in routes.docs) ?_route(d.data())],
      log: [for (final d in log.docs) ?_entry(d.data())],
      badges: PlayerState.fromDoc(user.data()).badges,
      approvedReports: reports.size,
    );
  }

  @override
  Future<void> addRoute(String uid, StartedRoute route) =>
      _routes.add(uid, route);

  @override
  Future<void> award(
    String uid,
    List<PointsEntry> entries, {
    Set<GameBadge> badges = const {},
    required DateTime now,
  }) async {
    final week = weekId(now);
    var pendingBadges = badges;
    for (final chunk in GameRules.chunk(entries)) {
      final sum = chunk.fold(0, (a, e) => a + e.points);
      final before = await player(uid);
      final points = before.points + sum;
      final weekPoints = before.weekPointsIn(week) + sum;
      final allBadges = {...before.badges, ...pendingBadges};
      final batch = _db.batch();
      for (final e in chunk) {
        batch.set(_log(uid).doc(), {
          PointsLogFields.type: e.type.id,
          PointsLogFields.points: e.points,
          PointsLogFields.refId: e.refId,
          PointsLogFields.createdAt: FieldValue.serverTimestamp(),
        });
      }
      batch.update(_user(uid), {
        UserFields.points: points,
        UserFields.weekId: week,
        UserFields.weekPoints: weekPoints,
        UserFields.badges: [for (final b in allBadges) b.id],
      });
      if (before.rankingConsent) {
        batch.set(_db.collection(FirestoreCollections.rankings).doc(uid), {
          RankingFields.nickname: before.nickname,
          RankingFields.district: before.district,
          RankingFields.points: points,
          RankingFields.weekId: week,
          RankingFields.weekPoints: weekPoints,
          RankingFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
      final district = before.district;
      if (district != null && sum > 0) {
        final ref = _db
            .collection(FirestoreCollections.districts)
            .doc(district);
        batch.update(ref, {DistrictFields.points: FieldValue.increment(sum)});
        batch.set(
          ref.collection(FirestoreCollections.weeks).doc(week),
          {DistrictFields.points: FieldValue.increment(sum)},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      pendingBadges = const {};
    }
  }

  @override
  Stream<PlayerState> watchPlayer(String uid) =>
      _user(uid).snapshots().map((s) => PlayerState.fromDoc(s.data()));

  @override
  Stream<List<PointsEntry>> watchLog(String uid, {int limit = 10}) => _log(uid)
      .orderBy(PointsLogFields.createdAt, descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => [for (final d in q.docs) ?_entry(d.data())]);

  static RouteRecord? _route(Map<String, dynamic> d) {
    final departAt = d[RouteFields.departAt];
    final sun = d[RouteFields.sunShare];
    if (departAt is! Timestamp || sun is! num) return null;
    return RouteRecord(
      departAt: departAt.toDate(),
      shadeShare: 1 - sun.toDouble(),
      endPlaceType: d[RouteFields.endPlaceType] as String?,
    );
  }

  static PointsEntry? _entry(Map<String, dynamic> d) {
    final type = PointsType.fromId('${d[PointsLogFields.type]}');
    final points = d[PointsLogFields.points];
    if (type == null || points is! num) return null;
    final at = d[PointsLogFields.createdAt];
    return PointsEntry(
      type: type,
      points: points.toInt(),
      refId: d[PointsLogFields.refId] as String?,
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => FirestoreGameRepository(
    ref.watch(firestoreProvider),
    ref.watch(routeHistoryRepositoryProvider),
  ),
);
