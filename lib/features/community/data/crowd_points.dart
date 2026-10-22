import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../auth/data/auth_repository.dart';

/// What the community marks on the map.
enum CrowdKind {
  /// «Posadź tu drzewo»: a street with no shade.
  tree,

  /// «Kranówka tu»: free tap water (a café, a public tap).
  tap,
}

/// A point added by a user; others vote («Popieram») or confirm
/// («Potwierdzam»).
@immutable
class CrowdPoint {
  const CrowdPoint({
    required this.id,
    required this.kind,
    required this.point,
    required this.uid,
    this.note = '',
    this.votes = 0,
    this.createdAt,
  });

  final String id;
  final CrowdKind kind;
  final LatLng point;
  final String uid;
  final String note;
  final int votes;
  final DateTime? createdAt;

  static CrowdPoint? fromDoc(String id, Map<String, dynamic> d) {
    final kind = CrowdKind.values
        .where((k) => k.name == d[CrowdFields.kind])
        .firstOrNull;
    final lat = d[CrowdFields.lat];
    final lon = d[CrowdFields.lon];
    if (kind == null || lat is! num || lon is! num) return null;
    final at = d[CrowdFields.createdAt];
    return CrowdPoint(
      id: id,
      kind: kind,
      point: LatLng(lat.toDouble(), lon.toDouble()),
      uid: d[CrowdFields.uid] as String? ?? '',
      note: d[CrowdFields.note] as String? ?? '',
      votes: (d[CrowdFields.votes] as num?)?.toInt() ?? 0,
      createdAt: at is Timestamp ? at.toDate() : null,
    );
  }
}

abstract final class CrowdFields {
  static const uid = 'uid';
  static const kind = 'kind';
  static const lat = 'lat';
  static const lon = 'lon';
  static const note = 'note'; // ≤ 120 characters
  static const votes = 'votes'; // +1 per user, see votes/{uid}
  static const createdAt = 'createdAt';
}

/// Łódź and around: points outside are refused (also by the rules).
bool inLodz(LatLng p) =>
    p.latitude >= 51.68 &&
    p.latitude <= 51.86 &&
    p.longitude >= 19.32 &&
    p.longitude <= 19.64;

const crowdNoteMax = 120;

/// The points as GeoJSON for the city (Zarząd Zieleni Miejskiej, Wody
/// Miejskie): «where people want trees» / «where the tap water is».
String crowdGeoJson(Iterable<CrowdPoint> points) =>
    const JsonEncoder.withIndent(' ').convert({
      'type': 'FeatureCollection',
      'features': [
        for (final p in points)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                double.parse(p.point.longitude.toStringAsFixed(6)),
                double.parse(p.point.latitude.toStringAsFixed(6)),
              ],
            },
            'properties': {
              'kind': p.kind.name,
              'votes': p.votes,
              if (p.note.isNotEmpty) 'note': p.note,
              if (p.createdAt case final at?)
                'created': at.toUtc().toIso8601String(),
            },
          },
      ],
    });

/// The user already voted for this point.
class AlreadyVoted implements Exception {
  const AlreadyVoted();
}

abstract interface class CrowdRepository {
  /// The newest [limit] points.
  Stream<List<CrowdPoint>> watch({int limit = 500});

  Future<void> add(
    String uid,
    CrowdKind kind,
    LatLng point, {
    String note = '',
  });

  /// +1 vote; throws [AlreadyVoted].
  Future<void> vote(String uid, CrowdPoint point);

  /// Only the user's own point.
  Future<void> remove(CrowdPoint point);
}

class FirestoreCrowdRepository implements CrowdRepository {
  FirestoreCrowdRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _points =>
      _db.collection(FirestoreCollections.crowdPoints);

  static const commitWait = Duration(seconds: 5);

  @override
  Stream<List<CrowdPoint>> watch({int limit = 500}) => _points
      .orderBy(CrowdFields.createdAt, descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (q) => [for (final d in q.docs) ?CrowdPoint.fromDoc(d.id, d.data())],
      );

  @override
  Future<void> add(
    String uid,
    CrowdKind kind,
    LatLng point, {
    String note = '',
  }) async {
    final text = note.trim();
    await _points
        .add({
          CrowdFields.uid: uid,
          CrowdFields.kind: kind.name,
          CrowdFields.lat: point.latitude,
          CrowdFields.lon: point.longitude,
          if (text.isNotEmpty)
            CrowdFields.note: text.length > crowdNoteMax
                ? text.substring(0, crowdNoteMax)
                : text,
          CrowdFields.votes: 0,
          CrowdFields.createdAt: FieldValue.serverTimestamp(),
        })
        .timeout(commitWait, onTimeout: () => _points.doc());
  }

  @override
  Future<void> vote(String uid, CrowdPoint point) async {
    final ref = _points.doc(point.id);
    final vote = ref.collection(FirestoreCollections.votes).doc(uid);
    if ((await vote.get()).exists) throw const AlreadyVoted();
    final batch = _db.batch()
      ..set(vote, {CrowdFields.createdAt: FieldValue.serverTimestamp()})
      ..update(ref, {CrowdFields.votes: FieldValue.increment(1)});
    await batch.commit().timeout(commitWait, onTimeout: () {});
  }

  @override
  Future<void> remove(CrowdPoint point) => _points.doc(point.id).delete();
}

final crowdRepositoryProvider = Provider<CrowdRepository>(
  (ref) => FirestoreCrowdRepository(ref.watch(firestoreProvider)),
);

/// Everyone's points (signed in only: the rules require it).
final crowdPointsProvider = StreamProvider<List<CrowdPoint>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(crowdRepositoryProvider).watch();
});
