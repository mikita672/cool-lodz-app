import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';

/// S15 problem types (`FirestoreReports.types`).
enum ReportType {
  noBench('noBench'),
  noWater('noWater'),
  noShade('noShade'),
  other('other');

  const ReportType(this.id);

  final String id;
}

/// `reports/{id}`: created by the author with status `new`; the status is
/// changed by hand in the Firebase console (approved → +20 points).
abstract interface class ReportRepository {
  /// A new id for one report: S15 keeps it, so a retry after a timeout
  /// writes the same document (the rules allow create only) instead of a
  /// duplicate report.
  String newId();

  Future<void> create({
    required String id,
    required String uid,
    required ReportType type,
    required double lat,
    required double lon,
    String? comment,
  });
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db);

  final FirebaseFirestore _db;

  @override
  String newId() => _db.collection(FirestoreCollections.reports).doc().id;

  @override
  Future<void> create({
    required String id,
    required String uid,
    required ReportType type,
    required double lat,
    required double lon,
    String? comment,
  }) {
    final text = comment?.trim();
    return _db.collection(FirestoreCollections.reports).doc(id).set({
      ReportFields.uid: uid,
      ReportFields.type: type.id,
      ReportFields.lat: lat,
      ReportFields.lon: lon,
      if (text != null && text.isNotEmpty)
        ReportFields.comment: text.characters
            .take(FirestoreReports.commentMaxLength)
            .toString(),
      ReportFields.status: FirestoreReports.statusNew,
      ReportFields.createdAt: FieldValue.serverTimestamp(),
    });
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FirestoreReportRepository(ref.watch(firestoreProvider)),
);
