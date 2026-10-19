import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/clock.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../cool_places/data/places_providers.dart';

/// The quest «Chłodne hasło»: places in order with their letters.
@immutable
class Quest {
  const Quest({required this.id, required this.places, required this.password});

  static const defaultId = 'chlodne-haslo-2026';

  final String id;

  /// In letter order, with name and position from the cool places list.
  final List<QuestStop> places;

  /// E.g. «CHŁODNO»: the file's password, or the letters in order.
  final String password;

  QuestStop? stop(String placeId) {
    for (final s in places) {
      if (s.placeId == placeId) return s;
    }
    return null;
  }

  /// Ignores case and spaces. Polish letters count: «Ł» is not «L».
  bool checkPassword(String typed) =>
      typed.trim().toUpperCase().replaceAll(' ', '') == password.toUpperCase();
}

@immutable
class QuestStop {
  const QuestStop({required this.quest, this.place});

  final QuestPlace quest;

  /// The matching cool place (name, position, hours); null if missing.
  final Place? place;

  String get placeId => quest.placeId;
  String get letter => quest.letter;
  int get order => quest.order;
}

/// The quest from the bundled `quest.json` (module D has no quest
/// endpoint; Firestore `questPlaces` is seeded from the same file).
final questProvider = FutureProvider<Quest>((ref) async {
  final raw = await ref.watch(assetLoaderProvider)('assets/demo/quest.json');
  final data = QuestData.fromJson(jsonDecode(raw) as Object);
  final places = await ref.watch(coolPlacesProvider.future);
  final byId = {for (final p in places) p.id: p};
  final ordered = data.ordered;
  return Quest(
    id: data.questId ?? Quest.defaultId,
    places: [
      for (final q in ordered) QuestStop(quest: q, place: byId[q.placeId]),
    ],
    password: data.password ?? ordered.map((q) => q.letter).join(),
  );
}, retry: noRetry);

/// `visits/{uid}_{placeId}_{yyyyMMdd}` of the signed-in user.
abstract interface class QuestRepository {
  /// Visit ids (see `visitId()`), live.
  Stream<Set<String>> watchVisits(String uid);

  /// Creates the visit. The rules reject a wrong code, an unknown place,
  /// another day and a second scan today: [VisitRejected].
  Future<void> addVisit({
    required String uid,
    required String placeId,
    required String code,
    required double lat,
    required double lon,
    required DateTime now,
  });
}

class VisitRejected implements Exception {
  const VisitRejected();
}

class FirestoreQuestRepository implements QuestRepository {
  FirestoreQuestRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Set<String>> watchVisits(String uid) => _db
      .collection(FirestoreCollections.visits)
      .where(VisitFields.uid, isEqualTo: uid)
      .snapshots()
      .map((q) => {for (final d in q.docs) d.id});

  @override
  Future<void> addVisit({
    required String uid,
    required String placeId,
    required String code,
    required double lat,
    required double lon,
    required DateTime now,
  }) async {
    try {
      await _db
          .collection(FirestoreCollections.visits)
          .doc(visitId(uid, placeId, now))
          .set({
            VisitFields.uid: uid,
            VisitFields.placeId: placeId,
            VisitFields.code: code,
            VisitFields.lat: lat,
            VisitFields.lon: lon,
            VisitFields.createdAt: FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const VisitRejected();
      rethrow;
    }
  }
}

final questRepositoryProvider = Provider<QuestRepository>(
  (ref) => FirestoreQuestRepository(ref.watch(firestoreProvider)),
);

/// Place ids the user has visited (any day).
final visitedPlacesProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref
      .watch(questRepositoryProvider)
      .watchVisits(uid)
      .map((ids) => {for (final id in ids) ?placeIdOfVisit(id, uid)});
});

/// Place ids visited today (Polish date of the device).
final visitedTodayProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  final today = visitId('', '', ref.read(clockProvider)()).substring(2);
  return ref
      .watch(questRepositoryProvider)
      .watchVisits(uid)
      .map(
        (ids) => {
          for (final id in ids)
            if (id.endsWith(today)) ?placeIdOfVisit(id, uid),
        },
      );
});

/// `{uid}_{placeId}_{yyyyMMdd}` → placeId.
String? placeIdOfVisit(String visitId, String uid) {
  final prefix = '${uid}_';
  if (!visitId.startsWith(prefix) || visitId.length < prefix.length + 10) {
    return null;
  }
  return visitId.substring(prefix.length, visitId.length - 9);
}

/// A scanned quest QR: `coollodz://quest/{placeId}?c={kod}`.
@immutable
class QuestCode {
  const QuestCode(this.placeId, this.code);

  final String placeId;
  final String code;

  static QuestCode? parse(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'coollodz' ||
        uri.host != 'quest' ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final code = uri.queryParameters['c'];
    if (code == null || code.isEmpty) return null;
    return QuestCode(uri.pathSegments.single, code);
  }
}
