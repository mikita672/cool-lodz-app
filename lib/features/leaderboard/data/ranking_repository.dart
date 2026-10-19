import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/clock.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/game/game_config.dart';
import '../../auth/data/auth_repository.dart';
import '../../game/game_service.dart';

enum RankingScope { districts, users }

enum RankingPeriod { week, summer }

/// One row of S13: a user (nickname) or a district.
@immutable
class RankingEntry {
  const RankingEntry({
    required this.id,
    required this.name,
    required this.points,
  });

  /// uid or district id.
  final String id;
  final String name;
  final int points;
}

/// Display name of a district id (`GameConfig.districts`, same order as
/// `FirestoreDistricts.ids`).
String districtName(String id) {
  final i = FirestoreDistricts.ids.indexOf(id);
  return i < 0 ? id : GameConfig.districts[i];
}

/// S13 data. Users come from the public `rankings/{uid}` (only users who
/// agreed to the ranking, Q-09), districts from `districts` and their
/// weeks.
abstract interface class RankingRepository {
  /// Top [GameConfig.rankingUsersLimit] users.
  Future<List<RankingEntry>> users(RankingPeriod period, String weekId);

  /// 1-based place of a user with [points] (for the pinned own row).
  Future<int> userRank(RankingPeriod period, String weekId, int points);

  /// All 5 districts, best first.
  Future<List<RankingEntry>> districts(RankingPeriod period, String weekId);
}

class FirestoreRankingRepository implements RankingRepository {
  FirestoreRankingRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rankings =>
      _db.collection(FirestoreCollections.rankings);

  @override
  Future<List<RankingEntry>> users(RankingPeriod period, String weekId) async {
    final field = period == RankingPeriod.week
        ? RankingFields.weekPoints
        : RankingFields.points;
    Query<Map<String, dynamic>> q = _rankings;
    if (period == RankingPeriod.week) {
      q = q.where(RankingFields.weekId, isEqualTo: weekId);
    }
    final snap = await q
        .orderBy(field, descending: true)
        .limit(GameConfig.rankingUsersLimit)
        .get();
    return [
      for (final d in snap.docs)
        RankingEntry(
          id: d.id,
          name: (d.data()[RankingFields.nickname] as String?) ?? '',
          points: (d.data()[field] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<int> userRank(RankingPeriod period, String weekId, int points) async {
    Query<Map<String, dynamic>> q = _rankings;
    if (period == RankingPeriod.week) {
      q = q
          .where(RankingFields.weekId, isEqualTo: weekId)
          .where(RankingFields.weekPoints, isGreaterThan: points);
    } else {
      q = q.where(RankingFields.points, isGreaterThan: points);
    }
    final count = await q.count().get();
    return (count.count ?? 0) + 1;
  }

  @override
  Future<List<RankingEntry>> districts(
    RankingPeriod period,
    String weekId,
  ) async {
    final col = _db.collection(FirestoreCollections.districts);
    final entries = <RankingEntry>[];
    if (period == RankingPeriod.summer) {
      final snap = await col.get();
      for (final d in snap.docs) {
        entries.add(
          RankingEntry(
            id: d.id,
            name: districtName(d.id),
            points: (d.data()[DistrictFields.points] as num?)?.toInt() ?? 0,
          ),
        );
      }
    } else {
      final weeks = await Future.wait([
        for (final id in FirestoreDistricts.ids)
          col.doc(id).collection(FirestoreCollections.weeks).doc(weekId).get(),
      ]);
      for (var i = 0; i < weeks.length; i++) {
        final id = FirestoreDistricts.ids[i];
        entries.add(
          RankingEntry(
            id: id,
            name: districtName(id),
            points:
                (weeks[i].data()?[DistrictFields.points] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    // Districts with no points yet still show up, at the bottom.
    for (final id in FirestoreDistricts.ids) {
      if (!entries.any((e) => e.id == id)) {
        entries.add(RankingEntry(id: id, name: districtName(id), points: 0));
      }
    }
    return entries..sort((a, b) => b.points.compareTo(a.points));
  }
}

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => FirestoreRankingRepository(ref.watch(firestoreProvider)),
);

/// Current ISO week in Poland, e.g. `2026-W43`.
final currentWeekProvider = Provider<String>(
  (ref) => weekId(ref.watch(clockProvider)()),
);

/// The rows of one S13 view.
final rankingProvider =
    FutureProvider.family<List<RankingEntry>, (RankingScope, RankingPeriod)>((
      ref,
      key,
    ) {
      final (scope, period) = key;
      final repo = ref.watch(rankingRepositoryProvider);
      final week = ref.watch(currentWeekProvider);
      // Refresh when the player's points change.
      ref.watch(playerProvider.select((p) => p.value?.points));
      return scope == RankingScope.users
          ? repo.users(period, week)
          : repo.districts(period, week);
    }, retry: noRetry);

/// The user's own row: null when they do not take part (no consent).
final ownRankingProvider =
    FutureProvider.family<(int, RankingEntry)?, RankingPeriod>((
      ref,
      period,
    ) async {
      final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
      final player = await ref.watch(playerProvider.future);
      if (uid == null || !player.rankingConsent) return null;
      final week = ref.watch(currentWeekProvider);
      final points = period == RankingPeriod.week
          ? player.weekPointsIn(week)
          : player.points;
      final rank = await ref
          .watch(rankingRepositoryProvider)
          .userRank(period, week, points);
      return (
        rank,
        RankingEntry(id: uid, name: player.nickname, points: points),
      );
    }, retry: noRetry);
