import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

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

  /// Saves S03 choices with `acceptedAt` set by the server.
  Future<void> saveConsents(String uid, Consents consents);

  /// Whether S03 was completed for this account.
  Future<bool> hasAcceptedConsents(String uid);
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
  Future<void> saveConsents(String uid, Consents consents) => _doc(uid).set({
    'consents': {
      'location': consents.location,
      'push': consents.push,
      'ranking': consents.ranking,
      'acceptedAt': FieldValue.serverTimestamp(),
    },
  }, SetOptions(merge: true));

  @override
  Future<bool> hasAcceptedConsents(String uid) async {
    final snapshot = await _doc(uid).get();
    return snapshot.data()?['consents'] is Map;
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firestoreProvider)),
);
