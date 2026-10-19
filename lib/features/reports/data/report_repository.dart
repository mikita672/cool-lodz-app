import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<void> create({
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
  Future<void> create({
    required String uid,
    required ReportType type,
    required double lat,
    required double lon,
    String? comment,
  }) {
    final text = comment?.trim();
    return _db.collection(FirestoreCollections.reports).add({
      ReportFields.uid: uid,
      ReportFields.type: type.id,
      ReportFields.lat: lat,
      ReportFields.lon: lon,
      if (text != null && text.isNotEmpty)
        ReportFields.comment: text.length > FirestoreReports.commentMaxLength
            ? text.substring(0, FirestoreReports.commentMaxLength)
            : text,
      ReportFields.status: FirestoreReports.statusNew,
      ReportFields.createdAt: FieldValue.serverTimestamp(),
    });
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FirestoreReportRepository(ref.watch(firestoreProvider)),
);
