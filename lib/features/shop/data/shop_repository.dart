import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../game/data/game_repository.dart';
import 'rewards.dart';

/// Not enough points for the reward.
class NotEnoughPoints implements Exception {
  const NotEnoughPoints();
}

/// The shop: spending adds to `users/{uid}.spent` (points and the ranking
/// stay) and stores the code in `users/{uid}/redemptions`, in one batch.
abstract interface class ShopRepository {
  /// Throws [NotEnoughPoints].
  Future<Redemption> redeem(String uid, Reward reward, {required DateTime now});

  /// Newest first.
  Stream<List<Redemption>> watchRedemptions(String uid);
}

class FirestoreShopRepository implements ShopRepository {
  FirestoreShopRepository(this._db, this._game);

  final FirebaseFirestore _db;
  final GameRepository _game;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(FirestoreCollections.users).doc(uid);

  CollectionReference<Map<String, dynamic>> _redemptions(String uid) =>
      _user(uid).collection(FirestoreCollections.redemptions);

  /// How long [redeem] waits for the server (offline it is queued).
  static const commitWait = Duration(seconds: 5);

  @override
  Future<Redemption> redeem(
    String uid,
    Reward reward, {
    required DateTime now,
  }) async {
    final player = await _game.player(uid);
    if (player.available < reward.cost) throw const NotEnoughPoints();
    final code = redemptionCode(reward, uid, now);
    final batch = _db.batch()
      ..update(_user(uid), {UserFields.spent: player.spent + reward.cost})
      ..set(_redemptions(uid).doc(), {
        RedemptionFields.rewardId: reward.id,
        RedemptionFields.cost: reward.cost,
        RedemptionFields.code: code,
        RedemptionFields.createdAt: FieldValue.serverTimestamp(),
      });
    await batch.commit().timeout(commitWait, onTimeout: () {});
    return Redemption(rewardId: reward.id, cost: reward.cost, code: code);
  }

  @override
  Stream<List<Redemption>> watchRedemptions(String uid) => _redemptions(uid)
      .orderBy(RedemptionFields.createdAt, descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) ?_parse(d.data())]);

  static Redemption? _parse(Map<String, dynamic> d) {
    final id = d[RedemptionFields.rewardId];
    final cost = d[RedemptionFields.cost];
    final code = d[RedemptionFields.code];
    if (id is! String || cost is! num || code is! String) return null;
    final at = d[RedemptionFields.createdAt];
    return Redemption(
      rewardId: id,
      cost: cost.toInt(),
      code: code,
      at: at is Timestamp ? at.toDate() : null,
    );
  }
}

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => FirestoreShopRepository(
    ref.watch(firestoreProvider),
    ref.watch(gameRepositoryProvider),
  ),
);
