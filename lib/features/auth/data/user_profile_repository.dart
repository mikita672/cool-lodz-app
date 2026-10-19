import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../profile/data/comfort_profile.dart';

/// Choices from S03 (spec: `users/{uid}.consents`).
@immutable
class Consents {
  const Consents({
    required this.location,
    required this.push,
    required this.ranking,
  });

  final bool location;
  final bool push;
  final bool ranking;

  @override
  bool operator ==(Object other) =>
      other is Consents &&
      other.location == location &&
      other.push == push &&
      other.ranking == ranking;

  @override
  int get hashCode => Object.hash(location, push, ranking);

  @override
  String toString() =>
      'Consents(location: $location, push: $push, ranking: $ranking)';
}

/// The account document `users/{uid}`.
abstract interface class UserProfileRepository {
  /// Called once on registration.
  Future<void> createProfile({required String uid, required String nickname});

  /// Creates `users/{uid}` with [nickname] when it is missing (a sign-up
  /// whose profile write never reached the server). Keeps an existing one.
  Future<void> ensureProfile({required String uid, required String nickname});

  /// Saves S03 choices with `acceptedAt` set by the server.
  Future<void> saveConsents(String uid, Consents consents);

  /// Whether S03 was completed for this account.
  Future<bool> hasAcceptedConsents(String uid);

  /// The S03 choices, or null when S03 was never completed.
  Future<Consents?> loadConsents(String uid);

  /// Stores (or with null removes) `fcmToken` for heat alerts.
  Future<void> saveFcmToken(String uid, String? token);

  /// Saves the S04 choice as `profile` {id, weights, seniorMode}.
  Future<void> saveComfortProfile(String uid, ComfortProfile profile);

  /// The saved S04 choice, or null when S04 was never completed (or the
  /// saved value cannot be read).
  Future<ComfortProfile?> loadComfortProfile(String uid);
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<void> createProfile({required String uid, required String nickname}) =>
      // merge: S03 may already have written consents if this write was slow.
      _doc(uid).set({
        'nickname': nickname,
        'points': 0,
        'weekPoints': 0,
        'badges': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> ensureProfile({
    required String uid,
    required String nickname,
  }) async {
    final snapshot = await _doc(uid).get();
    if (snapshot.exists) return;
    await createProfile(uid: uid, nickname: nickname);
  }

  @override
  Future<void> saveConsents(String uid, Consents consents) {
    final batch = _firestore.batch()
      ..set(_doc(uid), {
        'consents': {
          'location': consents.location,
          'push': consents.push,
          'ranking': consents.ranking,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
        if (!consents.push) 'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    // The rules want no public ranking copy without the consent (e.g. S03
    // shown again after it had been on).
    if (!consents.ranking) {
      batch.delete(_firestore.collection('rankings').doc(uid));
    }
    return batch.commit();
  }

  @override
  Future<bool> hasAcceptedConsents(String uid) async {
    final snapshot = await _doc(uid).get();
    return snapshot.data()?['consents'] is Map;
  }

  @override
  Future<Consents?> loadConsents(String uid) async {
    final raw = (await _doc(uid).get()).data()?['consents'];
    if (raw is! Map) return null;
    return Consents(
      location: raw['location'] == true,
      push: raw['push'] == true,
      ranking: raw['ranking'] == true,
    );
  }

  @override
  Future<void> saveFcmToken(String uid, String? token) => _doc(
    uid,
  ).set({'fcmToken': token ?? FieldValue.delete()}, SetOptions(merge: true));

  @override
  Future<void> saveComfortProfile(String uid, ComfortProfile profile) =>
      _doc(uid).set({'profile': profile.toJson()}, SetOptions(merge: true));

  @override
  Future<ComfortProfile?> loadComfortProfile(String uid) async {
    final snapshot = await _doc(uid).get();
    final raw = snapshot.data()?['profile'];
    if (raw is! Map) return null;
    try {
      return ComfortProfile.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('Unreadable users/$uid.profile: $e');
      return null;
    }
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firestoreProvider)),
);
