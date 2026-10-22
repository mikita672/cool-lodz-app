import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../auth/data/user_profile_repository.dart';

/// S16 changes to `users/{uid}` that touch the public ranking, and the
/// account removal.
abstract interface class AccountRepository {
  /// Sets the district (a `FirestoreDistricts` id); keeps `rankings/{uid}`
  /// in step when the user takes part in the ranking.
  Future<void> setDistrict(String uid, String district);

  /// Saves new S03 choices. Turning the ranking on publishes
  /// `rankings/{uid}`; turning it off deletes it in the same batch (the
  /// rules require both).
  Future<void> setConsents(String uid, Consents consents);

  /// Deletes every document of the user (Q-10): points log, routes,
  /// visits, reports, the ranking copy and `users/{uid}`.
  Future<void> deleteUserData(String uid);
}

class FirestoreAccountRepository implements AccountRepository {
  FirestoreAccountRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection(FirestoreCollections.users).doc(uid);

  DocumentReference<Map<String, dynamic>> _ranking(String uid) =>
      _db.collection(FirestoreCollections.rankings).doc(uid);

  Map<String, Object?> _mirror(Map<String, dynamic> user) => {
    RankingFields.nickname: user[UserFields.nickname],
    RankingFields.district: user[UserFields.district],
    RankingFields.points: user[UserFields.points] ?? 0,
    RankingFields.weekId: user[UserFields.weekId],
    RankingFields.weekPoints: user[UserFields.weekPoints] ?? 0,
    RankingFields.updatedAt: FieldValue.serverTimestamp(),
  };

  static bool _rankingOn(Map<String, dynamic> user) {
    final c = user[UserFields.consents];
    return c is Map && c[UserFields.consentRanking] == true;
  }

  @override
  Future<void> setDistrict(String uid, String district) async {
    final user = (await _user(uid).get()).data() ?? {};
    final batch = _db.batch()
      ..update(_user(uid), {UserFields.district: district});
    if (_rankingOn(user)) {
      batch.set(
        _ranking(uid),
        _mirror({...user, UserFields.district: district}),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> setConsents(String uid, Consents consents) async {
    final user = (await _user(uid).get()).data() ?? {};
    final batch = _db.batch()
      ..update(_user(uid), {
        '${UserFields.consents}.${UserFields.consentLocation}':
            consents.location,
        '${UserFields.consents}.${UserFields.consentPush}': consents.push,
        '${UserFields.consents}.${UserFields.consentRanking}': consents.ranking,
        if (!consents.push) UserFields.fcmToken: FieldValue.delete(),
      });
    if (consents.ranking) {
      batch.set(_ranking(uid), _mirror(user));
    } else {
      batch.delete(_ranking(uid));
    }
    await batch.commit();
  }

  @override
  Future<void> deleteUserData(String uid) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final sub in [
      FirestoreCollections.pointsLog,
      FirestoreCollections.routes,
      FirestoreCollections.redemptions,
    ]) {
      final q = await _user(uid).collection(sub).get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    for (final col in [
      FirestoreCollections.visits,
      FirestoreCollections.reports,
      FirestoreCollections.crowdPoints,
    ]) {
      final q = await _db
          .collection(col)
          .where(VisitFields.uid, isEqualTo: uid)
          .get();
      refs.addAll(q.docs.map((d) => d.reference));
    }
    refs
      ..add(_ranking(uid))
      ..add(_user(uid));
    // A batch holds at most 500 writes.
    for (var i = 0; i < refs.length; i += 450) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(450)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => FirestoreAccountRepository(ref.watch(firestoreProvider)),
);
