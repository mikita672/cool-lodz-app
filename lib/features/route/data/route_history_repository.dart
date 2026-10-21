import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/models/models.dart';

/// A route the user started with «Prowadź» (decision Q-08, #45). Used for
/// badges (Pierwszy krok, Cienista dziesiątka, Ranny ptaszek, Łowca parków)
/// and route points.
@immutable
class StartedRoute {
  const StartedRoute({
    required this.from,
    required this.to,
    required this.departAt,
    required this.variant,
    required this.sunShare,
    required this.distanceM,
    this.endPlaceType,
    this.durationS,
    this.shortestSunShare,
    this.waterStops,
  });

  final RoutePoint from;
  final RoutePoint to;
  final DateTime departAt;
  final RouteVariantType variant;

  /// 0..1 at [departAt].
  final double sunShare;
  final int distanceM;

  /// Category of the destination place (`park`, `library`…), null for an
  /// address.
  final String? endPlaceType;

  /// Walking time of the chosen variant.
  final int? durationS;

  /// The shortest variant's sun share at [departAt] («Twój wpływ»: sun
  /// avoided).
  final double? shortestSunShare;

  /// Drinking water points along the way.
  final int? waterStops;

  double get shadeShare => 1 - sunShare;

  Map<String, Object?> toFirestore() => {
    RouteFields.from: _point(from),
    RouteFields.to: _point(to),
    RouteFields.departAt: Timestamp.fromDate(departAt),
    RouteFields.variant: variant.name,
    RouteFields.sunShare: sunShare,
    RouteFields.distanceM: distanceM,
    RouteFields.endPlaceType: endPlaceType,
    RouteFields.createdAt: FieldValue.serverTimestamp(),
    RouteFields.durationS: ?durationS,
    RouteFields.shortestSunShare: ?shortestSunShare,
    RouteFields.waterStops: ?waterStops,
  };

  static Map<String, Object?> _point(RoutePoint p) => {
    'lat': p.lat,
    'lon': p.lon,
    if (p.label != null) 'label': p.label,
  };
}

/// `users/{uid}/routes`: create, read (badges) and delete (account removal).
abstract interface class RouteHistoryRepository {
  Future<void> add(String uid, StartedRoute route);
}

class FirestoreRouteHistoryRepository implements RouteHistoryRepository {
  FirestoreRouteHistoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> add(String uid, StartedRoute route) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.routes)
      .add(route.toFirestore());
}

final routeHistoryRepositoryProvider = Provider<RouteHistoryRepository>(
  (ref) => FirestoreRouteHistoryRepository(ref.watch(firestoreProvider)),
);
