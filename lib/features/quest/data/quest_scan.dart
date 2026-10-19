import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/clock.dart';
import '../../../core/firestore/collections.dart';
import '../../../core/game/game_config.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/geo.dart';
import '../../auth/data/auth_repository.dart';
import '../../game/game_service.dart';
import 'quest_repository.dart';

/// Why a scan did not count (S11 messages).
enum ScanProblem {
  /// «Kod nieważny»: not a quest code, unknown place or wrong code.
  invalidCode,

  /// «Ten kod już dziś zeskanowałeś».
  alreadyToday,

  /// «Jesteś za daleko od miejsca» (> 150 m).
  tooFar,

  /// No position: location is needed to confirm the visit.
  noLocation,

  /// Network or other error.
  failed,
}

@immutable
sealed class ScanResult {
  const ScanResult();
}

class ScanSuccess extends ScanResult {
  const ScanSuccess({required this.stop, required this.award});

  final QuestStop stop;
  final GameAward award;
}

class ScanFailure extends ScanResult {
  const ScanFailure(this.problem, {this.distanceMeters});

  final ScanProblem problem;
  final double? distanceMeters;
}

/// S11 checks, in order: quest code → already today → within 150 m → the
/// visit write (the rules compare the code) → points and badges.
class QuestScanService {
  QuestScanService(this._ref);

  final Ref _ref;

  Future<ScanResult> scan(String raw) async {
    final code = QuestCode.parse(raw);
    if (code == null) return const ScanFailure(ScanProblem.invalidCode);
    final uid = _ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return const ScanFailure(ScanProblem.failed);

    final Quest quest;
    try {
      quest = await _ref.read(questProvider.future);
    } catch (e) {
      debugPrint('Quest not loaded: $e');
      return const ScanFailure(ScanProblem.failed);
    }
    final stop = quest.stop(code.placeId);
    final place = stop?.place;
    if (stop == null || place == null) {
      return const ScanFailure(ScanProblem.invalidCode);
    }

    final now = _ref.read(clockProvider)();
    final visits = await _visitIds(uid);
    if (visits.contains(visitId(uid, code.placeId, now))) {
      return const ScanFailure(ScanProblem.alreadyToday);
    }

    final LatLng position;
    try {
      position = await _ref.read(locationServiceProvider).current();
    } on LocationUnavailable {
      return const ScanFailure(ScanProblem.noLocation);
    }
    final distance = distanceMeters(position, place.latLng);
    if (distance > GameConfig.scanMaxDistanceMeters) {
      return ScanFailure(ScanProblem.tooFar, distanceMeters: distance);
    }

    try {
      await _ref
          .read(questRepositoryProvider)
          .addVisit(
            uid: uid,
            placeId: code.placeId,
            code: code.code,
            lat: position.latitude,
            lon: position.longitude,
            now: now,
          );
    } on VisitRejected {
      // The repeat case was checked above, so the code is wrong (or the
      // place's code was rotated).
      return const ScanFailure(ScanProblem.invalidCode);
    } catch (e) {
      debugPrint('Saving the visit failed: $e');
      return const ScanFailure(ScanProblem.failed);
    }

    GameAward award;
    try {
      award = await _ref.read(gameServiceProvider).placeScanned(code.placeId);
    } catch (e) {
      // The visit counts; points may be missing until the next event.
      debugPrint('Awarding the scan failed: $e');
      award = GameAward.none;
    }
    return ScanSuccess(stop: stop, award: award);
  }

  /// Today's repeat is checked here; if the list cannot be read, the rules
  /// still reject a second visit.
  Future<Set<String>> _visitIds(String uid) async {
    try {
      return await _ref
          .read(questRepositoryProvider)
          .watchVisits(uid)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Visits not read: $e');
      return const {};
    }
  }
}

final questScanServiceProvider = Provider<QuestScanService>(
  QuestScanService.new,
);
